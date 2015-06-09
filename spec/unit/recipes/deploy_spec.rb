require 'spec_helper'

# Simple FakeNode to muck Chef::Node class
class MyFakeNode
  attr_reader :name

  def initialize(name)
    @name = name
  end
end

describe "delivery-truck::deploy" do
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
      node.set['delivery']['change']['phase'] = 'deploy'
      node.set['delivery']['change']['git_url'] = 'https://git.co/my_project.git'
      node.set['delivery']['change']['sha'] = '0123456789abcdef'
      node.set['delivery']['change']['patchset_branch'] = 'mypatchset/branch'
    end.converge(described_recipe)
  end

  let(:search_query) do
    "(#{recipe_list}) AND chef_environment:union AND recipes:push-jobs*"
  end
  let(:node_list) { [MyFakeNode.new("node1"), MyFakeNode.new("node2")] }
  let(:node_name_list) { node_list.map(&:name) }

  # context "when a single cookbook has been modified" do
  #   before do
  #     allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
  #     allow_any_instance_of(Chef::Recipe).to receive(:get_cookbook_version).and_return('1.0.0')
  #   end
  #
  #   let(:recipe_list) { 'recipes:julia*' }
  #
  #   it "deploy only that cookbook" do
  #     expect(DeliveryTruck::Helpers::Deploy).to receive(:delivery_chef_server_search).with(:node, search_query).and_return(node_list)
  #     expect(chef_run).to run_ruby_block('update the union environment')
  #     expect(chef_run).to dispatch_delivery_push_job("deploy_Secret").with(
  #                           :command => 'chef-client',
  #                           :nodes => node_list
  #                         )
  #   end
  # end

  context "when multiple cookbooks have been modified" do
    before do
      allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
      allow_any_instance_of(Chef::Recipe).to receive(:get_cookbook_version).and_return('1.0.0')
    end

    let(:recipe_list) { 'recipes:julia* OR recipes:gordon*' }

    it "deploy only those cookbooks" do
      allow_any_instance_of(Chef::Recipe).to receive(:delivery_chef_server_search).with(:node, search_query).and_return(node_list)
      expect(chef_run).to run_ruby_block('update the union environment')
      expect(chef_run).to dispatch_delivery_push_job("deploy_Secret").with(
                            :command => 'chef-client',
                            :nodes => node_name_list
                          )
    end
  end

  # context "when no cookbooks have been modified" do
  #   before do
  #     allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
  #     allow_any_instance_of(Chef::Recipe).to receive(:get_cookbook_version).and_return('1.0.0')
  #   end
  #
  #   it "does not deploy any cookbooks" do
  #     expect(chef_run).to run_ruby_block('update the union environment')
  #     expect(chef_run).not_to dispatch_delivery_push_job("deploy_Secret")
  #   end
  # end
end
