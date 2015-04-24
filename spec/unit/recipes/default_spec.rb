require 'spec_helper'

describe "delivery-truck::default" do
  cached(:chef_run) do
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
      node.set['delivery']['change']['stage'] = 'acceptance'
      node.set['delivery']['change']['phase'] = 'functional'
      node.set['delivery']['change']['git_url'] = 'https://git.co/my_project.git'
      node.set['delivery']['change']['sha'] = '0123456789abcdef'
      node.set['delivery']['change']['patchset_branch'] = 'mypatchset/branch'
    end.converge(described_recipe)
  end

  before do
    allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).and_call_original
    allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('docker')
    allow_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('aufs')
  end

  it 'installs docker' do
    expect_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('docker')
    expect_any_instance_of(Chef::Recipe).to receive(:include_recipe).with('aufs')
    chef_run
  end

  it 'configures dbuild to run docker as sudo' do
    expect(chef_run).to install_sudo('dbuild-docker').with(
                          user: 'dbuild',
                          runas: 'root',
                          commands: ['/usr/bin/docker'],
                          defaults: ['setenv', 'env_reset'],
                          nopasswd: true)
  end

  it 'installs necessary gems' do
    expect(chef_run).to install_chef_gem('kitchen-docker').with(version: '2.0.0')
    expect(chef_run).to install_chef_gem('chefspec').with(version: '4.1.1')
    expect(chef_run).to upgrade_chef_gem('chef-sugar')
  end
end
