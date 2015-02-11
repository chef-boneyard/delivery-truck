require 'spec_helper'

describe "delivery-truck::default" do
    let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

    it 'installs chefspec gem' do
      expect(chef_run).to install_gem_package('chefspec')
        .with(version: '4.1.1')
    end
end
