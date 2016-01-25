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

# TODO: This is a temporary workaround; ultimately, this should be
# handled either by delivery_build or (preferably) the server itself.
ruby_block "copy env from prior to current" do
  block do
    with_server_config do
      case node['delivery']['change']['stage']
      when 'acceptance'
        ::DeliveryTruck::Helpers::Provision.handle_acceptance_pinnings(get_acceptance_environment)
      when 'union'
        ::DeliveryTruck::Helpers::Provision.handle_union_pinnings(get_acceptance_environment)
      else
        ::DeliveryTruck::Helpers::Provision.handle_other_pinnings
      end
    end
  end
end
