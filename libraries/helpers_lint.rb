#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
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
