class DebugHelper
	attr_accessor :debug_level

	def initialize(debug_level)
		@debug_level = debug_level
	end

	def print(level, *stringargs)
		if level >= debug_level
			puts stringargs.to_a.join(", ")
			puts "\n"
		end
	end
end