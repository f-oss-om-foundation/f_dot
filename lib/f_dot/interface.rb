# frozen_string_literal: true

=begin

  interface.rb

  f_dot interface.

  created by i2097i

=end

module FDot
  module Based
    class Interface
      include Singleton

      attr_accessor :program_data

      def write_space!(program_data = {})
        self.program_data = program_data
        return true
      end

      def show_space!
        puts JSON.pretty_generate(self.program_data)
      end
    end
  end
end