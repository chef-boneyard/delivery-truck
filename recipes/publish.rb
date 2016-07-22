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

# If the user specified a supermarket server to share to, share it
if share_cookbook_to_supermarket?
  # Load secrets if custom_supermarket_credentials was specified
  if use_custom_supermarket_credentials?
    secrets = get_project_secrets
    if secrets['supermarket_user'].nil? || secrets['supermarket_user'].empty?
      raise RuntimeError, 'If supermarket-custom-credentials is set to true, ' \
                          'you must add supermarket_user to the secrets data bag.'
    end

    if secrets['supermarket_key'].nil? || secrets['supermarket_key'].nil?
      raise RuntimeError, 'If supermarket-custom-credentials is set to true, ' \
                          'you must add supermarket_key to the secrets data bag.'
    end
  end

  changed_cookbooks.each do |cookbook|
    delivery_supermarket "share_#{cookbook.name}_to_supermarket" do
      site node['delivery']['config']['delivery-truck']['publish']['supermarket']
      cookbook cookbook.name
      version cookbook.version
      path cookbook.path
      if use_custom_supermarket_credentials?
        user secrets['supermarket_user']
        key secrets['supermarket_key']
      end
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

# Upload each cookbook to the Chef Server
if upload_cookbook_to_chef_server?
  changed_cookbooks.each do |cookbook|
    if File.exist?(File.join(cookbook.path, 'Berksfile'))
      execute "berks_vendor_cookbook_#{cookbook.name}" do
        command "berks vendor #{cookbook_directory}"
        cwd cookbook.path
      end
    else
      link ::File.join(cookbook_directory, cookbook.name) do
        to cookbook.path
      end
    end

    execute "upload_cookbook_#{cookbook.name}" do
      command "knife cookbook upload #{cookbook.name} --freeze --all --force " \
              "--config #{delivery_knife_rb} " \
              "--cookbook-path #{cookbook_directory}"
    end
  end
end

# If the user specified a github repo to push to, push to that repo
if push_repo_to_github?
  secrets = get_project_secrets
  github_repo = node['delivery']['config']['delivery-truck']['publish']['github']

  delivery_github github_repo do
    deploy_key secrets['github']
    branch node['delivery']['change']['pipeline']
    remote_url "git@github.com:#{github_repo}.git"
    repo_path node['delivery']['workspace']['repo']
    cache_path node['delivery']['workspace']['cache']
    action :push
  end
end

# If the user specified a general git repo to push to, push to that repo
if push_repo_to_git?
  secrets = get_project_secrets
  git_repo = node['delivery']['config']['delivery-truck']['publish']['git']

  delivery_github git_repo do
    deploy_key secrets['git']
    branch node['delivery']['change']['pipeline']
    remote_url git_repo
    repo_path node['delivery']['workspace']['repo']
    cache_path node['delivery']['workspace']['cache']
    action :push
  end
end
