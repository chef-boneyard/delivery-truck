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

      def provision(stage_name, node, acceptance_env_name, cookbooks)
        if stage_name == 'acceptance'
          handle_acceptance_pinnings(node, acceptance_env_name, cookbooks)
        elsif stage_name == 'union'
          handle_union_pinnings(node, acceptance_env_name, cookbooks)
        elsif stage_name == 'rehearsal'
          handle_rehearsal_pinnings(node)
        elsif stage_name == 'delivered'
          handle_delivered_pinnings(node)
        else
          chef_log.info("Nothing to do for #{stage_name}, did you mean to copy this environment?")
        end
      end

      # Refresh Acceptance from Union without overwriting Acceptance's pins
      # for the current project's applications and cookbooks by:
      # 1) Pulling the current Acceptance version pins for apps and cookbooks
      #    related to the project into memory before overwriting Acceptance.
      # 2) Overwrite Acceptance app and cookbook pinnings with Union to make sure
      #    Acceptance environment is up to date with Union.
      # 3) Insert the preserved, original version pins on the apps and cookbooks
      #    for the current project, resulting in an Acceptance that resembled
      #    Union except for Acceptance's original pinnings for the current project.
      # 4) Copy over pins for all project cookbooks.
      def handle_acceptance_pinnings(node, acceptance_env_name, get_all_project_cookbooks)
        union_env_name = 'union'

        union_env = fetch_or_create_environment(union_env_name)
        acceptance_env = fetch_or_create_environment(acceptance_env_name)

        # Before we overwite acceptance with union,
        # remember the cookbook and application pinnings in acceptance for this project.
        cookbook_pinnings = project_cookbook_version_pins_from_env(node, acceptance_env)
        app_pinnings = project_application_version_pins_from_env(node, acceptance_env)

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

        # Copy over pins for any cookbook that changes.
        version_map = {}

        get_all_project_cookbooks.each do |cookbook|
          version_map[cookbook.name] = cookbook.version
        end

        version_map.each do |cookbook, version|
          acceptance_env.cookbook(cookbook, version)
        end

        acceptance_env.save
        acceptance_env
      end

      # Promote all cookbooks and apps related to the current project from
      # Acceptance to Union.
      def handle_union_pinnings(node, acceptance_env_name, project_cookbooks)
        union_env_name = 'union'

        acceptance_env = fetch_or_create_environment(acceptance_env_name)
        union_env = fetch_or_create_environment(union_env_name)

        union_env.default_attributes['delivery'] ||= {}
        union_env.default_attributes['delivery']['project_artifacts'] ||= {}
        union_env.default_attributes['delivery']['union_changes'] ||= []

        change_id = node['delivery']['change']['change_id']

        # There's a race condition where acceptance can be updated between re-runs of union
        # with changes that are note yet approved.  Thus we don't want to re-promote pinnings
        # if we're in a re-run situation.
        unless union_env.default_attributes['delivery']['union_changes'].include?(change_id)
          union_env.default_attributes['delivery']['union_changes'] << change_id
          promote_project_cookbooks(node, acceptance_env, union_env, project_cookbooks)
          promote_project_apps(node, acceptance_env, union_env)

          ## Update cached project metadata
          project_name = project_name(node)
          union_env.default_attributes['delivery']['project_artifacts'][project_name] ||= {}
          populate_project_artifacts(node, project_cookbooks, acceptance_env, union_env)
          union_env.save
        end

        union_env
      end

      def handle_rehearsal_pinnings(node)
        union_env = fetch_or_create_environment('union')
        cleanup_union_changes(union_env, node)

        blocked = ::DeliveryTruck::DeliveryApiClient.blocked_projects(node)

        rehearsal_env = fetch_or_create_environment('rehearsal')

        chef_log.info("current environment: #{rehearsal_env.name}")
        chef_log.info("promoting pinnings from environment: #{union_env.name}")

        promote_unblocked_cookbooks_and_applications(union_env, rehearsal_env, blocked)

        chef_log.info("Promoting environment from #{union_env.name} to #{rehearsal_env.name}")

        rehearsal_env.save
        rehearsal_env
      end

      # This introduces a race condition with a small target window. If
      # union/provision and rehearsal/provision end up running simultaneously
      # the union env could end up in an unknown state because we are doing a
      # read/modify/write in both places.
      def cleanup_union_changes(union_env, node)
        union_changes = union_env.default_attributes['delivery']['union_changes'] || []
        union_changes.delete(node['delivery']['change']['change_id'])
        union_env.default_attributes['delivery']['union_changes'] = union_changes
        union_env.save
      end

      # Promote the from_env's attributes and cookbook_verions to to_env.
      # We want rehearsal to match union, and delivered to match rehearsal
      # so we promote all cookbook_versions, default_attributes, and
      # override_attributes (not just for the current project, but everything
      # in from_env).
      def handle_delivered_pinnings(node)
        to_env_name = 'delivered'
        from_env_name = 'rehearsal'

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

      def project_name(node)
        node['delivery']['change']['project']
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
      def set_project_cookbooks(node)
        default_cookbooks = [project_name(node)]
        unless node['delivery']['project_cookbooks']
          node.default['delivery']['project_cookbooks'] = default_cookbooks
        end
      end

      # Sets the node.default value ['delivery']['project_apps'] based on
      # the node's current value for ['delivery']['project_apps'], using
      # the project name as a default if project_cookbooks not set.
      def set_project_apps(node)
        default_apps = [project_name(node)]
        unless node['delivery']['project_apps']
          node.default['delivery']['project_apps'] = default_apps
        end
      end

      # Determines which cookbooks and applications are a part of this project and
      # updates union_env's project_artifacts accordingly
      # Does _not_ call save on the enviornment so that changes can be more transactional
      def populate_project_artifacts(node, project_cookbooks, acceptance_env, union_env)
        # Can't blindly set project_artifacts based on project_apps and project_cookbooks,
        # must check if anything actually exists on the acceptance env
        # like the rest of the code does.
        new_applications = []
        if acceptance_env.override_attributes['applications']
          node['delivery']['project_apps'].each do |app|
            new_applications << app if acceptance_env.override_attributes['applications'][app]
          end
        end
        union_env.default_attributes['delivery']['project_artifacts'][project_name(node)]['applications'] = new_applications

        new_cookbooks = []
        node['delivery']['project_cookbooks'].each do |cookbook|
          if acceptance_env.cookbook_versions[cookbook]
            new_cookbooks << cookbook
          end
        end

        # project_cookbooks is something that's set by the user's build cookbook.
        # We're also pulling in any cookbooks we auto-detect for backwards compatability
        project_cookbooks.each do |cookbook|
          new_cookbooks << cookbook.name unless new_cookbooks.include?(cookbook.name)
        end

        union_env.default_attributes['delivery']['project_artifacts'][project_name(node)]['cookbooks'] = new_cookbooks
      end

      # Returns a hash of {cookbook_name => pin, ...} where pin is the passed
      # environment's pin for all project_cookbooks from the node.
      # Cookbooks that do no have an environment pin are excluded.
      def project_cookbook_version_pins_from_env(node, env)
        pinnings = {}
        set_project_cookbooks(node)

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
      def project_application_version_pins_from_env(node, env)
        pinnings = {}
        set_project_apps(node)

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
      # cookbook_verions pins for all project_cookbooks.
      # This promotes all cookbooks related to the project in promoted_from_env to promoted_on_env.
      def promote_project_cookbooks(node, promoted_from_env, promoted_on_env, project_cookbooks)
        set_project_cookbooks(node)

        all_project_cookbooks = []
        project_cookbooks.each do |cookbook|
          all_project_cookbooks << cookbook.name
        end

        all_project_cookbooks.concat(node['delivery']['project_cookbooks'])

        all_project_cookbooks.each do |pin|
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
      def promote_project_apps(node, promoted_from_env, promoted_on_env)
        set_project_apps(node)

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
        promoted_on_env.cookbook_versions(promoted_from_env.cookbook_versions)
      end

      def promote_unblocked_cookbooks_and_applications(promoted_from_env, promoted_on_env, blocked)
        if blocked.empty?
          promote_cookbook_versions(promoted_from_env, promoted_on_env)
          promote_default_attributes(promoted_from_env, promoted_on_env)
          promote_override_attributes(promoted_from_env, promoted_on_env)
          return
        end
        # Initialize the attributes if they don't exist.
        promoted_on_env.default_attributes['delivery'] ||= {}
        promoted_on_env.default_attributes['delivery']['project_artifacts'] ||= {}
        promoted_on_env.override_attributes['applications'] ||= {}

        promoted_from_env.default_attributes['delivery']['project_artifacts'].each do |project_name, project_contents|
          if blocked.include?(project_name)
            chef_log.info("Project #{project_name} is currently blocked." +
                          "not promoting its cookbooks or applications")
          else
            chef_log.info("Promoting cookbooks and applications for project #{project_name}")

            # promote cookbooks
            (project_contents['cookbooks'] || []).each do |cookbook_name|
              if promoted_from_env.cookbook_versions[cookbook_name]
                promoted_on_env.cookbook_versions[cookbook_name] = promoted_from_env.cookbook_versions[cookbook_name]
              else
                chef_log.warn("Unable to promote cookbook '#{cookbook_name}' because " +
                              "it does not exist in #{promoted_from_env.name} environment.")
              end
            end

            promoted_on_env.default_attributes['delivery']['project_artifacts'][project_name] = project_contents

            (project_contents['applications'] || []).each do |app_name|
              if promoted_from_env.override_attributes['applications'][app_name]
                promoted_on_env.override_attributes['applications'][app_name] =
                  promoted_from_env.override_attributes['applications'][app_name]
              else
                chef_log.warn("Unable to promote application '#{app_name}' because " +
                              "it does not exist in #{promoted_from_env.name} environment.")
              end
            end
          end
        end
      end

      # Simply set promoted_on_env's default_attributes to match
      # promoted_from_env's
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
        ## Only a one-level deep hash merge
        if promoted_on_env.override_attributes && !promoted_on_env.override_attributes.empty?
          promoted_on_env.override_attributes.merge!(promoted_from_env.override_attributes)
        else
          promoted_on_env.override_attributes(promoted_from_env.override_attributes)
        end
      end
    end
  end
end
