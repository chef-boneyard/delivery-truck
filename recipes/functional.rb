#
# Cookbook: delivery-truck
# Recipe: functional
#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

# We aren't at a point where we're ready for functional stuff yet so this
# recipe will do nothing for the time being.

load_config File.join(repo_path, '.delivery', 'config.json')

if current_stage.eql?('acceptance')

  # This will stop all running containers
  execute 'stop_all_docker_containers' do
    command 'docker stop $(docker ps --quiet --filter "status=running")'
    ignore_failure true
  end

  # This will kill all containers
  execute 'kill_all_docker_containers' do
    command 'docker rm $(docker ps --all --quiet)'
    ignore_failure true
  end

  changed_cookbooks.each do |cookbook|
    # Run Test Kitchen against any cookbooks that were modified.
    delivery_truck_exec "functional_kitchen_#{cookbook[:name]}" do
      cwd cookbook[:path]
      command "KITCHEN_YAML=#{cookbook[:path]}/.kitchen.docker.yml kitchen test"
      only_if { has_kitchen_tests?(cookbook[:path]) }
    end
  end
end
