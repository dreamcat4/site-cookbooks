maintainer        "Opscode, Inc."
maintainer_email  "cookbooks@opscode.com"
license           "Apache 2.0"
description       "Installs erlang"
version           "0.7"

%w{ ubuntu debian mac_os_x }.each do |os|
  supports os
end
