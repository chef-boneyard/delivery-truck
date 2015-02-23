require 'spec_helper'

describe "delivery-truck::deploy" do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  before do
    allow(DeliveryTruck::Helpers).to receive(:load_config).and_return(nil)
    allow(DeliveryTruck::Helpers).to receive(:project_name).and_return(project_name)
    allow(DeliveryTruck::Helpers).to receive(:repo_path).and_return('/tmp')
  end

  context "when a single cookbook has been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
    end

    it "deploy only that cookbook" do
      expect(chef_run).to run_delivery_truck_deploy("deploy_#{project_name}").with(
        :search => "recipes:julia*"
      )
    end
  end

  context "when multiple cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
    end

    it "deploy only those cookbooks" do
      expect(chef_run).to run_delivery_truck_deploy("deploy_#{project_name}").with(
        :search => "recipes:julia* OR recipes:gordon*"
      )
    end
  end

  context "when no cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
    end

    it "does not deploy any cookbooks" do
      expect(chef_run).not_to run_delivery_truck_deploy("deploy_#{project_name}")
    end
  end
end
