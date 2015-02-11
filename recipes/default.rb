#
# Cookbook: delivery-truck
# Recipe: default
#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

ENV['PATH'] = "/opt/chefdk/bin:/opt/chefdk/embedded/bin:#{ENV['PATH']}"

#######################################################################

remote_file "chefdk-0.4.0" do
  path "#{Chef::Config[:file_cache_path]}/chefdk-0.4.0.deb"
  source "https://web-dl.packagecloud.io/chef/stable/packages/ubuntu/trusty/chefdk_0.4.0-1_amd64.deb"
  checksum "e135c0719fc80fc7b95560e90839103167308a45d4927cf8da9c22bdc385cc7d"
  notifies :install, "dpkg_package[chefdk-0.4.0]", :immediately
end

dpkg_package "chefdk-0.4.0" do
  source "#{Chef::Config[:file_cache_path]}/chefdk-0.4.0.deb"
  action :nothing
end
