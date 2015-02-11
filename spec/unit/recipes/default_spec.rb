require 'spec_helper'

describe "delivery-truck::default" do
    let(:chef_run) { ChefSpec::SoloRunner.new.converge(described_recipe) }

    it 'downloads chefdk package' do
      expect(chef_run).to create_remote_file('chefdk-0.4.0')
    end

    it 'installs chefdk package when downloaded' do
      remote_file = chef_run.remote_file('chefdk-0.4.0')
      expect(remote_file).to notify('dpkg_package[chefdk-0.4.0]')
                              .to(:install).immediately
    end
end
