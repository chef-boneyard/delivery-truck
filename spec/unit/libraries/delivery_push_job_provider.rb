require 'spec_helper'
require 'chef/node'
require 'chef/event_dispatch/dispatcher'
require 'chef/run_context'

describe Chef::Provider::DeliveryPushJob do
  let(:node) { Chef::Node.new }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node, {}, events) }

  let(:nodes) { %w(node1 node2) }
  let(:server_url) { 'http://push.example.com' }
  let(:command) { 'chef-client' }
  let(:timeout) { 10 }

  let(:new_resource) { Chef::Resource::DeliveryPushJob.new(command, run_context) }
  let(:provider) { described_class.new(new_resource, run_context) }

  let(:rest) { double('Chef::REST') }

  before do
    allow(Chef::REST).to receive(:new).with(server_url).and_return(rest)
    new_resource.nodes nodes
    new_resource.server_url server_url
    new_resource.timeout timeout
  end

  describe '#initialize' do
    it 'established connection to Push Server API' do
      expect(DeliverySugar::PushJob).to receive(:new).with(
        server_url,
        command,
        nodes,
        timeout
      )
      described_class.new(new_resource, nil)
    end
  end

  describe '#action_dispatch' do
    context 'when the node list is empty' do
      let(:nodes) { [] }

      it 'does nothing' do
        expect(provider.push_job).not_to receive(:dispatch)
        expect(provider.push_job).not_to receive(:wait)
        provider.action_dispatch
      end
    end

    it 'dispatches push job and waits for completion' do
      allow(provider.push_job).to receive(:dispatch)
      allow(provider.push_job).to receive(:wait)
      expect(new_resource).to receive(:updated_by_last_action).with(true)
      provider.action_dispatch
    end
  end
end
