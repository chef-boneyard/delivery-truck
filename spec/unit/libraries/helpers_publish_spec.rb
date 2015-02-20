require 'spec_helper'

describe DeliveryTruck::Helpers::Publish do
  let(:node) { Chef::Node.new }

  describe '.upload_cookbook_to_chef_server?' do
    context 'when config value is unset' do
      it 'returns false' do
        expect(described_class.upload_cookbook_to_chef_server?(node)).to eql(false)
      end
    end

    context 'when config value is set' do
      it 'returns the value' do
        node.default['delivery_config']['build_attributes']['publish']['chef_server'] = true
        expect(described_class.upload_cookbook_to_chef_server?(node)).to eql(true)

        node.default['delivery_config']['build_attributes']['publish']['chef_server'] = false
        expect(described_class.upload_cookbook_to_chef_server?(node)).to eql(false)
      end
    end

  end

  describe '.push_repo_to_github?' do
    context 'when value is unspecified' do
      it 'returns false' do
        expect(described_class.push_repo_to_github?(node)).to eql(false)
      end
    end

    context 'when config value is set' do
      it 'returns the value' do
        node.default['delivery_config']['build_attributes']['publish']['github'] = true
        expect(described_class.push_repo_to_github?(node)).to eql(true)

        node.default['delivery_config']['build_attributes']['publish']['github'] = false
        expect(described_class.push_repo_to_github?(node)).to eql(false)
      end
    end
  end

  describe '.github_repo' do
    before do
      node.default['delivery_config']['build_attributes']['publish']['github'] = 'chef/chef'
    end

    it 'returns the github repo' do
      expect(described_class.github_repo(node)).to eql('chef/chef')
    end
  end
end
