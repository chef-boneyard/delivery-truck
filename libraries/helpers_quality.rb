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

module DeliveryTruck
  module Helpers
    module Quality
      extend self

      # See if there's a .kitchen-ec2.yml file at the root of the repo, return true if so
      #
      # @param [Chef::Node] Chef Node object
      # @return [TrueClass, FalseClass]
      def run_kitchen_test?(node)
        File.exists?( "#{node['delivery']['workspace']['repo']}/.kitchen-ec2.yml" )
      rescue
        false
      end
    end
  end

  module DSL
    # Check for whether user wants to run test kitchen using kitchen-ec2
    def run_test_kitchen?
      DeliveryTruck::Helpers::Quality.run_kitchen_test?(node)
    end
  end
end
