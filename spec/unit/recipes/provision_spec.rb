require 'spec_helper'

describe "delivery-truck::provision" do
  let(:chef_run) do
    @node = nil
    ChefSpec::SoloRunner.new do |node|
      @node = node
      node.default['delivery']['workspace']['root'] = '/tmp'
      node.default['delivery']['workspace']['repo'] = '/tmp/repo'
      node.default['delivery']['workspace']['chef'] = '/tmp/chef'
      node.default['delivery']['workspace']['cache'] = '/tmp/cache'

      node.default['delivery']['change']['enterprise'] = 'Chef'
      node.default['delivery']['change']['organization'] = 'Delivery'
      node.default['delivery']['change']['project'] = 'Secret'
      node.default['delivery']['change']['pipeline'] = 'master'
      node.default['delivery']['change']['change_id'] = 'aaaa-bbbb-cccc'
      node.default['delivery']['change']['patchset_number'] = '1'
      node.default['delivery']['change']['stage'] = 'union'
      node.default['delivery']['change']['phase'] = 'provision'
      node.default['delivery']['change']['git_url'] = 'https://git.co/my_project.git'
      node.default['delivery']['change']['sha'] = '0123456789abcdef'
      node.default['delivery']['change']['patchset_branch'] = 'mypatchset/branch'
    end.converge(described_recipe)
  end

  before do
    allow(Chef::Config).to receive(:from_file).with('/var/opt/delivery/workspace/.chef/knife.rb').and_return(true)
  end

  it 'copy env from prior to current' do
    expect(chef_run).to run_ruby_block('copy env from prior to current')
    expect(::DeliveryTruck::Helpers::Provision).to receive(:provision).with('union', @node, 'acceptance-Chef-Delivery-Secret-master', [])

    chef_run.find_resources(:ruby_block).first.old_run_action(:create)
  end
end
