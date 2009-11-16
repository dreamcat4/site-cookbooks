#
# Cookbook Name:: rvm
# Recipe:: default
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

def eval_and_converge(&blk)
  tmp_collection = Chef::ResourceCollection.new
  tmp_recipe = Chef::Recipe.new(@cookbook_name, @recipe_name, @node, tmp_collection)
  tmp_recipe.instance_eval(&(blk))
  Chef::Runner.new(@node,tmp_collection).converge
end

package "curl"
package "patch" unless platform?("mac_os_x")

if node[:rvm][:jruby_deps]
  case node[:platform]
  when "debian", "ubuntu"
    package "sun-java6-bin"
    package "sun-java6-jre"
    package "sun-java6-jdk"
  when "mac_os_x"
    package "openjdk6"
  end
end

if node[:rvm][:mri_ree_deps]
  package "bison"
  package "git-core"
  case node[:platform]
  when "debian", "ubuntu"
    package "build-essential"
    package "zlib1g-dev"
    package "libssl-dev"
    package "libreadline5-dev"
    package "libxml2-dev"
  when "man_os_x"
    package "zlib"
    package "openssl"
    package "readline"
    package "libxml2"
  end
end

if node[:rvm][:ironruby_deps]
  if node[:rvm][:jruby_deps]
    case node[:platform]
    when "debian", "ubuntu"
      package "mono-2.0-devel"
    when "mac_os_x"
      package "mono"
    end
  end 
end
   
root_group = value_for_platform(
  "openbsd" => { "default" => "wheel" },
  "freebsd" => { "default" => "wheel" },
  "mac_os_x"  => { "default" => "admin" },
  "default" => "root"
)


template "/etc/gemrc" do
  source "gemrc.erb"
  owner "root"
  group root_group
  mode "644"
  backup false
end

template "/etc/rvmrc" do
  source "rvmrc.erb"
  owner "root"
  group root_group
  mode "644"
  backup false
end


rvm_bin = "#{node[:rvm][:path]}/bin/rvm"
unless File.exists?(rvm_bin)
  # Install rvm
  rvm_version = nil
  if node[:rvm][:version]
    rvm_version = node[:rvm][:version]
  else
    eval_and_converge do
      stable_version = "#{node[:rvm][:download_dir]}/rvm-stable-version.txt"

      remote_file stable_version do
        source "http://rvm.beginrescueend.com/releases/stable-version.txt"
        mode "644"
        backup false
      end

      ruby_block do
        block do
          rvm_version = `cat #{stable_version}`.match(/^(.*)$/)[1]
          raise "Couldn't parse rvm_version" unless rvm_version
        end
      end
    end
  end

  rvm_tarball = "#{node[:rvm][:download_dir]}/rvm-#{rvm_version}.tar.gz"
  rvm_tarball_src = "http://github.com/wayneeseguin/rvm/tarball/#{rvm_version}"
  
  remote_file rvm_tarball do
    source rvm_tarball_src
    mode "644"
    backup false
  end

  directory node[:rvm][:path] do
    recursive true
    mode "755"
  end

  rvm_path = node[:rvm][:path]
  ruby_block "Installing rvm..." do
    block do
      `tar -xzvf "#{rvm_tarball}" --strip 1 -C "#{rvm_path}"`
      # Chef::Log.info `bash -l -c "#{rvm_path}/install --auto"`
      Chef::Log.info `bash -l -c "cd #{rvm_path}; export rvm_path=#{rvm_path}; export source_path=#{rvm_path}; #{rvm_path}/install --auto --prefix #{rvm_path}"`
    end
    not_if { File.exists?("#{rvm_bin}") }
  end
  
  restart "login_shell"
end

# # update rvm
# execute "Updating Ruby Version Manager (rvm)" do
#   node[:rvm][:head] ? command("rvm update --head") : command("rvm update")
#   only_if { File.exists?(rvm_bin) }
# end


# stdout = `#{rvm_bin} #{node[:rvm][:default_ruby]}`
# if $?.exitstatus == 0
#   # update default ruby
# else
#   # install default ruby
#   execute "Installing default ruby #{node[:rvm][:default_ruby]}..." do
#     command "rvm install #{node[:rvm][:default_ruby]}"
#   end
# end

bash "Installing default ruby #{node[:rvm][:default_ruby]}..." do
  code    "#{rvm_bin} --default install #{node[:rvm][:default_ruby]}"
  not_if  "#{rvm_bin} #{node[:rvm][:default_ruby]}"
end


# install array list of rubies
node[:rvm][:rubies].each do |r|
  bash "Installing #{r}..." do
    code    "#{rvm_bin} install #{r}"
    not_if  "#{rvm_bin} #{r}"
  end
end


# we might need to re-think this and use come 
# comparison method agains the gems files
def gems_not_in(new_gems, old_gems)
  # convert to arrays
  o = old_gems.gsub(/^#.*$/,"").split
  n = new_gems.gsub(/^#.*$/,"").split
  missing_gems = o - n
end

# # reinstall any initial gems (from the stock ruby)
# gems_file="#{node[:rvm][:path]}/tmp/starter.gems"
# unless File.exists?(gems_file)
#   rvm_flags = "--latest" if node[:rvm][:dump_gems_latest]
#   dump_cmd = "rvm #{rvm_flags} gems dump #{gems_file}"
#   
#   bash "Re-install the stock ruby gems" do
#     code <<-EOH
#     # get gems list
#     rvm use system
#     #{dump_cmd}
# 
#     # read gems list, copy any existing gems onto the default rvm ruby
#     rvm use #{node[:rvm][:default_ruby]}
#     rvm gems load #{gems_file}
#     EOH
#     # creates gems_file
#   end
# end


# # install chef 0.8.0 from HEAD
# restart "login_shell" do
#   before_restart do
#     include_recipe "git"
# 
#     git "/opt/git/chef" do
#       repository "git://github.com/opscode/chef.git"
#       reference "HEAD"
#       action :sync
#     end
#   
#     # 0.8.0 build dependancies:
#     # chef gem            : {rake, cucumber, rspec}
#     # chef-server-api gem : {merb-core}
#     # chef-solr gem       : {jeweler}
#     %w{ rake cucumber rspec merb-core jeweler }.each do |gem|
#       gem_package gem
#     end
# 
#     execute "cd /opt/git/chef && rake install"
# 
#     # restart the new chef and continue
#     new_chef_binary = $0.split("/").last
#     $0 = new_chef_binary
#   end
# end



# restart "login_shell" do
#   before_restart do
#     gem_package "rvm"
#     rvm_install = "rvm-install"
#     case node[:platform]
#     when "debian", "ubuntu"
#       if ENV['SUDO_USER']
#         gem_bin_path = `gem env`.match(/EXECUTABLE DIRECTORY: (.*)$/)[1]
#         puts "gem_bin_path = #{gem_bin_path}"
#         rvm_install = "#{gem_bin_path}/rvm-install --auto"
#       end
#     end
#     puts "rvm_install = #{rvm_install}"
#     execute "Installing Ruby Version Manager (rvm)..." do
#       command rvm_install
#     end
#   end
#   not_if { File.exists?(rvm_bin) }
# end





