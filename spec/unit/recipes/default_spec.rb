require 'spec_helper'

describe 'delivery-truck::default', ignore: true do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  it 'should install chefspec' do
    expect(chef_run).to install_chef_gem('chefspec')
      .with_version('4.1.1')
      .with_compile_time(false)
  end

  it 'should upgrade chef-sugar' do
    expect(chef_run).to upgrade_chef_gem('chef-sugar')
      .with_compile_time(false)
  end

  it 'should install knife-supermarket' do
    expect(chef_run).to install_chef_gem('chefspec')
      .with_compile_time(false)
  end
end
