#
# Cookbook Name:: mac_os_x
# Attributes:: mac_os_x
#
# Copyright 2008-2009, Opscode, Inc.
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


#######################################################################################################
# software_update
# 

# Notice: This must always be set !! otherwise, 'softwareupdate' will fail and error out
set_unless[:mac_os_x][:swupdate][:admin_user] = nil     # the unix usename of an admin user

set_unless[:mac_os_x][:swupdate][:server_url] = nil     # default: "http://swscan.apple.com:8088"
set_unless[:mac_os_x][:swupdate][:frequency] = "weekly" # "daily", "weekly", "monthly"

set_unless[:mac_os_x][:swupdate][:apple_check] = false  # how the regular SU GUI pops up
set_unless[:mac_os_x][:swupdate][:by_host_id]  = nil    # in most cases, not needed

# use the zeller check to download and install updates automatically
# if a reboot is required, then updates will be installed next boot
set_unless[:mac_os_x][:swupdate][:zeller_check] = true

# do not set this if the node already gets rebooted from time to time
# it displays a very dodgy-looking dialog box (most times not needed)
set_unless[:mac_os_x][:swupdate][:zeller][:prompt_user_reboot] = false

# if you set this option, the node will reboot itself at random times, unexpectedly,
# and without warning. may be okay for certain kinds of headless osx-server
set_unless[:mac_os_x][:swupdate][:zeller][:automatic_reboot] = false

# Generally we dont need to mess around with these
set_unless[:mac_os_x][:swupdate][:com_apple_SoftwareUpdate] = {
  "AgreedToLicenseAgrement" => true,
  "AutomaticDownload"       => true,
  "BackgroundDownload"      => true,
  "LaunchAppInBackground"   => true
}




#######################################################################################################
# xcode_devtools
# 
# By default we look for the Mac OSX Installation DVD
set_unless[:mac_os_x][:devtools][:install_src] = "/Volumes/Mac OS X Install DVD"

# Otherwise install_src can be...
# os-x dvd dir   "/Volumes/Mac OS X Install DVD"
# http dmg url   "http://url_pointing_to/xcode.dmg"
# dmg file       "/path/to/xcode.dmg"
# directory      "/path/to/installer/dir"

set_unless[:mac_os_x][:devtools][:download_dir] = "/var/tmp"

# occasionally we may need to tweak these options
set_unless[:mac_os_x][:devtools][:force_install] = false
set_unless[:mac_os_x][:devtools][:keep_dmg]  = true
set_unless[:mac_os_x][:devtools][:pkg_names] = [
  "Optional Installs/Xcode Tools/XcodeTools.mpkg",
  "Optional Installs.localized/Xcode.mpkg",
  "XcodeTools.mpkg",
  "Xcode.mpkg",
  "iPhone SDK.mpkg",
  "iPhone SDK and Tools for Snow Leopard.mpkg"
  ]

set_unless[:mac_os_x][:devtools][:updates] = [
  "Xcode3.2.1Update-3.2.1"
  ]

# hardly ever need these
set_unless[:mac_os_x][:devtools][:raise_media_missing] = false
set_unless[:mac_os_x][:devtools][:mountpoint] = "/Volumes/Xcode Devtools Installer"
set_unless[:mac_os_x][:devtools][:eject_dvd] = true

# xcode uninstall command
# sudo /Developer/Library/uninstall-devtools --mode=all




#######################################################################################################
# macports
# 
set_unless[:mac_os_x][:macports][:portfile_url] = \
  "http://svn.macports.org/repository/macports/trunk/dports/sysutils/MacPorts/Portfile"
set_unless[:mac_os_x][:macports][:download_dir] = "/var/tmp"
set_unless[:mac_os_x][:macports][:version] = nil
set_unless[:mac_os_x][:macports][:source_url] = "http://distfiles.macports.org/MacPorts"
set_unless[:mac_os_x][:macports][:raise_media_missing] = false
set_unless[:mac_os_x][:macports][:force_install] = false
set_unless[:mac_os_x][:macports][:mountpoint] = "/Volumes/Macports Installer"
set_unless[:mac_os_x][:macports][:keep_dmg] = true
set_unless[:mac_os_x][:macports][:upgrade_outdated] = false



