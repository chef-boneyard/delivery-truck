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
    module Lint
      extend self

      # Based on the properties in the Delivery Config, create the tags string
      # that will be passed into the foodcritic command.
      #
      # @param node [Chef::Node] Chef Node object
      # @return [String]
      def foodcritic_tags(node)
        begin
          config = node[CONFIG_ATTRIBUTE_KEY]['build_attributes']['lint']['foodcritic']
          case
          when config['only_rules'] && !config['only_rules'].empty?
            "-t " + config['only_rules'].join(" -t ")
          when config['ignore_rules'] && !config['ignore_rules'].empty?
            "-t ~" + config['ignore_rules'].join(" -t ~")
          else
            ""
          end
        rescue
          ""
        end
      end
    end
  end

  module DSL

    # Return the applicable tags for foodcritic runs
    def foodcritic_tags
      DeliveryTruck::Helpers::Lint.foodcritic_tags(node)
    end
  end
end
