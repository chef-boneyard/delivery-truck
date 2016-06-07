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

ruby_block "Save Cookbook Pins" do
  block do
    save_cookbook_pins
  end
end

# The intended purpose of this recipe is to publish modified files to the
# necessary endpoints like Chef Servers or Supermarkets. The specific details
# about what to publish and where to publish it will be specified in the
# `.delivery/config.json` file. Please see the
# [`delivery-truck` cookbook's README](README.md) for
# additional configuration details.

# If the user specified a supermarket server to share to, share it
if share_cookbook_to_supermarket?
  supermarket_site = node['delivery']['config']['delivery-truck']['publish']['supermarket']
  cookbook_directory_supermarket = File.join(node['delivery']['workspace']['cache'], "cookbook-share")

  # Start with empty string to pass if use_custom_supermarket_credentials?
  # is false, then populate if true and override --user and --key in the
  # knife supermarket command to superseed delivery_knife_rb.
  custom_supermarket_credentials_options = ""
  if use_custom_supermarket_credentials?
    secrets = get_project_secrets
    if secrets['supermarket_user'].nil?
      Chef::Log.fatal "If supermarket-custom-credentials is set to true, you must add supermarket_user to the secrets data bag."
      raise RuntimeError, "supermarket-custom-credentials was true and supermarket_user was not defined in delivery secrets."
    end
    custom_supermarket_credentials_options << " -u #{secrets['supermarket_user']}"

    if secrets['supermarket_key'].nil?
      Chef::Log.fatal "If supermarket-custom-credentials is set to true, you must add supermarket_key to the secrets data bag."
      raise RuntimeError, "supermarket-custom-credentials was true and supermarket_key was not defined in delivery secrets."
    end

    # write the supermarket_key to a file on disk since knife needs a file
    supermarket_tmp_key_path = File.join(node['delivery']['workspace']['cache'], "supermarket.pem")
    f = File.new(supermarket_tmp_key_path, "w+")
    f.write(secrets['supermarket_key'])
    f.close
    custom_supermarket_credentials_options << " -k #{supermarket_tmp_key_path}"
  end

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
    link ::File.join(cookbook_directory_supermarket, cookbook.name) do
      to cookbook.path
    end

    execute "share_cookbook_to_supermarket_#{cookbook.name}" do
      command "knife supermarket share #{cookbook.name} " \
              "--config #{delivery_knife_rb} " \
              "--supermarket-site #{supermarket_site} " \
              "--cookbook-path #{cookbook_directory_supermarket}" +
              custom_supermarket_credentials_options
      not_if "knife supermarket show #{cookbook.name} #{cookbook.version} " \
              "--config #{delivery_knife_rb} " \
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
