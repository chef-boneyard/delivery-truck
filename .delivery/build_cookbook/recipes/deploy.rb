include_recipe 'delivery-truck::default'

# In Acceptance
#
# We want to push changes to Github Branch? so we can test other cookbooks
# that use delivery-truck. This will allow us to know if it is working
# fine or not. Then we can Deliver to share it to Supermarket
if delivery_environment == get_acceptance_environment
  # Pull the encrypted secrets from the Chef Server
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

# In Delivered
#
# We want to share the build-cookbook to supermarket to make it
# offitially released.
if delivery_environment == 'delivered'
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

  cookbook = DeliverySugar::Cookbook.new(node['delivery']['workspace']['repo'])
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
            "--cookbook-path #{cookbook_directory_supermarket}" \
            "#{custom_supermarket_credentials_options}"
    not_if "knife supermarket show #{cookbook.name} #{cookbook.version} " \
            "--config #{delivery_knife_rb} " \
            "--supermarket-site #{supermarket_site}"
  end
end
