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

class Chef
  class Provider
    class DeliveryTruckDeploy < Chef::Provider::LWRPBase
      action :run do
        converge_by("Dispatch push-job for #{delivery_environment} => #{node['delivery']['change']['project']} - #{new_resource.name}") do
          result = with_server_config { deploy_ccr }
          new_resource.updated_by_last_action(result)
        end
      end

      private

      SLEEP_TIME ||= 15
      PUSH_SLEEP_TIME ||= 5

      def get_search
        @search ||= begin
          # Our default search has to be here since we evaluate `project_name`
          #
          # This search is designed to include all the nodes that in the expanded
          # run_list have the "project_name". This will apply the majority of the
          # times with cookbooks that doesn't have a secial sausage like:
          # => `my_app_cookbook:deploy_db`
          #
          # If this is a project like delivery that the app_name and the
          # project_name are totally different from the deploy_cookbook you
          # can customize the search.
          (@new_resource.search || "recipes:#{node['delivery']['change']['project']}*").tap do |search|
            # We validate that the user has provided a chef_environment
            search << " AND chef_environment:#{delivery_environment}" unless search =~ /chef_environment/

            # We will search only on nodes that has push-jobs
            search << " AND recipes:push-jobs*"
          end
        end
      end

      def timeout
        @timeout ||= new_resource.timeout
      end

      def dec_timeout(number)
        @timeout -= number
      end

      def deploy_ccr
        origin = timeout

        ::Chef::Log.info("Will wait up to #{timeout/60} minutes for " +
                         "deployment to complete...")

        begin
          # Sleep unless this is our first time through the loop.
          sleep(SLEEP_TIME) unless timeout == origin

          # Find any dependency/app node
          ::Chef::Log.info("Finding dependency/app nodes in #{delivery_environment}...")
          nodes = search(:node, get_search)

          if !nodes || nodes.empty?
            # We didn't find any node to deploy. Lets skip this phase!
            ::Chef::Log.info("No dependency/app nodes found. Skipping phase!")
            break
          end

          node_names = nodes.map { |n| n.name }

          # We take out the build node we are running on
          node_names.delete(node.name)

          ::Chef::Log.info("Found dependency/app nodes: #{node_names}")

          chef_server_rest = Chef::REST.new(Chef::Config[:chef_server_url])

          # Kick off command via push.
          ::Chef::Log.info("Triggering #{new_resource.command} on dependency nodes " +
                           "with Chef Push Jobs...")

          req = {
              'command' => new_resource.command,
              'nodes' => node_names
          }
          resp = chef_server_rest.post('/pushy/jobs', req)
          job_uri = resp['uri']

          unless job_uri
            # We were not able to start the push job.
            ::Chef::Log.info("Could not start push job. " +
                             "Will try again in #{SLEEP_TIME} seconds...")
            next
          end

          ::Chef::Log.info("Started push job with id: #{job_uri[-32,32]}")
          previous_state = "initialized"
          begin
            sleep(PUSH_SLEEP_TIME) unless previous_state == "initialized"
            job = chef_server_rest.get_rest(job_uri)
            case job['status']
            when 'new'
              finished = false
              state = 'initialized'
            when 'voting'
              finished = false
              state = job['status']
            else
              total = job['nodes'].values.inject(0) do |sum, n|
                sum + n.length
              end

              in_progress = job['nodes'].keys.inject(0) do |sum, status|
                nodes = job['nodes'][status]
                sum + (%w(new voting running).include?(status) ? 1 : 0)
              end

              if job['status'] == 'running'
                finished = false
                state = job['status'] +
                        " (#{in_progress}/#{total} in progress) ..."
              else
                finished = true
                state = job['status']
              end
            end
            if state != previous_state
              ::Chef::Log.info("Push Job Status: #{state}")
              previous_state = state
            end

            ## Check for success
            if finished && job['nodes']['succeeded'] &&
               job['nodes']['succeeded'].size == nodes.size
              ::Chef::Log.info("Deployment complete in " +
                                "#{(origin-timeout)/60} minutes. " +
                                "Deploy Successful!")
              break
            elsif finished == true && job['nodes']['failed'] || job['nodes']['unavailable']
              ::Chef::Log.info("Deployment failed on the following nodes with status: ")
              ::Chef::Log.info(" => Failed: #{job['nodes']['failed']}.") if job['nodes']['failed']
              ::Chef::Log.info(" => Unavailable: #{job['nodes']['unavailable']}.") if job['nodes']['unavailable']
              raise "Deployment failed! Not all nodes were successful."
            end

            dec_timeout(PUSH_SLEEP_TIME)
          end until timeout <= 0

          break if finished

          ## If we make it here and we are past our timeout the job timed out
          ## waiting for the push job.
          if timeout <= 0
            ::Chef::Log.error("Timed out after #{origin/60} minutes waiting "+
                              "for push job. Deploy Failed...")
            raise "Timeout waiting for deploy..."
          end

          dec_timeout(SLEEP_TIME)
        end while timeout > 0

        ## If we make it here and we are past our timeout the job timed out.
        if timeout <= 0
          ::Chef::Log.error("Timed out after #{origin/60} minutes waiting "+
                            "for deployment to complete. Deploy Failed...")
          raise "Timeout waiting for deploy..."
        end

        # we survived
        true
      end
    end
  end
end

class Chef
  class Resource
    class DeliveryTruckDeploy < Chef::Resource::LWRPBase

      actions :run

      default_action :run

      attribute :command, :kind_of => String,   :default => 'chef-client'
      attribute :timeout, :kind_of => Integer,  :default => 30 * 60 # 30 mins
      attribute :search,  :kind_of => String

      self.resource_name = :delivery_truck_deploy
      def initialize(name, run_context=nil)
        super
        @provider = Chef::Provider::DeliveryTruckDeploy
      end
    end
  end
end
