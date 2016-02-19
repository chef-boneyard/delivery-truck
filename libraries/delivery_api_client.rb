#
# Copyright:: Copyright (c) 2016 Chef Software, Inc.
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

require 'net/http'

module DeliveryTruck
  module DeliveryApiClient
    class BadApiResponse < StandardError
    end

    # Determines the list of bocked projects
    # @params Node object to pull the enterprise from.
    # @returns An array of blocked projects.  If the api doesn't exist returns [].
    def self.blocked_projects(node)
      # Ask the API about how things are looking in union
      ent_name = node['delivery']['change']['enterprise']
      request_url = "/api/v0/e/#{ent_name}/blocked_projects"
      change = get_change_hash(node)
      uri = URI.parse(change['delivery_api_url'])
      http_client = Net::HTTP.new(uri.host, uri.port)

      if uri.scheme == "https"
        http_client.use_ssl = true
        http_client.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      result = http_client.get(request_url, get_headers(change['token']))

      case
      when result.code == "404"
        Chef::Log.info("HTTP 404 recieved from #{request_url}. Please upgrade your Delivery Server.")
        []
      when result.code.match(/20\d/)
        JSON.parse(result.body)['blocked_projects']
      else # not success or 404
        error_str = "Failed request to #{request_url} returned #{result.code}"
        Chef::Log.fatal(error_str)
        raise BadApiResponse.new(error_str)
      end
    end

    def self.get_headers(token)
       {"chef-delivery-token" => token,
         "chef-delivery-user"  => 'builder'}
    end

    def self.get_change_hash(node)
      change_file = ::File.read(::File.expand_path('../../../../../../../change.json', node['delivery_builder']['workspace']))
      change_hash = ::JSON.parse(change_file)
    end

  end
end
