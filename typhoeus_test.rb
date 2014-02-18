require 'typhoeus'
require 'allocation_stats'
require 'pry'
 
num_requests = 20
requests_per_iteration = 50
 
stats = AllocationStats.trace do
	num_requests.times do
		hydra = Typhoeus::Hydra.new
		
		requests_per_iteration.times do |i|
			hydra.queue(Typhoeus::Request.new("https://www.google.com?q=foo-#{i}"))
		end

		hydra.run
	
	end
	
	# not necessary to reproduce, just to show that this not just
	# uncollected memory
	GC.start
end

puts "Generating text"
#binding.pry
text = stats.allocations(alias_paths: true).group_by(:sourcefile, :sourceline, :class).sort_by_count.to_text
File.write("logs/typhoeus/#{Time.now}.log", text)
#binding.pry
