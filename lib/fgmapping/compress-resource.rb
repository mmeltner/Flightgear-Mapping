#!/usr/bin/ruby

require "Qt"
require 'ftools'
require 'zlib'
require "resources.rb"

FN_RESOURCE_BACKUP = "resources-orig.rb"
FN_MARSHAL = "resources.marshal"
DECOMPRESS_CODE = <<EOS
# load marshalled resource data
require 'zlib'
FN_MARSHAL = \"#{FN_MARSHAL}\"
Zlib::GzipReader.open(FN_MARSHAL) {|gz|
	@@qt_resource_data = Marshal.restore(gz.read)
}
EOS

puts "Compressing Resources File"
data = QCleanupResources__dest_class__.qt_resource_data

puts "Initial Filesize: #{File.size("resources.rb")}"
File.copy("resources.rb", FN_RESOURCE_BACKUP)

skip = false
File.open(FN_RESOURCE_BACKUP, "r") do |fin|
	File.open("resources.rb", "w") do |fout|
		while l=fin.gets do
			if l =~ /@@qt_resource_data = / then
				skip = true
				fout.puts(DECOMPRESS_CODE)
			end
			if !skip then
				fout.puts(l)
			end
			if skip and l =~ /\]/ then
				skip = false
			end
		end
	end
end


Zlib::GzipWriter.open(FN_MARSHAL) do |gz|
	gz.write(Marshal.dump(data))
end
puts "Compressed Filesize: #{File.size(FN_MARSHAL)}"
puts "Compression finished."

