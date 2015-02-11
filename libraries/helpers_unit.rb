#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

module DeliveryTruck
  module Helpers
    module Unit
      extend self

      # Look in the cookbook and return whether or not we can find Spec tests.
      #
      # @param cookbook_path [String] Path to cookbook
      # @return [TrueClass, FalseClass]
      def has_spec_tests?(cookbook_path)
        File.directory?(File.join(cookbook_path, 'spec'))
      end
    end
  end

  module DSL

    # Does cookbook have spec tests?
    def has_spec_tests?(cookbook_path)
      DeliveryTruck::Helpers::Unit.has_spec_tests?(cookbook_path)
    end
  end
end
