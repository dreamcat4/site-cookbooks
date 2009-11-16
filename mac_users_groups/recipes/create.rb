#
# Cookbook Name:: mac_users_groups
# Recipe:: default
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

group "ding" do
  members ["white"]
  action :create
end

user "ding" do
  comment "Ding Master"
  home "/Users/ding"
  # shell "/bin/bash"
  gid 20
  # password "ding"
  supports :manage_home => true
  action :create
end

user "higgins" do
  comment "John Higgins"
  home "/Users/higgins"
  password ""
  shell ""
  gid "admin"
  action :create
end

user "white" do
  comment "Jimmy White"
  home "/Users/white"
  gid "wheel"
  password "jimmy"
  supports :manage_home => true
  action :create
end


