#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

require 'chef/mixin/shell_out'
require 'chef/cookbook/metadata'
require_relative 'errors'

module DeliveryTruck
  module Helpers
    include Chef::Mixin::ShellOut
    extend self

    # This value is also set in the delivery_builder cookbook. To avoid
    # depending on an external cookbook we are going to duplicate its definition
    # here.
    unless defined? CONFIG_ATTRIBUTE_KEY
      CONFIG_ATTRIBUTE_KEY = 'delivery_config'.freeze
    end

    # Inspect the files that are different between the patchset and the current
    # HEAD of the pipeline branch. If any files related to a cookbook have
    # changed, return the name of that cookbook along with its path.
    #
    # @example Simple loop to exemplify how to access the name and path.
    #   changed_cookbooks.each do |cookbook|
    #     puts "Cookbook #{cookbook[:name]} has been modified."
    #     puts "It is avaialble at #{cookbook[:path]}"
    #   end
    #
    # @param node [Chef::Node] Chef Node object
    # @return [Array#Hash]
    def changed_cookbooks(node)
      modified_files = changed_files(
        pipeline_sha(node),
        patchset_sha(node),
        node
      )
      repo_dir = repo_path(node)

      changed_cookbooks = []
      cookbooks_in_repo(node).each do |cookbook|
        if cookbook == repo_dir && !modified_files.empty?
          name = get_cookbook_name(repo_dir)
          changed_cookbooks << {:name => name, :path => repo_dir}
        elsif !modified_files.select { |file| file.include? cookbook }.empty?
          path = File.join(repo_dir, cookbook)
          name = get_cookbook_name(path)
          changed_cookbooks << {:name => name, :path => path}
        end
      end

      changed_cookbooks
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
        :cwd => repo_path(node)
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
      if is_cookbook?(repo_path(node))
        [repo_path(node)]

      # Is there a `cookbooks` directory in this directory?
      elsif File.directory?(File.join(repo_path(node), 'cookbooks'))
        # If so, return a list of the folders inside this directory but...
        Dir.chdir(repo_path(node)) do
          Dir.glob('cookbooks/*').select do |entry|
            full_path = File.join(repo_path(node), entry)

            # Make sure the entry is a directory and a cookbook
            File.directory?(full_path) && is_cookbook?(full_path)
          end
        end

      # It looks like there are no cookbooks in the directory
      else
        []
      end
    end

    # This method will leverage a core Chef library to load a cookbook's
    # metadata file and return the name of the cookbook.
    #
    # @param path [String] The path to the cookbook
    # @param [String]
    def get_cookbook_name(path)
      metadata = Chef::Cookbook::Metadata.new
      if File.exist?(File.join(path, 'metadata.json'))
        metadata.from_json_file(File.join(path, 'metadata.json'))
      else
        metadata.from_file(File.join(path, 'metadata.rb'))
      end
      metadata.name
    end

    # Looks for indications that the directory passed is a Chef cookbook.
    #
    # @param path [String] Directory to check
    # @return [TrueClass, FalseClass]
    def is_cookbook?(path)
      File.exist?(File.join(path, 'metadata.json')) ||
      File.exist?(File.join(path, 'metadata.rb'))
    end

    # This method will load the Delivery configuration file. If we are running
    # on a Delivery Build Node, then the delivery_builder cookbook will have
    # already done this for us. If the config file has not been loaded then we
    # will need to load it ourselves.
    #
    # @param config_file [String] Fully-qualified path to Delivery config file.
    # @param node [Chef::Node] Chef Node object
    # @return [nil]
    def load_config(config_file, node)
      # Check to see if CONFIG_ATTRIBUTE_KEY is present. This is set by the
      # delivery_builder cookbook and will indicate that we are running on
      # a Delivery build node.
      if node[CONFIG_ATTRIBUTE_KEY]
        # We don't need to do anything since the delivery_builder cookbook has
        # already loaded the attributes.
      else
        # Check to see if the Delivery config exists in the project root. If it
        # does, then load it into the node object.
        if File.exist?(config_file)
          config = Chef::JSONCompat.from_json(IO.read(config_file))
          node.force_override[CONFIG_ATTRIBUTE_KEY] = config
        else
          raise DeliveryTruck::MissingConfiguration, config_file
        end
      end
      nil
    end

    # Rerturn the SHA for the HEAD of the current patchset.
    #
    # @param [Chef::Node] Chef Node object
    # @return [String]
    def patchset_sha(node)
      node['delivery_builder']['change']['sha']
    end

    # Return the SHA for the HEAD of the pipeline branch
    #
    # @param [Chef::Node] Chef Node object
    # @return [String]
    def pipeline_sha(node)
      branch = node['delivery_builder']['change']['pipeline']
      shell_out(
        "git rev-parse origin/#{branch}",
        :cwd => repo_path(node)
      ).stdout.strip
    end

    # Return the fully-qualified path to the root of the repo.
    #
    # @param [Chef::Node] Chef Node object
    # @return [String]
    def repo_path(node)
      node['delivery_builder']['repo'] || File.expand_path("../..", __FILE__)
    end

    # Return the path to the chef config file for use with knife commands inside
    # the phase recipes.
    #
    # @param [Chef::Node] Chef Node object
    # @return [String]
    def delivery_workspace_chef_config(node)
      "#{node['delivery_builder']['workspace']}/solo.rb"
    end
  end

  module DSL

    # Return a list of the cookbooks that have been modified
    def changed_cookbooks
      DeliveryTruck::Helpers.changed_cookbooks(node)
    end

    # Load the Delivery configuration file into the node object
    def load_config(config_file)
      DeliveryTruck::Helpers.load_config(config_file, node)
    end

    # Return the SHA for the patchset currently being tested
    def patchset_sha
      DeliveryTruck::Helpers.patchset_sha(node)
    end

    # Return the SHA for the HEAD of the pipeline branch
    def pipeline_sha
      DeliveryTruck::Helpers.pipeline_sha(node)
    end

    # Return the path to the project workspace on the Delivery Builder
    def repo_path
      DeliveryTruck::Helpers.repo_path(node)
    end

    # Return the path to the Chef config file for the current workspace
    def delivery_workspace_chef_config
      DeliveryTruck::Helpers.delivery_workspace_chef_config(node)
    end
  end
end
