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
search_terms = []
get_all_project_cookbooks.each do |cookbook|
  search_terms << "recipes:#{cookbook.name}*"
end

unless search_terms.empty?
  search_query = "(#{search_terms.join(' OR ')}) " \
                 "AND chef_environment:#{delivery_environment} " \
                 "AND #{deployment_search_query}"

  log "Search criteria used to deploy: '#{search_query}'"

  my_nodes = delivery_chef_server_search(:node, search_query)
  my_nodes.map!(&:name)

  delivery_push_job "deploy_#{node['delivery']['change']['project']}" do
    command 'chef-client'
    nodes my_nodes
  end
end
