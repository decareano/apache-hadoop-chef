#!/bin/bash

command=namenode
h=`hostname`

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin"; pwd`

DEFAULT_LIBEXEC_DIR="$bin"/../libexec
HADOOP_LIBEXEC_DIR=${HADOOP_LIBEXEC_DIR:-$DEFAULT_LIBEXEC_DIR}
. $HADOOP_LIBEXEC_DIR/hadoop-config.sh
. ${bin}/set-env.sh

log=<%= node[:hadoop][:logs_dir] %>/hadoop-<%= node[:hdfs][:user] %>-$command-$h.log

"$bin"/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs $command -bootstrapStandby -force
sleep 2; head "$log"

PID_FILE=$HADOOP_PID_DIR/hadoop-<%= node[:hdfs][:user] %>-$command.pid
PID=`cat $PID_FILE` 
kill -0 $PID 

exit $?

