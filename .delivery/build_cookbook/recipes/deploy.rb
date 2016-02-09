include_recipe 'delivery-truck::default'

if delivery_environment == 'delivered'
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

if delivery_environment == 'acceptance'
  supermarket_site = 'https://supermarket.chef.io'
  cookbook_directory_supermarket = File.join(node['delivery']['workspace']['cache'], "cookbook-share")

  directory cookbook_directory_supermarket do
    recursive true
    # We delete the cookbook-to-share staging directory each time to ensure we
    # don't have out-of-date cookbooks hanging around from a previous build.
    action [:delete, :create]
  end

  cookbook = load_cookbook(node['delivery']['workspace']['repo'])
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
            "--cookbook-path #{cookbook_directory_supermarket}"
    not_if "knife supermarket show #{cookbook.name} #{cookbook.version} " \
            "--config #{delivery_knife_rb} " \
            "--supermarket-site #{supermarket_site}"
  end
end
