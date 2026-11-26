# frozen_string_literal: true

=begin

  based.rb

  f_dot based.

  created by i2097i

=end

module FDot
  module Based
    PROMPT = TTY::Prompt.new
    FOLDER_NAME = ".f_dot"

    TYPES = [
      :dot_nulls,
      :dot_bools,
      :dot_ints,
      :dot_floats,
      :dot_strings,
      :dot_arrays,
      :dot_objects
    ]

    NUMBERS = [
      :zero,
      :one,
      :two,
      :three,
      :four,
      :five,
      :six,
      :seven,
      :eight,
      :nine,
      :ten
    ]

    def self.print_large_title!
      puts TTY::Font.new(:standard).write(
        :f_dot.to_s,
        letter_spacing: 1
      )
    end

    def self.generate_uuid
      SecureRandom.send(:uuid_v7)
    end

    def self.f_dot_space_path
      path = File.join(
        FDot::Based::Processor.instance.f_dot_space_override_path || ENV["HOME"],
        FDot::Based::FOLDER_NAME
      )
      unless Dir.exist?(path)
        FileUtils.mkdir_p(path)
      end

      return path
    end

    def self.ask(message)
      if FDot::Based::Interface.instance.display_mode == FDot::DISPLAY_MODES[:websockets]
        option = {
          type: :text,
          name: message,
          value: nil
        }
        FDot::Based::Cubicus.update_with([option]) {|new_value|
          puts new_value
          yield(new_value)
        }
      else
        yield(FDot::Based::PROMPT.ask(message))
      end
    end

    def self.less(message)
      if FDot::Based::Interface.instance.display_mode == FDot::DISPLAY_MODES[:websockets] ||
        !FDot::Based::Processor.user_setting!(:debug_inspectors_enabled)
        message.split("\n").each{|l|
          puts l
        }
      else
        IO.popen("less -X", "w") { |f| f.puts(message) }
      end
    end

    def self.tty_prompt_select(
      display_text = "select something: ",
      options = []
    )
      if FDot::Based::Interface.instance.display_mode == FDot::DISPLAY_MODES[:websockets]
        puts display_text
        FDot::Based::Cubicus.update_with(options) {|selected_option|
          puts selected_option
          yield(selected_option)
        }
      else
        if options.nil? || options.empty?
          puts "there is nothing here"
          return
        end
        yield(
          FDot::Based::PROMPT.select(
           display_text,
           options,
           show_help: :always,
           cycle: true,
           per_page: 11
         )
        )
      end
    end

  end
end
