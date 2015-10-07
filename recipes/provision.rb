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

# TODO: This is a temporary workaround; ultimately, this should be
# handled either by delivery_build or (preferably) the server itself.
ruby_block "copy env from prior to current" do
  block do
    to_env_name = node['delivery']['change']['stage']

    with_server_config do
      if to_env_name == 'acceptance'
        # Using DSL to get the right acceptance environment
        to_env_name = delivery_environment
        from_env_name = 'union'


        begin
          from_env = Chef::Environment.load(from_env_name)
        rescue Net::HTTPServerException => http_e
          raise http_e unless http_e.response.code == "404"
          Chef::Log.info("Creating Environment #{from_env_name}")
          from_env = Chef::Environment.new()
          from_env.name(from_env_name)
          from_env.create
        end

        begin
          to_env = Chef::Environment.load(to_env_name)
        rescue Net::HTTPServerException => http_e
          raise http_e unless http_e.response.code == "404"
          Chef::Log.info("Creating Environment #{to_env_name}")
          to_env = Chef::Environment.new()
          to_env.name(to_env_name)
          to_env.create
        end

        # Remember the pinnings in acceptance for this project
        acc_pinnings = {}
        default_cookbooks = [node['delivery']['change']['project']]
        unless node['delivery']['project_cookbooks']
          node.default['delivery']['project_cookbooks'] = default_cookbooks
        end

        Chef::Log.info("Checking #{to_env_name} pinnings for" +
                       " #{node['delivery']['project_cookbooks']}")
        node['delivery']['project_cookbooks'].each do |pin|
          if to_env.cookbook_versions[pin]
            acc_pinnings[pin] = to_env.cookbook_versions[pin]
          end
        end

        Chef::Log.info("Remembering pinning for #{acc_pinnings}...")

        acc_apps = {}
        default_apps = [node['delivery']['change']['project']]
        unless  node['delivery']['project_apps']
          node.default['delivery']['project_apps'] = default_apps
        end

        Chef::Log.info("Checking #{to_env_name} apps for" +
                       " #{node['delivery']['project_apps']}")
        node['delivery']['project_apps'].each do |app|
          if to_env.override_attributes['applications'] &&
             to_env.override_attributes['applications'][app]
            acc_apps[app] = to_env.override_attributes['applications'][app]
          end
        end

        Chef::Log.info("Remembering app versions for #{acc_apps}...")

        # Pull and merge the pinnings and attrs from union_good into
        # this acceptance env..
        Chef::Log.info("Pulling back environment from #{from_env_name} into #{to_env_name}")
        if to_env.cookbook_versions && !to_env.cookbook_versions.empty?
          to_env.cookbook_versions.merge!(from_env.cookbook_versions)
        else
          to_env.cookbook_versions(from_env.cookbook_versions)
        end

        if to_env.override_attributes && !to_env.override_attributes.empty? &&
           to_env.override_attributes['applications'] != nil
          from_apps = from_env.override_attributes['applications']
          to_env.override_attributes['applications'].merge!(from_apps) unless from_apps.nil?
        else
          to_env.override_attributes(from_env.override_attributes)
        end

        acc_pinnings.each do |cb, pin|
          Chef::Log.info("Setting version pinning for #{cb} to what we" +
                         " remembered earlier: (#{pin})")
          to_env.cookbook(cb, pin)
        end

        ## Make sure the outer key is there
        if to_env.override_attributes['applications'].nil?
          to_env.override_attributes['applications'] = {}
        end

        acc_apps.each do |app, version|
          Chef::Log.info("Setting version for app #{app} to what we" +
                         " remembered earlier: (#{version})")
          to_env.override_attributes['applications'][app] = version
        end

        to_env.save
      elsif to_env_name == 'union'
        # Getting the right acceptance environment
        from_env_name = get_acceptance_environment

        begin
          from_env = Chef::Environment.load(from_env_name)
        rescue Net::HTTPServerException => http_e
          raise http_e unless http_e.response.code == "404"
          Chef::Log.info("Creating Environment #{from_env_name}")
          from_env = Chef::Environment.new()
          from_env.name(from_env_name)
          from_env.create
        end

        begin
          to_env = Chef::Environment.load(to_env_name)
        rescue Net::HTTPServerException => http_e
          raise http_e unless http_e.response.code == "404"
          Chef::Log.info("Creating Environment #{to_env_name}")
          to_env = Chef::Environment.new()
          to_env.name(to_env_name)
          to_env.create
        end

        acc_pinnings = {}
        default_cookbooks = [node['delivery']['change']['project']]
        unless node['delivery']['project_cookbooks']
          node.default['delivery']['project_cookbooks'] = default_cookbooks
        end

        node['delivery']['project_cookbooks'].each do |pin|
          from_v = from_env.cookbook_versions[pin]
          to_v = to_env.cookbook_versions[pin]
          if from_v
            Chef::Log.info("Promoting #{pin} @ #{from_v} from #{from_env_name}" +
                           " to #{to_env_name} was @ #{to_v}.")
            to_env.cookbook_versions[pin] = from_v
          end
        end

        acc_apps = {}
        default_apps = [node['delivery']['change']['project']]
        unless  node['delivery']['project_apps']
          node.default['delivery']['project_apps'] = default_apps
        end

        ## Make sure the outer key is there
        if to_env.override_attributes['applications'].nil?
          to_env.override_attributes['applications'] = {}
        end

        node['delivery']['project_apps'].each do |app|
          from_v = from_env.override_attributes['applications'][app]
          to_v = to_env.override_attributes['applications'][app]
          if from_v
            Chef::Log.info("Promoting #{app} @ #{from_v} from #{from_env_name}" +
                           " to #{to_env_name} was @ #{to_v}.")
            to_env.override_attributes['applications'][app] = from_v
          end
        end

        to_env.save
      else
        if to_env_name == 'rehearsal'
          from_env_name = 'union'
        elsif to_env_name == 'delivered'
          from_env_name = 'rehearsal'
        end

        Chef::Log.info("current environment: #{to_env_name}")
        Chef::Log.info("promoting pinnings from environment: #{from_env_name}")

        begin
          from_env = Chef::Environment.load(from_env_name)
        rescue Net::HTTPServerException => http_e
          raise http_e unless http_e.response.code == "404"
          Chef::Log.info("Creating Environment #{from_env_name}")
          from_env = Chef::Environment.new()
          from_env.name(from_env_name)
          from_env.create
        end

        begin
          to_env = Chef::Environment.load(to_env_name)
        rescue Net::HTTPServerException => http_e
          raise http_e unless http_e.response.code == "404"
          Chef::Log.info("Creating Environment #{to_env_name}")
          to_env = Chef::Environment.new()
          to_env.name(to_env_name)
          to_env.create
        end

        if to_env.cookbook_versions && !to_env.cookbook_versions.empty?
          to_env.cookbook_versions.merge!(from_env.cookbook_versions)
        else
          to_env.cookbook_versions(from_env.cookbook_versions)
        end

        ## Promote the env attributes. we want rehearsal to match union,
        ## and prod to match rehearsal so we promote everything.
        if to_env.default_attributes && !to_env.default_attributes.empty?
          to_env.default_attributes.merge!(from_env.default_attributes)
        else
          to_env.default_attributes(from_env.default_attributes)
        end

        if to_env.override_attributes && !to_env.override_attributes.empty?
          to_env.override_attributes.merge!(from_env.override_attributes)
        else
          to_env.override_attributes(from_env.override_attributes)
        end

        Chef::Log.info("Promoting environment from #{from_env_name} to #{to_env_name}")
        # From here on out, we have broken the environment unless all the cookbook
        # constraints get satisfied Heads way the hell up, kids.
        to_env.save
      end
    end
  end
end
