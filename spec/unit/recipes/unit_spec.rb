require 'spec_helper'

describe "delivery-truck::unit" do
  let(:chef_run) do
    ChefSpec::SoloRunner.new do |node|
      node.default['delivery']['workspace']['root'] = '/tmp'
      node.default['delivery']['workspace']['repo'] = '/tmp/repo'
      node.default['delivery']['workspace']['chef'] = '/tmp/chef'
      node.default['delivery']['workspace']['cache'] = '/tmp/cache'

      node.default['delivery']['change']['enterprise'] = 'Chef'
      node.default['delivery']['change']['organization'] = 'Delivery'
      node.default['delivery']['change']['project'] = 'Secret'
      node.default['delivery']['change']['pipeline'] = 'master'
      node.default['delivery']['change']['change_id'] = 'aaaa-bbbb-cccc'
      node.default['delivery']['change']['patchset_number'] = '1'
      node.default['delivery']['change']['stage'] = 'union'
      node.default['delivery']['change']['phase'] = 'deploy'
      node.default['delivery']['change']['git_url'] = 'https://git.co/my_project.git'
      node.default['delivery']['change']['sha'] = '0123456789abcdef'
      node.default['delivery']['change']['patchset_branch'] = 'mypatchset/branch'
    end.converge(described_recipe)
  end

  context "when a single cookbook has been modified" do
    before do
      allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
      allow(DeliveryTruck::Helpers::Unit).to receive(:has_spec_tests?).with('/tmp/repo/cookbooks/julia').and_return(true)
    end

    it "runs test-kitchen against only that cookbook" do
      expect(chef_run).to run_execute("unit_rspec_julia").with(
        :cwd => "/tmp/repo/cookbooks/julia",
        :command => "rspec --format documentation --color"
      )
      expect(chef_run).not_to run_execute("unit_rspec_gordon")
      expect(chef_run).not_to run_execute("unit_rspec_emeril")
    end
  end

  context "when multiple cookbooks have been modified" do
    before do
      allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
      allow(DeliveryTruck::Helpers::Unit).to receive(:has_spec_tests?).with('/tmp/repo/cookbooks/julia').and_return(true)
      allow(DeliveryTruck::Helpers::Unit).to receive(:has_spec_tests?).with('/tmp/repo/cookbooks/gordon').and_return(true)
    end

    it "runs test-kitchen against only those cookbooks" do
      expect(chef_run).to run_execute("unit_rspec_julia").with(
        :cwd => "/tmp/repo/cookbooks/julia",
        :command => "rspec --format documentation --color"
      )
      expect(chef_run).to run_execute("unit_rspec_gordon").with(
        :cwd => "/tmp/repo/cookbooks/gordon",
        :command => "rspec --format documentation --color"
      )
      expect(chef_run).not_to run_execute("unit_rspec_emeril")
    end
  end

  context "when no cookbooks have been modified" do
    before do
      allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
    end

    it "does not run test-kitchen against any cookbooks" do
      expect(chef_run).not_to run_execute("unit_rspec_julia")
      expect(chef_run).not_to run_execute("unit_rspec_gordon")
      expect(chef_run).not_to run_execute("unit_rspec_emeril")
    end
  end
end
