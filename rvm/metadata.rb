maintainer        "Opscode, Inc."
maintainer_email  "cookbooks@opscode.com"
license           "Apache 2.0"
description       "Installs ruby version manager"
version           "0.7"

%w{ centos redhat fedora ubuntu debian mac_os_x }.each do |os|
  supports os
end
