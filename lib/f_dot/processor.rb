# frozen_string_literal: true

=begin

  processor.rb

  f_dot processor.

  created by i2097i

=end

module FDot
  module Based
    class Processor
      include Singleton

      private attr_accessor :program

      def initialize
        self.program = nil
      end

      def run(new_program)
        raise "already running #{self.program.inspect}!" unless self.program.nil?
        raise "invalid program! #{new_program}" unless new_program.kind_of?(FDot::Based::Program)

        self.program = new_program
        puts "loaded #{self.program}"

        loop do
          # read_program_data
          program_data = self.program.read_space!
          raise "failed to read_program_data! #{program_data}" if program_data == false

          # write_user_space
          write_success = FDot::Based::Interface.instance.write_space!(program_data)
          raise "failed to write_user_space! #{write_success}" if write_success == false

          FDot::Based::Interface.instance.show_space!
          user_input = self.get_user_input
          break if user_input == false
          raise "invalid user input! #{user_input}" if user_input.nil? || user_input.empty?

          FDot::Based::PROMPT.less(
            self.program.variables.select{|v| v.uuid == user_input}
          )
        end
      end

      def get_user_input
        FDot::Based.tty_prompt_select(
          "select something: ", self.program.user_input_options
        )
      end

    end
  end
end