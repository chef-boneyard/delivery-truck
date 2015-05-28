require 'spec_helper'

describe DeliverySugar::Exceptions::PushJobFailed do
  let(:job) do
    {
      'id' => 'aaaaaaaaaaaa25fd67fa8715fd547d3d',
      'command' => 'chef-client',
      'run_timeout' => 30,
      'status' => 'complete',
      'created_at' => 'Tue, 04 Sep 2012 23:01:02 GMT',
      'updated_at' => 'Tue, 04 Sep 2012 23:17:56 GMT',
      'nodes' => {
        'crashed' => %w(node1 node3),
        'succeeded' => ['node2']
      }
    }
  end

  describe '#to_s' do
    let(:expected_output) do
      <<-EOM
The push-job aaaaaaaaaaaa25fd67fa8715fd547d3d failed to complete successfully.

Command: chef-client
Nodes:
   crashed: node1, node3
   succeeded: node2

      EOM
    end

    subject { described_class.new(job) }

    it 'returns the expected output' do
      expect(subject.to_s).to eql(expected_output)
    end
  end
end

describe DeliverySugar::Exceptions::PushJobError do
  let(:job) do
    {
      'id' => 'aaaaaaaaaaaa25fd67fa8715fd547d3d',
      'command' => 'chef-client',
      'run_timeout' => 30,
      'status' => 'crashed',
      'created_at' => 'Tue, 04 Sep 2012 23:01:02 GMT',
      'updated_at' => 'Tue, 04 Sep 2012 23:17:56 GMT',
      'nodes' => {
        'crashed' => %w(node1 node3),
        'succeeded' => ['node2']
      }
    }
  end

  describe '#to_s' do
    let(:expected_output) do
      <<-EOM
The push-job aaaaaaaaaaaa25fd67fa8715fd547d3d failed with error state "crashed".

Command: chef-client
Nodes:
   crashed: node1, node3
   succeeded: node2

      EOM
    end

    subject { described_class.new(job) }

    it 'returns the expected output' do
      expect(subject.to_s).to eql(expected_output)
    end
  end
end
