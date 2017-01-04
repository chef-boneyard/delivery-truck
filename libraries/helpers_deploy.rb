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
    module Deploy
      extend self

      # Read the Delivery Config to see if the user has indicated an
      # specific deployment search query to use
      #
      # @param [Chef::Node] Chef Node object
      # @return [String] The deployment search query
      def deployment_search_query(node)
        node['delivery']['config']['delivery-truck']['deploy']['search']
      rescue
        'recipes:*push-jobs*'
      end

      def delivery_chef_server_search(type, query, delivery_knife_rb)
        results = []
        DeliverySugar::ChefServer.new(delivery_knife_rb).with_server_config do
          ::Chef::Search::Query.new.search(type, query) { |o| results << o }
        end
        results
      end
    end
  end

  module DSL
    def delivery_chef_server_search(type, query)
      DeliveryTruck::Helpers::Deploy.delivery_chef_server_search(type, query, delivery_knife_rb)
    end

    # Check config.json to get deployment search query
    def deployment_search_query
      DeliveryTruck::Helpers::Deploy.deployment_search_query(node)
    end
  end
end
