require 'spec_helper'

describe "delivery-truck::quality" do
  let(:chef_run) do
    ChefSpec::SoloRunner.new do |node|
      node.set['delivery']['workspace']['root'] = '/tmp'
      node.set['delivery']['workspace']['repo'] = '/tmp/repo'
      node.set['delivery']['workspace']['chef'] = '/tmp/chef'
      node.set['delivery']['workspace']['cache'] = '/tmp/cache'

      node.set['delivery']['change']['enterprise'] = 'Chef'
      node.set['delivery']['change']['organization'] = 'Delivery'
      node.set['delivery']['change']['project'] = 'Secret'
    end.converge(described_recipe)
  end

  context "when a .kitchen-ec2.yml file is present" do
    let(:secrets) {{
      'ec2' => {
        'access_key' => 'MyAccessKey',
        'secret_key' => 'MySecretKey',
        'keypair_name' => 'MyKeypairName',
        'private_key' => 'MyPrivatKey'
      }
    }}

    before do
      allow_any_instance_of(Chef::Recipe).to receive(:get_project_secrets).and_return(secrets)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('HOME').and_return('/tmp/cache')
      allow(File).to receive(:exists?).and_call_original
      allow(File).to receive(:exists?).with("/tmp/repo/.kitchen-ec2.yml").and_return(true)
    end

    it 'creates the ~/.aws and ~/.ssh directories correctly' do
      %w[ .aws .ssh ].each { |d| expect(chef_run).to create_directory(File.join(ENV['HOME'], d)) }
    end

    it 'creates the ~/.aws/credentials file with correct contents' do
      expect(chef_run).to create_template(File.join(ENV['HOME'], '.aws/credentials'))
      expect(chef_run).to render_file(File.join(ENV['HOME'], '.aws/credentials')).with_content { |content|
        expect(content).to include ("aws_access_key_id = #{secrets['ec2']['access_key']}")
        expect(content).to include ("aws_secret_access_key = #{secrets['ec2']['secret_key']}")
      }
    end

    it 'creates the EC2 private key file with the correct contents' do
      expect(chef_run).to render_file(File.join(ENV['HOME'], ".ssh/#{secrets['ec2']['keypair_name']}.pem")).with_content(secrets['ec2']['private_key'])
    end

    it "runs kitchen test" do
      expect(chef_run).to run_execute("kitchen test")
    end
  end

  context "when a .kitchen-ec2.yml file is not present" do
    before do
      # allow_any_instance_of(Chef::Recipe).to receive(:changed_cookbooks).and_return(one_changed_cookbook)
      allow(File).to receive(:exists?).and_call_original
      allow(File).to receive(:exists?).with("/tmp/repo/.kitchen-ec2.yml").and_return(false)
    end

    it "does not run kitchen test" do
      expect(chef_run).not_to run_execute("kitchen test")
    end
  end
end
