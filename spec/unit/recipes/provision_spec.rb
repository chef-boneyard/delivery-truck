require 'spec_helper'

describe "delivery-truck::provision" do
  let(:chef_run) do
    @node = nil
    ChefSpec::SoloRunner.new do |node|
      @node = node
      node.set['delivery']['workspace']['root'] = '/tmp'
      node.set['delivery']['workspace']['repo'] = '/tmp/repo'
      node.set['delivery']['workspace']['chef'] = '/tmp/chef'
      node.set['delivery']['workspace']['cache'] = '/tmp/cache'

      node.set['delivery']['change']['enterprise'] = 'Chef'
      node.set['delivery']['change']['organization'] = 'Delivery'
      node.set['delivery']['change']['project'] = 'Secret'
      node.set['delivery']['change']['pipeline'] = 'master'
      node.set['delivery']['change']['change_id'] = 'aaaa-bbbb-cccc'
      node.set['delivery']['change']['patchset_number'] = '1'
      node.set['delivery']['change']['stage'] = 'union'
      node.set['delivery']['change']['phase'] = 'provision'
      node.set['delivery']['change']['git_url'] = 'https://git.co/my_project.git'
      node.set['delivery']['change']['sha'] = '0123456789abcdef'
      node.set['delivery']['change']['patchset_branch'] = 'mypatchset/branch'
    end.converge(described_recipe)
  end

  before do
    allow(Chef::Config).to receive(:from_file).with('/var/opt/delivery/workspace/.chef/knife.rb').and_return(true)
  end

  it 'copy env from prior to current' do
    expect(chef_run).to run_ruby_block('copy env from prior to current')
    expect(::DeliveryTruck::Helpers::Provision).to receive(:provision).with(@node, 'union', 'acceptance-Chef-Delivery-Secret-master', [])

    chef_run.find_resources(:ruby_block).first.old_run_action(:create)
  end
end
