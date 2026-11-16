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

    def self.generate_uuid
      SecureRandom.send(:uuid_v7)
    end

    def self.user_space_path
      path = File.join(ENV["HOME"], FDot::Based::FOLDER_NAME)
      unless Dir.exist?(path)
        puts "FileUtils.mkdir_p(#{path})"
        FileUtils.mkdir_p(path)
      end

      return path
    end

    def self.tty_prompt_select(
      display_text = "select something: ",
      options = [{name: :some, value: :thing}]
    )
      FDot::Based::PROMPT.select(
        display_text,
        options,
        show_help: :always,
        cycle: true,
        per_page: 11
      )
    end

  end
end
