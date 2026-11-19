# frozen_string_literal: true

#
# deserialization_testing.rb
#
# f_dot deserialization_testing.
#
# right now this is a simple example of utilizing the
#   FDot::Based::Processor.instance.write_state_callback
#
# within an oss_om plugin.
#
# by i2097i

require "f_dot"

load_from_file_name = "f_dot_local_storage.json"

serialized_data = {}

# load from existing data
if File.exist?(load_from_file_name)
  serialized_data = JSON.parse File.read(load_from_file_name)
end

FDot::Based::Processor.instance.write_state_callback = Proc.new{|incoming_data|
  puts "received #{incoming_data.to_s.length} ascii on callback stream"
  serialized_data = incoming_data.dup
  File.open(load_from_file_name, "w+") do |file|
    file.write(serialized_data.to_json)
  end
}

if File.exist?(load_from_file_name)
  FDot::Based::Processor.initialize_with_data(serialized_data)
else
  # create the file
  File.open(load_from_file_name, "w+") do |file|
    file.write(serialized_data.to_json)
  end
  FDot::Based::Processor.instance.run
end

