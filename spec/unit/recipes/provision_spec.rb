require 'spec_helper'

describe "delivery-truck::provision" do
  let(:chef_run) do
    ChefSpec::SoloRunner.new do |node|
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

  context 'when workflow data bag exists' do
    before do
      stub_data_bag_item("workflow-promotion-data", 'aaaa-bbbb-cccc').and_return([])
    end
    it 'uses v2 of provision helper logic' do
      expect(chef_run).to run_ruby_block('copy promotion data to current env')
    end
  end

  context 'when workflow data bag does not exist' do
    before do
      stub_data_bag_item("workflow-promotion-data", 'aaaa-bbbb-cccc').and_raise(Chef::Exceptions::InvalidDataBagItemID)
    end
    it 'uses v1 of provision helper logic' do
      expect(chef_run).to run_ruby_block('copy env from prior to current')
    end
  end
end
