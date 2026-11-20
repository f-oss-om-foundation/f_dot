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
      attr_accessor :delegate
      attr_accessor :delegate_mutex
      attr_accessor :prompt

      FOLDER_NAME = ".cubicus"


      def initialize
        self.prompt = TTY::Prompt.new
        self.delegate_mutex = Mutex.new
      end

      class DefaultDelegate
        attr_accessor :direction
        attr_accessor :position

        DIRECTIONS = {
          north: 0,
          south: 1,
          east: 2,
          west: 3
        }

        def initialize
          self.direction = FDot::Based::Cubicus::DefaultDelegate::DIRECTIONS[:north]
          self.position = {
            x: 0,
            y: 0,
            z: 0
          }
          puts "this is the default cubicus display delegate."
        end

        def direction_name
          FDot::Based::Cubicus::DefaultDelegate::DIRECTIONS.select{|k, v| v == self.direction}.first[0]
        end
        def current_display
          (TTY::Font.new(:standard).write(
            :cubicus.to_s,
            letter_spacing: 1
          ).split("\n") + [
            "the user is facing #{direction_name}.",
            "the user's position is #{position}.",
          ]).join("\n")
        end
        def current_controls
          [
            {name: "(a):forward", value: :forward},
            {name: "(b):left", value: :left},
            {name: "(c):up", value: :up},
            {name: "(d):down", value: :down},
            {name: "(e):right", value: :right},
            {name: "(f):backward", value: :backward}
          ]
        end
        def respond_to_control(control_hash)

          raise "invalid control_hash!" if control_hash.nil? || !control_hash.kind_of?(Hash)

          respond_to_value = control_hash["value"].to_sym

          puts "user selected #{control_hash} control option"
          case respond_to_value
          when :forward
            self.move_forward!
          when :left
            self.rotate(respond_to_value)
          when :up
            self.position[:z] += 1
          when :down
            self.position[:z] -= 1
          when :right
            self.rotate(respond_to_value)
          when :backward
            self.move_backward!
          end
        end

        def move_forward!
          case self.direction
          when DIRECTIONS[:north]
            self.position[:x] += 1
          when DIRECTIONS[:south]
            self.position[:x] -= 1
          when DIRECTIONS[:east]
            self.position[:y] += 1
          when DIRECTIONS[:west]
            self.position[:y] -= 1
          end
        end

        def move_backward!
          case self.direction
          when DIRECTIONS[:north]
            self.position[:x] -= 1
          when DIRECTIONS[:south]
            self.position[:x] += 1
          when DIRECTIONS[:east]
            self.position[:y] -= 1
          when DIRECTIONS[:west]
            self.position[:y] += 1
          end
        end

        def rotate(rotation_key)
          raise "invalid rotate rotation_key!" unless [:left, :right].include?(rotation_key)

          case self.direction
          when DIRECTIONS[:north]
            self.direction = DIRECTIONS[rotation_key == :left ? :west : :east]
          when DIRECTIONS[:south]
            self.direction = DIRECTIONS[rotation_key == :left ? :east : :west]
          when DIRECTIONS[:east]
            self.direction = DIRECTIONS[rotation_key == :left ? :north : :south]
          when DIRECTIONS[:west]
            self.direction = DIRECTIONS[rotation_key == :left ? :south : :north]
          end
        end
      end

      def self.launch!(delegate = nil)
        delegate ||= FDot::Based::Cubicus::DefaultDelegate.new

        raise "invalid delegate!" unless !delegate.nil? &&
          delegate.respond_to?(:current_display) &&
          delegate.respond_to?(:current_controls) &&
          delegate.respond_to?(:respond_to_control)

        self.instance.delegate = delegate
        puts "launching new cubicus in #{cubicus_space_path}"

        cubicus_running = true
        while cubicus_running
          self.instance.render_cubicus!

          options = Dir[File.join(self.cubicus_space_path, "*")].select{|f|
            File.basename(f) != :display.to_s
          }.map{|f|
            {name: File.basename(f), value: f}
          } + [{name: :quit, value: :quit}]

          puts delegate.current_display
          selected_option = self.instance.prompt.select(
            "make a selection",
            options,
            show_help: :always,
            cycle: true
          )

          cubicus_running = selected_option != :quit
          break unless cubicus_running

          delegate.respond_to_control(JSON.parse(File.read(selected_option)))
        end
      end

      def render_cubicus!
        unless File.exist?(self.class.cubicus_display_path)
          File.open(self.class.cubicus_display_path, "w+") do |f|
            f.write(self.delegate.current_display)
          end
        end

        unless self.delegate.current_controls.empty?
          self.delegate.current_controls.each{|control|
            control_path = File.join(
              self.class.cubicus_space_path,
              control[:name].to_s
            )

            File.open(control_path, "w+") do |f|
              f.write(control.to_json)
            end
          }
        else
          # add keyboard movement
          self.prompt.on(:keypress){|event|
            return unless self.delegate.current_controls.empty?
            case event.value.to_sym
            when :w
              self.prompt.trigger(:keyup)
            when :a
              self.prompt.trigger(:keyleft)
            when :s
              self.prompt.trigger(:keydown)
            when :d
              self.prompt.trigger(:keyright)
            end
          }
          self.prompt.on(:keyup){|event|
            self.delegate.respond_to_control(event)
          }
          self.prompt.on(:keydown){|event|
            self.delegate.respond_to_control(event)
          }
          self.prompt.on(:keyleft){|event|
            self.delegate.respond_to_control(event)
          }
          self.prompt.on(:keyright){|event|
            self.delegate.respond_to_control(event)
          }
        end

      end

      def self.default_display
        File.read(self.cubicus_display_path)
      end

      def self.cubicus_display_path
        File.join(
          self.cubicus_space_path,
          :display.to_s
        )
      end

      def self.cubicus_space_path
        path = File.join(
          FDot::Based::Processor.instance.f_dot_space_override_path || ENV["HOME"],
          FDot::Based::Cubicus::FOLDER_NAME
        )
        unless Dir.exist?(path)
          FileUtils.mkdir_p(path)
        end

        return path
      end

    end
  end
end