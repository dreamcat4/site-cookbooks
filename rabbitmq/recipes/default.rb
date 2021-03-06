#
# Author:: Daniel DeLeo <dan@kallistec.com>
#
# Cookbook Name:: rabbitmq
# Recipe:: default
#
# Copyright 2009, Daniel DeLeo
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


# Is this valid for all platforms? Is it not just rabbitmq on some platform?
# Valid for ubuntu, *probably* debian and EL5
# http://download.fedora.redhat.com/pub/epel/5/x86_64/repoview/letter_r.group.html

if platform?("mac_os_x")
  include_recipe "erlang"
end

package "rabbitmq-server"

service "rabbitmq-server" do
  if platform?("centos","redhat","fedora")
    start_command "/sbin/service rabbitmq-server start &> /dev/null"
    stop_command "/sbin/service rabbitmq-server stop &> /dev/null"
    supports [ :restart, :status ]
    action [ :enable, :start ]

  elsif platform?("mac_os_x")
    # start_command "launchctl load -w /Library/LaunchDaemons/org.macports.rabbitmq-server.plist &> /dev/null"
    # stop_command "launchctl unload -w /Library/LaunchDaemons/org.macports.rabbitmq-server.plist &> /dev/null"
    start_command "port load rabbitmq-server &> /dev/null;:"
    stop_command "port unload rabbitmq-server &> /dev/null;:"
    action [ :start ]
  else
    supports [ :restart, :status ]
    action [ :enable, :start ]
  end
end
