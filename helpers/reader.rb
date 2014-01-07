require_relative 'debug.rb'

class Reader
	attr_accessor :file, :filename, :mode, :debug

	def initialize(config)
		@filename = config[:filename]
		@mode = config[:mode] || "r"
		@debug = DebugHelper.new(config[:debug_level])
	end

	def open
		debug.print(3, "Opening file for reading: ", filename, File.basename(__FILE__), __LINE__)
		self.file = File.open( filename, mode)
	end

	def read_array
		open
		lines = file.readlines
		data =  lines.map do |line|
			line.strip()
		end
		file.rewind
		data
	end

	def read_marshal_dump
		open
		text = file.read
		if not text.empty?
			data = Marshal.load(text)
		else
			data = []
		end
		file.rewind
		data
	end

	def read_hash
	end

	def read_hashes
	end
end