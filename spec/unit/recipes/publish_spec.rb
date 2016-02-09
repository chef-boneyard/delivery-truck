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
    allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
    allow_any_instance_of(Chef::Recipe).to receive(:delivery_chef_server).and_return(delivery_chef_server)
  end

  context 'always' do
    before do
      chef_run.converge(described_recipe)
    end

    it 'deletes and recreates cookbook staging directory' do
      expect(chef_run).to delete_directory("/tmp/cache/cookbook-upload").with(recursive: true)
      expect(chef_run).to create_directory("/tmp/cache/cookbook-upload")
    end
  end

  context 'when user does not specify they wish to share to Supermarket Server' do
    before do
      allow(DeliveryTruck::Helpers::Publish).to receive(:share_cookbook_to_supermarket?).and_return(false)
      chef_run.converge(described_recipe)
    end

    it 'does not share cookbooks' do
      expect(chef_run).not_to create_link('/tmp/cache/cookbook-share/julia')
      expect(chef_run).not_to create_link('/tmp/cache/cookbook-share/gordon')
      expect(chef_run).not_to create_link('/tmp/cache/cookbook-share/emeril')

      expect(chef_run).not_to run_execute("share_cookbook_to_supermarket_julia")
      expect(chef_run).not_to run_execute("share_cookbook_to_supermarket_gordon")
      expect(chef_run).not_to run_execute("share_cookbook_to_supermarket_emeril")
    end
  end

  context 'when user specifies they wish to share to Supermarket Server' do
    before do
      allow(DeliveryTruck::Helpers::Publish).to receive(:share_cookbook_to_supermarket?).and_return(true)
      chef_run.node.set['delivery']['config']['delivery-truck']['publish']['supermarket'] = 'https://supermarket.chef.io'
    end

    context 'always' do
      before do
        chef_run.converge(described_recipe)
      end

      it 'deletes and recreates cookbook-to-share directory' do
        expect(chef_run).to delete_directory("/tmp/cache/cookbook-share").with(recursive: true)
        expect(chef_run).to create_directory("/tmp/cache/cookbook-share")
      end
    end

    shared_examples_for 'properly working supermarket upload' do
      context 'and no cookbooks changed' do
        before do
          allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
          chef_run.converge(described_recipe)
        end

        it 'does nothing' do
          expect(chef_run).not_to create_link('/tmp/cache/cookbook-share/julia')
          expect(chef_run).not_to create_link('/tmp/cache/cookbook-share/gordon')
          expect(chef_run).not_to create_link('/tmp/cache/cookbook-share/emeril')

          expect(chef_run).not_to run_execute("share_cookbook_to_supermarket_julia")
          expect(chef_run).not_to run_execute("share_cookbook_to_supermarket_gordon")
          expect(chef_run).not_to run_execute("share_cookbook_to_supermarket_emeril")
        end
      end

      context 'and one cookbook changed' do
        before do
          allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
          stub_command('knife supermarket show julia 0.1.0 ' \
                       '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                       '--supermarket-site https://supermarket.chef.io').and_return(false)
          chef_run.converge(described_recipe)
        end

        it 'shares only that cookbook' do
          expect(chef_run).to create_link('/tmp/cache/cookbook-share/julia')
                               .with(to: '/tmp/repo/cookbooks/julia')
          expect(chef_run).not_to create_link('/tmp/cache/cookbook-share/gordon')
          expect(chef_run).not_to create_link('/tmp/cache/cookbook-share/emeril')

          expect(chef_run).to run_execute("share_cookbook_to_supermarket_julia")
                               .with(command: 'knife supermarket share julia ' \
                                              '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                                              '--supermarket-site https://supermarket.chef.io ' \
                                              '--cookbook-path /tmp/cache/cookbook-share' + expected_extra_args)
          expect(chef_run).not_to run_execute("share_cookbook_to_supermarket_gordon")
          expect(chef_run).not_to run_execute("share_cookbook_to_supermarket_emeril")
        end

        context 'but it already exists on Supermarket' do
          before do
            stub_command('knife supermarket show julia 0.1.0 ' \
                         '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                         '--supermarket-site https://supermarket.chef.io').and_return(true)
            chef_run.converge(described_recipe)
          end

          it 'do not share that cookbook' do
            expect(chef_run).not_to run_execute("share_cookbook_to_supermarket_julia")
                                     .with(command: 'knife supermarket share julia ' \
                                                    '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                                                    '--supermarket-site https://supermarket.chef.io ' \
                                                    '--cookbook-path /tmp/cache/cookbook-share' + expected_extra_args)
          end
        end
      end

      context 'and multiple cookbooks changed' do
        before do
          allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
          stub_command('knife supermarket show julia 0.1.0 ' \
                       '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                       '--supermarket-site https://supermarket.chef.io').and_return(false)
          stub_command('knife supermarket show gordon 0.2.0 ' \
                       '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                       '--supermarket-site https://supermarket.chef.io').and_return(false)
          chef_run.converge(described_recipe)
        end

        it 'shares only those cookbook' do
          expect(chef_run).to create_link('/tmp/cache/cookbook-share/julia')
                               .with(to: '/tmp/repo/cookbooks/julia')
          expect(chef_run).to create_link('/tmp/cache/cookbook-share/gordon')
                               .with(to: '/tmp/repo/cookbooks/gordon')
          expect(chef_run).not_to create_link('/tmp/cache/cookbook-share/emeril')

          expect(chef_run).to run_execute("share_cookbook_to_supermarket_julia")
                               .with(command: 'knife supermarket share julia ' \
                                              '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                                              '--supermarket-site https://supermarket.chef.io ' \
                                              '--cookbook-path /tmp/cache/cookbook-share' + expected_extra_args)
          expect(chef_run).to run_execute("share_cookbook_to_supermarket_gordon")
                               .with(command: 'knife supermarket share gordon ' \
                                              '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                                              '--supermarket-site https://supermarket.chef.io ' \
                                              '--cookbook-path /tmp/cache/cookbook-share' + expected_extra_args)
          expect(chef_run).not_to run_execute("share_cookbook_to_supermarket_emeril")
        end
      end
    end

    context 'when supermarket-custom-credentials is not specified' do
      let(:expected_extra_args) { '' }

      it_behaves_like 'properly working supermarket upload'
    end

    context 'when supermarket-custom-credentials is specified' do
      before do
        chef_run.node.set['delivery']['config']['delivery-truck']['publish']['supermarket-custom-credentials'] = true
        allow_any_instance_of(Chef::Recipe).to receive(:get_project_secrets).and_return(secrets)
      end

      context 'when secrets are properly set' do
        let(:supermarket_tmp_path) { '/tmp/cache/supermarket.pem' }
        let(:secrets) do
          {
            'supermarket_user' => 'test-user',
            'supermarket_key' => 'test-key',
          }
        end

        let(:expected_extra_args) { " -u test-user -k #{supermarket_tmp_path}" }

        before do
          file = instance_double('File')
          allow(File).to receive(:new).with(supermarket_tmp_path, 'w+').and_return(file)
          allow(file).to receive(:write).with('test-key')
          allow(file).to receive(:close)
        end

        it_behaves_like 'properly working supermarket upload'
      end

      context 'when secrets are missing' do
        before do
          allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
          stub_command('knife supermarket show julia 0.1.0 ' \
                       '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                       '--supermarket-site https://supermarket.chef.io').and_return(false)
          stub_command('knife supermarket show gordon 0.2.0 ' \
                       '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                       '--supermarket-site https://supermarket.chef.io').and_return(false)
        end

        context 'when supermarket_user is not specified in secrets' do
          let(:secrets) do
            {
              'supermarket_key' => 'test-key'
            }
          end

          it 'rasies an error' do
            expect { chef_run.converge(described_recipe) }.to raise_error(RuntimeError)
          end

        end

        context 'when supermarket_user is not specified in secrets' do
          let(:secrets) do
            {
              'supermarket_user' => 'test-user'
            }
          end

          it 'rasies an error' do
            expect { chef_run.converge(described_recipe) }.to raise_error(RuntimeError)
          end

        end
      end
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
        allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(no_changed_cookbooks)
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
        allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
        chef_run.converge(described_recipe)
      end

      it 'uploads only that cookbook' do
        expect(chef_run).to create_link('/tmp/cache/cookbook-upload/julia')
                             .with(to: '/tmp/repo/cookbooks/julia')
        expect(chef_run).not_to create_link('/tmp/cache/cookbook-upload/gordon')
        expect(chef_run).not_to create_link('/tmp/cache/cookbook-upload/emeril')

        expect(chef_run).to run_execute("upload_cookbook_julia")
                             .with(command: 'knife cookbook upload julia ' \
                                            '--freeze --all --force ' \
                                            '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                                            '--cookbook-path /tmp/cache/cookbook-upload')
        expect(chef_run).not_to run_execute("upload_cookbook_gordon")
        expect(chef_run).not_to run_execute("upload_cookbook_emeril")
      end
    end

    context 'and multiple cookbooks changed' do
      before do
        allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(two_changed_cookbooks)
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
                                            '--freeze --all --force ' \
                                            '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                                            '--cookbook-path /tmp/cache/cookbook-upload')
        expect(chef_run).to run_execute("upload_cookbook_gordon")
                             .with(command: 'knife cookbook upload gordon ' \
                                            '--freeze --all --force ' \
                                            '--config /var/opt/delivery/workspace/.chef/knife.rb ' \
                                            '--cookbook-path /tmp/cache/cookbook-upload')
        expect(chef_run).not_to run_execute("upload_cookbook_emeril")
      end
    end

    context 'a Berksfile exists' do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with('/tmp/repo/cookbooks/julia/Berksfile').and_return(true)
        allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
        chef_run.converge(described_recipe)
      end

      it 'vendors all dependencies with Berkshelf' do

        expect(chef_run).to run_execute("berks_vendor_cookbook_julia")
                             .with(command: 'berks vendor /tmp/cache/cookbook-upload')
                             .with(cwd: '/tmp/repo/cookbooks/julia')

        expect(chef_run).to run_execute("upload_cookbook_julia")
                             .with(command: 'knife cookbook upload julia ' \
                                            '--freeze --all --force ' \
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
      allow_any_instance_of(Chef::Recipe).to receive(:get_project_secrets).and_return(secrets)
      stub_command("git remote --verbose | grep ^github").and_return(false)
      chef_run.node.set['delivery']['config']['delivery-truck']['publish']['github'] = 'spec/spec'
      chef_run.converge(described_recipe)
    end

    it 'pushes to github' do
      expect(chef_run).to push_delivery_github('spec/spec')
                              .with(deploy_key: 'SECRET',
                                    branch: 'master',
                                    remote_url: 'git@github.com:spec/spec.git',
                                    repo_path: '/tmp/repo',
                                    cache_path: '/tmp/cache',
                                    action: [:push])
    end
  end

  context 'when they do not wish to push to git' do
    before do
      allow(DeliveryTruck::Helpers::Publish).to receive(:push_repo_to_git?).and_return(false)
      chef_run.converge(described_recipe)
    end

    it 'does not push to git' do
      expect(chef_run).not_to run_execute("push_to_git")
    end
  end

  context 'when they wish to push to git' do
    let(:secrets) {{'git' => 'SECRET'}}

    before do
      allow_any_instance_of(Chef::Recipe).to receive(:get_project_secrets).and_return(secrets)
      chef_run.node.set['delivery']['config']['delivery-truck']['publish']['git'] = 'ssh://git@stash:2222/spec/spec.git'
      chef_run.converge(described_recipe)
    end

    it 'pushes to git' do
      expect(chef_run).to push_delivery_github('ssh://git@stash:2222/spec/spec.git')
                              .with(deploy_key: 'SECRET',
                                    branch: 'master',
                                    remote_url: 'ssh://git@stash:2222/spec/spec.git',
                                    repo_path: '/tmp/repo',
                                    cache_path: '/tmp/cache',
                                    action: [:push])
    end
  end

end
