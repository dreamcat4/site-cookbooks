#
# Author:: Joshua Timberman <joshua@opscode.com>
# Cookbook Name:: couchdb
# Recipe:: default
#
# Copyright 2008-2009, Opscode, Inc
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

if platform?("mac_os_x")
  # patch macports couchdb Portfile
  port_dir = "/opt/local/var/macports/sources/rsync.macports.org/release/ports"
  patch_file_source = "couchdb_Portfile.diff"
  patch_file = "/tmp/#{patch_file_source}"

  remote_file "#{patch_file}" do
    source patch_file_source
    owner "root"
    group "admin"
    mode 0644
  end

  bash "Patch couchdb for port load command" do
    code <<-EOH
    patch -Nu "#{port_dir}/databases/couchdb/Portfile" < #{patch_file}
    EOH
    not_if { 
      File.exists?("#{port_dir}/databases/couchdb/Portfile") &&
      File.read("#{port_dir}/databases/couchdb/Portfile") =~ /startupitem\.uniquname/
      }
  end
end

package "couchdb" do
  package_name value_for_platform(
    "openbsd" => { "default" => "apache-couchdb" },
    "gentoo" => { "default" => "dev-db/couchdb" },
    "default" => "couchdb"
  )
end

directory "/var/lib/couchdb" do
  owner "couchdb"
  group "couchdb"
  recursive true
  path value_for_platform(
    "openbsd" => { "default" => "/var/couchdb" },
    "freebsd" => { "default" => "/var/couchdb" },
    "gentoo"  => { "default" => "/var/couchdb" },
    "mac_os_x"  => { "default" => "/opt/local/var/lib/couchdb" },
    "default" => "/var/lib/couchdb"
  )
end

service "couchdb" do
  if platform?("centos","redhat","fedora")
    start_command "/sbin/service couchdb start &> /dev/null;:"
    stop_command "/sbin/service couchdb stop &> /dev/null;:"
    supports [ :restart, :status ]
    action [ :enable, :start ]

  elsif platform?("mac_os_x")
    start_command "launchctl load -w /Library/LaunchDaemons/org.apache.couchdb.plist &> /dev/null"
    stop_command "launchctl unload -w /Library/LaunchDaemons/org.apache.couchdb.plist &> /dev/null"
    # start_command "port load couchdb &> /dev/null"
    # stop_command "port unload couchdb &> /dev/null"
    action [ :start ]
  else
    supports [ :restart, :status ]
    action [ :enable, :start ]
  end
end
