#
# Cookbook Name:: restart
# Library:: restart
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

require "fileutils"
module FileUtils
  class << self
    def mountpoints
      m = `mount`.split("\n")
      m.map! do |s|
        s.gsub!(/( on )(.*) \([^\(\)]*\)$/,"")
        $2
      end
      m.delete("/")
      return m
    end

    def on_mounted_dir?(path)
      return false unless path
      mountpoints.each do |m|
        if path =~ Regexp.new("^#{m}")
          return true
        end
      end
      return false
    end
  end
end


class Chef
  class Resource
    class Restart < Chef::Resource

      def initialize(name, collection=nil, node=nil)
        super(name, collection, node)
        @resource_name = :restart
        @context = name || "node"
        @shell   = nil
        @creates = nil
        @action = "restart"
        @allowed_actions.push(:restart)
      end

      def context(arg=nil)
        set_or_return(
          :context,
          arg,
          :kind_of => [ String ],
          :regex => [ /^(chef|login_shell|node)$/ ]
        )
      end

      def shell(arg=nil)
        set_or_return(
          :shell,
          arg,
          :kind_of => [ String ],
          :regex => [ /^(sh|bash|csh|tcsh|ash|dash|ksh|zsh)$/ ]
        )
      end

      def creates(arg=nil)
        set_or_return(
          :creates,
          arg,
          :kind_of => [ String ]
        )
      end

      def before_restart(arg=nil, &block)
        arg ||= block
        set_or_return(:before_restart, arg, :kind_of => [Proc, String])
      end

    end
  end

  class Provider
    class Restart < Chef::Provider

      def load_current_resource
        Chef::Log.debug(@new_resource.inspect)
        true
      end

      # Saving state to the constant CHEF_RESTART isnt ideal. Perhaps that could be changed
      CHEF_RESTART = {}

      def eval_and_converge(&blk)
        tmp_collection = Chef::ResourceCollection.new
        tmp_recipe = Chef::Recipe.new(@new_resource.cookbook_name, @new_resource.recipe_name, @node, tmp_collection)
        tmp_recipe.instance_eval(&(blk))
        Chef::Runner.new(@node,tmp_collection).converge
      end

      def spawning_shell?
        parent = `ps c -o command= #{Process.ppid}`.delete("\n")
        [:sh,:bash,:csh,:tcsh,:ash,:dash,:ksh,:zsh].each do |shell|
          return shell.to_s if parent =~ Regexp.new("^-?#{shell.to_s}")
        end
        return nil
      end

      def user_shell
        user = ENV['SUDO_USER'] || Etc.getpwuid(Process::UID.eid).name
        user_shell = File.basename(Etc.getpwnam(user).shell)
      end

      def shell_best_guess
        spawning_shell? || user_shell
      end

      def action_restart
        @counter ||= CHEF_RESTART[:counter] ||= {}
        @recipe_context ||= CHEF_RESTART[:recipe_context] ||= []
        @new_resource.shell shell_best_guess unless @new_resource.shell

        @run_state_pfx = "CHEF_RUN_PART__"
        @run_state = "#{@run_state_pfx}#{convert_to_class_name(@new_resource.cookbook_name.to_s)}#{convert_to_class_name(@new_resource.recipe_name.to_s)}"
        @recipe_context.push(@run_state)

        incr_count()
        
        if @new_resource.creates
          if ::File.exists?(@new_resource.creates)
            Chef::Log.debug("Skipping restart \##{count} in Cookbook: #{@new_resource.cookbook_name}, Recipe: #{@new_resource.recipe_name} - creates #{@new_resource.creates} exists.")
            return false
          end
        end
        
        if env == count.to_s
          incr_env()
          descr = "Restart \##{count} in Cookbook: #{@new_resource.cookbook_name}, Recipe: #{@new_resource.recipe_name}"
          prepare_reboot!(@new_resource) if @new_resource.context == "node"
          Chef::Log.info("Executing #{descr}...")

          begin
            case @new_resource.before_restart
            when String
              Chef::Mixin::Command.run_command(:command => @new_resource.before_restart)
            when Proc
              eval_and_converge &(@new_resource.before_restart)
            end
          rescue
            cancel_reboot!(@new_resource) if @new_resource.context == "node"
            raise
          end

          Chef::Log.info("#{descr} done.")
          @run_state = @recipe_context.pop
          restart!
        else
          @run_state = @recipe_context.pop
        end
      end

      def incr_count
        @counter[@run_state] ||= 0
        @counter[@run_state]  += 1
      end

      def count
        @counter[@run_state]
      end

      def incr_env
        if(@recipe_context.length > 1)
          last_stack_level = @recipe_context[@recipe_context.length-2]
          ENV[last_stack_level] = (ENV[last_stack_level].to_i-1).to_s
        end
        ENV[@run_state] ||= "0"
        ENV[@run_state] = (ENV[@run_state].to_i+1).to_s
      end

      def env
        ENV[@run_state] ||= "1"
      end

      def cancel_reboot!(new_resource)
        eval_and_converge do
          Chef::Log.info("Cancelling pending restart, backing out...")
          @new_resource = new_resource
          
          case node[:platform]
          when "debian", "ubuntu"
            bootscript_basename = "chef-restart"
            bootscript_symlink = "/etc/init.d/#{bootscript_basename}"
            link bootscript_symlink do
              action :delete
              only_if { ::File.exists? bootscript_symlink }
            end

            execute "rc disable" do
              command "update-rc.d -f #{bootscript_basename} remove"
            end

          when "mac_os_x"
            bootscript_basename = "com.opscode.chef-restart.plist"
            bootscript_symlink = "/Library/LaunchDaemons/#{bootscript_basename}"
            link bootscript_symlink do
              action :delete
              only_if { ::File.exists? bootscript_symlink }
            end
          end

          if node[:restart][:cleanup_temp_path]
            directory node[:restart][:temp_path] do
               action :delete
               recursive true
               only_if { ::File.exists? node[:restart][:temp_path] }
            end
          end

          Chef::Log.info("Done.")
        end 
      end

      def prepare_reboot!(new_resource)
        eval_and_converge do
          Chef::Log.info("Scheduling chef restart on next boot...")
          @new_resource = new_resource

          root_group = value_for_platform(
            "openbsd" => { "default" => "wheel" },
            "freebsd" => { "default" => "wheel" },
            "mac_os_x"  => { "default" => "admin" },
            "default" => "root"
          )

          args = $*.dup

          if node[:restart][:raise_on_mounted_volumes]
            Chef::Config[:cookbook_path].each do |path|
              if ::FileUtils.on_mounted_dir?(path)
                Chef::Log.info("Cookbook path '#{path}' appears to be on a mounted volume")
                Chef::Log.info("Cant gaurantee that this volume will be available during boot time")
                raise "Set [:restart][:raise_on_mounted_volumes] = false to override."          
              end
            end

            if ::FileUtils.on_mounted_dir?(::FileUtils.pwd)
              Chef::Log.info("Current working directory '#{::FileUtils.pwd}' appears to be on a mounted volume")
              Chef::Log.info("Cant gaurantee that this volume will be available during boot time")
              raise "Set [:restart][:raise_on_mounted_volumes] = false to override."
            end

            if ::FileUtils.on_mounted_dir?($0)
              Chef::Log.info("The executable '#{$0}' appears to be on a mounted volume")
              Chef::Log.info("Cant gaurantee that this volume will be available during boot time")
              raise "Set [:restart][:raise_on_mounted_volumes] = false to override."
            end

            args.each do |arg|
              file = nil
              file = arg                           if ::File.exists?(arg) 
              file = ::File.join(FileUtils.pwd,arg)  if ::File.exists?(::File.join(::FileUtils.pwd,arg))
              if ::FileUtils.on_mounted_dir?(file)
                Chef::Log.info("File #{f} appears to be on a mounted volume")
                Chef::Log.info("Cant gaurantee that this volume will be available during boot time")
                raise "Set [:restart][:raise_on_mounted_volumes] = false to override."
              end
            end
          end

          env_vars=""
          if node[:restart][:preserve_environment]
            ENV.each { |k,v| env_vars << "export #{k}=\"#{v}\"\n" unless k == "CHEF_RUN_WAIT_REBOOT" }
          else
            ENV.each { |k,v| env_vars << "export #{k}=\"#{v}\"\n" if k =~ Regexp.new("^#{@run_state_pfx}") }
          end
          env_vars.gsub!(/\n\z/,"")

          if ENV['SUDO_UID'] && ENV['SUDO_GID']
            if node[:restart][:use_sudo_nopasswd]
              # check sudo can be executed without password
              `sudo -u #{Etc.getpwuid(ENV['SUDO_UID'].to_i).name} sudo -n sleep 0`
              sudo_nopasswd = true if $?.exitstatus == 0
            end
          else
            # restart node manually without sudo (not implemented, requires runit)
            unless Etc.getpwuid(Process::UID.eid).name == "root"
              raise "Insufficient permissions. We need superuser credentials to set up the necessary boot scripts."
            end
          end

          quoted_args = "'" << args.join("' '") << "'" unless args.empty?
          cmd = %Q{'#{$0}' #{quoted_args}}

          directory node[:restart][:temp_path] do
              owner "root"
              group root_group
              mode "755"
              recursive true
          end

          file node[:restart][:log_file] do
            owner "root"
            group root_group
            mode "644"
            backup false
          end

          # Nested restart blocks: we can remove any restart script that was written earlier on
          # because we are only interested in continuing after the last (inner) point in execution
          # So we remember any current / previous continue_script to the global constant here:
          if CHEF_RESTART[:continue_script]
            file CHEF_RESTART[:continue_script] do
              action :delete
              backup false
            end
          end

          chef_continue_run_basename = "continue_run__#{convert_to_class_name(@new_resource.cookbook_name.to_s)}#{convert_to_class_name(@new_resource.recipe_name.to_s)}"
          chef_continue_run = "#{node[:restart][:temp_path]}/#{chef_continue_run_basename}"
          CHEF_RESTART[:continue_script] = chef_continue_run

          shell = @new_resource.shell

          run_login_shell_basename = "run_login_shell"
          run_login_shell = "#{node[:restart][:temp_path]}/#{run_login_shell_basename}"

          template run_login_shell do
            source "run_login_shell.sh.erb"
            owner "root"
            group root_group
            mode "755"
            backup false
            variables(
              :shell => shell,
              :sudo_nopasswd => sudo_nopasswd,
              :user => ENV['SUDO_USER'] || Etc.getpwuid(Process::UID.eid).name,
              :chef_continue_run   => chef_continue_run
            )
          end

          case node[:platform]
          when "debian", "ubuntu"
            # write boot script
            bootscript_basename = "chef-restart"
            bootscript = "#{node[:restart][:temp_path]}/#{bootscript_basename}"
            template bootscript do
              source "chef-restart.init.erb"
              owner "root"
              group root_group
              mode "755"
              backup false
              variables(
                :run_login_shell => run_login_shell,
                :log_file => node[:restart][:log_file]
              )
            end
            # enable boot script
            bootscript_symlink = "/etc/init.d/#{bootscript_basename}"
            link bootscript_symlink do
              to bootscript
            end
            execute "rc enable" do
              command "update-rc.d #{bootscript_basename} start 89 S ." # where halt=90
            end
            rc_disable = "update-rc.d -f #{bootscript_basename} remove"

          when "mac_os_x"
            # write boot script
            bootscript_basename = "com.opscode.chef-restart.plist"
            bootscript = "#{node[:restart][:temp_path]}/#{bootscript_basename}"
            template bootscript do
              source "com.opscode.chef-restart.plist.erb"
              owner "root"
              group root_group
              mode "644"
              backup false
              variables(
                :label => "com.opscode.chef-restart",
                :run_login_shell => run_login_shell,
                :run_at_load => true,
                :debug => true,
                :log_file => node[:restart][:log_file]
              )
            end
            # enable boot script
            bootscript_symlink = "/Library/LaunchDaemons/#{bootscript_basename}"
            link bootscript_symlink do
              to bootscript
            end
          end

          # if the file was touched, then we have pending restarts so we
          # update the mtime/atime for the script "chef_continue_run"
          # this flicks the wait_restart variable in the continue script
          file bootscript_symlink do
            action :touch
          end
          
          shell = @new_resource.shell
          cookbook_name = @new_resource.cookbook_name.to_s
          recipe_name = @new_resource.recipe_name.to_s

          # script to restart chef after the next reboot
          template chef_continue_run do
            source "chef_continue_run.sh.erb"
            owner "root"
            group root_group

            if node[:restart][:preserve_environment]
              mode "700"
            else
              mode "755"
            end
            backup false
            variables(
              :cookbook_name => cookbook_name,
              :recipe_name => recipe_name,
              :shell => shell,
              :env_vars => env_vars,
              :working_directory => FileUtils.pwd,
              :cmd  => cmd,
              :chef_continue_run   => chef_continue_run,
              :bootscript_symlink  => bootscript_symlink,
              :sudo_nopasswd => sudo_nopasswd,
              :remove_files => node[:restart][:cleanup_temp_path],
              :temp_path => node[:restart][:temp_path],
              :rc_disable => rc_disable
            )
          end

          Chef::Log.info("Done.")
        end
      end
      
      include Chef::Mixin::Language
      def restart!(msg="Restarting #{@new_resource.context}...")
        if @new_resource.context == "node"
          if platform?("ubuntu","debian","mac_os_x")

            unless node[:restart][:reboot_unattended]
              Chef::Log.info("Chef run is pending Reboot.")
              Chef::Log.info("Output will be appended to: #{node[:restart][:log_file]}.")
              Chef::Log.info("")
              Chef::Log.info("#################################################################")
              Chef::Log.info("#  !! Chef run not yet complete !!  Please reboot to continue.  #")
              Chef::Log.info("#################################################################")
              exit 0
            end
          else
            raise Chef::Exceptions::UnsupportedAction, "Run and restart does not support rebooting the operating system"
          end
        end
        if fork # we're the parent
          Chef::Log.info(msg)
          exit 0
        else
          # in child
          sleep 0.1 until(Process.ppid() == 1)
          quoted_args = "'" << $*.join("' '") << "'" unless $*.empty?
          if @new_resource.context == "chef"
            exec %Q{'#{$0}' #{quoted_args}}

          elsif @new_resource.context == "login_shell"
            exec %Q{/usr/bin/env printf "'#{$0}' #{quoted_args}" | /usr/bin/env #{@new_resource.shell} -l}

          elsif @new_resource.context == "node"
            # gracefully shutdown / restart the computer
            Chef::Log.info("Rebooting to complete Chef Run")
            Chef::Log.info("Output will be appended to: #{node[:restart][:log_file]}")
            sleep 3
            exec "shutdown -r now"
            exit 0
          else
            raise Chef::Exceptions::UnsupportedAction, "Unsupported restart context. Default is \"node\""
          end
        end
      end

    end
  end
end

Chef::Platform.platforms[:default].merge! :restart => Chef::Provider::Restart

