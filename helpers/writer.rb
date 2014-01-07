require_relative 'debug.rb'

class Writer
	attr_accessor :file, :filename, :mode, :debug
	
	def initialize(config)
		@filename = config[:filename]
		@mode = config[:mode]
		@debug = DebugHelper.new(config[:debug_level])
	end

	def open
		debug.print(3, "Opening file for writing", filename, File.basename(__FILE__), __LINE__)
		self.file = File.open( filename, mode)
		self.file.sync = true
	end

	def write_array(array)
		open
		s = CSV.generate do |csv|
			array.each do |item|
				csv << [item]
			end
		end
		
		file.write(s)
	end

	def write_marshal_dump(array)
		open
		file.write(Marshal.dump(array))
	end

	def write_hash(hash)
		open
		s = CSV.generate do |csv|
			csv << hash.values
		end
		file.write(s)
	end

	def write_hashes(hashes)
		open
		#column_names = hashes.first.keys

		s = CSV.generate do |csv|
		  		#csv << column_names
		  		hashes.each do |x|
		  			csv << x.values
		  		end
		  	end

		  	file.write(s)
	end
end