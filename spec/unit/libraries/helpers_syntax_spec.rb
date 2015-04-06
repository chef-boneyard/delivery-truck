require 'spec_helper'

describe DeliveryTruck::Helpers::Syntax do

  describe '.bumped_version?' do
    let(:node) do
      nodee = Chef::Node.new
      nodee.default['delivery']['workspace']['repo'] = '/tmp/repo'
      nodee.default['delivery']['change']['sha'] = '0123456789abcdef'
      nodee
    end

    before(:each) do
      allow(DeliveryTruck::Helpers).to receive(:changed_files).and_return(changed_files)
      allow(DeliveryTruck::Helpers).to receive(:pre_change_sha).and_return('ABCDEFG')
    end

    context 'when metadata in root cookbook was updated' do
      let(:changed_files) { ['recipes/default.rb', 'metadata.rb'] }

      it 'returns true' do
        expect(described_class.bumped_version?('/tmp/repo', node)).to eql true
      end
    end

    context 'when metadata in root cookbook was not updated' do
      let(:changed_files) { ['recipes/default.rb'] }

      it 'returns false' do
        expect(described_class.bumped_version?('/tmp/repo', node)).to eql false
      end
    end

    context 'when metadata for cookbook in cookbooks directory was updated' do
      let(:changed_files) { ['cookbooks/julia/recipes/default.rb', 'cookbooks/julia/metadata.rb'] }

      it 'returns true' do
        expect(described_class.bumped_version?('/tmp/repo/cookbooks/julia', node)).to eql true
      end
    end

    context 'when metadata for cookbook in cookbooks directory was not updated' do
      let(:changed_files) { ['cookbooks/julia/recipes/default.rb' ] }

      it 'returns false' do
        expect(described_class.bumped_version?('/tmp/repo/cookbooks/julia', node)).to eql false
      end
    end
  end
end
