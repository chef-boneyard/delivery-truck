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

# Setup AUFS
# There is currently a bug in devicemapper with Docker #9562 and #4036.
# To get around this we are using AUFS.
include_recipe 'aufs'

# Install and setup Docker
include_recipe 'docker'

# Allow dbuild to execute Docker as sudo
sudo 'dbuild-docker' do
  user 'dbuild'
  runas 'root'
  commands ['/usr/bin/docker']
  defaults ['setenv', 'env_reset']
  nopasswd true
end

chef_gem 'kitchen-docker' do
  version '2.0.0'
end

# Temporary workaround until we reliably use a newer version of ChefDK
chef_gem 'chefspec' do
  version '4.1.1'
end

# Temporary workaround until chefdk installs chef-sugar.
chef_gem 'chef-sugar' do
  # We always ride the latest version of chef-sugar. This could prove dangerous
  # but it more closely matches the CD philosophy which Delivery implements!
  action :upgrade
end
