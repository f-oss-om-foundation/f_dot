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

      def initialize
        FDot.state[:program] = nil
        FDot.state[:f_dot_queue] = nil
        FDot.state[:instructions] = nil
      end

      def run
        raise "already running #{FDot.state[:program].inspect}!" unless FDot.state[:program].nil?

        FDot.state[:program] = FDot::Based::Program.new
        puts "loaded #{FDot.state[:program]}"

        loop do
          FDot::Based::Interface.reconfigure_user_space!
          # list .f_dot directory
          # Dir[
          #   File.join(FDot::Based.f_dot_space_path, "*")
          # ].each{|d|
          #   puts d.gsub(FDot::Based.f_dot_space_path, "")
          # }
          user_input = self.get_user_input

          if Dir.exist?(user_input)
            domain_name = File.basename(user_input)
            if FDot::DOMAINS[domain_name.to_sym] == FDot::DOMAINS[:user]
              selected_variable_file_path = FDot::Based.tty_prompt_select(
                "select a variable: ", FDot::Based::Interface.user_input_options(user_input)
              )
              next if selected_variable_file_path.nil?
              variable_uuid = FDot::Based::Interface.get_variable_uuid_from_file(
                selected_variable_file_path
              )
              raise "invalid variable uuid! #{variable_uuid}" if variable_uuid.nil? ||
                !FDot.state[:program].variables.keys.include?(variable_uuid)

              selected_variable_option = FDot::Based.tty_prompt_select(
                "select an action: ", FDot::Based::Interface.user_variable_options(variable_uuid)
              )
              if selected_variable_option == :move_to_compiler

                # move for the user
                FDot.state[:program].add_move_history(
                  FDot.state[:program].variables[variable_uuid],
                  :processor
                )

                # move for the programmer
                programmer_variable_uuid = FDot.state[:programmer][:variables].sample
                FDot.state[:program].add_move_history(
                  FDot.state[:program].variables[programmer_variable_uuid],
                  :processor
                )
              end

            else
              listing_text = ["listing #{File.basename(user_input)} domain..."]
              Dir[
                File.join(user_input, "*")
              ].each{|d|
                listing_text << d.gsub(user_input, "")
              }
              FDot::Based.less(
                listing_text.join("\n")
              )
            end
          elsif File.exist?(user_input)
            file_contents = JSON.parse(File.read(user_input))
            if File.basename(user_input) == :compiler.to_s
              file_contents["variables"] = file_contents["variables"].map{|v_uuid|
                FDot.state[:program].variables[v_uuid].to_s
              }
              file_contents["instructions"] = file_contents["instructions"].map{|i_uuid|
                FDot.state[:program].instructions[i_uuid].to_s
              }
            end

            puts "reading #{File.basename(user_input)} file..."
            FDot::Based.less(
              JSON.pretty_generate(file_contents)
            )
          end
        end
      end

      def get_user_input
        FDot::Based.tty_prompt_select(
          "#{self.class.name}.#{__method__}: ", FDot::Based::Interface.user_input_options
        )
      end

    end
  end
end