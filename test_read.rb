require 'fileutils'

file_path = File.expand_path('.flutter-plugins-dependencies', __dir__)

puts "Attempting to read file: #{file_path}"

begin
  content = File.read(file_path)
  puts "Successfully read file. First 100 characters:"
  puts content[0..99] # Print first 100 characters
  puts "File length: #{content.length} bytes"
rescue Errno::ENOENT => e
  puts "ERROR: File not found or accessible. #{e.message}"
rescue => e
  puts "AN UNEXPECTED ERROR OCCURRED: #{e.class} - #{e.message}"
end
