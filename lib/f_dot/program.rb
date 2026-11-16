# frozen_string_literal: true

=begin

  program.rb

  f_dot program.

  created by i2097i

=end

module FDot
  module Based

    class Program
      attr_accessor :uuid
      attr_accessor :variables

      def initialize
        self.uuid = FDot::Based.generate_uuid
        self.variables = []

        generate_variables!
      end

      def generate_variables!
        FDot::Based::TYPES.each_with_index{|b_type, b_type_index|
          FDot::Based::NUMBERS.each_with_index{|b_number, b_number_index|
            self.variables << FDot::Based::Variable.new(
              self.uuid,
              b_type,
              b_number_index
            )
          }
        }
        puts startup_notes
      end

      def self.startup
        # new program instance
        program = FDot::Based::Program.new
        FDot::Based::Processor.instance.run(program)
      end

      def read_space!
        return true
      end

      def user_input_options
        self.variables.map{|v|
          {name: v.label, value: v.uuid}
        }
      end

      def startup_notes
        [
          "starting #{self.class.name}...",
          "there are #{self.variables.count} variables inside of this program.",
          "within the program you are able to work with the variables.",
          "the workspace is an in-memory runtime application that uses",
          "oss_om to store program state.",
          "the location of the value of a variable may be modified.",
          "a blank directory is required in user space for the program to run.",
          "this is called the user_space_path.",
          "located at #{FDot::Based.user_space_path}."
        ].join("\n")
      end

    end
  end
end