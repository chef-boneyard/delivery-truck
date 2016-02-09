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
    module Publish
      extend self

      # Read the Delivery Config to see if the user has indicated they want their
      # cookbooks uploaded to Delivery's Chef Server. This is an intermediate
      # solution until more flexible endpoints are developed.
      #
      # @param [Chef::Node] Chef Node object
      # @return [TrueClass, FalseClass]
      def upload_cookbook_to_chef_server?(node)
        node['delivery']['config']['delivery-truck']['publish']['chef_server']
      rescue
        false
      end

      # Read the Delivery Config to see if the user has indicated a Github
      # repo they would like to push to.
      #
      # @param [Chef::Node] Chef Node object
      # @return [TrueClass, FalseClass]
      def push_repo_to_github?(node)
        !!node['delivery']['config']['delivery-truck']['publish']['github']
      rescue
        false
      end

      # Read the Delivery Config to see if the user has indicated a Git Server
      # repo they would like to push to.
      #
      # @param [Chef::Node] Chef Node object
      # @return [TrueClass, FalseClass]
      def push_repo_to_git?(node)
        !!node['delivery']['config']['delivery-truck']['publish']['git']
      rescue
        false
      end

      # Read the Delivery Config to see if the user has indicated a Supermarket
      # Server they would like to share to.
      #
      # @param [Chef::Node] Chef Node object
      # @return [TrueClass, FalseClass]
      def share_cookbook_to_supermarket?(node)
        !!node['delivery']['config']['delivery-truck']['publish']['supermarket']
      rescue
        false
      end

      # Read the Delivery Config to see if the user has indicated custom credentials
      # should be used instead of those found in delivery_knife_rb. If so, they should
      # loaded from via get_project_secrets.
      #
      # @param [Chef::Node] Chef Node object
      # @return [TrueClass, FalseClass]
      def use_custom_supermarket_credentials?(node)
        !!node['delivery']['config']['delivery-truck']['publish']['supermarket-custom-credentials']
      rescue
        false
      end
    end
  end

  module DSL
    # Check config.json for whether user wants to upload to Chef Server
    def upload_cookbook_to_chef_server?
      DeliveryTruck::Helpers::Publish.upload_cookbook_to_chef_server?(node)
    end

    # Check config.json for whether user wants to push to Github
    def push_repo_to_github?
      DeliveryTruck::Helpers::Publish.push_repo_to_github?(node)
    end

    # Check config.json for whether user wants to push to a Git Server
     def push_repo_to_git?
      DeliveryTruck::Helpers::Publish.push_repo_to_git?(node)
    end

    # Check config.json for whether user wants to share to Supermarket
    def share_cookbook_to_supermarket?
      DeliveryTruck::Helpers::Publish.share_cookbook_to_supermarket?(node)
    end

    # Check config.json for whether user wants to share to Supermarket
    def use_custom_supermarket_credentials?
      DeliveryTruck::Helpers::Publish.use_custom_supermarket_credentials?(node)
    end
  end
end
