#
# Cookbook Name:: restart
# Attributes:: restart
#
# Copyright 2008-2010, Opscode, Inc.
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


# For restart "node" context
set_unless[:restart][:temp_path] = "/var/tmp/chef-restart"
set_unless[:restart][:log_file]  = "/var/log/chef/solo.log"

set_unless[:restart][:cleanup_temp_path]        = true
set_unless[:restart][:reboot_unattended]        = false
set_unless[:restart][:preserve_environment]     = false

set_unless[:restart][:use_sudo_nopasswd]        = true
set_unless[:restart][:raise_on_mounted_volumes] = true

# set_unless[:restart][:use_runit] # not implemented






