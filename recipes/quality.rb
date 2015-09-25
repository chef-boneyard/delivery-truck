#
# Copyright:: Copyright (c) 2015 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if run_test_kitchen?
  # Load secrets from delivery-truck data bag
  my_secrets = get_project_secrets

  # Variables we'll use for configuring and running test kitchen
  homedir = ENV['HOME']
  ec2_keypair_name = my_secrets['ec2']['keypair_name']
  ec2_private_key_file = "#{homedir}/.ssh/#{ec2_keypair_name}.pem"

  # Create directories for AWS credentials and SSH key
  %w[ .aws .ssh ].each { |d| directory File.join(ENV['HOME'], d) }

  # Create AWS credentials file
  template "#{homedir}/.aws/credentials" do
    mode '0400'
    variables(
      access_key: my_secrets['ec2']['access_key'],
      secret_key: my_secrets['ec2']['secret_key']
    )
  end

  # Create private key
  file ec2_private_key_file do
    mode      '0400'
    content   my_secrets['ec2']['private_key']
    sensitive true
  end

  # Run kitchen test, passing ENV variables for kitchen to use
  execute 'kitchen test' do
    cwd node['delivery']['workspace']['repo']
    environment(
      'KITCHEN_YAML'              => "#{node['delivery']['workspace']['repo']}/.kitchen-ec2.yml",
      'AWS_SSH_KEY_ID'            => ec2_keypair_name,
      'KITCHEN_EC2_SSH_KEY_PATH'  => ec2_private_key_file,
      'KITCHEN_INSTANCE_NAME'     => "test-kitchen-#{node['delivery']['change']['project']}-#{node['delivery']['change']['change_id']}" 
    )
  end
end
