require 'spec_helper'

describe "delivery-truck::lint" do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  before do
    allow(DeliveryTruck::Helpers).to receive(:load_config).and_return(nil)
    allow(DeliveryTruck::Helpers).to receive(:repo_path).and_return('/tmp')
  end

  context "when a single cookbook has been modified" do
    before do
      allow(DeliveryTruck::Helpers::Lint).to receive(:foodcritic_tags).and_return("-t FC001")
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
    end

    it "runs test-kitchen against only that cookbook" do
      expect(chef_run).to run_delivery_truck_exec("lint_foodcritic_julia").with(
        :command => "foodcritic -f correctness -t FC001 /tmp/cookbooks/julia"
      )
      expect(chef_run).not_to run_delivery_truck_exec("lint_foodcritic_gordon")
      expect(chef_run).not_to run_delivery_truck_exec("lint_foodcritic_emeril")
    end
  end

  context "when multiple cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers::Lint).to receive(:foodcritic_tags).and_return("-t ~FC002")
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
    end

    it "runs test-kitchen against only those cookbooks" do
      expect(chef_run).to run_delivery_truck_exec("lint_foodcritic_julia").with(
        :command => "foodcritic -f correctness -t ~FC002 /tmp/cookbooks/julia"
      )
      expect(chef_run).to run_delivery_truck_exec("lint_foodcritic_gordon").with(
        :command => "foodcritic -f correctness -t ~FC002 /tmp/cookbooks/gordon"
      )
      expect(chef_run).not_to run_delivery_truck_exec("lint_foodcritic_emeril")
    end
  end

  context "when no cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers::Lint).to receive(:foodcritic_tags).and_return("")
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
    end

    it "does not run test-kitchen against any cookbooks" do
      expect(chef_run).not_to run_delivery_truck_exec("lint_foodcritic_julia")
      expect(chef_run).not_to run_delivery_truck_exec("lint_foodcritic_gordon")
      expect(chef_run).not_to run_delivery_truck_exec("lint_foodcritic_emeril")
    end
  end
end
