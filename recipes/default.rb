#
# Cookbook: delivery-truck
# Recipe: default
#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

ENV['PATH'] = "/opt/chefdk/bin:/opt/chefdk/embedded/bin:#{ENV['PATH']}"

#######################################################################


# This is a temporary workaround until a more suitable long term plan can be
# found. Maybe by incorporating packagecloud directly.
chefdk_version = '0.4.0'

execute "install_chefdk" do
  command "curl https://www.chef.io/chef/install.sh | bash -- -P chefdk -v #{chefdk_version}"
  not_if "chef --version | grep #{chefdk_version}"
end
