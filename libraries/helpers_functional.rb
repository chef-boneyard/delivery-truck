#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

module DeliveryTruck
  module Helpers
    module Functional
      extend self

      # Look in the cookbook and return whether or not we can find a .kitchen.yml
      #
      # @param cookbook_path [String] Path to cookbook
      # @return [TrueClass, FalseClass]
      def has_kitchen_tests?(cookbook_path)
        File.exist?(File.join(cookbook_path, '.kitchen.docker.yml'))
      end
    end
  end

  module DSL

    # Can we find Test Kitchen files?
    def has_kitchen_tests?(cookbook_path)
      DeliveryTruck::Helpers::Functional.has_kitchen_tests?(cookbook_path)
    end
  end
end
