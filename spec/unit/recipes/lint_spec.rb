require 'spec_helper'

describe "delivery-truck::lint" do
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

  context "when a single cookbook has been modified" do
    before do
      allow(DeliveryTruck::Helpers::Lint).to receive(:foodcritic_tags).and_return("-t FC001")
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
    end

    it "runs test-kitchen against only that cookbook" do
      expect(chef_run).to run_execute("lint_foodcritic_julia").with(
        :command => "foodcritic -f correctness -t FC001 /tmp/repo/cookbooks/julia"
      )
      expect(chef_run).not_to run_execute("lint_foodcritic_gordon")
      expect(chef_run).not_to run_execute("lint_foodcritic_emeril")
    end
  end

  context "when multiple cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers::Lint).to receive(:foodcritic_tags).and_return("-t ~FC002")
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
    end

    it "runs test-kitchen against only those cookbooks" do
      expect(chef_run).to run_execute("lint_foodcritic_julia").with(
        :command => "foodcritic -f correctness -t ~FC002 /tmp/repo/cookbooks/julia"
      )
      expect(chef_run).to run_execute("lint_foodcritic_gordon").with(
        :command => "foodcritic -f correctness -t ~FC002 /tmp/repo/cookbooks/gordon"
      )
      expect(chef_run).not_to run_execute("lint_foodcritic_emeril")
    end
  end

  context "when no cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers::Lint).to receive(:foodcritic_tags).and_return("")
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
    end

    it "does not run test-kitchen against any cookbooks" do
      expect(chef_run).not_to run_execute("lint_foodcritic_julia")
      expect(chef_run).not_to run_execute("lint_foodcritic_gordon")
      expect(chef_run).not_to run_execute("lint_foodcritic_emeril")
    end
  end

  context "when a .rubocop.yml is present" do
    before do
      allow(DeliveryTruck::Helpers::Lint).to receive(:foodcritic_tags).and_return("")
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with("/tmp/repo/cookbooks/julia/.rubocop.yml").and_return(true)
    end

    it "runs Rubocop" do
      expect(chef_run).to run_execute("lint_rubocop_julia").with(
        :command => "rubocop /tmp/repo/cookbooks/julia"
      )
      expect(chef_run).not_to run_execute("lint_rubocop_gordon")
      expect(chef_run).not_to run_execute("lint_rubocop_emeril")
    end
  end
end
