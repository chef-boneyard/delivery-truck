require 'spec_helper'

describe "delivery-truck::publish" do
  let(:publish_run) do
    ChefSpec::SoloRunner.new do |node|
      node.default['delivery_builder']['cache'] = "/tmp/workspace/cache"
      node.default['delivery_builder']['repo'] = "/tmp/workspace/repo"
      node.default['delivery_builder']['root_workspace_etc'] = "/tmp/root_workspace_etc"
    end.converge(described_recipe)
  end

  before do
    allow(DeliveryTruck::Helpers).to receive(:get_acceptance_environment).and_return('spec')
    allow(DeliveryTruck::Helpers).to receive(:load_config).and_return(nil)
    allow(DeliveryTruck::Helpers).to receive(:repo_path).and_return('/tmp')
    allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
  end

  it 'creates cookbook staging directory' do
    expect(publish_run).to create_directory("/tmp/workspace/cache/cookbook-upload")
  end

  it 'creates the Chef Environment if it is missing' do
    expect(publish_run).to run_ruby_block("Create Env spec if not there.")
  end

  context 'when user does not specify they wish to upload to Chef Server' do
    before do
      allow(DeliveryTruck::Helpers::Publish).to receive(:upload_cookbook_to_chef_server?).and_return(false)
    end

    it 'does not upload cookbooks' do
      expect(publish_run).not_to create_link('/tmp/workspace/cache/cookbook-upload/julia')
      expect(publish_run).not_to create_link('/tmp/workspace/cache/cookbook-upload/gordon')
      expect(publish_run).not_to create_link('/tmp/workspace/cache/cookbook-upload/emeril')

      expect(publish_run).not_to run_delivery_truck_exec("upload_cookbook_julia")
      expect(publish_run).not_to run_delivery_truck_exec("upload_cookbook_gordon")
      expect(publish_run).not_to run_delivery_truck_exec("upload_cookbook_emeril")
    end
  end

  context 'when user specifies they wish to upload to Chef Server' do
    before do
      allow(DeliveryTruck::Helpers::Publish).to receive(:upload_cookbook_to_chef_server?).and_return(true)
    end

    context 'and no cookbooks changed' do
      before do
        allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
      end

      it 'does nothing' do
        expect(publish_run).not_to create_link('/tmp/workspace/cache/cookbook-upload/julia')
        expect(publish_run).not_to create_link('/tmp/workspace/cache/cookbook-upload/gordon')
        expect(publish_run).not_to create_link('/tmp/workspace/cache/cookbook-upload/emeril')

        expect(publish_run).not_to run_delivery_truck_exec("upload_cookbook_julia")
        expect(publish_run).not_to run_delivery_truck_exec("upload_cookbook_gordon")
        expect(publish_run).not_to run_delivery_truck_exec("upload_cookbook_emeril")
      end
    end

    context 'and one cookbook changed' do
      before do
        allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
      end

      it 'uploads only that cookbook' do
        expect(publish_run).to create_link('/tmp/workspace/cache/cookbook-upload/julia')
                                .with(to: '/tmp/cookbooks/julia')
        expect(publish_run).not_to create_link('/tmp/workspace/cache/cookbook-upload/gordon')
        expect(publish_run).not_to create_link('/tmp/workspace/cache/cookbook-upload/emeril')

        expect(publish_run).to run_delivery_truck_exec("upload_cookbook_julia")
                                .with(command: 'knife cookbook upload julia ' \
                                               '--freeze --env spec ' \
                                               '--config /tmp/root_workspace_etc/delivery.rb ' \
                                               '--cookbook-path /tmp/workspace/cache/cookbook-upload')
        expect(publish_run).not_to run_delivery_truck_exec("upload_cookbook_gordon")
        expect(publish_run).not_to run_delivery_truck_exec("upload_cookbook_emeril")
        end
    end

    context 'and multiple cookbooks changed' do
      before do
        allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
      end

      it 'uploads only that cookbook' do
        expect(publish_run).to create_link('/tmp/workspace/cache/cookbook-upload/julia')
                                .with(to: '/tmp/cookbooks/julia')
        expect(publish_run).to create_link('/tmp/workspace/cache/cookbook-upload/gordon')
                                .with(to: '/tmp/cookbooks/gordon')
        expect(publish_run).not_to create_link('/tmp/workspace/cache/cookbook-upload/emeril')

        expect(publish_run).to run_delivery_truck_exec("upload_cookbook_julia")
                                .with(command: 'knife cookbook upload julia ' \
                                               '--freeze --env spec ' \
                                               '--config /tmp/root_workspace_etc/delivery.rb ' \
                                               '--cookbook-path /tmp/workspace/cache/cookbook-upload')
        expect(publish_run).to run_delivery_truck_exec("upload_cookbook_gordon")
                                    .with(command: 'knife cookbook upload gordon ' \
                                                   '--freeze --env spec ' \
                                                   '--config /tmp/root_workspace_etc/delivery.rb ' \
                                                   '--cookbook-path /tmp/workspace/cache/cookbook-upload')
        expect(publish_run).not_to run_delivery_truck_exec("upload_cookbook_emeril")
      end
    end
  end

  context 'when they do not wish to push to github' do
    before do
      allow(DeliveryTruck::Helpers::Publish).to receive(:push_repo_to_github?).and_return(false)
      stub_command("git remote --verbose | grep ^github").and_return(false)
    end

    it 'does not push to github' do
      expect(publish_run).not_to run_delivery_truck_exec("push_to_github")
    end
  end

  context 'when they wish to push to github' do
    let(:secrets) {{'github' => 'SECRET'}}

    before do
      allow(DeliveryTruck::Helpers::Publish).to receive(:push_repo_to_github?).and_return(true)
      allow(DeliveryTruck::Helpers::Publish).to receive(:github_repo).and_return('spec/spec')
      allow(DeliveryTruck::Helpers).to receive(:project_slug).and_return('local-delivery-truck')
      allow(DeliveryTruck::Helpers).to receive(:get_project_secrets).and_return(secrets)
      stub_command("git remote --verbose | grep ^github").and_return(false)
    end

    it 'creates git_ssh wrapper' do
      expect(publish_run).to create_file("/tmp/workspace/cache/git_ssh")
                              .with(mode: '0755')
      expect(publish_run).to render_file("/tmp/workspace/cache/git_ssh")
                              .with_content(/IdentityFile=\/home\/dbuild\/.ssh\/local-delivery-truck-github.pem/)
    end

    it 'adds github remote' do
      expect(publish_run).to run_delivery_truck_exec("add_github_remote")
                              .with(command: 'git remote add github git@github.com:spec/spec.git',
                                    cwd: '/tmp/workspace/repo',
                                    environment: {"GIT_SSH" => "/tmp/workspace/cache/git_ssh"})
    end

    it 'pushes to github' do
      expect(publish_run).to run_delivery_truck_exec('push_to_github')
                              .with(command: 'git push github master',
                                    cwd: '/tmp/workspace/repo',
                                    environment: {"GIT_SSH" => "/tmp/workspace/cache/git_ssh"})
    end
  end

end
