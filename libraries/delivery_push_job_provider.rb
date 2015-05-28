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

require 'chef/provider'

class Chef
  class Provider
    class DeliveryPushJob < Chef::Provider
      attr_reader :push_job

      def whyrun_supported?
        true
      end

      def initialize(new_resource, run_context)
        super

        @push_job = DeliverySugar::PushJob.new(
          new_resource.server_url,
          new_resource.command,
          new_resource.nodes,
          new_resource.timeout
        )
      end

      def load_current_resource
      end

      def action_dispatch
        converge_by("Dispatch push jobs for #{new_resource.command} on " \
                    "#{new_resource.nodes.join(',')}") do
          @push_job.dispatch
          @push_job.wait
          new_resource.updated_by_last_action(true)
        end unless new_resource.nodes.empty?
      end
    end
  end
end
