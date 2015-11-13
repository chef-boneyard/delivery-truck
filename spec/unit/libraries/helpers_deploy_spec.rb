require 'spec_helper'

describe DeliveryTruck::Helpers::Deploy do
  let(:node) { Chef::Node.new }

  describe '.deployment_search_query' do
    context 'when config value is unset' do
      it 'returns default search query' do
        expect(described_class.deployment_search_query(node)).to eql('recipes:*push-jobs*')
      end
    end

    context 'when config value is set' do
      let(:custom_search){ 'cool:attributes OR awful:constraints' }
      it 'returns the custom search query' do
        node.default['delivery']['config']['delivery-truck']['deploy']['search'] = custom_search
        expect(described_class.deployment_search_query(node)).to eql(custom_search)
      end
    end
  end
end
