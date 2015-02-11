require 'spec_helper'

describe "delivery-truck::syntax" do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  before do
    allow(DeliveryTruck::Helpers).to receive(:load_config).and_return(nil)
    allow(DeliveryTruck::Helpers).to receive(:repo_path).and_return('/tmp')
  end

  context "when a single cookbook has been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:delivery_workspace_chef_config).and_return("/etc/chef/solo.rb")
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
    end

    it "runs test-kitchen against only that cookbook" do
      expect(chef_run).to run_delivery_truck_exec("syntax_check_julia").with(
        :command => "knife cookbook test -c /etc/chef/solo.rb -o /tmp/cookbooks/julia -a"
      )
      expect(chef_run).not_to run_delivery_truck_exec("syntax_check_gordon")
      expect(chef_run).not_to run_delivery_truck_exec("syntax_check_emeril")
    end
  end

  context "when multiple cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:delivery_workspace_chef_config).and_return("/etc/chef/solo.rb")
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
    end

    it "runs test-kitchen against only those cookbooks" do
      expect(chef_run).to run_delivery_truck_exec("syntax_check_julia").with(
        :command => "knife cookbook test -c /etc/chef/solo.rb -o /tmp/cookbooks/julia -a"
      )
      expect(chef_run).to run_delivery_truck_exec("syntax_check_gordon").with(
        :command => "knife cookbook test -c /etc/chef/solo.rb -o /tmp/cookbooks/gordon -a"
      )
      expect(chef_run).not_to run_delivery_truck_exec("syntax_check_emeril")
    end
  end

  context "when no cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:delivery_workspace_chef_config).and_return("/etc/chef/solo.rb")
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
    end

    it "does not run test-kitchen against any cookbooks" do
      expect(chef_run).not_to run_delivery_truck_exec("syntax_check_julia")
      expect(chef_run).not_to run_delivery_truck_exec("syntax_check_gordon")
      expect(chef_run).not_to run_delivery_truck_exec("syntax_check_emeril")
    end
  end
end
