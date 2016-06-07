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
    module ProvisionV2
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
      # 4) Copy over pins for all project cookbooks.
      def handle_acceptance_pinnings(node, acceptance_env_name)
        union_env_name = 'union'

        union_env = fetch_or_create_environment(union_env_name)
        acceptance_env = fetch_or_create_environment(acceptance_env_name)

        pins = fetch_promotion_data(node)

        ############################################################################
        # Copy Union State Onto Acceptance So Acceptance Looks Like Union To Start #
        ############################################################################

        # Pull and merge the pinnings and attrs from union into this acceptance env.
        chef_log.info("Pulling back environment from #{union_env_name} into #{acceptance_env_name}")
        promote_cookbook_versions(union_env, acceptance_env)

        acceptance_env.override_attributes ||= {}
        acceptance_env.override_attributes['applications'] ||= {}

        union_apps = union_env.override_attributes['applications'] || {}
        acceptance_env.override_attributes['applications'].merge!(union_apps)

        ####################################################################
        # Overwrite Acceptance Pins For Project Related Cookbooks and Apps #
        ####################################################################
        pins['project_cookbooks'].each do |cb, pin|
          chef_log.info("Setting version pinning for #{cb} to #{pin}")
          acceptance_env.cookbook(cb, pin)
        end

        pins['applications'].each do |app, metadata|
          chef_log.info("Setting version for app #{app} to #{metadata['version']}")
          acceptance_env.override_attributes['applications'][app] = metadata['version']
        end

        acceptance_env.save
        acceptance_env
      end

      # Promote all cookbooks and apps related to the current project from
      # Acceptance to Union.
      def handle_union_pinnings(node)
        union_env_name = 'union'

        union_env = fetch_or_create_environment(union_env_name)
        union_env.override_attributes['applications'] ||= {}

        pins = fetch_promotion_data(node)

        pins['project_cookbooks'].each do |cb, pin|
          chef_log.info("Setting version pinning for #{cb} to #{pin}")
          union_env.cookbook(cb, pin)
        end

        pins['applications'].each do |app, metadata|
          chef_log.info("Setting version for app #{app} to #{metadata['version']}")
          union_env.override_attributes['applications'][app] = metadata['version']
        end

        ## Update cached project metadata
        union_env.default_attributes['delivery'] ||= {}
        union_env.default_attributes['delivery']['project_artifacts'] ||= {}
        project_name = project_name(node)
        union_env.default_attributes['delivery']['project_artifacts'][project_name] ||= {}

        populate_project_artifacts(node, union_env, pins)

        union_env.save
        union_env
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

      def change_id(node)
        node['delivery']['change']['change_id']
      end

      def fetch_promotion_data(node)
        Chef::DataBagItem.load('workflow-promotion-data', node['delivery']['change']['change_id'])
      rescue Net::HTTPServerException => http_e
        chef_log.info("Failed to find workflow-promotion-data for #{node['delivery']['change']['change_id']}.")
        raise http_e
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

      def populate_project_artifacts(node, union_env, promotion_data)
        new_applications = []
        promotion_data['applications'].each do |app, metadata|
          new_applications << app
        end
        union_env.default_attributes['delivery']['project_artifacts'][project_name(node)]['applications'] = new_applications

        new_cookbooks = []
        promotion_data['project_cookbooks'].each do |cookbook, version|
          new_cookbooks << cookbook
        end

        union_env.default_attributes['delivery']['project_artifacts'][project_name(node)]['cookbooks'] = new_cookbooks
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
            project_contents['cookbooks'].each do |cookbook_name|
              promoted_on_env.cookbook_versions[cookbook_name] =
                promoted_from_env.cookbook_versions[cookbook_name]
            end

            promoted_on_env.default_attributes['delivery']['project_artifacts'][project_name] = project_contents

            project_contents['applications'].each do |app_name|
              promoted_on_env.override_attributes['applications'][app_name] =
                promoted_from_env.override_attributes['applications'][app_name]
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
