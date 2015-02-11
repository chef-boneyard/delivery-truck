require 'spec_helper'

describe "delivery-truck::functional", :ignore => true do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  before do
    allow(DeliveryTruck::Helpers).to receive(:load_config).and_return(nil)
    allow(DeliveryTruck::Helpers).to receive(:repo_path).and_return('/tmp')
  end

  context "when a single cookbook has been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
      allow(DeliveryTruck::Helpers::Functional).to receive(:has_kitchen_tests?).with('/tmp/cookbooks/julia').and_return(true)
    end

    it "runs test-kitchen against only that cookbook" do
      expect(chef_run).to run_delivery_truck_exec("functional_kitchen_julia").with(
        :cwd => "/tmp/cookbooks/julia",
        :command => "kitchen test"
      )
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_gordon")
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_emeril")
    end
  end

  context "when multiple cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
      allow(DeliveryTruck::Helpers::Functional).to receive(:has_kitchen_tests?).with('/tmp/cookbooks/julia').and_return(true)
      allow(DeliveryTruck::Helpers::Functional).to receive(:has_kitchen_tests?).with('/tmp/cookbooks/gordon').and_return(true)
    end

    it "runs test-kitchen against only those cookbooks" do
      expect(chef_run).to run_delivery_truck_exec("functional_kitchen_julia").with(
        :cwd => "/tmp/cookbooks/julia",
        :command => "kitchen test"
      )
      expect(chef_run).to run_delivery_truck_exec("functional_kitchen_gordon").with(
        :cwd => "/tmp/cookbooks/gordon",
        :command => "kitchen test"
      )
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_emeril")
    end
  end

  context "when no cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
    end

    it "does not run test-kitchen against any cookbooks" do
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_julia")
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_gordon")
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_emeril")
    end
  end
end
