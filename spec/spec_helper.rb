require 'chefspec'
require 'chefspec/berkshelf'

TOPDIR = File.expand_path(File.join(File.dirname(__FILE__), ".."))
$: << File.expand_path(File.dirname(__FILE__))

# Require all our libraries
Dir['libraries/*.rb'].each { |f| require File.expand_path(f) }

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
