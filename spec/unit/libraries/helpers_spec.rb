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
      allow(described_class).to receive(:pre_change_sha)
        .with(node).and_return("01234")
      allow(described_class).to receive(:change_sha)
        .with(node).and_return("12345")
      allow(described_class).to receive(:repo_path)
        .with(node).and_return("/tmp")
    end

    context 'when repo itself is a cookbook and' do
      before do
        allow(described_class).to receive(:cookbooks_in_repo)
          .with(node).and_return(['/tmp'])
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
          allow(described_class).to receive(:get_cookbook_name).with('/tmp')
            .and_return('tmp')
        end

        it 'returns a single-value array with path to the project root' do
          expect(described_class.changed_cookbooks(node)).to eql [
            {:name => 'tmp', :path => '/tmp'}
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
            .with('/tmp/cookbooks/julia').and_return('julia')
        end

        it 'returns an array with one cookbook' do
          expect(described_class.changed_cookbooks(node)).to eql [
            {:name => 'julia', :path => '/tmp/cookbooks/julia'}
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
            .with('/tmp/cookbooks/julia').and_return('julia')
          allow(described_class).to receive(:get_cookbook_name)
            .with('/tmp/cookbooks/gordon').and_return('gordon')
        end

        it 'should return an array with multiple cookbooks' do
          expect(described_class.changed_cookbooks(node)).to eql [
            {:name => 'julia', :path => '/tmp/cookbooks/julia'},
            {:name => 'gordon', :path => '/tmp/cookbooks/gordon'}
          ]
        end
      end
    end
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
      allow(described_class).to receive(:repo_path)
        .with(node).and_return("/tmp")
    end

    it 'returns an array of files that changed' do
      allow(described_class).to receive(:shell_out!)
        .with(
          "git diff --name-only #{parent_sha} #{change_sha}",
          :cwd => "/tmp"
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
      allow(described_class).to receive(:repo_path).with(node)
        .and_return("/tmp")
    end

    context 'when the project itself is a cookbook' do
      before do
        allow(described_class).to receive(:is_cookbook?).with('/tmp')
          .and_return(true)
        allow(File).to receive(:directory?).with('/tmp/cookbooks')
          .and_return(false)
      end

      it 'returns an array with the project root in it' do
        expect(described_class.cookbooks_in_repo(node)).to eql ['/tmp']
      end
    end

    context 'when there are no cookbooks' do
      before do
        allow(described_class).to receive(:is_cookbook?).with('/tmp')
          .and_return(false)
        allow(File).to receive(:directory?).with('/tmp/cookbooks')
          .and_return(false)
      end

      it 'returns an empty array' do
        expect(described_class.cookbooks_in_repo(node)).to eql []
      end
    end

    context 'when there are one or more cookbooks in a cookbooks dir' do
      before do
        allow(described_class).to receive(:is_cookbook?).with('/tmp')
          .and_return(false)
        allow(File).to receive(:directory?).with('/tmp/cookbooks')
          .and_return(true)
        ['julia', 'gordon', 'emeril'].each do |chef|
          allow(File).to receive(:directory?).with("/tmp/cookbooks/#{chef}")
            .and_return(true)
          allow(described_class).to receive(:is_cookbook?)
            .with("/tmp/cookbooks/#{chef}").and_return(true)
        end

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

  describe '.get_cookbook_name' do

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

  describe '.load_config' do
    context 'when node attribute is already set' do
      before do
        node.force_override['delivery_config'] = {'preset' => true}
      end

      it 'does nothing' do
        described_class.load_config('.delivery/config.json', node)
        expect(node['delivery_config']).to eql({'preset' => true})
      end
    end

    context 'when node attribute is not set' do
      before do
        allow(described_class).to receive(:repo_path).with(node)
          .and_return('/tmp')
        allow(File).to receive(:exist?).with('/tmp/.delivery/config.json')
          .and_return(true)
        allow(IO).to receive(:read).with('/tmp/.delivery/config.json')
          .and_return("{\"postset\":true}")
      end

      it 'sets the config values' do
        described_class.load_config('/tmp/.delivery/config.json', node)
        expect(node['delivery_config']).to eql({'postset' => true})
      end
    end

    context 'when configuration file is missing' do
      before do
        allow(described_class).to receive(:repo_path).with(node)
          .and_return('/tmp')
        allow(File).to receive(:exist?).with('/tmp/.delivery/config.json')
          .and_return(false)
      end

      it 'raises an MissingConfiguration exception' do
        expect{described_class.load_config('/tmp/.delivery/config.json', node)}
          .to raise_error DeliveryTruck::MissingConfiguration
      end
    end
  end

  describe '.change_sha' do
    before { node.default['delivery_builder']['change']['sha'] = '01234'}
    subject { described_class.change_sha(node) }
    it { is_expected.to eql '01234' }
  end

  describe '.pre_change_sha' do
    let(:response) { double("git rev-parse", :stdout => "qwerty012\n") }

    context 'when running in verify' do
      before do
        node.default['delivery_builder']['change']['stage'] = 'verify'
        node.default['delivery_builder']['change']['pipeline'] = 'master'
        allow(described_class).to receive(:repo_path).with(node).and_return('/tmp')
        allow(described_class).to receive(:shell_out).with(
                                    "git rev-parse origin/master",
                                    :cwd => '/tmp'
                                  ).and_return(response)
      end

      it 'returns the SHA at the HEAD of the pipeline branch' do
        expect(described_class.pre_change_sha(node)).to eql 'qwerty012'
      end
    end

    context 'when running in later stages' do
      before do
        node.default['delivery_builder']['change']['stage'] = 'build'
        node.default['delivery_builder']['change']['pipeline'] = 'master'
        allow(described_class).to receive(:repo_path).with(node).and_return('/tmp')
        allow(described_class).to receive(:shell_out).with(
                                    "git log origin/master --merges --pretty=\"%H\" -n2 | tail -n1",
                                    :cwd => '/tmp'
                                  ).and_return(response)
      end

      it 'returns the SHA for the 2nd most recent merge to pipeline' do
        expect(described_class.pre_change_sha(node)).to eql 'qwerty012'
      end
    end
  end

  describe '.repo_path' do
    before { node.default['delivery_builder']['repo'] = '/tmp' }
    subject { described_class.repo_path(node) }
    it { is_expected.to eql '/tmp' }
  end

  describe '.current_stage' do
    before { node.default['delivery_builder']['change']['stage'] = 'union' }
    subject { described_class.current_stage(node) }
    it { is_expected.to eql 'union' }
  end
end
