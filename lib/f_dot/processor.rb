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

      attr_accessor :user_settings
      attr_accessor :serialized_state
      attr_accessor :write_state_callback
      attr_accessor :plugin_mutex
      attr_accessor :state_mutex
      attr_accessor :f_dot_space_override_path
      attr_accessor :is_processing
      attr_accessor :processing_mode
      attr_accessor :default_display_override

      DEFAULT_SETTINGS = {
        show_history_logging: false,
        auto_compile_enabled: true,
        debug_inspectors_enabled: false
      }

      MODES = {
        default: 0,
        one_move: 1
      }

      def initialize
        self.user_settings = FDot::Based::Processor::DEFAULT_SETTINGS.dup
        self.serialized_state = {}
        self.write_state_callback = nil
        self.plugin_mutex = Mutex.new
        self.state_mutex = Mutex.new
        self.f_dot_space_override_path = nil
        self.is_processing = true
        self.processing_mode = FDot::Based::Processor::MODES[:default]
        self.default_display_override = false

        FDot.state[:completed_programs] = {}
        FDot.state[:program] = nil
        FDot.state[:f_dot_queue] = []
        FDot.state[:instructions] = []
      end

      def self.serialize_state!
        self.instance.serialized_state = {
          based_uuid: FDot.state[:based_uuid],
          # completed_programs: FDot.state[:completed_programs].map{|k, v| v.compute_serialized_state!},
          program: FDot.state[:program].compute_serialized_state!,
          f_dot_queue: FDot.state[:f_dot_queue],
          instructions: FDot.state[:instructions],
          user: {
            variables: FDot.state[:user][:variables] || []
          },
          programmer: {
            variables: FDot.state[:programmer][:variables] || []
          }
        }

        unless self.instance.write_state_callback.nil?
          self.instance.plugin_mutex.synchronize do
            self.instance.write_state_callback.call(
              self.instance.serialized_state
            )
          end
        end
      end

      def self.initialize_with_data(
        override_path = nil,
        callback = nil,
        initialize_data = {},
        one_move_mode = false
      )

        if one_move_mode
          self.instance.processing_mode = FDot::Based::Processor::MODES[:one_move]
          self.set_user_setting(:show_history_logging, true)
        end

        self.instance.write_state_callback = callback
        self.instance.f_dot_space_override_path = override_path

        return self.instance.run unless initialize_data.kind_of?(Hash) &&
          !initialize_data.empty?

        new_serialized_state = {}

        [
          :based_uuid,
          :f_dot_queue,
          :instructions,
          :program,
          :user,
          :programmer,
          :completed_programs
        ].each{|k|
          k = k.to_sym

          new_serialized_state[k] = initialize_data[k.to_s]
          if new_serialized_state[k].nil?
            puts "skipping #{k} because initialize_data[#{k}] is not present."
            next
          end

          if ![:user, :programmer].include?(k)
            case k
            when :based_uuid
              puts "setting based_uuid from data init: #{new_serialized_state[k]}"
              FDot.state[:based_uuid] = new_serialized_state[k]
            when :completed_programs
              puts :todo_initialize_completed_programs
            when :program
              begin
                p_serialized = new_serialized_state[k]

                program_instance = FDot::Based::Program.new(p_serialized["uuid"])
                puts "#{__method__} init program from serialized data! #{program_instance}"
                program_instance.uuid = p_serialized["uuid"]
                FDot.state[:program] = program_instance

                p_serialized["variables"].each{|_, serialized|
                  FDot::Based::Variable.deserialize_into!(FDot.state[:program], serialized)
                } unless p_serialized["variables"].nil?

                p_serialized["instructions"].each{|_, serialized|
                  FDot::Based::Instruction.deserialize_into!(FDot.state[:program], serialized)
                } unless p_serialized["variables"].nil?

                p_serialized["history"].map{|historical_uuid, _|
                  p_serialized["history"][historical_uuid].each{|h|
                    FDot::Based::History.deserialize_into!(FDot.state[:program], h)
                  }
                } unless p_serialized["variables"].nil?
              rescue StandardError => e
                puts e.inspect
                puts Thread.main.backtrace
              end
            when :f_dot_queue, :instructions
              FDot.state[k] = new_serialized_state[k]
            end
          else
            new_serialized_state[k][:variables] = new_serialized_state[k]["variables"].dup
            new_serialized_state[k].delete("variables")
            new_serialized_state[k][:variables].each{|variable_uuid|
              FDot.state[:program].variables[variable_uuid].domain = FDot::DOMAINS[k.to_sym]
            }
            FDot.state[k.to_sym] = {
              variables: [],
              instructions: []
            }
            FDot.state[k.to_sym][:variables] = new_serialized_state[k][:variables]
          end
        }
        puts "#{__method__} about to run with FDot.state[:program] set to: #{FDot.state[:program]}"
        self.instance.serialized_state = new_serialized_state
        self.instance.run(true)
      end

      def run(force = false)
        raise "already running #{FDot.state[:program].uuid}!" if !force && !FDot.state[:program].nil?

        if FDot::Based::Program.show_startup!.to_sym != :start
          self.class.user_exited!
        else
          FDot.state[:program] ||= FDot::Based::Program.new
          puts "loaded #{FDot.state[:program]}"
          self.is_processing = true
        end

        while self.is_processing

          FDot::Based::Interface.reconfigure_user_space!
          if !self.default_display_override
            FDot::Based.print_large_title!
            self.class.print_file_contents(FDot::Based::Interface.compiler_file_path)
          else
            self.default_display_override = false
          end

          user_input = self.get_user_input

          next if FDot::Based::Interface.open_main_menu?(user_input)

          if Dir.exist?(user_input)
            domain_name = File.basename(user_input)
            if FDot::DOMAINS[domain_name.to_sym] == FDot::DOMAINS[:user]
              FDot::Based.tty_prompt_select(
                "select a variable: ", FDot::Based::Interface.user_input_options(user_input)
              ) {|selected_variable_file_path|
                next if FDot::Based::Interface.open_main_menu?(selected_variable_file_path)
                next if selected_variable_file_path.nil?
                variable_uuid = FDot::Based::Interface.get_variable_uuid_from_file(
                  selected_variable_file_path
                )
                raise "invalid variable uuid! #{variable_uuid}" if variable_uuid.nil? ||
                  !FDot.state[:program].variables.keys.include?(variable_uuid)

                if FDot::Based::Processor.user_setting!(:debug_inspectors_enabled)
                  debugger_open = true
                  while debugger_open
                    v = FDot.state[:program].variables[variable_uuid]
                    FDot::Based.tty_prompt_select(
                      "select attribute: ",
                      [{name: :close_debugger, value: :close_debugger}] + v.history_menu_options
                    ) {|variable_attribute|
                      if variable_attribute == :close_debugger
                        debugger_open = false
                      else
                        self.default_display_override = true
                        puts v.send(variable_attribute)
                      end
                    }
                  end
                end
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

                if self.processing_mode == FDot::Based::Processor::MODES[:one_move]
                  unless self.write_state_callback.nil?
                    self.write_state_callback.call(self.serialized_state, true)
                  end
                  FDot::Based::Interface.reconfigure_user_space!
                  self.class.user_exited!
                end
              }
            else
              listing_text = ["listing #{File.basename(user_input)} domain..."]
              Dir[
                File.join(user_input, "*")
              ].each{|d|
                listing_text << d.gsub(user_input, "")
              }
              self.default_display_override = true
              FDot::Based.less(
                listing_text.join("\n")
              )
            end
          elsif File.exist?(user_input)
            self.default_display_override = true
            self.class.print_file_contents(user_input)
          end
        end

        !self.is_processing
      end

      def self.print_file_contents(file_path)
        raise "invalid file_path! #{file_path}" unless File.exist?(file_path)

        file_contents = JSON.parse(File.read(file_path))
        if File.basename(file_path) == :compiler.to_s
          file_contents["variables"] = file_contents["variables"].map{|v_uuid|
            FDot.state[:program].variables[v_uuid].to_s
          }
          file_contents["instructions"] = file_contents["instructions"].map{|i_uuid|
            FDot.state[:program].instructions[i_uuid].to_s
          }
        end

        puts "reading #{File.basename(file_path)} file..."
        FDot::Based.less(
          JSON.pretty_generate(file_contents)
        )
      end

      def get_user_input
        FDot::Based.tty_prompt_select(
          "#{self.class.name}.#{__method__}: ", FDot::Based::Interface.user_input_options
        ) {|v|
          return v
        }
      end

      def self.user_exited!
        FDot::Based::Cubicus.run_exit_cleanup!
        self.instance.is_processing = false
      end

      def self.show_settings_menu!

        settings_menu_open = true
        while settings_menu_open
          FDot::Based.tty_prompt_select(
            "select a setting to toggle",
            [{name: :back, value: :back}] + self.instance.user_settings.map{|k, v|
              {name: "#{k}(#{v})", value: k}
            }
          ) {|setting_key|

            if setting_key == :back
              settings_menu_open = false
              next
            end

            set_user_setting(setting_key, !user_setting!(setting_key))
          }
        end
      end

      def self.user_setting!(setting_key)
        setting_key = setting_key.to_sym
        raise "invalid setting_key: #{setting_key}" unless self.instance.user_settings.keys.include?(setting_key)

        self.instance.user_settings[setting_key]
      end

      def self.set_user_setting(setting_key, setting_value)
        setting_key = setting_key.to_sym

        self.instance.user_settings[setting_key] = setting_value
      end

    end
  end
end