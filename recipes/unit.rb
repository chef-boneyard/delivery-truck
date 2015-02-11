#
# Cookbook: delivery-truck
# Recipe: unit
#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

load_config File.join(repo_path, '.delivery', 'config.json')

changed_cookbooks.each do |cookbook|
  # Run RSpec against the modified cookbook
  delivery_truck_exec "unit_rspec_#{cookbook[:name]}" do
    cwd cookbook[:path]
    command "rspec --format documentation --color"
    only_if { has_spec_tests?(cookbook[:path]) }
  end
end
