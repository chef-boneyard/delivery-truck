require 'spec_helper'

module DeliverySugar
  class Change
    def changed_files
    end
  end
end

describe DeliveryTruck::Helpers::Syntax do

  describe '.bumped_version?' do
    let(:node) do
      nodee = Chef::Node.new
      nodee.default['delivery']['workspace']['repo'] = '/tmp/repo'
      nodee.default['delivery']['change']['sha'] = '0123456789abcdef'
      nodee
    end

    let(:sugar_change) { instance_double("DeliverySugar::Change") }

    before(:each) do
      allow(DeliverySugar::Change).to receive(:new).and_return(sugar_change)
      allow(sugar_change).to receive(:changed_files).and_return(changed_files)
    end

    context 'when metadata in root cookbook was updated' do
      let(:changed_files) { ['README.md', 'recipes/default.rb', 'metadata.rb'] }

      it 'returns true' do
        expect(described_class.bumped_version?('/tmp/repo', node)).to eql true
      end
    end

    context 'when metadata in root cookbook was not updated' do
      let(:changed_files) { ['README.md', 'recipes/default.rb'] }

      it 'returns false' do
        expect(described_class.bumped_version?('/tmp/repo', node)).to eql false
      end
    end

    context 'when non-cookbook file in root cookbook was updated' do
      let(:changed_files) { ['README.md'] }

      it 'returns false' do
        expect(described_class.bumped_version?('/tmp/repo', node)).to eql true
      end
    end

    context 'when metadata for cookbook in cookbooks directory was updated' do
      let(:changed_files) { ['cookbooks/julia/README.md', 'cookbooks/julia/recipes/default.rb', 'cookbooks/julia/metadata.rb'] }

      it 'returns true' do
        expect(described_class.bumped_version?('/tmp/repo/cookbooks/julia', node)).to eql true
      end
    end

    context 'when metadata for cookbook in cookbooks directory was not updated' do
      let(:changed_files) { ['cookbooks/julia/README.md', 'cookbooks/julia/recipes/default.rb' ] }

      it 'returns false' do
        expect(described_class.bumped_version?('/tmp/repo/cookbooks/julia', node)).to eql false
      end
    end

    context 'when non-cookbook file in root cookbook was updated' do
      let(:changed_files) { ['cookbooks/julia/README.md'] }

      it 'returns false' do
        expect(described_class.bumped_version?('/tmp/repo/cookbooks/julia', node)).to eql true
      end
    end
  end
end
