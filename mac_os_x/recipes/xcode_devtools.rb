#
# Cookbook Name:: mac_os_x
# Recipe:: xcode_devtools
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
  node[:mac_os_x][:devtools][:raise_media_missing] ? raise(err_msg) : Chef::Log.warn(err_msg)
end

def iphone_sdk_warnings
  [
    "***********************************************************************************************",
    "mac_os_x: By default, iPhone SDK is ***NOT*** selected in the package options (requires SLA)...",
    "mac_os_x: for iPhoneSDK, edit the file iPhoneSDK.dist or reinstall with the Graphical Installer",
    "mac_os_x: ref http://www.ajobi.net/arthurlockman/2009/07/iphone-development-on-a-powerbook.html",
    "***********************************************************************************************"
  ]
end

if !File.exists?("/Developer/Applications/Xcode.app") || node[:mac_os_x][:devtools][:force_install]
  unless Etc.getpwuid(Process::UID.eid).name == "root"
    raise "Insufficient permissions. We need superuser credentials to install xcode devtools."
  end
  dmg_file = nil
  xcode_pkg = nil

  case node[:mac_os_x][:devtools][:install_src]
  when /^http:\/\/.*\.dmg$/
    dmg_file = "/var/tmp/#{File.basename(node[:mac_os_x][:devtools][:install_src])}"
    Chef::Log.info "mac_os_x: downloading xcode developer tools, this can take some time..."
    Chef::Log.info "mac_os_x: http_get: #{node[:mac_os_x][:devtools][:install_src]}"
    r = remote_file dmg_file do
      source node[:mac_os_x][:devtools][:install_src]
      mode "644"
    end
    r.run_action(:create) unless File.exists?(dmg_file)
  when /^.*\.dmg$/
    dmg_file = node[:mac_os_x][:devtools][:install_src]
  end

  case node[:mac_os_x][:devtools][:install_src]
  when /^.*\.dmg$/

    attach_cmd = "hdiutil attach \"#{dmg_file}\" -mountpoint \"#{node[:mac_os_x][:devtools][:mountpoint]}\""
    r = execute attach_cmd do
      creates node[:mac_os_x][:devtools][:mountpoint]
      action :nothing
    end
    r.run_action(:run)

    node[:mac_os_x][:devtools][:pkg_names].each do |p|
      p_path = "#{node[:mac_os_x][:devtools][:mountpoint]}/#{p}"
      xcode_pkg = p_path if File.exists? p_path
    end
    raise_or_warn "mac_os_x: The xcode installer was not found. Dmg file: #{dmg_file}" unless xcode_pkg

  when /^\/.*/
    dvd_path = node[:mac_os_x][:devtools][:install_src]
    if File.exists?(dvd_path)
      node[:mac_os_x][:devtools][:pkg_names].each do |p|
        p_path = "#{dvd_path}/#{p}"
        xcode_pkg = p_path if File.exists? p_path
      end
      raise_or_warn "mac_os_x: Xcode installer was not found. Wrong Install DVD? Mount point: \"#{dvd_path}\"" unless xcode_pkg
    else
      raise_or_warn "mac_os_x: Installer directory not found, or DVD not mounted"
    end
  end

  if xcode_pkg
    log "mac_os_x: Found xcode install pkg at"
    log "          #{xcode_pkg}"
    iphone_sdk_warnings.each { |w| log w } if xcode_pkg =~ /iphone/i
    log "mac_os_x: installing Xcode developer tools, this can take a while..."
    execute "installer -pkg \"#{xcode_pkg}\" -target / -verbose -dumplog"
    log "mac_os_x: Devtools installed."

    log "mac_os_x: Checking for updates, this can take a while..."
    devtools_updates = node[:mac_os_x][:devtools][:updates]
    pending_updates = []
    ruby_block do
      block do
        raise "mac_os_x: No admin user set (node[:mac_os_x][:swupdate][:admin_user])" unless node[:mac_os_x][:swupdate][:admin_user]
        admin_user = node[:mac_os_x][:swupdate][:admin_user]
        available_updates = `su #{admin_user} -c "softwareupdate --list"`
        devtools_updates.each do |u|
          esc_u = Regexp.escape u
          if available_updates.include? u
            unless available_updates =~ /#{esc_u}\n.*restart.*$/i
              pending_updates << u
            end
          end
        end
      end
    end
    
    execute "post-install... xcode updates" do
      command "softwareupdate --install #{pending_updates.join(' ')} --verbose"
      not_if { pending_updates.empty? }
    end

    if node[:mac_os_x][:devtools][:install_src] =~ /^\/.*$/
      execute "diskutil eject \"#{node[:mac_os_x][:devtools][:install_src]}\"; :" do
        only_if { node[:mac_os_x][:devtools][:eject_dvd] }
      end
    else
      execute "hdiutil detach \"#{node[:mac_os_x][:devtools][:mountpoint]}\"" do
        only_if { File.exists? node[:mac_os_x][:devtools][:mountpoint] }
      end
    end

    if node[:mac_os_x][:devtools][:install_src] =~ /^http:\/\/.*\.dmg$/
      unless node[:mac_os_x][:devtools][:keep_dmg]
        file dmg_file do
          action :delete
          backup false
        end
      end
    end

  end

end



