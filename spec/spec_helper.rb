require 'chefspec'

TOPDIR = File.expand_path(File.join(File.dirname(__FILE__), ".."))
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

# Declare common let declarations
module SharedLetDeclarations
  extend RSpec::SharedContext

  let(:one_changed_cookbook) {[
    double('delivery sugar cookbook', :name => 'julia', :path => '/tmp/repo/cookbooks/julia', :version => '0.1.0')
  ]}

  let(:two_changed_cookbooks) {[
    double('delivery sugar cookbook', :name => 'julia', :path => '/tmp/repo/cookbooks/julia', :version => '0.1.0'),
    double('delivery sugar cookbook', :name => 'gordon', :path => '/tmp/repo/cookbooks/gordon', :version => '0.2.0')
  ]}

  let(:no_changed_cookbooks) {[]}
end

RSpec.configure do |config|
  config.include SharedLetDeclarations
  config.filter_run_excluding :ignore => true
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  # Specify the operating platform to mock Ohai data from (default: nil)
  config.platform = 'ubuntu'

  # Specify the operating version to mock Ohai data from (default: nil)
  config.version = '12.04'
end
