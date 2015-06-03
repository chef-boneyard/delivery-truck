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

# These files create / add to the Delivery::DSL module
require_relative 'helpers_functional'
require_relative 'helpers_lint'
require_relative 'helpers_unit'
require_relative 'helpers_publish'
require_relative 'helpers_syntax'
require_relative 'helpers_deploy'

# And these mix the DSL methods into the Chef infrastructure
Chef::Recipe.send(:include, DeliveryTruck::DSL)
Chef::Resource.send(:include, DeliveryTruck::DSL)
Chef::Provider.send(:include, DeliveryTruck::DSL)
