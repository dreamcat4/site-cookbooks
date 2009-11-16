#
# Cookbook Name:: rvm
# Attributes:: rvm
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

# Where to install rvm
set_unless[:rvm][:path] = "/opt/rvm"

# version to install, by default: http://rvm.beginrescueend.com/releases/stable-verison.txt
# to override, set here the github branch or tag
# set_unless[:rvm][:version] = nil
set_unless[:rvm][:version] = nil # must be nil (stable), at least "0.1.16", or "master"

set_unless[:rvm][:download_dir] = "/var/tmp"

# Flick this to true if you want rvm updated to head (bleeding edge).
set_unless[:rvm][:head] = false

# Where to put rvm on the $PATH
set_unless[:rvm][:symlink_path] = "/usr/bin"

# This is the ruby that chef will boot into
set_unless[:rvm][:default_ruby] = "ree"

# Other ruby versions to install
set_unless[:rvm][:rubies] = [
#   "ree",
#   "1.9.1-p376",
#   "1.9.2",
#   "1.8.6-r24700",
#   "rbx-head"
]

# flick these to install the relevant package dependencies
set_unless[:rvm][:jruby_deps] = false
set_unless[:rvm][:mri_ree_deps] = false
set_unless[:rvm][:ironruby_deps] = false

# Default rubygems options
# set_unless[:rvm][:gem][:string] = "--no-rdoc --no-ri"
set_unless[:rvm][:gem][:string] = ""

# Copy over the system gems as their latest versions (as opposed to the same versions)
set_unless[:rvm][:dump_gems_latest] = false

# We believe these are the best gems sources
set_unless[:rvm][:gem][:sources] = [
  "http://gems.opscode.com",
  "http://gemcutter.org",
  "http://gems.rubyforge.org",
  "http://gems.github.com"
]

set_unless[:rvm][:gem][:backtrace] = true
set_unless[:rvm][:gem][:verbose] = true


# Compile ruby as either 32-bit or 64-bit.
# Default: `uname -m`. You generally don't want to mess with this.
# set_unless[:rvm][:architecture] = "i386" || "x86_64" 




# Do not edit below this point
# set_unless[:rvm][:bin] = "#{rvm[:path]}/bin/rvm"


