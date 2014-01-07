require_relative 'loader.rb'

class YelpSync
	attr_accessor :config, :analytics, :hydra, :moverdatawriter, :reader, :debug, :linkr, :linkw

	def initialize(config)
		@config = {
			:host => "yelp.com", 
			:search_path => "/search", 			
			:debug_level => config[:debug_level],
			:cookie => {file: "cookie.txt"},
			:category => config[:category],
			:headers=> {"User-Agent" => "Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.10) Gecko/20100915 Ubuntu/10.04 (lucid) Firefox/3.6.10"},
			:strategy => {type: "parallel", delaymin: 10, delaymax: 20},#linear or parallel
		}

		@debug = DebugHelper.new(config[:debug_level])

		@analytics = {}

		@linkr = Reader.new({filename: "links.txt", debug_level: 1})
		@linkw = Writer.new({filename: "links.txt", mode: "w", debug_level: 1})

		@moverdatawriter = Writer.new({filename: "moverdata.csv", mode: "a+"})

		@hydra = Typhoeus::Hydra.new(max_concurrency: 30)
	end

	# In case the website does not allow concurrent requests
	def delay_request
		if config[:strategy][:type] == "linear"
			delay = Random.rand( config[:strategy][:delaymin] .. config[:strategy][:delaymax]).to_f
			
			debug.print(3, "Delaying", delay, " before adding another request in queue", File.basename(__FILE__), __LINE__)
			
			sleep(delay)
		end
	end

	# Generate a typhoeus request with the required options
	def request(url)
		Typhoeus::Request.new(url, followlocation: true, headers: config[:headers], cookiefile: config[:cookie][:file], cookiejar: config[:cookie][:file])
	end

	# Read links from input file to parse
	def read_links()
		links = linkr.read_array()
	end

	# Add a single request to the queue
	def queue(request)
		#binding.pry
		request.on_complete {|response|  handle_response(request, response)}
		
		hydra.queue(request)
	end

	# Add multiple links to the queue
	def queue_links(links)
		links.each do |link|
			req = request(link)

			hydra.queue(req)
		end
	end

	# Get the current queued links as array
	def get_queued_links()
		hydra.queued_requests.map do |req|
			req.url
		end
	end

	def write_queued_links()
		links = get_queued_links()
	end

	# After we get a successfull response, we select what to do
	def match_response(request, response)
		# Instead of callbacks, i can have a url pattern check here to determine appropriate respose
		url = request.url
		html = response.body

		if url.match(/\/search/)
			# Pagination link found, fetch and grab links
			if url.match(/\&start\=/)
				
				mlinks = parse_moverlinks(html)

				# Queue the business links
				queue_links(mlinks)
			
			#First time hitting search
			else
				searchparams = {}
				CGI.parse(URI.parse(url).query()).map {|key, value| searchparams[key.to_sym] = value[0] }
					
				plinks =  pagination_links(html, searchparams)
					
				queue_links(plinks)
			end
		
		# If business link found
		elsif url.match(/\/biz/)
			
			data = parse_mover_profile(html)
			data[:link] = mover_profile_link

			# Save the moverdata to file
			moverdatawriter.write_hash(data)
		end

		#Possible actions are pagination_links, parse_moverlinks
				
	end

	# Abort program by writing down all the pending links to the file
	def exit
		debug.print(3, "Saving data to file", File.basename(__FILE__), __LINE__)
		
		#moverdatawriter.write_marshal_dump( fail_queue)
		pending_links = get_queued_links()
		linkw.write_array(pending_links)

		abort
	end

	# Choose between linear or parallel strategies
	def run
		debug.print(4, "Hydra Sync Running", File.basename(__FILE__), __LINE__)
		
		debug.print(3, "strategy is",  config[:strategy][:type], File.basename(__FILE__), __LINE__)
		debug.print(4, config[:strategy][:type].eql?("linear"), File.basename(__FILE__), __LINE__)

		puts Benchmark.measure {
			if config[:strategy][:type].eql?"linear"
				run_linear_strategy
			else
				run_parallel_strategy
			end

		}
		
		debug.print(4, "Hydra Sync Finished running", File.basename(__FILE__), __LINE__)
	end

	# Put a random delay between requests
	def run_linear_strategy
		debug.print(3, "Running linear strategy", File.basename(__FILE__), __LINE__)
		
		while  hydra.queued_requests.length > 0
			debug.print(1, "Inside requests", File.basename(__FILE__), __LINE__)

			req =  hydra.queued_requests.pop
			#binding.pry

			debug.print(1, "\n Popped", req.url, "length is",  hydra.queued_requests.length, File.basename(__FILE__), __LINE__) 
				#puts req,  hydra.queued_requests.length
				
				delay_request

				debug.print(1, "\nProcessing, ", req.url, File.basename(__FILE__), __LINE__)
				req.run
			end
		end

		def run_parallel_strategy
			debug.print(3, "Running parallel strategy", File.basename(__FILE__), __LINE__)
			#binding.pry
			hydra.run
		end

		def handle_response(request, response)
			if response.success?
			    # hell yeah
			    match_response(request, response)

	  		# The error case
			else
				binding.pry
				if response.timed_out?
				    # aw hell no
				    debug.print(3, "got a time out", File.basename(__FILE__), __LINE__)
				  elsif response.code == 0
				    # Could not get an http response, something's wrong.
				    debug.print(3, "response.return_message", File.basename(__FILE__), __LINE__)
				  else
				    # Received a non-successful http response.
				    debug.print(3, "HTTP request failed: " + response.code.to_s, File.basename(__FILE__), __LINE__)
				    debug.print(2, hydra.queued_requests.length,  fail_queue.length, File.basename(__FILE__), __LINE__)

				    if response.code.to_s.eql? "403"
				    	
				    	#fail_queue.push(request).concat(hydra.queued_requests)
				    	
				    	debug.print(4, "Exiting because of 403", fail_queue.length, File.basename(__FILE__), __LINE__)
				    	
				    	#exit
				    end
				  end

		  fail_queue.push(request).concat( hydra.queued_requests)

		  debug.print(2, "Pushed into fail_queue", request.url, "length is",  fail_queue.length, File.basename(__FILE__), __LINE__)
		end
	end

	def write_state_links(states)
		links = states.map do |state|
			
			searchparams = {find_desc: config[:category], find_loc: state}
			search_string = URI::HTTP.build(:host => config[:host], :path => config[:search_path], :query => searchparams.to_query).to_s
			
			# Write to file
		end

		# Initial prepopulation
		linkw.write_array(links)
	end

=begin
	def mover_data
		moverlinks.each do |mover_profile_link|
			request =  request(mover_profile_link)
			
			queue(request) { |doc|
				data =  parse_mover_profile(doc)
				data[:link] = mover_profile_link
				moverdata << data
			}
		end
	end
=end


	def parse_mover_profile(html)
		doc = dom(html)
		debug.print(2, "Parsing mover profile data", File.basename(__FILE__), __LINE__)

		moverdata = {
			name: doc.css("h1").text.sub("\n", "").strip,
			phone: doc.css("[itemprop='telephone']").text,
			address: doc.css("address").text.sub("\n", "").strip,
			numofreviews: doc.css("[itemprop='reviewCount']").text,
			homepage: doc.css("#bizUrl a").text,
			address: doc.css("address").text.sub("\n", "").strip,
			acceptscreditcards: doc.css(".attr-BusinessAcceptsCreditCards").text,
			hours: doc.css(".hours").text,
		}
		
		begin
			moverdata[:rating] = doc.css("[itemprop='ratingValue']").attr("content").value
		rescue
			moverdata[:rating] = ""
		end

		return moverdata
	end

	def dom(html)
		doc = Nokogiri::HTML(html)
		puts  hydra.queued_requests.length, "Requests Remaining\n" if  config[:remaining]
		return doc
	end

	def parse_moverlinks(html)
		doc = dom(html)
		
		debug.print(2, "Parsing moverlinks from html", File.basename(__FILE__), __LINE__)
		
		biz_links = doc.css("a.biz-name[href^='/biz']")
		links = biz_links.map {|link|  config[:host] + link['href'] }

		moverlinkswriter.write_array(links)
		
		moverlinks.concat(links)
	end

	def pagination_links(html, searchparams)
		doc = dom(html)
		links = []
		string = doc.css(".pagination-results-window").children.text
		
		unless string.empty?
			matches = string.match(/(\d+)-(\d+).+ (\d+)/)
			diff = matches[2].to_i - matches[1].to_i + 1
			total = matches[3].to_i
			number = total/diff

			number.times do |index|
				searchparams[:start] = (index + 1) * diff
				link = URI::HTTP.build(:host => config[:host], :path => config[:search_path], :query => searchparams.to_query).to_s
				links << link
				#puts link if config[:debug]
				debug.print(1, "Pagination link: ", link, File.basename(__FILE__), __LINE__)
			end
		end

		links

	end

end

class Runner
	attr_accessor :syncer

	def initialize(config)
		@syncer = YelpSync.new({category: "movers", debug_level: 1})
		#Phase 1
		states = ["AK",  "AL",  "AR",  "AS",  "AZ",  "CA",  "CO",  "CT",  "DC",  "DE",  "FL",  "GA",  "GU",  "HI",  "IA",  "ID",  "IL",  "IN",  "KS",  "KY",  "LA",  "MA",  "MD",  "ME",  "MI",  "MN",  "MO",  "MP",  "MS",  "MT",  "NC",  "ND",  "NE",  "NH",  "NJ",  "NM",  "NV",  "NY",  "OH",  "OK",  "OR",  "PA",  "PR",  "RI",  "SC",  "SD",  "TN",  "TX",  "UM",  "UT",  "VA",  "VI",  "VT",  "WA",  "WI",  "WV",  "WY"]

		unless config[:cache]
			syncer.write_state_links(states)
		end
		links = syncer.read_links()
		syncer.queue_links(links)
		
		#puts "Fresh start"
		syncer.run

		puts "Finished running"
		syncer.exit
	end

end

r = Runner.new({cache: false})
