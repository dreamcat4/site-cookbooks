#
# Cookbook Name:: mac_os_x
# Recipe:: software_update
#
# Copyright 2010, Opscode, Inc.
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

raise "mac_os_x: can't find PlistBuddy. Looked for /usr/libexec/PlistBuddy" unless File.exists?("/usr/libexec/PlistBuddy")

def plist_buddy(plist, cmd)
  `/usr/libexec/PlistBuddy -c "#{cmd}" "#{plist}"`.strip
end

unless Etc.getpwuid(Process::UID.eid).name == "root"
  raise "mac_os_x: Insufficient permissions. We need superuser credentials to configure Apple Software Update."
end

raise "mac_os_x: No admin user set (node[:mac_os_x][:swupdate][:admin_user])" unless node[:mac_os_x][:swupdate][:admin_user]
admin_user = node[:mac_os_x][:swupdate][:admin_user]

root_group = value_for_platform(
  "mac_os_x"  => { "default" => "admin" },
  "default" => "root"
)


# defaults -currentHost read com.apple.SoftwareUpdate
node[:mac_os_x][:swupdate][:com_apple_SoftwareUpdate].each do |key,val|
  execute "defaults -currentHost write com.apple.SoftwareUpdate #{key} -bool #{val}"
end


# defaults -currentHost read /Library/Preferences/com.apple.SoftwareUpdate CatalogURL
if node[:mac_os_x][:swupdate][:server_url]
  execute "defaults -currentHost write /Library/Preferences/com.apple.SoftwareUpdate CatalogURL \"#{node[:mac_os_x][:swupdate][:server_url]}\""
else
  execute "defaults -currentHost delete /Library/Preferences/com.apple.SoftwareUpdate CatalogURL; :"
end


interval = nil
case node[:mac_os_x][:swupdate][:frequency]
when "daily"
  interval = 86400
when "weekly"
  interval = 604800 
when "monthly"
  interval = 2592000
else
  if node[:mac_os_x][:swupdate][:apple_check] || node[:mac_os_x][:swupdate][:zeller_check]
    raise "mac_os_x: Software Update period \"#{node[:mac_os_x][:swupdate][:frequency]}\" not known. Valid values are \"daily\", \"weekly\" and \"monthly\" or false"
  end
end



# defaults -currentHost read ~/Library/Preferences/com.apple.scheduler
if node[:mac_os_x][:swupdate][:apple_check]

  unless `su #{admin_user} -c "softwareupdate --schedule"` =~ /on/
    `su #{admin_user} -c "softwareupdate --schedule on"`
  end

  by_host_id = node[:mac_os_x][:swupdate][:by_host_id] if node[:mac_os_x][:swupdate][:by_host_id]
  admin_home = `dscl . read /Users/#{admin_user} NFSHomeDirectory`.delete("\n").gsub(/NFSHomeDirectory: /,"")
  scheduler_glob = "#{admin_home}/Library/Preferences/ByHost/com.apple.scheduler.#{by_host_id}*.plist"
  scheduler_plist = Dir.glob(scheduler_glob)
  raise "mac_os_x: cant set scheduler preferences, no matches found for #{scheduler_glob}" unless scheduler_plist.first
  raise "mac_os_x: cant set scheduler preferences, set please set node[:mac_os_x][:swupdate][:by_host_id] (its a mac_addr or uuid)" unless scheduler_plist.size == 1
  repeat_interval_key = ":AbsoluteSchedule:com.apple.SoftwareUpdate:SUCheckSchedulerTag:Timer:repeatInterval"
  repeat_interval = plist_buddy(scheduler_plist[0],"print #{repeat_interval_key}").strip.to_i

  unless interval == repeat_interval
    plist_buddy(scheduler_plist,"set #{repeat_interval_key} #{interval}")
    execute "su #{admin_user} -c \"softwareupdate --schedule on\""
  end

else
  unless `su #{admin_user} -c "softwareupdate --schedule"` =~ /off/
    execute "su #{admin_user} -c \"softwareupdate --schedule off\""
  end
end



# zeller update script
if node[:mac_os_x][:swupdate][:zeller_check]
  # This script's launch time is determined by
  # /System/Library/LaunchDaemons/com.apple.periodic-%w{daily weekly monthly}.plist  
  # For more control, we might create our own launchd plist (not implemented)
  template "/etc/periodic/#{node[:mac_os_x][:swupdate][:frequency]}/zeller_swupdate.sh" do
    source "zeller_swupdate.sh.erb"
    owner "root"
    group root_group
    mode "755"
    backup false
    variables(
      :admin_user => node[:mac_os_x][:swupdate][:admin_user],
      :prompt_user_reboot => node[:mac_os_x][:swupdate][:zeller][:prompt_user_reboot],
      :automatic_reboot   => node[:mac_os_x][:swupdate][:zeller][:automatic_reboot]
    )
  end
else
  ["daily","weekly","monthly"].each do |p|
    zus = "/etc/periodic/#{p}/zeller_swupdate.sh"
    file zus do
      action :delete
      backup false
      only_if { File.exists? zus }
    end
  end
end


