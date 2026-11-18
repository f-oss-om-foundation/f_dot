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

      def ordinal
        FDot.state[:program].variables[variable_uuids.first].ordinal
      end

      def domain_key
        FDot::Based::Variable.domain_key_for(self.domain)
      end

      def to_s
        # todo: unicodeify
        "<#{variable_uuids.map{|v| FDot.state[:program].variables[v].to_s}.sort.join(":")}>"
      end

      def combine_with_instruction(to_combine_instruction)
        self.variable_uuids += to_combine_instruction.variable_uuids
        to_combine_instruction.variable_uuids = []
        # remove to_combine_instruction from the env
        FDot.state[:instructions].delete(to_combine_instruction.uuid)
        FDot.state[:program].instructions.delete(to_combine_instruction.uuid)
      end

    end
  end
end
