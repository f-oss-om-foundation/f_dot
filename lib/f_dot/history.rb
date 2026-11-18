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
      attr_accessor :instruction_uuid

      def self.create_instruction_history!(instruction, to_domain)
        new_history = self.new(to_domain)
        new_history.from_domain = instruction.domain
        new_history.instruction_uuid = instruction.uuid

        # update the instruction's domain
        instruction.domain = new_history.to_domain

        # return new_history
        new_history
      end

      def self.create_variable_history!(variable, to_domain)
        if variable.domain == to_domain &&
          variable.uuid != FDot.state[:based_uuid]

          puts variable.to_s
          puts "variable.domain == to_domain #{variable.domain == to_domain}"
          puts "FDot.state[:based_uuid]: #{FDot.state[:based_uuid]}"

          raise "invalid variable! only the based_variable can move that way."
        end

        new_history = self.new(to_domain)
        new_history.from_domain = variable.domain
        new_history.variable_uuid = variable.uuid

        # update the variable's domain
        variable.domain = new_history.to_domain

        # return new_history
        new_history
      end

      def initialize(to_domain)
        self.timestamp = Time.now.to_i
        self.to_domain = to_domain
      end

      def get_instruction
        return nil if self.instruction_uuid.nil?
        FDot.state[:program].instructions[self.instruction_uuid]
      end

      def get_variable
        return nil if self.variable_uuid.nil?
        FDot.state[:program].variables[self.variable_uuid]
      end


      def to_s
        instance_object = get_variable || get_instruction
        [
          "[#{self.timestamp}]: '#{(instance_object).to_s}' moved",
          "\tfrom :#{FDot::Based::Variable.domain_key_for(self.from_domain)}",
          "\tto   :#{instance_object.domain_key}",
        ].join("\n")
      end

    end
  end
end
