#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

if defined?(ChefSpec)
  def run_delivery_truck_exec(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:delivery_truck_exec, :run, resource_name)
  end
end
