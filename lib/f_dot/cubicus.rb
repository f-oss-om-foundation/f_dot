# frozen_string_literal: true

=begin

  cubicus.rb

  f_dot cubicus.

  created by i2097i

=end

module FDot
  module Based
    class Cubicus
      include Singleton

      VALID_KEYS = [
        :controls,
        :display,
        :input,
        :f_dot_go,
        :"index.html"
      ]

      attr_accessor :ws_thread
      attr_accessor :controls
      attr_accessor :is_running
      attr_accessor :original_stdout
      attr_accessor :controls_delegate

      FOLDER_NAME = ".cubicus"

      GO_SERVER_BASENAME = "f_dot.go"

      def initialize
        self.is_running = false
        self.ws_thread = nil
        self.controls = {}
        self.controls_delegate = nil
      end

      def start_ws_thread
        self.ws_thread&.exit
        self.ws_thread&.kill

        prepare_f_dot_go!

        FDot::Based::Interface.instance.display_mode = FDot::DISPLAY_MODES[:websockets]
        go_server_path = self.class.path_for_file(:f_dot_go)

        self.original_stdout = $stdout
        $stdout.reopen(self.class.path_for_file(:display), "w")
        $stdout.sync = true
        self.ws_thread = Thread.new do
          system("#{go_server_path} > #{go_server_path}.log 2>&1")
        end
      end

      def self.run_exit_cleanup!
        puts __method__
        # do not run if not using websockets
        return unless FDot::Based::Interface.instance.display_mode == FDot::DISPLAY_MODES[:websockets]

        # do not run if in one_move mode
        if FDot::Based::Processor.instance.processing_mode == FDot::Based::Processor::MODES[:one_move]
          FDot::Based::Processor.instance.processing_mode = FDot::Based::Processor::MODES[:default]
          return
        end

        self.write_open_system!
        system("pkill f_dot_go") # todo: daemonize
        self.instance.ws_thread&.exit
        self.instance.ws_thread&.kill
        self.instance.ws_thread = nil
        if $stdout != self.instance.original_stdout
          $stdout = self.instance.original_stdout
        end
      end

      def self.read_input!
        unless File.exist?(self.path_for_file(:input))
          raise "invalid #{__method__} file does not exist at #{self.path_for_file(:input)}!"
        end

        input = JSON.parse(File.read(self.path_for_file(:input)))
        raise "invalid input uuid!" unless self.instance.controls.keys.include?(input["uuid"])

        control = self.instance.controls[input["uuid"]]
        raise "invalid control! #{input["uuid"]}" if control.nil? || !control.kind_of?(Hash)

        if control[:type].nil?
          # :name, :value hash
          return self.instance.controls[input["uuid"]][:value]
        else
          # assert input contains "new_value"
          raise "missing new_value for #{control[:name]} control!" if input["new_value"].nil? ||
            !input["new_value"].kind_of?(String) ||
            input["new_value"].empty?

          return input["new_value"]
        end
      end

      def self.write_open_system!
        # write current display
        $stdout.sync = true
        $stdout.flush

        # write current controls
        File.open(self.path_for_file(:controls), "w") do |f|
          f.write(self.instance.controls.map{|k, v|
            v.merge({uuid: k})
          }.to_json)
          f.fsync
        end

        # clear last input
        FileUtils.rm_rf(self.path_for_file(:input))

        system("curl -s http://localhost:8080/ready")
        $stdout.reopen(FDot::Based::Cubicus.path_for_file(:display), "w")
      end

      def self.update_with(controls)
        input_value = nil
        Thread.new{
          FDot::Based::Cubicus.instance.controls = {}
          controls.each{|c|
            control_uuid = FDot::Based.generate_uuid
            FDot::Based::Cubicus.instance.controls[control_uuid] = c
          }

          FDot::Based::Cubicus.write_open_system!

          # wait for user input
          while !File.exist?(FDot::Based::Cubicus.path_for_file(:input)) ||
            (File.read(FDot::Based::Cubicus.path_for_file(:input)) || "").empty?
          end

          input_value = FDot::Based::Cubicus.read_input!
        }.join

        yield(input_value)
      end

      private

      def prepare_f_dot_go!
        go_directory = File.join(
          FDot.gem_directory, "lib/go"
        )
        go_file_path = File.join(
          go_directory, FDot::Based::Cubicus::GO_SERVER_BASENAME
        )

        raise "#{go_file_path} is not a valid file path!" unless File.exist?(go_file_path)

        puts "ensure index.html exists in .f_dot directory:"
        puts "(#{File.join(go_directory, "index.html")}, #{FDot::Based.f_dot_space_path})"
        FileUtils.cp(File.join(go_directory, "index.html"), FDot::Based.f_dot_space_path)

        puts "ensure .f_dot/javascript directory exists:"
        puts "(#{File.join(go_directory, "javascript")}, #{FDot::Based.f_dot_space_path})"
        FileUtils.cp_r(File.join(go_directory, "javascript"), FDot::Based.f_dot_space_path)

        puts "ensure .f_dot/stylesheets directory exists:"
        puts "(#{File.join(go_directory, "stylesheets")}, #{FDot::Based.f_dot_space_path})"
        FileUtils.cp_r(File.join(go_directory, "stylesheets"), FDot::Based.f_dot_space_path)

        if File.exist?(self.class.path_for_file(:f_dot_go))
          FileUtils.rm_rf(self.class.path_for_file(:f_dot_go))
          FileUtils.rm_rf("#{self.class.path_for_file(:f_dot_go)}.log")
        end

        puts "system(go build -o #{self.class.path_for_file(:f_dot_go)} #{go_file_path})"
        system("go build -C #{go_directory} -o #{self.class.path_for_file(:f_dot_go)} #{go_file_path}")

        raise "failed to build #{self.class.path_for_file(:f_dot_go)}!" unless File.exist?(self.class.path_for_file(:f_dot_go))
      end

      def self.path_for_file(cubicus_file_key)
        cubicus_file_key = cubicus_file_key.to_sym
        raise "invalid cubicus_file_key!" unless FDot::Based::Cubicus::VALID_KEYS.include?(cubicus_file_key)

        File.join(FDot::Based.f_dot_space_path, cubicus_file_key.to_s)
      end

    end
  end
end
