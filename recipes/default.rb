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
#

ENV['PATH'] = "/opt/chefdk/bin:/opt/chefdk/embedded/bin:#{ENV['PATH']}"

#######################################################################

# Temporary workaround until we reliably use a newer version of ChefDK
chef_gem 'chefspec' do
  compile_time false
  version '4.1.1'
end

# Temporary workaround until chefdk installs chef-sugar.
chef_gem 'chef-sugar' do
  compile_time false
  # We always ride the latest version of chef-sugar. This could prove dangerous
  # but it more closely matches the CD philosophy which Delivery implements!
  action :upgrade
end

# If the user specified a supermarket server lets install the knife plugin
chef_gem 'knife-supermarket' do
  compile_time false
  only_if { share_cookbook_to_supermarket? }
  action :install
end

# If the user user wants to run test kitchen during the quality phase
chef_gem 'kitchen-ec2' do
  compile_time false
  only_if { run_test_kitchen? }
  action :install
end
