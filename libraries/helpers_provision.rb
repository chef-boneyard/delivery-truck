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
    module Provision
      extend self

      # Refresh Acceptance from Union without overwriting Acceptance's pins
      # for the current project's applications and cookbooks by:
      # 1) Pulling the current Acceptance version pins for apps and cookbooks
      #    related to the project into memory before overwriting Acceptance.
      # 2) Overwrite Acceptance app and cookbook pinnings with Union to make sure
      #    Acceptance environment is up to date with Union.
      # 3) Insert the preserved, original version pins on the apps and cookbooks
      #    for the current project, resulting in an Acceptance that resembled
      #    Union except for Acceptance's original pinnings for the current project.
      def handle_acceptance_pinnings(acceptance_env_name)
        union_env_name = 'union'

        union_env = fetch_or_create_environment(union_env_name)
        acceptance_env = fetch_or_create_environment(acceptance_env_name)

        # Before we overwite acceptance with union,
        # remember the cookbook and application pinnings in acceptance for this project.
        cookbook_pinnings = project_cookbook_version_pins_from_env(acceptance_env)
        app_pinnings = project_application_version_pins_from_env(acceptance_env)

        ############################################################################
        # Copy Union State Onto Acceptance So Acceptance Looks Like Union To Start #
        ############################################################################

        # Pull and merge the pinnings and attrs from union into this acceptance env.
        chef_log.info("Pulling back environment from #{union_env_name} into #{acceptance_env_name}")
        promote_cookbook_versions(union_env, acceptance_env)

        if acceptance_env.override_attributes && !acceptance_env.override_attributes.empty? &&
           acceptance_env.override_attributes['applications'] != nil
          union_apps = union_env.override_attributes['applications']
          acceptance_env.override_attributes['applications'].merge!(union_apps) unless union_apps.nil?
        else
          acceptance_env.override_attributes(union_env.override_attributes)
        end

        ####################################################################
        # Overwrite Acceptance Pins For Project Related Cookbooks and Apps #
        ####################################################################
        cookbook_pinnings.each do |cb, pin|
          chef_log.info("Setting version pinning for #{cb} to what we" +
                         " remembered earlier: (#{pin})")
          acceptance_env.cookbook(cb, pin)
        end

        # Make sure the outer key is there.
        if acceptance_env.override_attributes['applications'].nil?
          acceptance_env.override_attributes['applications'] = {}
        end

        app_pinnings.each do |app, version|
          chef_log.info("Setting version for app #{app} to what we" +
                         " remembered earlier: (#{version})")
          acceptance_env.override_attributes['applications'][app] = version
        end

        acceptance_env.save
        acceptance_env
      end

      # Promote all cookbooks and apps related to the current project from
      # Acceptance to Union.
      def handle_union_pinnings(acceptance_env_name)
        union_env_name = 'union'

        acceptance_env = fetch_or_create_environment(acceptance_env_name)
        union_env = fetch_or_create_environment(union_env_name)

        promote_project_cookbooks(acceptance_env, union_env)
        promote_project_apps(acceptance_env, union_env)

        union_env.save
        union_env
      end

      # Promote the from_env's attributes and cookbook_verions to to_env.
      # We want rehearsal to match union, and delivered to match rehearsal
      # so we promote all cookbook_versions, default_attributes, and
      # override_attributes (not just for the current project, but everything
      # in from_env).
      def handle_other_pinnings(to_env_name)
        if to_env_name == 'rehearsal'
          from_env_name = 'union'
        elsif to_env_name == 'delivered'
          from_env_name = 'rehearsal'
        end

        chef_log.info("current environment: #{to_env_name}")
        chef_log.info("promoting pinnings from environment: #{from_env_name}")

        from_env = fetch_or_create_environment(from_env_name)
        to_env = fetch_or_create_environment(to_env_name)

        promote_cookbook_versions(from_env, to_env)
        promote_default_attributes(from_env, to_env)
        promote_override_attributes(from_env, to_env)

        chef_log.info("Promoting environment from #{from_env_name} to #{to_env_name}")

        # TODO: protect against this?
        # From here on out, we have broken the environment unless all the cookbook
        # constraints get satisfied. Heads way the hell up, kids.
        to_env.save
        to_env
      end

      #################################
      #  Helper methods
      #################################

      def chef_log
        Chef::Log
      end

      def fetch_or_create_environment(env_name)
        env = Chef::Environment.load(env_name)
      rescue Net::HTTPServerException => http_e
        raise http_e unless http_e.response.code == "404"
        chef_log.info("Creating Environment #{env_name}")
        env = Chef::Environment.new()
        env.name(env_name)
        env.create
      end

      # Sets the node.default value ['delivery']['project_cookbooks'] based on
      # the node's current value for ['delivery']['project_cookbooks'], using
      # the project name as a default if project_cookbooks not set.
      def set_project_cookbooks
        default_cookbooks = [node['delivery']['change']['project']]
        unless node['delivery']['project_cookbooks']
          node.default['delivery']['project_cookbooks'] = default_cookbooks
        end
      end

      # Sets the node.default value ['delivery']['project_apps'] based on
      # the node's current value for ['delivery']['project_apps'], using
      # the project name as a default if project_cookbooks not set.
      def set_project_apps
        default_apps = [node['delivery']['change']['project']]
        unless node['delivery']['project_apps']
          node.default['delivery']['project_apps'] = default_apps
        end
      end

      # Returns a hash of {cookbook_name => pin, ...} where pin is the passed
      # environment's pin for all project_cookbooks from the node.
      # Cookbooks that do no have an environment pin are excluded.
      def project_cookbook_version_pins_from_env(env)
        pinnings = {}
        set_project_cookbooks

        chef_log.info("Checking #{env.name} pinnings for" +
                      " #{node['delivery']['project_cookbooks']}")
        node['delivery']['project_cookbooks'].each do |pin|
          if env.cookbook_versions[pin]
            pinnings[pin] = env.cookbook_versions[pin]
          end
        end

        chef_log.info("Remembering pinning for #{pinnings}...")
        pinnings
      end

      # Returns a hash of {application_name => pin, ...} where pin is the passed
      # environment's override_attributes pin for all project_apps from the node.
      # Apps that do not have an environment pin are excluded.
      def project_application_version_pins_from_env(env)
        pinnings = {}
        set_project_apps

        chef_log.info("Checking #{env.name} apps for" +
                       " #{node['delivery']['project_apps']}")
        node['delivery']['project_apps'].each do |app|
          if env.override_attributes['applications'] &&
             env.override_attributes['applications'][app]
            pinnings[app] = env.override_attributes['applications'][app]
          end
        end

        chef_log.info("Remembering app versions for #{pinnings}...")
        pinnings
      end

      # Set promoted_on_env's cookbook_verions pins to promoted_from_env's
      # cookbook_verions pins for all project_cookbooks (or the base project
      # if no project_cookbooks set). This promotes all cookbooks related to the
      # project in promoted_from_env to promoted_on_env.
      def promote_project_cookbooks(promoted_from_env, promoted_on_env)
        set_project_cookbooks

        node['delivery']['project_cookbooks'].each do |pin|
          from_v = promoted_from_env.cookbook_versions[pin]
          to_v = promoted_on_env.cookbook_versions[pin]
          if from_v
            chef_log.info("Promoting #{pin} @ #{from_v} from #{promoted_from_env.name}" +
                          " to #{promoted_on_env.name} was @ #{to_v}.")
            promoted_on_env.cookbook_versions[pin] = from_v
          end
        end
      end

      # Set promoted_on_env's application pins to promoted_from_env's
      # application pins for all project_apps (or the base project
      # if no project_apps set). This promotes all applications in
      # promoted_from_env to promoted_on_env.
      def promote_project_apps(promoted_from_env, promoted_on_env)
        set_project_apps

        ## Make sure the outer key is there
        if promoted_on_env.override_attributes['applications'].nil?
          promoted_on_env.override_attributes['applications'] = {}
        end

        node['delivery']['project_apps'].each do |app|
          from_v = promoted_from_env.override_attributes['applications'][app]
          to_v = promoted_on_env.override_attributes['applications'][app]
          if from_v
            chef_log.info("Promoting #{app} @ #{from_v} from #{promoted_from_env.name}" +
                          " to #{promoted_on_env.name} was @ #{to_v}.")
            promoted_on_env.override_attributes['applications'][app] = from_v
          end
        end
      end

      # Simply set promoted_on_env's cookbook_versions to match
      # promoted_from_env's cookbook_verions for every cookbook that exists in
      # the latter.
      def promote_cookbook_versions(promoted_from_env, promoted_on_env)
        ## TODO: Should old keys be deleted?
        if promoted_on_env.cookbook_versions && !promoted_on_env.cookbook_versions.empty?
          promoted_on_env.cookbook_versions.merge!(promoted_from_env.cookbook_versions)
        else
          promoted_on_env.cookbook_versions(promoted_from_env.cookbook_versions)
        end
      end

      # Simply set promoted_on_env's default_attributes to match
      # promoted_from_env's cookbook_verions for every cookbook that exists in
      # the latter.
      def promote_default_attributes(promoted_from_env, promoted_on_env)
        if promoted_on_env.default_attributes && !promoted_on_env.default_attributes.empty?
          promoted_on_env.default_attributes.merge!(promoted_from_env.default_attributes)
        else
          promoted_on_env.default_attributes(promoted_from_env.default_attributes)
        end
      end

      # Simply set promoted_on_env's override_attributes to match
      # promoted_from_env's override_attributes for every cookbook that exists in
      # the latter.
      def promote_override_attributes(promoted_from_env, promoted_on_env)
        if promoted_on_env.override_attributes && !promoted_on_env.override_attributes.empty?
          promoted_on_env.override_attributes.merge!(promoted_from_env.override_attributes)
        else
          promoted_on_env.override_attributes(promoted_from_env.override_attributes)
        end
      end
    end
  end
end
