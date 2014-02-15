require_relative "crawler.rb"

#Runs the yelpsync in batches as queing them all at the same time will be a pain
class Runner
	attr_accessor :syncer, :current, :links

	def initialize(config)
		@syncer = YelpSync.new({category: config[:category], debug_level: config[:debug_level]})
		#syncer.exit

		# The gigantic array of all the links. Later read these step by step as well.
		@links = syncer.read_links()
		@links = @links[0..5000]

		@current = 0

		@batch_size = config[:batch_size]
	end

	def run_in_batches

		while @current < @links.length
			puts "Starting batch #{@current}"

			syncer.queue_links(@links[@current..@current + @batch_size - 1])
			#puts "Fresh start"
			syncer.run
			#binding.pry

			puts "Finished running batch #{@current}"
			
			@current += @batch_size

			GC.start
		end
	
	end

end

stats = AllocationStats.trace do
	r = Runner.new({category: "movers", debug_level: 2, batch_size: 20})
	r.run_in_batches
end

text = stats.allocations(alias_paths: true).group_by(:sourcefile, :class).to_text
File.write("logs/allocationstats/#{Time.now}.log", text)
#binding.pry
