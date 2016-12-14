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
          config = node['delivery']['config']['delivery-truck']['lint']['foodcritic']

          # We ignore these two by default since they search for the presence of
          # `issues_url` and `source_url` in the metadata.rb. Those fields will
          # only be populated by cookbooks uploading to Supermarket.
          default_ignore = "-t ~FC064 -t ~FC065"

          # Do not ignore these rules if the cookbook will be share to Supermarket
          if ::DeliveryTruck::Helpers::Publish.share_cookbook_to_supermarket?(node)
            default_ignore = ""
          end

          case
            when config.nil?
              default_ignore
            when config['only_rules'] && !config['only_rules'].empty?
              "-t " + config['only_rules'].join(",")
            when config['ignore_rules'].nil?
              default_ignore
            when config['ignore_rules'].empty?
              # They can set ignore_rules to an empty Array to disable these defaults
              ""
            when config['ignore_rules'] && !config['ignore_rules'].empty?
              "-t ~" + config['ignore_rules'].join(" -t ~")
            else
              ""
          end
        rescue
          ""
        end
      end

      # Based on the properties in the Delivery Config, create the --excludes
      # options that will be passed into the foodcritic command.
      #
      # @param node [Chef::Node] Chef Node object
      # @return [String]
      def foodcritic_excludes(node)
        begin
          config = node['delivery']['config']['delivery-truck']['lint']['foodcritic']
          case
          when config['excludes'] && !config['excludes'].empty?
            "--exclude " + config['excludes'].join(" --exclude ")
          else
            ""
          end
        rescue
          ""
        end
      end

      # Based on the properties in the Delivery Config, create the --epic_fail
      # (-f) tags that will be passed into the foodcritic command.
      #
      # @param node [Chef::Node] Chef Node object
      # @return [String]
      def foodcritic_fail_tags(node)
        config = node['delivery']['config']['delivery-truck']['lint']['foodcritic']
        case
        when config['fail_tags'] && !config['fail_tags'].empty?
          '-f ' + config['fail_tags'].join(',')
        else
          '-f correctness'
        end
      rescue
        '-f correctness'
      end
      # Read the Delivery Config to see if the user has indicated they want to
      # run cookstyle tests on their cookbook
      #
      # @param [Chef::Node] Chef Node object
      # @return [TrueClass, FalseClass]
      def cookstyle_enabled?(node)
        node['delivery']['config']['delivery-truck']['lint']['enable_cookstyle']
      rescue
        false
      end

    end
  end

  module DSL

    # Return the applicable tags for foodcritic runs
    def foodcritic_tags
      DeliveryTruck::Helpers::Lint.foodcritic_tags(node)
    end

    # Return the applicable excludes for foodcritic runs
    def foodcritic_excludes
      DeliveryTruck::Helpers::Lint.foodcritic_excludes(node)
    end

    # Return the fail tags for foodcritic runs
    def foodcritic_fail_tags
      DeliveryTruck::Helpers::Lint.foodcritic_fail_tags(node)
    end

    # Check config.json for whether user wants to share to Supermarket
    def cookstyle_enabled?
      DeliveryTruck::Helpers::Lint.cookstyle_enabled?(node)
    end
  end
end
