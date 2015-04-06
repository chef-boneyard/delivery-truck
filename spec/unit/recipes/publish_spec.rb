require 'spec_helper'

describe "delivery-truck::publish" do
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
      node.set['delivery']['change']['phase'] = 'publish'
      node.set['delivery']['change']['git_url'] = 'https://git.co/my_project.git'
      node.set['delivery']['change']['sha'] = '0123456789abcdef'
      node.set['delivery']['change']['patchset_branch'] = 'mypatchset/branch'
    end
  end

  let(:delivery_chef_server) do
    {
      chef_server_url: 'http://myserver.chef',
      options: {
        client_name: 'spec',
        signing_key_filename: '/tmp/keys/spec.pem'
      }
    }
  end

  before do
    allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
    allow(DeliveryTruck::Helpers).to receive(:delivery_chef_server).and_return(delivery_chef_server)
  end

  context 'always' do
    before do
      chef_run.converge(described_recipe)
    end

    it 'creates cookbook staging directory' do
      expect(chef_run).to create_directory("/tmp/cache/cookbook-upload")
    end
  end


  context 'when user does not specify they wish to upload to Chef Server' do
    before do
      allow(DeliveryTruck::Helpers::Publish).to receive(:upload_cookbook_to_chef_server?).and_return(false)
      chef_run.converge(described_recipe)
    end

    it 'does not upload cookbooks' do
      expect(chef_run).not_to create_link('/tmp/cache/cookbook-upload/julia')
      expect(chef_run).not_to create_link('/tmp/cache/cookbook-upload/gordon')
      expect(chef_run).not_to create_link('/tmp/cache/cookbook-upload/emeril')

      expect(chef_run).not_to run_execute("upload_cookbook_julia")
      expect(chef_run).not_to run_execute("upload_cookbook_gordon")
      expect(chef_run).not_to run_execute("upload_cookbook_emeril")
    end
  end

  context 'when user specifies they wish to upload to Chef Server' do
    before do
      allow(DeliveryTruck::Helpers::Publish).to receive(:upload_cookbook_to_chef_server?).and_return(true)
      chef_run.node.set['delivery']['config']['delivery-truck']['publish']['chef_server'] = true
    end

    context 'and no cookbooks changed' do
      before do
        allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
        chef_run.converge(described_recipe)
      end

      it 'does nothing' do
        expect(chef_run).not_to create_link('/tmp/cache/cookbook-upload/julia')
        expect(chef_run).not_to create_link('/tmp/cache/cookbook-upload/gordon')
        expect(chef_run).not_to create_link('/tmp/cache/cookbook-upload/emeril')

        expect(chef_run).not_to run_execute("upload_cookbook_julia")
        expect(chef_run).not_to run_execute("upload_cookbook_gordon")
        expect(chef_run).not_to run_execute("upload_cookbook_emeril")
      end
    end

    context 'and one cookbook changed' do
      before do
        allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
        chef_run.converge(described_recipe)
      end

      it 'uploads only that cookbook' do
        expect(chef_run).to create_link('/tmp/cache/cookbook-upload/julia')
                             .with(to: '/tmp/repo/cookbooks/julia')
        expect(chef_run).not_to create_link('/tmp/cache/cookbook-upload/gordon')
        expect(chef_run).not_to create_link('/tmp/cache/cookbook-upload/emeril')

        expect(chef_run).to run_execute("upload_cookbook_julia")
                             .with(command: 'knife cookbook upload julia ' \
                                            '--freeze --all ' \
                                            '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                                            '--cookbook-path /tmp/cache/cookbook-upload')
        expect(chef_run).not_to run_execute("upload_cookbook_gordon")
        expect(chef_run).not_to run_execute("upload_cookbook_emeril")
      end
    end

    context 'and multiple cookbooks changed' do
      before do
        allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
        chef_run.converge(described_recipe)
      end

      it 'uploads only those cookbook' do
        expect(chef_run).to create_link('/tmp/cache/cookbook-upload/julia')
                             .with(to: '/tmp/repo/cookbooks/julia')
        expect(chef_run).to create_link('/tmp/cache/cookbook-upload/gordon')
                             .with(to: '/tmp/repo/cookbooks/gordon')
        expect(chef_run).not_to create_link('/tmp/cache/cookbook-upload/emeril')

        expect(chef_run).to run_execute("upload_cookbook_julia")
                             .with(command: 'knife cookbook upload julia ' \
                                            '--freeze --all ' \
                                            '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                                            '--cookbook-path /tmp/cache/cookbook-upload')
        expect(chef_run).to run_execute("upload_cookbook_gordon")
                             .with(command: 'knife cookbook upload gordon ' \
                                            '--freeze --all ' \
                                            '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                                            '--cookbook-path /tmp/cache/cookbook-upload')
        expect(chef_run).not_to run_execute("upload_cookbook_emeril")
      end
    end

    context 'a Berksfile exists' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('/tmp/repo/cookbooks/julia/Berksfile').and_return(true)
        allow(DeliveryTruck::Helpers).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
        chef_run.converge(described_recipe)
      end

      it 'vendors all dependencies with Berkshelf' do

        expect(chef_run).to run_execute("berks_vendor_cookbook_julia")
                             .with(command: 'berks vendor /tmp/cache/cookbook-upload')
                             .with(cwd: '/tmp/repo/cookbooks/julia')

        expect(chef_run).to run_execute("upload_cookbook_julia")
                             .with(command: 'knife cookbook upload julia ' \
                                            '--freeze --all ' \
                                            '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                                            '--cookbook-path /tmp/cache/cookbook-upload')
      end
    end
  end

  context 'when they do not wish to push to github' do
    before do
      allow(DeliveryTruck::Helpers::Publish).to receive(:push_repo_to_github?).and_return(false)
      stub_command("git remote --verbose | grep ^github").and_return(false)
      chef_run.converge(described_recipe)
    end

    it 'does not push to github' do
      expect(chef_run).not_to run_execute("push_to_github")
    end
  end

  context 'when they wish to push to github' do
    let(:secrets) {{'github' => 'SECRET'}}

    before do
      allow(DeliveryTruck::Helpers).to receive(:get_project_secrets).and_return(secrets)
      stub_command("git remote --verbose | grep ^github").and_return(false)
      chef_run.node.set['delivery']['config']['delivery-truck']['publish']['github'] = 'spec/spec'
      chef_run.converge(described_recipe)
    end

    it 'creates a deploy key' do
      expect(chef_run).to create_file('/tmp/cache/github.pem')
                           .with(content: 'SECRET',
                                 owner: 'dbuild',
                                 mode: '0600',
                                 sensitive: true)
    end

    it 'creates the git_ssh wrapper file' do
      expect(chef_run).to create_template('/tmp/cache/git_ssh')
                           .with(source: 'git_ssh.erb',
                                 owner: 'dbuild',
                                 mode: '0755')
    end

    it 'adds git username' do
      expect(chef_run).to run_execute('set_git_username')
                           .with(command: "git config user.name 'Delivery'",
                                 cwd: '/tmp/repo',
                                 environment: {"GIT_SSH" => "/tmp/cache/git_ssh"})
    end

    it 'adds git email' do
      expect(chef_run).to run_execute('set_git_email')
                           .with(command: "git config user.email 'delivery@chef.io'",
                                 cwd: '/tmp/repo',
                                 environment: {"GIT_SSH" => "/tmp/cache/git_ssh"})
    end

    it 'adds github remote' do
      expect(chef_run).to run_execute("add_github_remote")
                           .with(command: 'git remote add github git@github.com:spec/spec.git',
                                 cwd: '/tmp/repo',
                                 environment: {"GIT_SSH" => "/tmp/cache/git_ssh"})
    end

    it 'pushes to github' do
      expect(chef_run).to run_execute('push_to_github')
                           .with(command: 'git push github master',
                                 cwd: '/tmp/repo',
                                 environment: {"GIT_SSH" => "/tmp/cache/git_ssh"})
    end
  end

end
