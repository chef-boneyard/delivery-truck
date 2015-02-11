# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

class Chef
  class Provider
    class DeliveryTruckExec < Chef::Provider::Execute
      def action_run
        opts = {}

        if sentinel_file = sentinel_file_if_exists
          Chef::Log.debug("#{@new_resource} sentinel file #{sentinel_file} exists - nothing to do")
          return false
        end

        # original implementation did not specify a timeout, but ShellOut
        # *always* times out. So, set a very long default timeout
        opts[:timeout] = @new_resource.timeout || 3600
        opts[:returns] = @new_resource.returns if @new_resource.returns
        opts[:environment] = @new_resource.environment if @new_resource.environment
        opts[:user] = @new_resource.user if @new_resource.user
        opts[:group] = @new_resource.group if @new_resource.group
        opts[:cwd] = @new_resource.cwd if @new_resource.cwd
        opts[:umask] = @new_resource.umask if @new_resource.umask
        opts[:log_level] = :info
        opts[:log_tag] = @new_resource.to_s
        opts[:live_stream] = Chef::Log.logger
        converge_by("execute #{@new_resource.command}") do
          shell_out!(@new_resource.command, opts)
          Chef::Log.info("#{@new_resource} ran successfully")
        end
      end

      private

      def sentinel_file_if_exists
        if sentinel_file = @new_resource.creates
          relative = Pathname(sentinel_file).relative?
          cwd = @new_resource.cwd
          if relative && !cwd
            Chef::Log.warn "You have provided relative path for execute#creates (#{sentinel_file}) without execute#cwd (see CHEF-3819)"
          end

          if ::File.exists?(sentinel_file)
            sentinel_file
          elsif cwd && relative
            sentinel_file = ::File.join(cwd, sentinel_file)
            sentinel_file if ::File.exists?(sentinel_file)
          end
        end
      end

    end
  end
end

class Chef
  class Resource
    class DeliveryTruckExec < Chef::Resource::Execute
      def initialize(name, run_context=nil)
        super
        @resource_name = :delivery_truck_exec
        @provider = Chef::Provider::DeliveryTruckExec
      end
    end
  end
end
