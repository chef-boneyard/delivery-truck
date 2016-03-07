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

require 'pathname'

module DeliveryTruck
  module Helpers
    module Syntax
      extend self

      # Check whether or not the metadata file was modified when cookbook-related
      # files were modified.
      #
      # @param path [String] The path to the cookbook
      # @param node [Chef::Node]
      # @return [TrueClass, FalseClass]
      def bumped_version?(path, node)
        modified_files = DeliverySugar::Change.new(node).changed_files

        cookbook_path = Pathname.new(path)
        workspace_repo = Pathname.new(node['delivery']['workspace']['repo'])
        relative_dir = cookbook_path.relative_path_from(workspace_repo).to_s
        files_to_check = %W(
          metadata\.(rb|json)
          Berksfile
          Berksfile\.lock
          Policyfile\.rb
          Policyfile\.lock\.json
          recipes\/.*
          attributes\/.*
          libraries\/.*
          files\/.*
          templates\/.*
        ).join('|')

        if relative_dir == '.' && !!modified_files.find {|f| /^(#{files_to_check})/ =~ f }
          !!modified_files.find {|f| /^metadata\.(rb|json)/ =~ f }
        elsif !!modified_files.find {|f| /^#{relative_dir}\/(#{files_to_check})/ =~ f }
          !!modified_files.find {|f| /^#{relative_dir}\/metadata\.(rb|json)/ =~ f }
        else
          # We return true here as an indication that we should not fail checks.
          # In reality we simply did not change any files that would require us
          # to bump our version number in our metadata.rb.
          true
        end
      end
    end
  end

  module DSL

    def bumped_version?(path)
      DeliveryTruck::Helpers::Syntax.bumped_version?(path, node)
    end
  end
end
