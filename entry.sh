#!/bin/sh
service mysql start
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start mysql: $status"
  exit $status
fi

if [ -f /root/.env ]
then
  echo "Setup has not been run yet, launching bash"
  cd /root
  exec bash
fi

service gotrue start
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start gotrue: $status"
  exit $status
fi

service git-gateway start
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start git-gateway: $status"
  exit $status
fi

service nginx start
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start git-gateway: $status"
  exit $status
fi

while sleep 60; do
  ps aux |grep gotrue/gotrue |grep -q -v grep
  PROCESS_1_STATUS=$?
  ps aux |grep mysqld_safe |grep -q -v grep
  PROCESS_2_STATUS=$?
  ps aux |grep git-gateway |grep -q -v grep
  PROCESS_3_STATUS=$?
  ps aux |grep sbin/nginx |grep -q -v grep
  PROCESS_4_STATUS=$?
  # If the greps above find anything, they exit with 0 status
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 -o $PROCESS_2_STATUS -ne 0 -o $PROCESS_3_STATUS -ne 0 -o $PROCESS_4_STATUS -ne 0 ]; then
    echo "One of the processes has already exited."
    exit 1
  fi
done