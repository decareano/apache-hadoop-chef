
case node.platform
when "ubuntu"
 if node.platform_version.to_f <= 14.04
   node.override.apache_hadoop.systemd = "false"
 end
end

private_ip = my_private_ip()
public_ip = my_public_ip()

for script in node.apache_hadoop.nn.scripts
  template "#{node.apache_hadoop.home}/sbin/#{script}" do
    source "#{script}.erb"
    owner node.apache_hadoop.hdfs.user
    group node.apache_hadoop.group
    mode 0775
  end
end 

activeNN = true
ha_enabled = false
if node.apache_hadoop.ha_enabled.eql? "true" || node.apache_hadoop.ha_enabled == true
  ha_enabled = true
end

# it is ok if all namenodes format the fs. Unless you add a new one later..
# if the nn has already been formatted, re-formatting it returns error
# TODO: test if the NameNode is running
if ::File.exist?("#{node.apache_hadoop.home}/.nn_formatted") === false || "#{node.apache_hadoop.reformat}" === "true"
  if activeNN == true
    sleep 10
    apache_hadoop_start "format-nn" do
      action :format_nn
      ha_enabled ha_enabled
    end
  else
    # wait for the active nn to come up
    # TODO - copy fsimage over from the active nn
    sleep 100
  end
else 
  Chef::Log.info "Not formatting the NameNode. Remove this directory before formatting: (sudo rm -rf #{node.apache_hadoop.nn.name_dir}/current) and set node.apache_hadoop.reformat to true"
end

if ha_enabled == true

  template "#{node.apache_hadoop.home}/sbin/start-zkfc.sh" do
    source "start-zkfc.sh.erb"
    owner node.apache_hadoop.hdfs.user
    group node.apache_hadoop.group
    mode 0754
  end

  template "#{node.apache_hadoop.home}/sbin/start-standby-nn.sh" do
    source "start-standby-nn.sh.erb"
    owner node.apache_hadoop.hdfs.user
    group node.apache_hadoop.group
    mode 0754
  end


  apache_hadoop_start "zookeeper-format" do
    action :zkfc
    ha_enabled ha_enabled
  end

  if activeNN == false
    apache_hadoop_start "standby-nn" do
      action :standby
      ha_enabled ha_enabled
    end
  end
end

service_name="namenode"

if node.apache_hadoop.systemd == "true"

  case node.platform_family
  when "debian"
    systemd_script = "/lib/systemd/system/#{service_name}.service"
  else
    systemd_script = "/usr/lib/systemd/system/#{service_name}.service" 
  end


  service "#{service_name}" do
    provider Chef::Provider::Service::Systemd
    supports :restart => true, :stop => true, :start => true, :status => true
    action :restart
  end



  template systemd_script do
    source "#{service_name}.service.erb"
    owner "root"
    group "root"
    mode 0754
    notifies :enable, "service[#{service_name}]"
    notifies :restart, "service[#{service_name}]", :immediately
  end


else  #sysv

  service "#{service_name}" do
    provider Chef::Provider::Service::Init::Debian
    supports :restart => true, :stop => true, :start => true, :status => true
    action :restart
  end

  template "/etc/init.d/#{service_name}" do
    source "#{service_name}.erb"
    owner node.apache_hadoop.hdfs.user
    group node.apache_hadoop.group
    mode 0754
    notifies :enable, resources(:service => "#{service_name}")
    notifies :restart, resources(:service => "#{service_name}"), :immediately
  end

end



if node.kagent.enabled == "true" 
  kagent_config "#{service_name}" do
    service "HDFS"
    start_script "#{node.apache_hadoop.home}/sbin/root-start-nn.sh"
    stop_script "#{node.apache_hadoop.home}/sbin/stop-nn.sh"
    init_script "#{node.apache_hadoop.home}/sbin/format-nn.sh"
    config_file "#{node.apache_hadoop.conf_dir}/core-site.xml"
    log_file "#{node.apache_hadoop.logs_dir}/hadoop-#{node.apache_hadoop.hdfs.user}-#{service_name}-#{node.hostname}.log"
    pid_file "#{node.apache_hadoop.logs_dir}/hadoop-#{node.apache_hadoop.hdfs.user}-#{service_name}.pid"
    web_port node.apache_hadoop.nn.http_port
  end
end

