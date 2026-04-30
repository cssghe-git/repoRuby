# frozen_string_literal: true
#
=begin

=end

module Debuggable
#++++++++++++++++
    # Debug method to display class name and all instance variables with their values
    def debug_vars
        "#{self.class} - #{instance_variables.map { |v| "#{v}=#{instance_variable_get(v)}" }.join(', ')}"
    end #<def>

    # Timestamp methods
      def created_at
        @created_at ||= Time.now
    end
  
    def updated_at
        @updated_at ||= Time.now
    end

    def ended_at
        @ended_at ||= Time.now
    end

end #<Module>