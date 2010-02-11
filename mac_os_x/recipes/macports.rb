#
# Cookbook Name:: mac_os_x
# Recipe:: macports
#
# Copyright 2009, Opscode, Inc.
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

include_recipe "mac_os_x::xcode_devtools"

if ::Chef::VERSION =~ /^0\.7\./
  # chef 0.7.16 is missing the "log" resource
  def log msg
    ruby_block do
      block do
        Chef::Log.info msg
      end
    end
  end
end

def raise_or_warn err_msg
  node[:mac_os_x][:macports][:raise_media_missing] ? raise(err_msg) : Chef::Log.warn(err_msg)
end

mpver = "1.8.1"
node[:mac_os_x][:macports][:version]
node[:mac_os_x][:macports][:source_url]

macports_dmg = nil
dmg_file = nil

if !File.exists?("/opt/local/bin/port") || node[:mac_os_x][:macports][:force_install]
  unless Etc.getpwuid(Process::UID.eid).name == "root"
    raise "Insufficient permissions. We need superuser credentials to install macports."
  end

  case node[:platform_version]
  when /^10\.5/
    macports_dmg = "MacPorts-#{node[:mac_os_x][:macports][:version]}-10.5-Leopard.dmg"

  when /^10\.6/
    macports_dmg = "MacPorts-#{node[:mac_os_x][:macports][:version]}-10.6-SnowLeopard.dmg"
  end

  if macports_dmg
    dmg_file = "/var/tmp/#{macports_dmg}"
    r = remote_file dmg_file do
      source "#{node[:mac_os_x][:macports][:source_url]}/#{macports_dmg}"
      mode "0644"
      not_if { File.exists? dmg_file }
    end
    r.run_action(:create) unless File.exists?(dmg_file)
  else
    raise_or_warn "macports: version not known or not supported - #{node[:platform]} #{node[:platform_version]}"
  end

  attach_cmd = "hdiutil attach \"#{dmg_file}\" -mountpoint \"#{node[:mac_os_x][:macports][:mountpoint]}\""
  r = execute attach_cmd do
    creates node[:mac_os_x][:macports][:mountpoint]
    action :nothing
  end
  r.run_action(:run)

  p_path = "#{node[:mac_os_x][:macports][:mountpoint]}/MacPorts-#{node[:mac_os_x][:macports][:version]}.pkg"
  macports_pkg = p_path if File.exists? p_path
  raise_or_warn "mac_os_x: The macports installer was not found. Dmg file: #{dmg_file}" unless macports_pkg

  if macports_pkg
    log "mac_os_x: Found macports install pkg at"
    log "          #{macports_pkg}"
    log "mac_os_x: installing MacPorts..."
    bash "install macports" do 
      code "installer -pkg \"#{macports_pkg}\" -target / -verbose -dumplog -dumplog"
    end
    log "mac_os_x: MacPorts installed."

    execute "hdiutil detach \"#{node[:mac_os_x][:macports][:mountpoint]}\"" do
      only_if { File.exists? node[:mac_os_x][:macports][:mountpoint] }
    end
  end
else  
  log "mac_os_x: Updating the ports tree..."
  execute "port selfupdate -d"
  if node[:mac_os_x][:macports][:upgrade_outdated]
    log "Upgrading outdated ports..."
    execute "port upgrade outdated"
  end
end




