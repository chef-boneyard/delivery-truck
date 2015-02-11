#
# Cookbook: delivery-truck
# Recipe: syntax
#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

load_config File.join(repo_path, '.delivery', 'config.json')

changed_cookbooks.each do |cookbook|
  # Run `knife cookbook test` against the modified cookbook
  delivery_truck_exec "syntax_check_#{cookbook[:name]}" do
    command "knife cookbook test -c #{delivery_workspace_chef_config} -o #{cookbook[:path]} -a"
  end
end
