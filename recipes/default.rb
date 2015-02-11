#
# Cookbook: delivery-truck
# Recipe: default
#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

ENV['PATH'] = "/opt/chefdk/bin:/opt/chefdk/embedded/bin:#{ENV['PATH']}"

#######################################################################

gem_package "chefspec" do
  version "4.1.1"
end
