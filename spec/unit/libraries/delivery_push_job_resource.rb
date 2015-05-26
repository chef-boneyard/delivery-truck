require 'spec_helper'
require 'chef/resource'

describe Chef::Resource::DeliveryPushJob do
  before(:each) do
    @resource = described_class.new('push_job')
  end

  describe '#initialize' do
    it 'creates a new Chef::Resource::DeliveryPushJob with default attrs' do
      expect(@resource).to be_a(Chef::Resource)
      expect(@resource).to be_a(described_class)
      expect(@resource.provider).to be(Chef::Provider::DeliveryPushJob)
      expect(@resource.command).to eql('push_job')
      expect(@resource.timeout).to eql(30 * 60)
      expect(@resource.nodes).to eql([])
    end

    it 'has a resource name of :delivery_push_job' do
      expect(@resource.resource_name).to eql(:delivery_push_job)
    end
  end

  describe '#command' do
    it 'requires a string' do
      @resource.command 'dance'
      expect(@resource.command).to eql('dance')
      expect { @resource.send(:command, ['r']) }.to raise_error(ArgumentError)
    end
  end

  describe '#timeout' do
    it 'requires an Integer' do
      @resource.timeout 10
      expect(@resource.timeout).to eql(10)
      expect { @resource.send(:timeout, '10') }.to raise_error(ArgumentError)
    end
  end

  describe '#nodes' do
    it 'requires an Array' do
      @resource.nodes %w(a b)
      expect(@resource.nodes).to eql(%w(a b))
      expect { @resource.send(:nodes, 'a') }.to raise_error(ArgumentError)
    end
  end
end
