require_relative "crawler.rb"

#Runs the yelpsync in batches as queing them all at the same time will be a pain
class Runner
	attr_accessor :syncer, :current, :links

	def initialize(config)
		@syncer = YelpSync.new({category: config[:category], debug_level: config[:debug_level]})
		#syncer.exit

		# The gigantic array of all the links. Later read these step by step as well.
		@links = syncer.read_links()
		@links = @links

		@current = 0

		@batch_size = config[:batch_size]
	end

	def run_in_batches

		while @current < @links.length
			puts "Starting batch #{@current}. #{}"

			syncer.queue_links(@links[@current..@current + @batch_size - 1])
			#puts "Fresh start"
			syncer.run

			#GC.enable
			#GC.start

			binding.pry

			puts "Finished running batch #{@current}. #{@links.length - @current} requests remaining"
			
			@current += @batch_size

			#GC.start
		end
	
	end

end

#binding.pry
#stats = AllocationStats.trace do
	r = Runner.new({category: "movers", debug_level: 12, batch_size: 100})
	r.run_in_batches
#end

puts "\nDone\n"

#text = stats.allocations(alias_paths: true).group_by(:sourcefile, :sourceline, :class).sort_by_count.to_text
#File.write("logs/allocationstats/#{Time.now}.log", text)
#binding.pry
