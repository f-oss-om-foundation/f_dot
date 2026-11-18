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

      def self.user_variable_options(variable_uuid)
        FDot.state[:program].get_options_for_variable_uuid(variable_uuid)
      end

      def self.user_input_options(folder_path = nil)
        folder_path = FDot::Based.f_dot_space_path if folder_path.nil? || !Dir.exist?(folder_path)

        # get listing for path and return sorted tty-prompt options
        Dir[
          File.join(folder_path, "*")
        ].map{|d|
          {name: File.basename(d), value: d}
        }.sort_by{|o|
          sorters = [o[:name]]
          unless File.expand_path(o[:value].gsub(o[:name], "")) == FDot::Based.f_dot_space_path
            sorters << FDot.state[:program].variables[get_variable_uuid_from_file(o[:value])].ordinal
          end
        }
      end

      def self.reconfigure_user_space!
        # clear user space
        FileUtils.rm_rf(FDot::Based.f_dot_space_path)

        # build program data
        FDot.state[:program].build_space!

        # write user space
        compiler_file_path = File.join(
          FDot::Based.f_dot_space_path,
          :compiler.to_s
        )

        compiler_data = FDot.state[:program].compiler_contents
        compiler_data[:variables] = compiler_data[:variables].sort
        compiler_data[:instructions] = compiler_data[:instructions].sort
        File.open(compiler_file_path, "w+") do |f|
          f.write(compiler_data.to_json)
        end

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
        end

        return true
      end

    end
  end
end