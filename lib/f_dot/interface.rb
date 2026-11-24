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

      attr_accessor :display_mode

      def initialize
        self.display_mode = FDot::DISPLAY_MODES[:terminal]
      end

      def self.get_variable_uuid_from_file(variable_file_path)
        raise "invalid variable_file_path! #{variable_file_path}" unless File.exist?(variable_file_path)
        variable_uuid = nil
        begin
          variable_json = JSON.parse(File.read(variable_file_path))
          variable_uuid = variable_json["uuid"]
        rescue StandardError => e
          raise e
        end

        raise "invalid variable file!" if variable_uuid.nil?
        raise "invalid variable!" unless FDot.state[:program].variables.keys.include?(variable_uuid)
        variable_uuid
      end

      def self.user_input_options(folder_path = nil)
        folder_path = FDot::Based.f_dot_space_path if folder_path.nil? || !Dir.exist?(folder_path)

        # get listing for path and return sorted tty-prompt options
        [{name: :f_dot_main_menu, value: :f_dot_main_menu}] + Dir[
          File.join(folder_path, "*")
        ].select{|d|
          !FDot::Based::Cubicus::VALID_KEYS.any?{|n| File.basename(d).include?(n.to_s)}
        }.map{|d|
          {name: File.basename(d), value: d}
        }.sort_by{|o|
          sorters = [o[:name]]
          unless File.expand_path(o[:value].gsub(o[:name], "")) == FDot::Based.f_dot_space_path
            sorters << FDot.state[:program].variables[get_variable_uuid_from_file(o[:value])].ordinal
          end
        }
      end

      def self.open_main_menu?(prompt_select_value)
        if prompt_select_value == :f_dot_main_menu
          self.show_main_menu!
          return true
        else
          self.reconfigure_user_space!
          return false
        end

      end

      def self.show_main_menu!
        main_menu_open = true
        while main_menu_open
          FDot::Based.tty_prompt_select(
            "f_dot_main_menu =>",
            self.main_menu_options.map{|k|
              {name: k, value: k}
            }
          ) {|user_selection|
            case user_selection
            when :resume_program
              main_menu_open = false
            when :startup_notes
              puts FDot::Based::Program.startup_notes
            when :open_history
              FDot.state[:program].show_history_interface!
            when :open_settings
              FDot::Based::Processor.show_settings_menu!
            when :close_program
              FDot::Based.tty_prompt_select(
                "are you sure?",
                [{name: :back, value: :back}, {name: :i_am_sure, value: :i_am_sure}]
              ){|v|
                if v == :i_am_sure
                  main_menu_open = false
                  return FDot::Based::Processor.user_exited!
                end
              }
            end
          }
        end
      end

      def self.compiler_file_path
        File.join(
          FDot::Based.f_dot_space_path,
          :compiler.to_s
        )
      end

      def self.reconfigure_user_space!
        # clear user space
        Dir[File.join(FDot::Based.f_dot_space_path, "*")].each{|f|
          FileUtils.rm_rf(f) unless FDot::Based::Cubicus::VALID_KEYS.any?{|n| File.basename(f).include?(n.to_s)}
        }

        # build program data
        FDot.state[:program].build_space!

        # write user space
        compiler_data = FDot.state[:program].compiler_contents
        compiler_data[:variables] = compiler_data[:variables].sort
        compiler_data[:instructions] = compiler_data[:instructions].sort
        File.open(self.compiler_file_path, "w+") do |f|
          f.write(compiler_data.to_json)
          f.fsync
        end

        unless FDot.state[:based_uuid].nil?
          # write based variable file
          based_variable = FDot.state[:program].variables[
            FDot.state[:based_uuid]
          ]
          based_file_path = File.join(
            FDot::Based.f_dot_space_path,
            based_variable.to_s
          )
          File.open(based_file_path, "w+") do |f|
            f.write({
              uuid: based_variable.uuid
            }.to_json)
            f.fsync
          end
        end

        # write programmer and user domain folders
        [:programmer, :user].each{|domain_key|
          # get domain folder path
          domain_folder_path = File.join(FDot::Based.f_dot_space_path, domain_key.to_s)

          # ensure domain folder exists
          FileUtils.mkdir_p(domain_folder_path)

          # create variable file in domain directory for each variable in the domain
          FDot.state[domain_key][:variables].each{|v|
            variable_instance = FDot.state[:program].variables[v]
            variable_file_path = File.join(
              domain_folder_path,
              domain_key == :user ? variable_instance.to_s : variable_instance.uuid
            )

            # write variable identifier into variable file
            File.open(variable_file_path, "w+") do |f|
              f.write({
                uuid: v
              }.to_json)
              f.fsync
            end
          }
        }

        # write processor domain folders
        processor_file_path = File.join(FDot::Based.f_dot_space_path, :processor.to_s)
        File.open(processor_file_path, "w+") do |f|
          f.write({
            variables: FDot.state[:f_dot_queue],
            instructions: FDot.state[:instructions]
          }.to_json)
          f.fsync
        end

        # write processor serialized_state file
        serialized_state_file_path = File.join(FDot::Based.f_dot_space_path, "processor_state.json")
        File.open(serialized_state_file_path, "w+") do |f|
          f.write(FDot::Based::Processor.instance.serialized_state.to_json)
          f.fsync
        end

        return true
      end

      private

      def self.main_menu_options
        [
          :resume_program,
          :startup_notes,
          :open_history,
          :open_settings,
          :close_program,
        ]
      end

    end
  end
end