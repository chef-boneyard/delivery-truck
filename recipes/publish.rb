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

# Create the upload directory where cookbooks to be uploaded will be staged
cookbook_directory = File.join(node['delivery_builder']['cache'], "cookbook-upload")
directory cookbook_directory

# Grab the Chef config file we'll use to publish to Chef Server
delivery_config = File.join(node['delivery_builder']['root_workspace_etc'], 'delivery.rb')

# Create the environment if it doesn't exist
env_name = get_acceptance_environment
ruby_block "Create Env #{env_name} if not there." do
  block do
    Chef_Delivery::ClientHelper.enter_client_mode_as_delivery

    begin
      env = Chef::Environment.load(env_name)
    rescue Net::HTTPServerException => http_e
      raise http_e unless http_e.response.code == "404"
      Chef::Log.info("Creating Environment #{env_name}")
      env = Chef::Environment.new()
      env.name(env_name)
      env.create
    end
    Chef_Delivery::ClientHelper.enter_solo_mode
  end
end

# Upload each cookbook to the Chef Server
if upload_cookbook_to_chef_server?
  changed_cookbooks.each do |cookbook|
    link ::File.join(cookbook_directory, cookbook[:name]) do
      to cookbook[:path]
    end

    delivery_truck_exec "upload_cookbook_#{cookbook[:name]}" do
      command "knife cookbook upload #{cookbook[:name]} --freeze " \
              "--env #{env_name} " \
              "--config #{delivery_config} " \
              "--cookbook-path #{cookbook_directory}"
    end
  end
end

# If the user specified a github repo to push to, push to that repo
if push_repo_to_github?
  build_user_home = "/home/#{node['delivery_builder']['build_user']}"
  deploy_key_path = "#{build_user_home}/.ssh/#{project_slug}-github.pem"
  git_ssh = ::File.join(node['delivery_builder']['cache'], 'git_ssh')
  secrets = get_project_secrets

  directory "#{build_user_home}/.ssh" do
    owner node['delivery_builder']['build_user']
    group 'root'
    mode '0700'
  end

  file deploy_key_path do
    content secrets['github']
    owner node['delivery_builder']['build_user']
    group 'root'
    mode '0600'
  end

  file git_ssh do
    content <<-EOH
#!/bin/bash
# Martin Emde
# https://github.com/martinemde/git-ssh-wrapper

unset SSH_AUTH_SOCK
ssh -o CheckHostIP=no \
    -o IdentitiesOnly=yes \
    -o LogLevel=INFO \
    -o StrictHostKeyChecking=no \
    -o PasswordAuthentication=no \
    -o UserKnownHostsFile=/tmp/delivery-git-known-hosts \
    -o IdentityFile=/home/dbuild/.ssh/#{project_slug}-github.pem \
    $*
    EOH
    mode '0755'
  end

  delivery_truck_exec "add_github_remote" do
    command "git remote add github git@github.com:#{github_repo}.git"
    cwd node['delivery_builder']['repo']
    environment({"GIT_SSH" => git_ssh})
    not_if "git remote --verbose | grep ^github"
  end

  delivery_truck_exec "push_to_github" do
    command "git push github master"
    cwd node['delivery_builder']['repo']
    environment({"GIT_SSH" => git_ssh})
  end
end
