require 'chefspec'

TOPDIR = File.expand_path(File.join(File.dirname(__FILE__), '..'))
$: << File.expand_path(File.dirname(__FILE__))

# Require all our libraries
Dir['libraries/*.rb'].each { |f| require File.expand_path(f) }

# Alright this is going to get crazy! :)
#
# PROBLEM: We would like to eat our own dogfood at the earliest Stage
# in Delivery, that means we need to pull delivery-sugar from DCC.
# The problem is that we can't release delivery-truck with this
# dependency because end-users won't be able to reach it
#
# For this reason we are going to inject the dependency before we
# run `berks install` inside chefspec. With that we will run our
# tests using the latest delivery-sugar cookbook and without issues
# in the release process
def delivery_sugar_dcc_dependency
  <<EOF
cookbook 'delivery-sugar',
  git: 'ssh://builder@chef@delivery.chef.co:8989/chef/Delivery-Build-Cookbooks/delivery-sugar',
  branch: 'master'
EOF
end

def whoami
  Etc.getpwuid(Process.uid).name
end

# If we are running inside Delivery
if whoami.eql?('dbuild')
  berks = ::File.open(File.join(TOPDIR, 'Berksfile'), 'a')
  berks.write(delivery_sugar_dcc_dependency)
  berks.close
end

require 'chefspec/berkshelf'

module ChefSpec
  class SoloRunner
    def initialize(options = {})
      @options = with_default_options(options)

      Chef::Log.level = @options[:log_level]

      Chef::Config.reset!
      Chef::Config.formatters.clear
      Chef::Config.add_formatter('chefspec')
      Chef::Config[:cache_type]      = 'Memory'
      Chef::Config[:client_key]      = nil
      Chef::Config[:client_name]     = nil
      Chef::Config[:node_name]       = nil
      Chef::Config[:file_cache_path] = @options[:file_cache_path] || file_cache_path
      Chef::Config[:cookbook_path]   = Array(@options[:cookbook_path])
      Chef::Config[:no_lazy_load]    = true
      Chef::Config[:role_path]       = Array(@options[:role_path])
      Chef::Config[:force_logger]    = true
      Chef::Config[:solo]            = true
      Chef::Config[:solo_legacy_mode] = true
      Chef::Config[:environment_path] = @options[:environment_path]
      Chef::Config[:use_policyfile] = false

      yield node if block_given?
    end
  end
end

# Declare common let declarations
module SharedLetDeclarations
  extend RSpec::SharedContext

  let(:one_changed_cookbook) do
    [
   double(
     'delivery sugar cookbook',
     name: 'julia',
     path: '/tmp/repo/cookbooks/julia',
     version: '0.1.0'
   ),
    ]
  end

  let(:two_changed_cookbooks) do
    [
   double(
     'delivery sugar cookbook',
     name: 'julia',
     path: '/tmp/repo/cookbooks/julia',
     version: '0.1.0'
   ),
   double(
     'delivery sugar cookbook',
     name: 'gordon',
     path: '/tmp/repo/cookbooks/gordon',
     version: '0.2.0'
   ),
    ]
  end

  let(:no_changed_cookbooks) { [] }
end

RSpec.configure do |config|
  config.include SharedLetDeclarations
  config.filter_run_excluding ignore: true
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  # Specify the operating platform to mock Ohai data from (default: nil)
  config.platform = 'ubuntu'

  # Specify the operating version to mock Ohai data from (default: nil)
  config.version = '12.04'
end
