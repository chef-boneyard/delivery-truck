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

if defined?(ChefSpec)
  def create_chef_environment(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:chef_environment, :create, resource_name)
  end

  def run_delivery_truck_deploy(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:delivery_truck_deploy, :run, resource_name)
  end
end
