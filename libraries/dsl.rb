#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

# These files create / add to the Delivery::DSL module
require_relative 'helpers'
require_relative 'helpers_functional'
require_relative 'helpers_lint'
require_relative 'helpers_unit'

# And these mix the DSL methods into the Chef infrastructure
Chef::Recipe.send(:include, DeliveryTruck::DSL)
Chef::Resource.send(:include, DeliveryTruck::DSL)
Chef::Provider.send(:include, DeliveryTruck::DSL)
