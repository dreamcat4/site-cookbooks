log_level          :info
log_location       STDOUT
cookbook_path [ "/srv/chef/site-cookbooks", "/srv/chef/cookbooks" ]
ssl_verify_mode    :verify_none
Chef::Log::Formatter.show_time = false
