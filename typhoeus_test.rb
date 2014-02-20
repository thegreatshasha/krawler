require 'object_graph'
require 'typhoeus'
require 'pry'

Typhoeus::Config.memoize = false
 
num_requests = 1001
gc_enabled = true
req = nil
 
#stats = AllocationStats.trace do
	
		hydra = Typhoeus::Hydra.new
	
		num_requests.times do |i|
			req = Typhoeus::Request.new("http://localhost:9000")
			hydra.queue(req)
		end

		hydra.run
	
	
	# not necessary to reproduce, just to show that this not just
	# uncollected memory
	#GC.start
#end

curr = Hash.new(0)

ObjectSpace.each_object do |o|
	binding.pry
	curr[o.class] << o #Marshal.dump(o).size rescue 1
end


#GC.start if gc_enabled

puts "Generating data"
#binding.pry
#text = "Data for #{num_requests} requests at #{Time.now}. Garbage collection was #{gc_enabled} \n. "
#text += stats.allocations(alias_paths: false).group_by(:sourcefile, :sourceline, :class, :memsize).sort_by_count.to_text

#File.write("logs/typhoeus/#{Time.now}.log", text)
#binding.pry
binding.pry
#ObjectGraph.new(req).view!