require 'typhoeus'
require 'allocation_stats'
require 'pry'

Typhoeus::Config.memoize = false
 
num_requests = 500
 
stats = AllocationStats.trace do
	
		hydra = Typhoeus::Hydra.new
	
		num_requests.times do |i|
			hydra.queue(Typhoeus::Request.new("https://www.google.com?q=foo-#{i}"))
		end

		hydra.run
	
	
	# not necessary to reproduce, just to show that this not just
	# uncollected memory
	#GC.start
end

puts "Generating text"
#binding.pry
text = stats.allocations(alias_paths: true).group_by(:sourcefile, :sourceline, :class, :memsize).sort_by_count.to_text
File.write("logs/typhoeus/#{Time.now}.log", text)
#binding.pry
