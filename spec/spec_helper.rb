require 'chefspec'

TOPDIR = File.expand_path(File.join(File.dirname(__FILE__), ".."))
$: << File.expand_path(File.dirname(__FILE__))

# Require all our libraries
Dir['libraries/*.rb'].each { |f| require File.expand_path(f) }

# Declare common let declarations
module SharedLetDeclarations
  extend RSpec::SharedContext

  let(:one_changed_cookbook) {[
    {:name => 'julia', :path => "/tmp/cookbooks/julia"}
  ]}

  let(:two_changed_cookbooks) {[
    {:name => 'julia', :path => "/tmp/cookbooks/julia"},
    {:name => 'gordon', :path => "/tmp/cookbooks/gordon"}
  ]}

  let(:no_changed_cookbooks) {[]}
end

RSpec.configure do |config|
  config.include SharedLetDeclarations
  config.filter_run_excluding :ignore => true

  # Specify the operating platform to mock Ohai data from (default: nil)
  config.platform = 'ubuntu'

  # Specify the operating version to mock Ohai data from (default: nil)
  config.version = '12.04'
end
