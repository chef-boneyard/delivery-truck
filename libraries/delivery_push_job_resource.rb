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

require 'chef/resource'

class Chef
  class Resource
    class DeliveryPushJob < Chef::Resource
      provides :delivery_push_job

      def initialize(name, run_context = nil)
        super
        @resource_name = :delivery_push_job

        @command = name
        @timeout = 30 * 60 # 30 minutes
        @nodes = []
        @server_url = Chef::Config[:chef_server_url]

        @provider = Chef::Provider::DeliveryPushJob
        @action = :dispatch
        @allowed_actions.push(:dispatch)
      end

      def command(arg = nil)
        set_or_return(
          :command,
          arg,
          kind_of: String
        )
      end

      def nodes(arg = nil)
        set_or_return(
          :nodes,
          arg,
          kind_of: Array
        )
      end

      def server_url(arg = nil)
        set_or_return(
          :server_url,
          arg,
          kind_of: String
        )
      end

      def timeout(arg = nil)
        set_or_return(
          :timeout,
          arg,
          kind_of: Integer
        )
      end
    end
  end
end
