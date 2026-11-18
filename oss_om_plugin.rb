# frozen_string_literal: true

=begin

  f_dot_plugin.rb

  oss_om f_dot plugin

  by i2097i

=end

module Aro
  module Dom
    class FDotPlugin
      include Singleton

      EXCLUDE_KEYS = [
        # ...
      ]

      attr_accessor :plugin_callback

      def initialize
        self.plugin_callback = nil
      end

      def self.configure_plugin_callback(new_callback)
        self.instance.plugin_callback = new_callback
        puts "#{__method__}"
        puts self.instance.plugin_callback.inspect
      end

      def self.oss_om_start!(plugin_data = {})
        Aro::P.less(:f_dot_plugin_starting)

        f_dot_installed = system("#{:which} -#{:s} #{:f_dot}")
        Aro::P.say("f_dot_installed: #{f_dot_installed}")
        raise "f_dot not installed!" unless f_dot_installed

        f_dot_state_data = plugin_data.dup

        require :f_dot.to_s
        begin
          FDot::Based::Processor.instance.write_state_callback = self.instance.plugin_callback
          FDot::Based::Processor.initialize_with_data(f_dot_state_data)
        rescue StandardError => e
          Aro::Prompt.say("f_dot thread threw an error: #{e}")
          puts Thread.current.backtrace
          raise e
        end
      end
    end
  end
end

