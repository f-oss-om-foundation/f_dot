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
      attr_accessor :program_id
      attr_accessor :type
      attr_accessor :ordinal

      def initialize(program_id, type, ordinal)
        self.uuid = FDot::Based.generate_uuid
        self.program_id = program_id
        self.type = type
        self.ordinal = ordinal
        puts "#{__method__} #{self.label}"
      end

      def number_key
        FDot::Based::NUMBERS[self.ordinal]
      end

      def label
        "#{self.number_key} of #{self.type}."
      end
    end
  end
end
