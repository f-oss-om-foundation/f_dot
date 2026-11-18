# frozen_string_literal: true

=begin

  variable.rb

  f_dot variable.

  created by i2097i

=end

module FDot
  module Based

    class Variable
      attr_accessor :uuid
      attr_accessor :program_uuid
      attr_accessor :type
      attr_accessor :ordinal
      attr_accessor :domain

      def initialize(program_uuid, type, ordinal)
        self.uuid = FDot::Based.generate_uuid
        self.program_uuid = program_uuid
        self.type = type
        self.ordinal = ordinal
        self.domain = FDot::DOMAINS[:processor]
      end

      def number_key
        FDot::Based::NUMBERS[self.ordinal]
      end

      def domain_key
        self.class.domain_key_for(self.domain)
      end

      def self.domain_key_for(domain_int)
        FDot::DOMAINS.keys.select{|k| FDot::DOMAINS[k] == domain_int}.first
      end

      def to_s
        "#{self.type_display}(#{self.ordinal})"
      end

      def type_display
        self.type.to_s.gsub("dot_", "").upcase
      end

      def combine_with_instruction(to_combine_instruction)
        unless to_combine_instruction.kind_of?(FDot::Based::Instruction)
          raise "cannot #{self.inspect} #{__method__} #{to_combine_instruction.inspect}"
        end

        raise "already combined with instruction!" if to_combine_instruction.variable_uuids.include?(self.uuid)

        to_combine_instruction.variable_uuids << self.uuid
        FDot.state[:program].history[to_combine_instruction.uuid] ||= []
        FDot.state[:program].history[to_combine_instruction.uuid] << FDot::Based::History.create_instruction_history!(
          to_combine_instruction,
          to_combine_instruction.domain
        )

        to_combine_instruction
      end

      def combine_with_variable(to_combine_variable)
        unless to_combine_variable.kind_of?(FDot::Based::Variable)
          raise "cannot #{self.inspect} #{__method__} #{to_combine_variable.inspect}"
        end
        new_instruction = FDot::Based::Instruction.new(self.program_uuid, [self.uuid, to_combine_variable.uuid])

        FDot.state[:program].history[new_instruction.uuid] = []
        FDot.state[:program].history[new_instruction.uuid] << FDot::Based::History.create_instruction_history!(
          new_instruction,
          new_instruction.domain
        )
        puts FDot.state[:program].history[new_instruction.uuid].last.to_s

        FDot.state[:instructions] << new_instruction.uuid

        new_instruction
      end

    end
  end
end
