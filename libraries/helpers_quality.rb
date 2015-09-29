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

      # See if there's a .kitchen.ec2.yml file at the root of the repo, return true if so
      #
      # @param [Chef::Node] Chef Node object
      # @return [TrueClass, FalseClass]
      def has_kitchen_ec2_tests?(node)
        File.exists?( "#{node['delivery']['workspace']['repo']}/.kitchen.ec2.yml" )
      rescue
        false
      end
    end
  end

  module DSL
    # Check for whether user wants to run test kitchen
    def run_test_kitchen_ec2?
      # For now, we only check for ec2 tests - the logic will need to be more nuanced if/when new drivers are added
      DeliveryTruck::Helpers::Quality.has_kitchen_ec2_tests?(node)
    end

    # Return file system path to .kitchen.ec2.yml file
    #
    # @param [Chef::Node] Chef Node object
    # @return [String] String representing full path to .kitchen.ec2.yml file in the repo
    def kitchen_ec2_yml_file
      File.join(node['delivery']['workspace']['repo'], 'kitchen.ec2.yml')
    end
  end
end
