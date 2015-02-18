#
# Copyright:: Copyright (c) 2012-2015 Chef Software, Inc.
#

module DeliveryTruck
  class Error < RuntimeError; end

  # Raise this when a `.delivery/config.json` file doesn't actually
  # exist.
  class MissingConfiguration < Error
    def initialize(path)
      @path = path
    end

    def to_s
      <<-EOM
Could not find a Delivery configuration file at:
#{@path}
      EOM
    end
  end

  # Raise when a cookbook said to be a cookbook is not a valid cookbook
  class NotACookbook < Error
    def initialize(path)
      @path = path
    end

    def to_s
      <<-EOM
The directory below is not a valid cookbook:
#{@path}
      EOM
    end
  end

  # If we do not have the change information yet lets report it
  class MissingChangeInformation < Error
    def initialize(message)
      @message = message
    end

    def to_s
      <<-EOM
At this point there is no Change Information loaded.
Extra Details:
#{@message}
EOM
    end
  end
end
