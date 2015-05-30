#
# Copyright:: Copyright (c) 2015 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# The intended purpose of this recipe is to publish modified files to the
# necessary endpoints like Chef Servers or Supermarkets. The specific details
# about what to publish and where to publish it will be specified in the
# `.delivery/config.json` file. Please see the
# [`delivery-truck` cookbook's README](README.md) for
# additional configuration details.

config_rb = File.join('/var/opt/delivery/workspace/.chef', 'knife.rb')

# If the user specified a supermarket server to share to, share it
if share_cookbook_to_supermarket?
  supermarket_site = node['delivery']['config']['delivery-truck']['publish']['supermarket']
  cookbook_directory_supermarket = File.join(node['delivery']['workspace']['cache'], "cookbook-share")

  directory cookbook_directory_supermarket do
    recursive true
    # We delete the cookbook-to-share staging directory each time to ensure we
    # don't have out-of-date cookbooks hanging around from a previous build.
    action [:delete, :create]
  end

  changed_cookbooks.each do |cookbook|
    # Supermarket does not let you share a cookbook without a `metadata.rb`
    # then running `berks vendor` is not an option otherwise we will ended
    # up just with a `metadata.json`
    #
    # Lets link the real cookbook.
    link ::File.join(cookbook_directory_supermarket, cookbook[:name]) do
      to cookbook[:path]
    end

    execute "share_cookbook_to_supermarket_#{cookbook[:name]}" do
      command "knife supermarket share #{cookbook[:name]} " \
              "--config #{config_rb} " \
              "--supermarket-site #{supermarket_site} " \
              "--cookbook-path #{cookbook_directory_supermarket}"
      not_if "knife supermarket show #{cookbook[:name]} #{cookbook[:version]} " \
              "--config #{config_rb} " \
              "--supermarket-site #{supermarket_site}"
    end
  end
end

# Create the upload directory where cookbooks to be uploaded will be staged
cookbook_directory = File.join(node['delivery']['workspace']['cache'], "cookbook-upload")
directory cookbook_directory do
  recursive true
  # We delete the cookbook upload staging directory each time to ensure we
  # don't have out-of-date cookbooks hanging around from a previous build.
  action [:delete, :create]
end

# We need this for berks vendor to work when puling cookbooks from Chef server.
directory "#{node['delivery']['workspace']['cache']}/.berkshelf" do
  recursive true
end

file "#{node['delivery']['workspace']['cache']}/.berkshelf/config.json" do
  content <<EOM
{
  "chef": {
     "client_key": "/var/opt/delivery/workspace/.chef/delivery.pem",
     "node_name": "delivery"
  }
}
EOM
end

# Upload each cookbook to the Chef Server
if upload_cookbook_to_chef_server?
  changed_cookbooks.each do |cookbook|
    if File.exist?(File.join(cookbook[:path], 'Berksfile'))
      execute "berks_vendor_cookbook_#{cookbook[:name]}" do
        command "berks vendor #{cookbook_directory}"
        cwd cookbook[:path]
      end
    else
      link ::File.join(cookbook_directory, cookbook[:name]) do
        to cookbook[:path]
      end
    end

    execute "upload_cookbook_#{cookbook[:name]}" do
      command "knife cookbook upload #{cookbook[:name]} --freeze --all --force " \
              "--config #{config_rb} " \
              "--cookbook-path #{cookbook_directory}"
    end
  end
end

# If the user specified a github repo to push to, push to that repo
if push_repo_to_github?
  git_ssh = File.join(node['delivery']['workspace']['cache'], 'git_ssh')
  deploy_key = File.join(node['delivery']['workspace']['cache'], 'github.pem')
  secrets = get_project_secrets

  file deploy_key do
    content secrets['github']
    owner 'dbuild'
    mode '0600'
    sensitive true
  end

  template git_ssh do
    source 'git_ssh.erb'
    owner 'dbuild'
    mode '0755'
  end

  execute "set_git_username" do
    command "git config user.name 'Delivery'"
    cwd node['delivery']['workspace']['repo']
    environment({"GIT_SSH" => git_ssh})
  end

  execute "set_git_email" do
    command "git config user.email 'delivery@chef.io'"
    cwd node['delivery']['workspace']['repo']
    environment({"GIT_SSH" => git_ssh})
  end

  github_repo = node['delivery']['config']['delivery-truck']['publish']['github']
  execute "add_github_remote" do
    command "git remote add github git@github.com:#{github_repo}.git"
    cwd node['delivery']['workspace']['repo']
    environment({"GIT_SSH" => git_ssh})
    not_if "git remote --verbose | grep ^github"
  end

  execute "push_to_github" do
    command "git push github master"
    cwd node['delivery']['workspace']['repo']
    environment({"GIT_SSH" => git_ssh})
  end
end
