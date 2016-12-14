require 'spec_helper'

describe "delivery-truck::default", :ignore => true do
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

  context 'when DeliveryTruck::Helpers::Quality::run_test_kitchen? returns true' do
    before do
      allow(DeliveryTruck::Helpers::Quality).to receive(:run_kitchen_test?).with(anything()).and_return(true)
    end

    it 'should install kitchen-ec2' do
      expect(chef_run).to install_chef_gem('kitchen-ec2')
        .with_compile_time(false)
    end
  end
  context 'when DeliveryTruck::Helpers::Quality::run_test_kitchen? returns false' do
    before do
      allow(DeliveryTruck::Helpers::Quality).to receive(:run_kitchen_test?).with(anything()).and_return(false)
    end

    it 'should not install kitchen-ec2' do
      expect(chef_run).not_to install_chef_gem('kitchen-ec2')
        .with_compile_time(false)
    end
  end
end
