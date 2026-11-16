# frozen_string_literal: true

=begin

  history.rb

  f_dot history.

  created by i2097i

=end

module FDot
  module Based
    class History
      attr_accessor :timestamp
      attr_accessor :from_domain
      attr_accessor :to_domain
      attr_accessor :variable_uuid

      def initialize(variable, to_domain)
        self.timestamp = Time.now.to_i
        self.from_domain = variable.domain
        self.to_domain = to_domain
        self.variable_uuid = variable.uuid

        raise "invalid history!" if variable.domain == to_domain &&
          variable.uuid != FDot.state[:based_uuid]

        variable.domain = to_domain
      end

      def get_variable
        FDot.state[:program].variables[self.variable_uuid]
      end

      def to_s
        [
          "[#{self.timestamp}]: '#{get_variable.to_s}' variable moved",
          "\tfrom :#{FDot::Based::Variable.domain_key_for(self.from_domain)}",
          "\tto   :#{get_variable.domain_key}",
        ].join("\n")
      end

    end
  end
end
