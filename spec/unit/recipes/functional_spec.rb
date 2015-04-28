require 'spec_helper'

RSpec.shared_examples "cleanup docker" do
  it "cleans up Docker" do
    expect(chef_run).to run_execute('stop_all_docker_containers')
                         .with(command: 'docker stop $(docker ps --quiet --filter "status=running")',
                               ignore_failure: true)
    expect(chef_run).to run_execute('kill_all_docker_containers')
                         .with(command: 'docker rm $(docker ps --all --quiet)',
                               ignore_failure: true)
  end
end

describe "delivery-truck::functional", :ignore => true do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  before do
    allow(DeliveryTruck::Helpers).to receive(:load_config).and_return(nil)
    allow(DeliveryTruck::Helpers).to receive(:repo_path).and_return('/tmp')
  end

  context "when a single cookbook has been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:current_stage).and_return('acceptance')
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
      allow(DeliveryTruck::Helpers::Functional).to receive(:has_kitchen_tests?).with('/tmp/cookbooks/julia').and_return(true)
    end

    include_examples "cleanup docker"

    it "runs test-kitchen against only that cookbook" do
      expect(chef_run).to run_delivery_truck_exec("functional_kitchen_julia").with(
                            :cwd => "/tmp/cookbooks/julia",
                            :command => "KITCHEN_YAML=/tmp/cookbooks/julia/.kitchen.docker.yml kitchen test"
                          )
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_gordon")
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_emeril")
    end
  end

  context "when multiple cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:current_stage).and_return('acceptance')
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
      allow(DeliveryTruck::Helpers::Functional).to receive(:has_kitchen_tests?).with('/tmp/cookbooks/julia').and_return(true)
      allow(DeliveryTruck::Helpers::Functional).to receive(:has_kitchen_tests?).with('/tmp/cookbooks/gordon').and_return(true)
    end

    include_examples "cleanup docker"

    it "runs test-kitchen against only those cookbooks" do
      expect(chef_run).to run_delivery_truck_exec("functional_kitchen_julia").with(
                            :cwd => "/tmp/cookbooks/julia",
                            :command => "KITCHEN_YAML=/tmp/cookbooks/julia/.kitchen.docker.yml kitchen test"
                          )
      expect(chef_run).to run_delivery_truck_exec("functional_kitchen_gordon").with(
                            :cwd => "/tmp/cookbooks/gordon",
                            :command => "KITCHEN_YAML=/tmp/cookbooks/gordon/.kitchen.docker.yml kitchen test"
                          )
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_emeril")
    end

    context "but a cookbook has no tests" do
      before do
        allow(DeliveryTruck::Helpers::Functional).to receive(:has_kitchen_tests?).with('/tmp/cookbooks/gordon').and_return(false)
      end

      include_examples "cleanup docker"

      it "skips that cookbook" do
        expect(chef_run).to run_delivery_truck_exec("functional_kitchen_julia").with(
                              :cwd => "/tmp/cookbooks/julia",
                              :command => "KITCHEN_YAML=/tmp/cookbooks/julia/.kitchen.docker.yml kitchen test"
                            )
        expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_gordon")
        expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_emeril")
      end
    end
  end

  context "when no cookbooks have been modified" do
    before do
      allow(DeliveryTruck::Helpers).to receive(:current_stage).and_return('acceptance')
      allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
    end

    it "does not run test-kitchen against any cookbooks" do
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_julia")
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_gordon")
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_emeril")
    end
  end

  context 'non-acceptance environments' do
    before do
      allow(DeliveryTruck::Helpers).to receive(:current_stage).and_return('union')
    end

    it 'does nothing' do
      expect(chef_run).not_to run_execute('stop_all_docker_containers')
      expect(chef_run).not_to run_execute('kill_all_docker_containers')
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_julia")
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_gordon")
      expect(chef_run).not_to run_delivery_truck_exec("functional_kitchen_emeril")
    end
  end
end
