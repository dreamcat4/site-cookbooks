#
# Cookbook Name:: restart
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

# These recipes are just examples for the restart functionality


# restart "login_shell" do
#   # this will be executed once and
#   # skiped on subsequent restarts 
# end
# 
# restart "login_shell" do
#   # this will be executed twice
#   # because it includes other restarts (nested)
#   include_recipe "restart::other_example"
# end
# 
# restart "login_shell" do
#   # this will be executed once
# end

 
# env_vars=""
# ENV.each { |k,v| env_vars << "export #{k}=\"#{v}\"\n" }
# puts env_vars



# run_and_restart "os" do
restart "node" do
  # this will be executed twice
  # because it includes other restarts (nested)

  before_restart do
    puts "executing point A"
    include_recipe "restart::nested_example"
    puts "executing point A2"
  end
end




puts "continue point A(end)"
# no more restarts after this point






















