#!/bin/bash

# Download and install the remote_syslog2 binary from papertrail
wget https://github.com/papertrail/remote_syslog2/releases/download/v0.20-beta2/remote_syslog_linux_amd64.tar.gz
tar xzf ./remote_syslog*.tar.gz
mv remote_syslog remote_syslog_dir
cd remote_syslog_dir
sudo cp ./remote_syslog /usr/local/bin

# Set it up as a service (assumes init script has already been cp'd)
sudo chmod +x /etc/init.d/remote_syslog
sudo service remote_syslog start
sudo update-rc.d remote_syslog defaults
