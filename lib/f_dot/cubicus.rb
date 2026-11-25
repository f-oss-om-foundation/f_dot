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
        return unless FDot::Based::Interface.instance.display_mode == FDot::DISPLAY_MODES[:websocket]

        self.write_open_system!
        if $stdout != FDot::Based::Cubicus.instance.original_stdout
          $stdout = FDot::Based::Cubicus.instance.original_stdout
        end
        FDot::Based::Cubicus.instance.ws_thread&.exit
        FDot::Based::Cubicus.instance.ws_thread&.kill
        FDot::Based::Cubicus.instance.ws_thread = nil
        system("pkill f_dot") # todo: daemonize
      end

      def self.read_input!
        unless File.exist?(self.path_for_file(:input))
          raise "invalid #{__method__} file does not exist at #{self.path_for_file(:input)}!"
        end

        input = JSON.parse(File.read(self.path_for_file(:input)))
        raise "invalid input uuid!" unless self.instance.controls.keys.include?(input["uuid"])

        self.instance.controls[input["uuid"]][:value]
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

        puts "update index.html in .f_dot directory: (#{File.join(go_directory, "index.html")}, #{FDot::Based.f_dot_space_path})"
        FileUtils.cp(File.join(go_directory, "index.html"), FDot::Based.f_dot_space_path)

        return if File.exist?(self.class.path_for_file(:f_dot_go))

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
