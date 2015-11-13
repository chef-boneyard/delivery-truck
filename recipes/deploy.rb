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

# Send CCR requests to every node that is running this cookbook or any
# other one in the current project
version_map = {}
search_terms = []
env_name = delivery_environment

changed_cookbooks.each do |cookbook|
  search_terms << "recipes:#{cookbook.name}*"
  version_map[cookbook.name] = cookbook.version
end

ruby_block "update the #{env_name} environment" do
  block do
    with_server_config do
      begin
        env = Chef::Environment.load(env_name)
      rescue Net::HTTPServerException => http_e
        raise http_e unless http_e.response.code == "404"
        Chef::Log.info("Creating Environment #{env_name}")
        env = Chef::Environment.new()
        env.name(env_name)
        env.create
      end

      version_map.each do |cookbook, version|
        env.cookbook(cookbook, version)
      end

      env.save
    end
  end
end

unless search_terms.empty?
  search_query = "(#{search_terms.join(' OR ')}) " \
                 "AND chef_environment:#{delivery_environment} " \
                 "AND #{deployment_search_query}"

  my_nodes = delivery_chef_server_search(:node, search_query)

  my_nodes.map!(&:name)

  delivery_push_job "deploy_#{node['delivery']['change']['project']}" do
    command 'chef-client'
    nodes my_nodes
  end
end
