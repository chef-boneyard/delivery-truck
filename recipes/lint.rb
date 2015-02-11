#
# Cookbook: delivery-truck
# Recipe: lint
#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

load_config File.join(repo_path, '.delivery', 'config.json')

changed_cookbooks.each do |cookbook|
  # Run Foodcritic against any cookbooks that were modified.
  delivery_truck_exec "lint_foodcritic_#{cookbook[:name]}" do
    command "foodcritic -f correctness #{foodcritic_tags} #{cookbook[:path]}"
  end
end
