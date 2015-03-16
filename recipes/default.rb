#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
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

# Add dbuild to sudoers for Docker commands
file '/etc/sudoers.d/delivery-truck' do
  content "dbuild ALL= NOPASSWD:SETENV: /usr/bin/docker\n"
  mode '440'
  owner 'root'
  group 'root'
end

# Install Docker
package 'curl'
execute 'install_docker' do
  command 'curl -sSL https://get.docker.com/ubuntu/ | sudo sh'
end

service 'docker' do
  action :start
end

# Install the kitchen-docker gem
chef_gem 'kitchen-docker' do
  version '1.7.0'
end

# Temporary workaround until we reliably use a newer version of ChefDK
chef_gem 'chefspec' do
  version '4.1.1'
end

# Temporary workaround until chefdk installs chef-sugar.
chef_gem 'chef-sugar' do
  version '2.5.0'
end
