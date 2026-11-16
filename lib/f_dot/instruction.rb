# frozen_string_literal: true

=begin

  instruction.rb

  f_dot instruction.

  created by i2097i

=end

module FDot
  module Based

    class Instruction
      attr_accessor :uuid
      attr_accessor :program_uuid
      attr_accessor :variable_uuids
      attr_accessor :domain
      attr_accessor :compiled_domain
      attr_accessor :compiler_variable_uuid

      def initialize(program_uuid, variable_uuids = [])
        self.uuid = FDot::Based.generate_uuid
        self.program_uuid = program_uuid
        self.variable_uuids = variable_uuids
        self.domain = FDot::DOMAINS[:processor]
        self.compiled_domain = nil
        self.compiler_variable_uuid = nil
        FDot.state[:program].instructions[self.uuid] = self
      end

      def self.create_with_combinable_instructions(program_uuid, combinable_instructions)
        # todo: validate that combinable_instructions can be combined
        distinct_variable_uuids = []
        combinable_instructions.each{|c|}
          distinct_variable_uuids += c.variable_uuids
          FDot.state[:instructions].delete(c.uuid)
          FDot.state[:program].instructions.delete(c.uuid)
        }
        new_instruction = FDot::Based::Instruction.new(program_uuid, distinct_variable_uuids)
        FDot.state[:instructions] << new_instruction.uuid
        FDot.state[:program].instructions[new_instruction.uuid] = new_instruction
      end

      def ordinal
        FDot.state[:program].variables[variable_uuids.first]
      end
    end
  end
end
