require 'spec_helper'

describe DeliveryTruck::Helpers::Lint do
  let(:node) { Chef::Node.new }

  describe '.foodcritic_tags' do
    context 'when foodcritic config is nil' do
      before do
        node.default['delivery']['config']['delivery-truck']['lint']['foodcritic'] = nil
      end

      it 'returns an empty string' do
        expect(described_class.foodcritic_tags(node)).to eql ""
      end
    end

    context 'when foodcritic config is empty' do
      before do
        node.default['delivery']['config']['delivery-truck']['lint']['foodcritic'] = {}
      end

      it 'returns an empty string' do
        expect(described_class.foodcritic_tags(node)).to eql ""
      end
    end

    context 'when `only_rules` has been set' do
      context 'with no rules' do
        before do
          node.default['delivery']['config']['delivery-truck']['lint']['foodcritic']['only_rules'] = []
        end

        it 'returns an empty string' do
          expect(described_class.foodcritic_tags(node)).to eql ""
        end
      end

      context 'with one rule' do
        before do
          node.default['delivery']['config']['delivery-truck']['lint']['foodcritic']['only_rules'] = ['FC001']
        end

        it 'returns a string with the one rule' do
          expect(described_class.foodcritic_tags(node)).to eql "-t FC001"
        end
      end

      context 'with multiple rules' do
        before do
          node.default['delivery']['config']['delivery-truck']['lint']['foodcritic']['only_rules'] = ['FC001', 'FC002']
        end

        it 'returns a string with multiple rules' do
          expect(described_class.foodcritic_tags(node)).to eql "-t FC001 -t FC002"
        end
      end
    end

    context 'when `ignore_rules` has been set' do
      context 'with no rules' do
        before do
          node.default['delivery']['config']['delivery-truck']['lint']['foodcritic']['ignore_rules'] = []
        end

        it 'returns an empty string' do
          expect(described_class.foodcritic_tags(node)).to eql ""
        end
      end

      context 'with one rule' do
        before do
          node.default['delivery']['config']['delivery-truck']['lint']['foodcritic']['ignore_rules'] = ['FC001']
        end

        it 'returns a string with the one rule' do
          expect(described_class.foodcritic_tags(node)).to eql "-t ~FC001"
        end
      end

      context 'with multiple rules' do
        before do
          node.default['delivery']['config']['delivery-truck']['lint']['foodcritic']['ignore_rules'] = ['FC001', 'FC002']
        end

        it 'returns a string with multiple rules' do
          expect(described_class.foodcritic_tags(node)).to eql "-t ~FC001 -t ~FC002"
        end
      end
    end

    context 'when `only_rules` and `ignore_rules` have both been set' do
      before do
        node.default['delivery']['config']['delivery-truck']['lint']['foodcritic']['only_rules'] = ['FC001']
        node.default['delivery']['config']['delivery-truck']['lint']['foodcritic']['ignore_rules'] = ['FC002']
      end

      it 'only `only_rules` values are honored' do
        expect(described_class.foodcritic_tags(node)). to eql "-t FC001"
      end
    end

    context 'when `exclude` has been set' do
      context 'with no paths' do
        before do
          node.default['delivery']['config']['delivery-truck']['lint']['foodcritic']['excludes'] = []
        end

        it 'returns an empty string' do
          expect(described_class.foodcritic_excludes(node)).to eql ""
        end
      end

      context 'with one path' do
        before do
          node.default['delivery']['config']['delivery-truck']['lint']['foodcritic']['excludes'] = ['spec']
        end

        it 'returns a string with the one exclude' do
          expect(described_class.foodcritic_excludes(node)).to eql "--exclude spec"
        end
      end

      context 'with multiple paths' do
        before do
          node.default['delivery']['config']['delivery-truck']['lint']['foodcritic']['excludes'] = ['spec', 'test']
        end

        it 'returns a string with multiple execludes' do
          expect(described_class.foodcritic_excludes(node)).to eql "--exclude spec --exclude test"
        end
      end
    end
  end
end
