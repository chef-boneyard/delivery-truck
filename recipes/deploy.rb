#
# Cookbook: delivery-truck
# Recipe: deploy
#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

load_config File.join(repo_path, '.delivery', 'config.json')

# Send CCR requests to every node that is running this cookbook or any
# other one in the current project
search_terms = changed_cookbooks.map {|cookbook| "recipes:#{cookbook[:name]}*" }

unless search_terms.empty?
  delivery_truck_deploy "deploy_#{project_name}" do
    search search_terms.join(" OR ")
  end
end
