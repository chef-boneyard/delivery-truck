require 'spec_helper'

describe "delivery-truck::functional" do
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
      node.set['delivery']['change']['stage'] = 'acceptance'
      node.set['delivery']['change']['phase'] = 'functional'
      node.set['delivery']['change']['git_url'] = 'https://git.co/my_project.git'
      node.set['delivery']['change']['sha'] = '0123456789abcdef'
      node.set['delivery']['change']['patchset_branch'] = 'mypatchset/branch'
    end
  end

  before do
    stub_const('ENV', {'PATH' => '/opt/chefdk/bin'})
  end

  context "when project contains only a single cookbook" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:all_cookbooks).and_return(one_changed_cookbook)
      allow(DeliveryTruck::Helpers::Functional).to receive(:has_kitchen_tests?).with('/tmp/repo/cookbooks/julia').and_return(true)
      chef_run.converge(described_recipe)
    end

    it "runs test-kitchen against only that cookbook" do
      expect(chef_run).to run_execute("functional_kitchen_julia").with(
                            cwd: '/tmp/repo/cookbooks/julia',
                            command: 'kitchen test',
                            environment: {
                              'PATH' => '/opt/chefdk/bin',
                              'KITCHEN_YAML' => '.kitchen.docker.yml'
                            }
                          )
      expect(chef_run).not_to run_execute("functional_kitchen_gordon")
      expect(chef_run).not_to run_execute("functional_kitchen_emeril")
    end
  end

  context "when project contains multiple cookbooks" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:all_cookbooks).and_return(two_changed_cookbooks)
      allow(DeliveryTruck::Helpers::Functional).to receive(:has_kitchen_tests?).with('/tmp/repo/cookbooks/julia').and_return(true)
      allow(DeliveryTruck::Helpers::Functional).to receive(:has_kitchen_tests?).with('/tmp/repo/cookbooks/gordon').and_return(true)
      chef_run.converge(described_recipe)
    end

    it "runs test-kitchen against only those cookbooks" do
      expect(chef_run).to run_execute("functional_kitchen_julia").with(
                            cwd: '/tmp/repo/cookbooks/julia',
                            command: 'kitchen test',
                            environment: {
                              'PATH' => '/opt/chefdk/bin',
                              'KITCHEN_YAML' => '.kitchen.docker.yml'
                            }
                          )
      expect(chef_run).to run_execute("functional_kitchen_gordon").with(
                            cwd: '/tmp/repo/cookbooks/gordon',
                            command: 'kitchen test',
                            environment: {
                              'PATH' => '/opt/chefdk/bin',
                              'KITCHEN_YAML' => '.kitchen.docker.yml'
                            }
                          )
      expect(chef_run).not_to run_execute("functional_kitchen_emeril")
    end

    context "but a cookbook has no tests" do
      before do
        allow(DeliveryTruck::Helpers::Functional).to receive(:has_kitchen_tests?).with('/tmp/repo/cookbooks/gordon').and_return(false)
        chef_run.converge(described_recipe)
      end

      it "skips that cookbook" do
        expect(chef_run).to run_execute("functional_kitchen_julia").with(
                              cwd: '/tmp/repo/cookbooks/julia',
                              command: 'kitchen test',
                              environment: {
                                'PATH' => '/opt/chefdk/bin',
                                'KITCHEN_YAML' => '.kitchen.docker.yml'
                              }
                            )
        expect(chef_run).not_to run_execute("functional_kitchen_gordon")
        expect(chef_run).not_to run_execute("functional_kitchen_emeril")
      end
    end
  end

  context 'non-acceptance environments' do
    before do
      chef_run.node.set['delivery']['change']['stage'] = 'union'
      allow(DeliveryTruck::Helpers).to receive(:all_cookbooks).and_return(no_changed_cookbooks)
      chef_run.converge(described_recipe)
   end

    it 'does nothing' do
      expect(chef_run).not_to run_execute("functional_kitchen_julia")
      expect(chef_run).not_to run_execute("functional_kitchen_gordon")
      expect(chef_run).not_to run_execute("functional_kitchen_emeril")
    end
  end
end
