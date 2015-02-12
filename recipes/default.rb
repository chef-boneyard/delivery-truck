#
# Cookbook: delivery-truck
# Recipe: default
#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

ENV['PATH'] = "/opt/chefdk/bin:/opt/chefdk/embedded/bin:#{ENV['PATH']}"

#######################################################################


# This is a temporary workaround until a more suitable long term plan can be
# found. Maybe by incorporating the install.sh script directly or by using
# the package cloud resources.
chefdk_version = '0.4.0'

remote_file "#{Chef::Config[:file_cache_path]}/install.sh" do
  source "https://www.chef.io/chef/install.sh"
  mode "0755"
end

execute "install_chefdk" do
  command "#{Chef::Config[:file_cache_path]}/install.sh -P chefdk -v #{chefdk_version}"
  not_if "chef --version | grep #{chefdk_version}"
end
