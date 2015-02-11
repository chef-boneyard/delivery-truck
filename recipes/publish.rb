#
# Cookbook: delivery-truck
# Recipe: publish
#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

# The intended purpose of this recipe is to publish modified files to the
# necessary endpoints like Chef Servers or Supermarkets. The specific details
# about what to publish and where to publish it will be specified in the
# `.delivery/config.json` file. Please see the
# [`delivery-truck` cookbook's README](README.md) for
# additional configuration details.

load_config File.join(repo_path, '.delivery', 'config.json')

# The following code is a temporary workaround that will allow us to delivery
# delivery-truck with delivery-truck. This code block should ultimately become
# a configurable block rather than hard-coded.
cookbook_directory = File.join(node['delivery_builder']['cache'], "cookbook-upload")
directory cookbook_directory

cb_dir = node['delivery_builder']['repo']
delivery_config = File.join(node['delivery_builder']['root_workspace_etc'], 'delivery.rb')

# Need to link this so we can find the cookbook via directory name
link File.join(cookbook_directory, 'delivery-truck') do
  to cb_dir
end

delivery_truck_exec "upload_cookbook_delivery-truck" do
  command "knife cookbook upload delivery-truck --freeze -c #{delivery_config} -o #{cookbook_directory}"
end
