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
        new_history = self.new(instruction, to_domain)

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

        new_history = self.new(variable, to_domain)

        # update the variable's domain
        variable.domain = new_history.to_domain

        # return new_history
        new_history
      end

      def initialize(historical, to_domain)
        self.timestamp = Time.now.to_i
        self.to_domain = to_domain
        self.from_domain = historical.domain
        if historical.kind_of?(FDot::Based::Instruction)
          self.instruction_uuid = historical.uuid
        elsif historical.kind_of?(FDot::Based::Variable)
          self.variable_uuid = historical.uuid
        else
          raise "invalid historical!"
        end
      end

      def get_instruction
        return nil if self.instruction_uuid.nil?
        FDot.state[:program].instructions[self.instruction_uuid]
      end

      def get_variable
        return nil if self.variable_uuid.nil?
        FDot.state[:program].variables[self.variable_uuid]
      end

      def show_interface!
        interface_open = true
        @historical_instance = nil
        puts "opening history #(#{self.timestamp})"
        puts self.to_s
        while interface_open
          FDot::Based.tty_prompt_select(
            "viewing historical_instance #{historical_instance.to_s}",
            [{name: :back, value: :back}] + historical_instance.history_menu_options
          ) {|historical_attribute|

            return if historical_attribute == :back

            puts historical_instance.send(historical_attribute)
          }
        end
      end

      def historical_instance
        @historical_instance ||= self.get_variable || self.get_instruction
      end

      def to_s
        instance_object = get_variable || get_instruction
        [
          "[#{self.timestamp}]: '#{instance_object&.to_s}' moved",
          "from <#{FDot::Based::Variable.domain_key_for(self.from_domain)}>",
          "to <#{instance_object&.domain_key}>",
        ].join(" ")
      end

      def compute_serialized_state!
        serialized_state = {
          name: self.to_s
        }
        FDot::Based::History.serialization_keys.each{|k|
          serialized_state[k] = self.send(k)
        }
        serialized_state
      end

      def self.deserialize_into!(program, serialized_history)
        raise "invalid serialized_history! #{serialized_history}" unless serialization_keys.all?{|k|
          serialized_history.keys.include?(k.to_s)
        }

        raise "missing instruction or variable uuid! #{serialized_history}" if [
          :instruction_uuid, :variable_uuid
        ].all?{|k| serialized_history[k.to_s].nil?}

        history_instance = nil
        unless serialized_history["variable_uuid"].nil?
          history_variable = program.variables[
            serialized_history["variable_uuid"]
          ]
          history_instance = self.new(history_variable, serialized_history["to_domain"])
        else
          history_instruction = program.instructions[
            serialized_history["instruction_uuid"]
          ]
          history_instance = self.new(history_instruction, serialized_history["to_domain"])
        end

        program.history[history_instance.historical_instance.uuid] ||= []
        program.history[history_instance.historical_instance.uuid] << history_instance

        history_instance
      end

      private

      def self.serialization_keys
        [
          :timestamp,
          :from_domain,
          :to_domain,
          :variable_uuid,
          :instruction_uuid,
        ]
      end

    end
  end
end
