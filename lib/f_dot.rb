# frozen_string_literal: true

=begin

  f_dot.rb

  f_dot.

  created by i2097i

=end

require "json"
require "securerandom"
require "fileutils"
require "tty-prompt"
require "tty-font"

[:f_dot].each{|d|
  Dir[
    File.join(__dir__, d.to_s, :"**/**/*.rb".to_s)
  ].each { |f| require f }
}

module FDot
  DOMAINS = {
    processor: 0,
    programmer: 1,
    user: 2
  }

  def self.state
    Thread.main[:f_dot_state] ||= {}
  end
end
