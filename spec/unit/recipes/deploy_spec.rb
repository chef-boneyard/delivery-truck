require 'spec_helper'

# Simple FakeNode to muck Chef::Node class
class MyFakeNode
  attr_reader :name

  def initialize(name)
    @name = name
  end
end

describe 'delivery-truck::deploy' do
  let(:chef_run) do
    ChefSpec::SoloRunner.new do |node|
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
      node.default['delivery']['change']['phase'] = 'deploy'
      node.default['delivery']['change']['git_url'] = 'https://git.co/my_project.git'
      node.default['delivery']['change']['sha'] = '0123456789abcdef'
      node.default['delivery']['change']['patchset_branch'] = 'mypatchset/branch'
    end.converge(described_recipe)
  end

  let(:search_query) do
    "(#{recipe_list}) AND chef_environment:union AND recipes:*push-jobs*"
  end
  let(:node_list) { [MyFakeNode.new('node1'), MyFakeNode.new('node2')] }
  let(:delivery_knife_rb) do
    '/var/opt/delivery/workspace/.chef/knife.rb'
  end

  context 'when a single cookbook has been modified' do
    before do
      allow_any_instance_of(Chef::Recipe).to receive(:get_all_project_cookbooks).and_return(one_changed_cookbook)
      allow_any_instance_of(Chef::Recipe).to receive(:get_cookbook_version).and_return('1.0.0')
    end

    let(:recipe_list) { 'recipes:julia*' }

    it 'deploy only that cookbook' do
      expect(DeliveryTruck::Helpers::Deploy).to receive(:delivery_chef_server_search).with(:node, search_query, delivery_knife_rb).and_return(node_list)
      expect(chef_run).to dispatch_delivery_push_job('deploy_Secret').with(
                            command: 'chef-client',
                            nodes: node_list
                          )
    end

    context 'and the user sets a different search query' do
      before do
        allow(DeliveryTruck::Helpers::Deploy).to receive(:deployment_search_query)
          .and_return('recipes:my_cool_push_jobs_cookbook AND more:constraints')
      end
      let(:search_query) do
        "(#{recipe_list}) AND chef_environment:union AND recipes:my_cool_push_jobs_cookbook AND more:constraints"
      end
      it 'deploy only that cookbook with the special search query' do
        expect(DeliveryTruck::Helpers::Deploy).to receive(:delivery_chef_server_search)
          .with(:node, search_query, delivery_knife_rb)
          .and_return(node_list)
        expect(chef_run).to dispatch_delivery_push_job('deploy_Secret').with(
                              command: 'chef-client',
                              nodes: node_list
                            )
      end
    end
  end

  context 'when multiple cookbooks have been modified' do
    before do
      allow_any_instance_of(Chef::Recipe).to receive(:get_all_project_cookbooks).and_return(two_changed_cookbooks)
      allow_any_instance_of(Chef::Recipe).to receive(:get_cookbook_version).and_return('1.0.0')
    end

    let(:recipe_list) { 'recipes:julia* OR recipes:gordon*' }

    it 'deploy only those cookbooks' do
      allow_any_instance_of(Chef::Recipe).to receive(:delivery_chef_server_search).with(:node, search_query).and_return(node_list)
      expect(chef_run).to dispatch_delivery_push_job('deploy_Secret').with(
                            command: 'chef-client',
                            nodes: node_list
                          )
    end
  end

  context 'when no cookbooks have been modified' do
    before do
      allow_any_instance_of(Chef::Recipe).to receive(:get_all_project_cookbooks).and_return(no_changed_cookbooks)
      allow_any_instance_of(Chef::Recipe).to receive(:get_cookbook_version).and_return('1.0.0')
    end

    it 'does not deploy any cookbooks' do
      expect(chef_run).not_to dispatch_delivery_push_job('deploy_Secret')
    end
  end
end
