maintainer       "Opscode, Inc."
maintainer_email "cookbooks@opscode.com"
license          "Apache 2.0"
description      "Configures RubyGems-installed Chef"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.1"

%w{ ubuntu debian redhat centos fedora freebsd openbsd mac_os_x }.each do |os|
  supports os
end

%w{ chef runit couchdb rabbitmq apache2 nanite }.each do |cb|
  depends cb
end
