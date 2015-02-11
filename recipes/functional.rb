#
# Cookbook: delivery-truck
# Recipe: functional
#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

# We aren't at a point where we're ready for functional stuff yet so this
# recipe will do nothing for the time being.

# load_config File.join(repo_path, '.delivery', 'config.json')
#
# changed_cookbooks.each do |cookbook|
#   # Run Test Kitchen against any cookbooks that were modified.
#   delivery_truck_exec "functional_kitchen_#{cookbook[:name]}" do
#     cwd cookbook[:path]
#     command "kitchen test"
#     only_if { has_kitchen_tests?(cookbook[:path]) }
#   end
# end
