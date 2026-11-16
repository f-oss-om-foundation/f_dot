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
    end
  end
end
