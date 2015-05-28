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

module DeliverySugar
  #
  # This class is our interface to execute push jobs against a push jobs server.
  #
  class PushJob
    attr_reader :server_url, :command, :nodes, :rest, :job_uri, :job

    # Variables for the Job itself
    attr_reader :id, :status, :created_at, :updated_at, :results

    # How long to wait between each refresh during #wait
    PAUSE_SECONDS = 5

    #
    # Create a new PushJob object
    #
    # @param server_url [String]
    #   The hostname for the server where the push jobs server is installed.
    #   The most common value for this will be Chef::Config[:chef_server_url]
    # @param command [String]
    #   The white-listed command to execute via push jobs
    # @param nodes [Array#String]
    #   An array of node names to run the push job against
    # @param timeout [Integer]
    #   How long to wait before timing out
    #
    # @return [DeliverySugar::PushJob]
    #
    def initialize(server_url, command, nodes, timeout)
      @server_url = server_url
      @command = command
      @nodes = nodes.map { |n| n.name }
      @timeout = timeout
      ::Chef_Delivery::ClientHelper.enter_client_mode_as_delivery
      @rest = Chef::REST.new(Chef::Config[:chef_server_url])
      ::Chef_Delivery::ClientHelper.leave_client_mode_as_delivery
    end

    #
    # Trigger the push job
    #
    def dispatch
      body = {
        'command' => @command,
        'nodes' => @nodes,
        'run_timeout' => @timeout
      }

      ::Chef_Delivery::ClientHelper.enter_client_mode_as_delivery
      resp = @rest.post_rest('/pushy/jobs', body)
      ::Chef_Delivery::ClientHelper.leave_client_mode_as_delivery

      @job_uri = resp['uri']
      refresh
    end

    #
    # Loop until the push job succeeds, errors, or times out.
    #
    def wait
      loop do
        refresh
        fail Exceptions::PushJobFailed, @job if timed_out?
        fail Exceptions::PushJobFailed, @job if failed?
        break if successful?
        pause
      end
    end

    #
    # Return whether or not a push job has completed or not
    #
    # @return [TrueClass, FalseClass]
    #
    def complete?
      case @status
      when 'new', 'voting', 'running'
        false
      when 'complete'
        true
      else
        fail Exceptions::PushJobError, @job
      end
    end

    #
    # Return whether or not the completed push job was successful.
    #
    # @return [TrueClass, FalseClass]
    #
    def successful?
      complete? && all_nodes_succeeded?
    end

    #
    # Return whether or not the completed push job failed.
    #
    # @return [TrueClass, FalseClass]
    #
    def failed?
      complete? && !all_nodes_succeeded?
    end

    #
    # Determine if the push job has been running longer than the timeout
    # would otherwise allow. We do this as a backup to the timeout in the
    # Push Job API itself.
    #
    # @return [TrueClass, FalseClass]
    #
    def timed_out?
      @status == 'timed_out' || (@created_at + @timeout < current_time)
    end

    #
    # Poll the API for an update on the Job data.
    #
    def refresh
      ::Chef_Delivery::ClientHelper.enter_client_mode_as_delivery
      @job = @rest.get_rest(@job_uri)
      ::Chef_Delivery::ClientHelper.leave_client_mode_as_delivery

      @id ||= job['id']
      @status = job['status']
      @created_at = DateTime.parse(job['created_at'])
      @updated_at = DateTime.parse(job['updated_at'])
      @results = job['nodes']
    end

    private

    #
    # Return the current time
    #
    # @return [DateTime]
    #
    def current_time
      DateTime.now
    end

    #
    # Return whether or not all nodes are marked as successful.
    #
    # @return [TrueClass, FalseClass]
    #
    def all_nodes_succeeded?
      @results['succeeded'] && @results['succeeded'].length == @nodes.length
    end

    #
    # Implement our method of pausing before we get the status of the
    # push job again.
    #
    def pause
      sleep PAUSE_SECONDS
    end
  end
end
