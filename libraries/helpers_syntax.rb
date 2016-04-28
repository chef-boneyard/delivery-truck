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

      # Check whether or not the metadata file was modified when
      # cookbook-related files were modified.
      #
      # Note: The concept of "the version of the cookbook at the merge base'
      # is inherently flawed. You can rename a cookbook in the metadata.rb and
      # leave it in the same path. You can move a cookbook to a new path and
      # could have edited it after the move. The cookbook might not exist in
      # this repo at the merge base - imagine migrating cookbooks from one repo
      # to another. It would next to impossible for delivery to correctly guess
      # the correct "base" version of this cookbook. We simply assume that if
      # a base cookbook were to exist, it exists at the same location with the
      # same name.
      #
      # @param path [String] The path to the cookbook
      # @param node [Chef::Node]
      #
      # @return [TrueClass, FalseClass]
      #
      def bumped_version?(path, node)
        change = DeliverySugar::Change.new(node)
        modified_files = change.changed_files

        cookbook_path = Pathname.new(path)
        workspace_repo = Pathname.new(change.workspace_repo)
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

        clean_relative_dir = relative_dir == "." ? "" : Regexp.escape("#{relative_dir}/")

        if modified_files.any? { |f| /^#{clean_relative_dir}(#{files_to_check})/ =~ f }
          base = change.merge_sha.empty? ? "origin/#{change.pipeline}" : "#{change.merge_sha}~1"
          base_metadata = change.cookbook_metadata(path, base)
          base_metadata.nil? ||
            change.cookbook_metadata(path).version != base_metadata.version
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
