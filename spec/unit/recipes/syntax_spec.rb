require 'spec_helper'

describe "delivery-truck::syntax" do
  let(:chef_run) do
    ChefSpec::ServerRunner.new do |node|
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

  describe 'syntax checks using `knife cookbook test`' do
    before do
      allow(DeliveryTruck::Helpers::Syntax).to receive(:bumped_version?).and_return(true)
    end

    context "when a single cookbook has been modified" do
      before do
        allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
      end

      it "runs `knife cookbook test` against only that cookbook" do
        expect(chef_run).to run_execute("syntax_check_julia").with(
          :command => "knife cookbook test -o /tmp/repo/cookbooks/julia -a"
        )
        expect(chef_run).not_to run_execute("syntax_check_gordon")
        expect(chef_run).not_to run_execute("syntax_check_emeril")
      end
    end

    context "when multiple cookbooks have been modified" do
      before do
        allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
      end

      it "runs `knife cookbook test` against only those cookbooks" do
        expect(chef_run).to run_execute("syntax_check_julia").with(
          :command => "knife cookbook test -o /tmp/repo/cookbooks/julia -a"
        )
        expect(chef_run).to run_execute("syntax_check_gordon").with(
          :command => "knife cookbook test -o /tmp/repo/cookbooks/gordon -a"
        )
        expect(chef_run).not_to run_execute("syntax_check_emeril")
      end
    end

    context "when no cookbooks have been modified" do
      before do
        allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
      end

      it "does not run `knife cookbook test` against any cookbooks" do
        expect(chef_run).not_to run_execute("syntax_check_julia")
        expect(chef_run).not_to run_execute("syntax_check_gordon")
        expect(chef_run).not_to run_execute("syntax_check_emeril")
      end
    end
  end

  # Temporal Test - Modifying the Release process Stage 1
  #
  # TODO: Remove this on Stage 2
  describe 'temporal test to detect entries in Berksfile' do
    before do
      allow(DeliveryTruck::Helpers::Syntax).to receive(:bumped_version?).and_return(true)
      allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
    end

    context 'when there are NO entries' do
      it 'logs warning messages' do
        expect(chef_run).not_to write_log('warning_delivery-sugar_pull_from_github')
        expect(chef_run).not_to write_log('warning_delivery-truck_pull_from_github')
      end
    end

    context 'when there are wrong entries' do
      let(:mock_berksfile) do
        <<EOF
source "https://supermarket.chef.io"

metadata

cookbook 'delivery-truck',
  git: 'https://github.com/chef-cookbooks/delivery-truck.git',
  branch: 'master'

cookbook 'delivery-sugar',
  git: 'https://github.com/chef-cookbooks/delivery-sugar.git',
  branch: 'master'
EOF
      end

      before do
        allow(::File).to receive(:exist?).and_call_original
        allow(::File).to receive(:exist?)
          .with('/tmp/chef/build_cookbook/Berksfile')
          .and_return(true)
        allow(::File).to receive(:read).and_call_original
        allow(::File).to receive(:read)
          .with('/tmp/chef/build_cookbook/Berksfile')
          .and_return(mock_berksfile)
      end

      it 'logs warning messages' do
        expect(chef_run).to write_log('warning_delivery-sugar_pull_from_github')
        expect(chef_run).to write_log('warning_delivery-truck_pull_from_github')
      end
    end
  end
end
