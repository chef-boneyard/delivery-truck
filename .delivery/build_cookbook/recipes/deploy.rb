include_recipe 'delivery-truck::default'

# Modifying the Release Process
#
# Stage 1
# We will continue pushing to Github until all our customers point
# their build-cookbooks to pull from Supermarket instead. In Stage 2
# we will move the push to Github process to Acceptance.
if delivery_environment == 'delivered' # <- Delete on Stage 2

# In Acceptance
#
# We want to push changes to Github so we can test other cookbooks
# that use delivery-truck. This will allow us to know if it is working
# fine or not. Then when we Deliver we will share it to Supermarket
#if delivery_environment == get_acceptance_environment # <- Uncomment on Stage 2
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
#end # <- Uncomment on Stage 2

# In Delivered
#
# We want to share the build-cookbook to supermarket release it officially.
#if delivery_environment == 'delivered' # <- Uncomment on Stage 2

  if use_custom_supermarket_credentials?
    #secrets = get_project_secrets # <- Uncomment on Stage 2
    if secrets['supermarket_user'].nil? || secrets['supermarket_user'].empty?
      raise RuntimeError, 'If supermarket-custom-credentials is set to true, ' \
                          'you must add supermarket_user to the secrets data bag.' \
    end

    if secrets['supermarket_key'].nil? || secrets['supermarket_key'].nil?
      raise RuntimeError, 'If supermarket-custom-credentials is set to true, ' \
                          'you must add supermarket_key to the secrets data bag.'
    end
  end

  delivery_supermarket 'share_delivery_truck_to_supermarket' do
    site node['delivery']['config']['delivery-truck']['publish']['supermarket']
    if use_custom_supermarket_credentials?
      user secrets['supermarket_user']
      key secrets['supermarket_key']
    end
  end
end
