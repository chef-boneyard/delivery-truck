require 'spec_helper'

describe DeliveryTruck::Helpers do
  let(:ckbks_in_repo) do
    [
      'cookbooks/julia',
      'cookbooks/gordon',
      'cookbooks/emeril'
    ]
  end

  let(:node) { Chef::Node.new }

  describe '.changed_cookbooks' do
    before do
      node.default['delivery']['change']['sha'] = '12345'
      node.default['delivery']['workspace']['repo'] = '/tmp/repo'
      allow(described_class).to receive(:pre_change_sha)
                                 .with(node).and_return("01234")
      allow(described_class).to receive(:get_cookbook_version).and_return('1.0.0')

    end

    context 'when repo itself is a cookbook and' do
      before do
        allow(described_class).to receive(:cookbooks_in_repo)
                                   .with(node).and_return(['/tmp/repo'])
      end

      context 'there are no changes' do
        before do
          allow(described_class).to receive(:changed_files)
                                     .with('01234', '12345', node)
                                     .and_return([])
        end

        it 'returns an empty array' do
          expect(described_class.changed_cookbooks(node)).to eql []
        end
      end

      context 'there are changes' do
        before do
          allow(described_class).to receive(:changed_files)
                                     .with('01234', '12345', node)
                                     .and_return(['recipes/default.rb'])
          allow(described_class).to receive(:get_cookbook_name).with('/tmp/repo')
                                     .and_return('repo')
        end

        it 'returns a single-value array with path to the project root' do
          expect(described_class.changed_cookbooks(node)).to eql [
                                                               {:name => 'repo', :path => '/tmp/repo', :version => '1.0.0'}
                                                             ]
        end
      end
    end

    context 'when repo contains a cookbook directory and' do
      before do
        allow(described_class).to receive(:cookbooks_in_repo)
                                   .with(node).and_return([
                                                            'cookbooks/julia',
                                                            'cookbooks/gordon',
                                                            'cookbooks/emeril'
                                                          ])
      end

      context 'no cookbooks have changed' do
        before do
          allow(described_class).to receive(:changed_files)
                                     .with('01234', '12345', node)
                                     .and_return([])
        end

        it 'returns an empty array' do
          expect(described_class.changed_cookbooks(node)).to eql []
        end
      end

      context 'one cookbook has changed' do
        before do
          allow(described_class).to receive(:changed_files)
                                     .with('01234', '12345', node)
                                     .and_return(['cookbooks/julia/recipes/default.rb'])
          allow(described_class).to receive(:get_cookbook_name)
                                     .with('/tmp/repo/cookbooks/julia').and_return('julia')
        end

        it 'returns an array with one cookbook' do
          expect(described_class.changed_cookbooks(node)).to eql [
                                                               {:name => 'julia', :path => '/tmp/repo/cookbooks/julia', :version => '1.0.0'}
                                                             ]
        end
      end

      context 'multiple cookbooks have changed' do
        before do
          allow(described_class).to receive(:changed_files)
                                     .with('01234', '12345', node)
                                     .and_return([
                                                   'cookbooks/julia/recipes/default.rb',
                                                   'cookbooks/gordon/metadata.rb'
                                                 ])
          allow(described_class).to receive(:get_cookbook_name)
                                     .with('/tmp/repo/cookbooks/julia').and_return('julia')
          allow(described_class).to receive(:get_cookbook_name)
                                     .with('/tmp/repo/cookbooks/gordon').and_return('gordon')
        end

        it 'should return an array with multiple cookbooks' do
          expect(described_class.changed_cookbooks(node)).to eql [
                                                               {:name => 'julia', :path => '/tmp/repo/cookbooks/julia', :version => '1.0.0'},
                                                               {:name => 'gordon', :path => '/tmp/repo/cookbooks/gordon', :version => '1.0.0'}
                                                             ]
        end
      end
    end
  end

  describe '.get_acceptance_environment' do
    before do
      node.default['delivery']['change']['enterprise'] = 'Chef'
      node.default['delivery']['change']['organization'] = 'Delivery'
      node.default['delivery']['change']['project'] = 'Secret'
      node.default['delivery']['change']['pipeline'] = 'master'
    end

    it 'create acceptance environment slug' do
      expect(described_class.get_acceptance_environment(node)).to eql "acceptance-Chef-Delivery-Secret-master"
    end
  end

  describe '.delivery_environment' do
    before do
      node.default['delivery']['change']['enterprise'] = 'Chef'
      node.default['delivery']['change']['organization'] = 'Delivery'
      node.default['delivery']['change']['project'] = 'Secret'
      node.default['delivery']['change']['pipeline'] = 'master'
    end

    context 'when in acceptance' do
      before do
        node.default['delivery']['change']['stage'] = 'acceptance'
      end

      it 'returns the special acceptance slug' do
        expect(described_class.delivery_environment(node)).to eql "acceptance-Chef-Delivery-Secret-master"
      end
    end

    context 'when in other environment' do
      before do
        node.default['delivery']['change']['stage'] = 'delivered'
      end

      it 'returns the stage' do
        expect(described_class.delivery_environment(node)).to eql('delivered')
      end
    end
  end

  describe '.project_slug' do
    before do
      node.default['delivery']['change']['enterprise'] = 'Chef'
      node.default['delivery']['change']['organization'] = 'Delivery'
      node.default['delivery']['change']['project'] = 'Secret'
      node.default['delivery']['change']['pipeline'] = 'master'
    end

    it 'returns the project name in slug format' do
      expect(described_class.project_slug(node)).to eql "Chef-Delivery-Secret"
    end
  end

  # Ignoring for the time being since I'm not 100% sure how to deal with the
  # context switching yet.
  describe '.get_project_secrets', :ignore => true do

  end

  describe '.delivery_chef_server', :ignore => true do

  end

  describe '.changed_files' do
    let(:parent_sha) { '01234' }
    let(:change_sha) { '12345' }
    let(:response) do
      double("git diff", :stdout => [
               'cookbooks/julia/recipes/default.rb',
               'cookbooks/gordon/metadata.rb'
             ].join("\n"))
    end

    before do
      node.set['delivery']['workspace']['repo'] = '/tmp/repo'
    end

    it 'returns an array of files that changed' do
      allow(described_class).to receive(:shell_out!)
                                 .with(
                                   "git diff --name-only #{parent_sha} #{change_sha}",
                                   :cwd => "/tmp/repo"
                                 ).and_return(response)
      expect(described_class.changed_files(parent_sha, change_sha, node))
        .to eql [
              'cookbooks/julia/recipes/default.rb',
              'cookbooks/gordon/metadata.rb'
            ]
    end
  end

  describe '.cookbooks_in_repo' do
    before do
      node.set['delivery']['workspace']['repo'] = '/tmp/repo'
    end

    context 'when the project itself is a cookbook' do
      before do
        allow(described_class).to receive(:is_cookbook?).with('/tmp/repo')
                                   .and_return(true)
        allow(File).to receive(:directory?).with('/tmp/repo/cookbooks')
                        .and_return(false)
      end

      it 'returns an array with the project root in it' do
        expect(described_class.cookbooks_in_repo(node)).to eql ['/tmp/repo']
      end
    end

    context 'when there are no cookbooks' do
      before do
        allow(File).to receive(:directory?).with('/tmp/repo/cookbooks')
                        .and_return(false)
      end

      it 'returns an empty array' do
        expect(described_class.cookbooks_in_repo(node)).to eql []
      end
    end

    context 'when there are one or more cookbooks in a cookbooks dir' do
      before do
        allow(described_class).to receive(:is_cookbook?).with('/tmp/repo').and_return(false)
        allow(File).to receive(:directory?).with('/tmp/repo/cookbooks').and_return(true)
        ['julia', 'gordon', 'emeril'].each do |chef|
          allow(File).to receive(:directory?).with("/tmp/repo/cookbooks/#{chef}").and_return(true)
          allow(described_class).to receive(:is_cookbook?)
                                     .with("/tmp/repo/cookbooks/#{chef}").and_return(true)
        end

        allow(Dir).to receive(:chdir).with('/tmp/repo'){ |_, &block| block.call }
        allow(Dir).to receive(:glob).with('cookbooks/*').and_return([
                                                                      'cookbooks/julia',
                                                                      'cookbooks/gordon',
                                                                      'cookbooks/emeril'
                                                                    ])
      end

      it 'returns an array with cookbook paths relative to project root' do
        expect(described_class.cookbooks_in_repo(node)).to eql [
                                                             'cookbooks/julia',
                                                             'cookbooks/gordon',
                                                             'cookbooks/emeril'
                                                           ]
      end
    end
  end

  describe '.is_cookbook?' do
    context 'when no metadata files exist' do
      before do
        allow(File).to receive(:exist?).with('/tmp/metadata.json')
                        .and_return(false)
        allow(File).to receive(:exist?).with('/tmp/metadata.rb')
                        .and_return(false)
      end

      it 'returns false' do
        expect(described_class.is_cookbook?('/tmp')).to eql false
      end
    end

    context 'when a metadata.json file exists' do
      before do
        allow(File).to receive(:exist?).with('/tmp/metadata.json')
                        .and_return(true)
        allow(File).to receive(:exist?).with('/tmp/metadata.rb')
                        .and_return(false)
      end

      it 'returns true' do
        expect(described_class.is_cookbook?('/tmp')).to eql true
      end
    end

    context 'when a metadata.rb file exists' do
      before do
        allow(File).to receive(:exist?).with('/tmp/metadata.json')
                        .and_return(true)
        allow(File).to receive(:exist?).with('/tmp/metadata.rb')
                        .and_return(false)
      end

      it 'returns true' do
        expect(described_class.is_cookbook?('/tmp')).to eql true
      end
    end
  end

  describe '.pre_change_sha' do
    let(:response) { double("git rev-parse", :stdout => "qwerty012\n") }

    context 'when running in verify' do
      before do
        node.default['delivery']['change']['stage'] = 'verify'
        node.default['delivery']['change']['pipeline'] = 'master'
        node.default['delivery']['workspace']['repo'] = '/tmp/repo'
        allow(described_class).to receive(:shell_out).with(
                                    "git rev-parse origin/master",
                                    :cwd => '/tmp/repo'
                                  ).and_return(response)
      end

      it 'returns the SHA at the HEAD of the pipeline branch' do
        expect(described_class.pre_change_sha(node)).to eql 'qwerty012'
      end
    end

    context 'when running in later stages' do
      before do
        node.default['delivery']['change']['stage'] = 'build'
        node.default['delivery']['change']['pipeline'] = 'master'
        node.default['delivery']['workspace']['repo'] = '/tmp/repo'
        allow(described_class).to receive(:shell_out).with(
                                    "git log origin/master --merges --pretty=\"%H\" -n2 | tail -n1",
                                    :cwd => '/tmp/repo'
                                  ).and_return(response)
      end

      it 'returns the SHA for the 2nd most recent merge to pipeline' do
        expect(described_class.pre_change_sha(node)).to eql 'qwerty012'
      end
    end
  end
end
