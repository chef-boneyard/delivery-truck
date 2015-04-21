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

require 'chef/mixin/shell_out'
require 'chef/cookbook/metadata'
require_relative 'errors'

module DeliveryTruck
  module Helpers
    include Chef::Mixin::ShellOut
    extend self

    # Inspect the files that are different between the patchset and the current
    # HEAD of the pipeline branch. If any files related to a cookbook have
    # changed, return the name of that cookbook along with its path.
    #
    # @example Simple loop to exemplify how to access the name, path and version.
    #   changed_cookbooks.each do |cookbook|
    #     puts "Cookbook #{cookbook[:name]} has been modified."
    #     puts "It is avaialble at #{cookbook[:path]}"
    #     puts "It is currently at v#{cookbook[:version]}"
    #   end
    #
    # @param node [Chef::Node] Chef Node object
    # @return [Array#Hash]
    def changed_cookbooks(node)
      modified_files = changed_files(
        pre_change_sha(node),
        node['delivery']['change']['sha'],
        node
      )
      repo_dir = node['delivery']['workspace']['repo']

      changed_cookbooks = []
      cookbooks_in_repo(node).each do |cookbook|
        if cookbook == repo_dir && !modified_files.empty?
          name = get_cookbook_name(repo_dir)
          version = get_cookbook_version(repo_dir)
          changed_cookbooks << {:name => name, :path => repo_dir, :version => version}
        elsif !modified_files.select { |file| file.include? cookbook }.empty?
          path = File.join(repo_dir, cookbook)
          name = get_cookbook_name(path)
          version = get_cookbook_version(path)
          changed_cookbooks << {:name => name, :path => path, :version => version}
        end
      end

      changed_cookbooks
    end

    # Get a list of all the cookbooks in the project and return metadata about
    # each of them including name, path and version.
    #
    # @example Simple loop to exemplify how to access name, path and version
    #   all_cookbooks.each do |cookbook|
    #     puts "This project has a cookbook named #{cookbook[:name]}"
    #     puts "It is located at #{cookbook[:path]}"
    #     puts "It is currently at v#{cookbook[:version]}"
    #   end
    #
    # @param node [Chef::Node] Chef Node object
    # @return [Array#Hash]
    def all_cookbooks(node)
      repo_dir = node['delivery']['workspace']['repo']

      all_cookbooks = []
      cookbooks_in_repo(node).each do |cookbook|
        if cookbook == repo_dir
          name = get_cookbook_name(repo_dir)
          version = get_cookbook_version(repo_dir)
          all_cookbooks << {:name => name, :path => repo_dir, :version => version}
        else
          path = File.join(repo_dir, cookbook)
          name = get_cookbook_name(path)
          version = get_cookbook_version(path)
          all_cookbooks << {:name => name, :path => path, :version => version}
        end
      end

      all_cookbooks
    end

    # Get a list of the files that have changed between two shas and return them
    # as an array. This will typically be done to find the difference between
    # the latest patchset and the head of the pipeline.
    #
    # @param parent_sha [String] The SHA of the earlier commit.
    # @param change_sha [String] The SHA of the later commit.
    # @param node [Chef::Node] Chef Node object
    # @return [Array#String]
    def changed_files(parent_sha, change_sha, node)
      response = shell_out!(
        "git diff --name-only #{parent_sha} #{change_sha}",
        :cwd => node['delivery']['workspace']['repo']
      ).stdout.strip

      changed_files = []
      response.each_line do |line|
        changed_files << line.strip
      end
      changed_files
    end

    # Get a list of the paths for all the cookbooks in the current project
    # relative to the project root.
    #
    # There are two "happy paths" that this method is designed for. First is the
    # situation where the project is a cookbook (i.e. the Berkshelf Way). The
    # second is the monolithic chef repo where in the project root there is a
    # cookbooks directory where you keep all your cookbooks.
    #
    # This method is not designed to handle more than one cookbooks folder.
    #
    # @param node [Chef::Node] Chef Node object
    # @return [Array#String]
    def cookbooks_in_repo(node)

      # Is the current directory a cookbook?
      if is_cookbook?(node['delivery']['workspace']['repo'])
        [node['delivery']['workspace']['repo']]

      # Is there a `cookbooks` directory in this directory?
      elsif File.directory?(File.join(node['delivery']['workspace']['repo'], 'cookbooks'))
        # If so, return a list of the folders inside this directory but...
        Dir.chdir(node['delivery']['workspace']['repo']) do
          Dir.glob('cookbooks/*').select do |entry|
            full_path = File.join(node['delivery']['workspace']['repo'], entry)

            # Make sure the entry is a directory and a cookbook
            File.directory?(full_path) && is_cookbook?(full_path)
          end
        end

      # It looks like there are no cookbooks in the directory
      else
        []
      end
    end

    # This method will return the name of a cookbook based on that
    # cookbook's metadata.
    #
    # @param path [String] The path to the cookbook
    # @return [String]
    def get_cookbook_name(path)
      metadata = load_metadata(path)
      metadata.name
    end


    # This method will return the version of a cookbook based on that
    # cookbook's metadata.
    #
    # @param path [String] The path to the cookbook
    # @return [String]
    def get_cookbook_version(path)
      metadata = load_metadata(path)
      metadata.version
    end

    # Load the metadata.(rb|json) from a cookbook. Use the internal Chef
    # libary to read that metadata.
    #
    # @param path [String] The path to the cookbook
    # @return [Chef::Cookbook::Metadata]
    def load_metadata(path)
      metadata = Chef::Cookbook::Metadata.new
      if File.exist?(File.join(path, 'metadata.json'))
        metadata.from_json(File.read(File.join(path, 'metadata.json')))
      else
        metadata.from_file(File.join(path, 'metadata.rb'))
      end
      metadata
    end

    # Looks for indications that the directory passed is a Chef cookbook.
    #
    # @param path [String] Directory to check
    # @return [TrueClass, FalseClass]
    def is_cookbook?(path)
      File.exist?(File.join(path, 'metadata.json')) ||
        File.exist?(File.join(path, 'metadata.rb'))
    end

    # Return the SHA for the point in our history where we split off. For verify
    # this will be HEAD on the pipeline branch. For later stages, because HEAD
    # on the pipeline branch is our change, we will look for the 2nd most recent
    # commit to the pipeline branch.
    #
    # @param [Chef::Node] Chef Node object
    # @return [String]
    def pre_change_sha(node)
      branch = node['delivery']['change']['pipeline']

      if node['delivery']['change']['stage'] == 'verify'
        shell_out(
          "git rev-parse origin/#{branch}",
          :cwd => node['delivery']['workspace']['repo']
        ).stdout.strip
      else
        # This command looks in the git history for the last two merges to our
        # pipeline branch. The most recent will be our SHA so the second to last
        # will be the SHA we are looking for.
        command = "git log origin/#{branch} --merges --pretty=\"%H\" -n2 | tail -n1"
        shell_out(command, :cwd => node['delivery']['workspace']['repo']).stdout.strip
      end
    end

    # Return the Standard Acceptance Environment Name
    #
    # @param [Chef::Node] Chef Node object
    #
    def get_acceptance_environment(node)
      change = node['delivery']['change']
      ent = change['enterprise']
      org = change['organization']
      proj = change['project']
      pipe = change['pipeline']
      "acceptance-#{ent}-#{org}-#{proj}-#{pipe}"
    end

    # Return the Standard Delivery Environment Name
    #
    # @param [Chef::Node] Chef Node object
    # @param [String] Could Return:
    # => get_acceptance_environment
    # => union
    # => rehearsal
    # => delivered
    def delivery_environment(node)
      if node['delivery']['change']['stage'] == 'acceptance'
        get_acceptance_environment(node)
      else
        node['delivery']['change']['stage']
      end
    end

    # Using identifying components of the change, generate a project slug.
    #
    # @param [Chef::Node] Chef Node object
    # @param [String]
    def project_slug(node)
      change = node['delivery']['change']
      ent = change['enterprise']
      org = change['organization']
      proj = change['project']
      "#{ent}-#{org}-#{proj}"
    end

    # Pull down the encrypted data bag containing the secrets for this project.
    #
    # @param [Chef::Node] Chef Node object
    # @return [Hash]
    def get_project_secrets(node)
      ::Chef_Delivery::ClientHelper.enter_client_mode_as_delivery
      secret_file = Chef::EncryptedDataBagItem.load_secret(Chef::Config[:encrypted_data_bag_secret])
      secrets = Chef::EncryptedDataBagItem.load('delivery-secrets', project_slug(node), secret_file)
      ::Chef_Delivery::ClientHelper.leave_client_mode_as_delivery
      secrets
    end

    # Create a hash object with the necessary details for Cheffish to talk to
    # the Chef Server that triggered the change.
    #
    # @param [Chef::Node] Chef node object
    # @return [Hash]
    def delivery_chef_server(node)
      server_details = {}
      ::Chef_Delivery::ClientHelper.enter_client_mode_as_delivery
      server_details[:chef_server_url] = Chef::Config[:chef_server_url]
      server_details[:options] = {
        client_name: ::Chef::Config[:node_name],
        signing_key_filename: ::Chef::Config[:client_key]
      }
      ::Chef_Delivery::ClientHelper.leave_client_mode_as_delivery
      server_details
    end
  end

  module DSL

    # Return a list of all the cookbooks in the project
    def all_cookbooks
      DeliveryTruck::Helpers.all_cookbooks(node)
    end

    # Return a list of the cookbooks that have been modified
    def changed_cookbooks
      DeliveryTruck::Helpers.changed_cookbooks(node)
    end

    # Return a list of the files that have been modified
    def changed_files
      DeliveryTruck::Helpers.changed_files(
        DeliveryTruck::Helpers.pre_change_sha(node),
        node['delivery']['change']['sha'],
        node
      )
    end

    # Get the acceptance environment
    def get_acceptance_environment
      DeliveryTruck::Helpers.get_acceptance_environment(node)
    end

    # Return the Standard Delivery Environment Name
    def delivery_environment
      DeliveryTruck::Helpers.delivery_environment(node)
    end

    # Return a project slug
    def project_slug
      DeliveryTruck::Helpers.project_slug(node)
    end

    # Grab the data bag from the Chef Server where the secrets for this
    # project are kept
    def get_project_secrets
      DeliveryTruck::Helpers.get_project_secrets(node)
    end

    # Return a hash object for cheffish with details to talk to the Chef Server
    def delivery_chef_server
      DeliveryTruck::Helpers.delivery_chef_server(node)
    end
  end
end
