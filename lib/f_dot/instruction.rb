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
        program_instance.instructions[self.uuid] = self
      end

      def ordinal
        program_instance.variables[variable_uuids.first].ordinal
      end

      def domain_key
        FDot::Based::Variable.domain_key_for(self.domain)
      end

      def to_s
        # todo: unicodeify
        "<#{variable_uuids.map{|v| program_instance.variables[v].to_s}.sort.join(":")}>"
      end

      def program_instance
        FDot.state[:program].uuid == self.program_uuid ? FDot.state[:program] : FDot.state[:completed_programs][self.program_uuid]
      end

      def combine_with_instruction(to_combine_instruction)
        self.variable_uuids += to_combine_instruction.variable_uuids
        to_combine_instruction.variable_uuids = []
        # remove to_combine_instruction from the env
        FDot.state[:instructions].delete(to_combine_instruction.uuid)
        FDot.state[:program].history.delete(to_combine_instruction.uuid)
        FDot.state[:program].instructions.delete(to_combine_instruction.uuid)
      end

      def history_menu_options
        [
          :uuid,
          :program_uuid,
          :variable_uuids,
          :domain_key,
          :ordinal,
          :compiled_domain,
          :compiler_variable_uuid
        ].map{|attribute|
          implementation_notes = ""
          if [:compiled_domain, :compiler_variable_uuid].include?(attribute)
            implementation_notes = " (todo: #{attribute} is not implemented.)"
          end
          {
            name: "#{attribute}#{implementation_notes}",
            value: attribute
          }
        }
      end

      def compute_serialized_state!
        serialized_state = {
          name: self.to_s
        }
        FDot::Based::Instruction.serialization_keys.each{|k|
          serialized_state[k] = self.send(k)
        }
        serialized_state
      end

      def self.deserialize_into!(program, serialized_instruction)
        raise "invalid serialized_instruction! #{serialized_instruction}" unless serialization_keys.all?{|k|
          serialized_instruction.keys.include?(k.to_s)
        }
        instruction_instance = self.new(program.uuid, serialized_instruction["variable_uuids"])

        raise "missing variable uuid!" if serialized_instruction["uuid"].nil? || serialized_instruction["uuid"].empty?

        program.instructions.delete(instruction_instance.uuid)
        instruction_instance.uuid = serialized_instruction["uuid"]
        instruction_instance.domain = serialized_instruction["domain"].to_i
        instruction_instance.compiled_domain = serialized_instruction["compiled_domain"]
        instruction_instance.compiler_variable_uuid = serialized_instruction["compiler_variable_uuid"]
        program.instructions[serialized_instruction["uuid"]] = instruction_instance

        instruction_instance
      end

      private

      def self.serialization_keys
        [
          :uuid,
          :program_uuid,
          :variable_uuids,
          :domain
        ]
      end

    end
  end
end
