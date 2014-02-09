require_relative 'loader.rb'

class YelpSync
	attr_accessor :config, :analytics, :hydra, :reader, :debug, :linkr, :finished_queue, :initial_queue
	attr_accessor :zip_writer, :moverdatawriter

	def initialize(config)
		@config = {
			:host => "city-data.com", 
			:debug_level => config[:debug_level],
			:cookie => {file: "cookie.txt"},
			:strategy => {type: "parallel", delaymin: 0, delaymax: 2},#linear or parallel
		}

		@debug = DebugHelper.new(config[:debug_level])

		@analytics = {}

		@linkr = Reader.new({filename: "zipcodes.txt", debug_level: 1})
		#@zip_writer = Writer.new({filename: "zipcodes.txt", mode: "a+", debug_level: 1})
		#@bizlinkw = Writer.new({filename: "moverlinks4.txt", mode: "a+", debug_level: 1})

		@moverdatawriter = Writer.new({filename: "moverdataamsa2.csv", mode: "a+", debug_level: 1})

		@hydra = Typhoeus::Hydra.new(max_concurrency: 40)

		@finished_queue = []
		@initial_queue = []

		@state_link_map = {}
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
		Typhoeus::Request.new( url, 
			followlocation: true, 
			headers: {"User-Agent" => BrowserHeader.random}, 
			cookiefile: config[:cookie][:file],
			cookiejar: config[:cookie][:file]
		)
	end

	def get_params(url, property = nil)
		params = {}
		
		CGI.parse(URI.parse(url).query()).map {|key, value| params[key.to_sym] = value[0] }

		return params[property] if property
		return params
	end

	# Read links from input file to parse
	def read_links()
		links = linkr.read_array()
		###binding.pry
		@initial_queue = links
		###binding.pry
		links

	end

	# Add a single request to the queue
	def queue(link)
		####binding.pry
		req = request(link)
		######binding.pry
		req.on_complete {|res|  
			######binding.pry
			handle_response(req, res)
		}
		#####binding.pry
		hydra.queue(req)
		####binding.pry
	end

	# Add multiple links to the queue
	def queue_links(links)
		links.each do |link|
			queue(link)
		end
	end

	# Get the current queued links as array
	def get_queued_links()
		hydra.queued_requests.map do |req|
			req.url
		end
	end

	def get_unfinished_links()
		initial_queue - finished_queue
	end

	# After we get a successfull response, we select what to do
	def match_response(req, res)
		# Instead of callbacks, i can have a url pattern check here to determine appropriate respose
		url = req.url
		html = res.body
		#binding.pry

		#Match conditions here
		if url.match(/amsa-promover-results\.asp/)
			#binding.pry
			movers = parse(html, get_params(url, :ProMoverZip))

			moverdatawriter.write_hashes(movers)

			#bizlinkw.write_array(mlinks)
			#zip_writer.write_array(ziplinks)
			# Queue the business links
			#Uncomment after replacing these links by webcache links
			##binding.pry
			#queue_links(ziplinks)
		end
		#Possible actions are pagination_links, parse_links
				
	end

	# Abort program by writing down all the pending links to the file
	def write_pending_links(links = nil)
		debug.print(3, "Saving links to file", File.basename(__FILE__), __LINE__)
		
		#moverdatawriter.write_marshal_dump( fail_queue)
		pending_links = links || get_unfinished_links()
		###binding.pry
		linkw.write_array(pending_links)

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
			#######binding.pry

			debug.print(1, "\n Popped", req.url, "length is",  hydra.queued_requests.length, File.basename(__FILE__), __LINE__) 
				#puts req,  hydra.queued_requests.length
				
				delay_request

				debug.print(1, "\nProcessing, ", req.url, File.basename(__FILE__), __LINE__)
				req.run
			end
		end

	def run_parallel_strategy
		debug.print(3, "Running parallel strategy", File.basename(__FILE__), __LINE__)
		######binding.pry
		hydra.run
	end

	def handle_response(req, res)
		####binding.pry
		if res.success?
			###binding.pry
		    # hell yeah
		    debug.print(3, "Success", req.url)
		    match_response(req, res)

		    finished_queue << req.url

  		# The error case
		else
			######binding.pry
			if res.timed_out?
			    # aw hell no
			    debug.print(3, "got a time out", File.basename(__FILE__), __LINE__)
			elsif res.code == 0
			    # Could not get an http response, something's wrong.
			    debug.print(3, "response.return_message", File.basename(__FILE__), __LINE__)
			else
			    # Received a non-successful http response.
			    debug.print(3, "HTTP request failed: " + res.code.to_s, File.basename(__FILE__), __LINE__)
			    debug.print(2,"Reamining: ", hydra.queued_requests.length,  File.basename(__FILE__), __LINE__)

			    if res.code.to_s.eql? "403"
			    	
			    	debug.print(4, "Exiting because of 403", File.basename(__FILE__), __LINE__)
			    	
					write_pending_links()
			    	#exit
			    	abort
			    end
			end

		end
	end

	
	def parse(html, zipcode)
		doc = dom(html)
		debug.print(2, "Parsing mover profile data", File.basename(__FILE__), __LINE__)
		#binding.pry
		movers = []

		doc.css("div.AMSACompanyList").each do |minidoc|
			moverdata = {}

			minidoc.css("br").each { |node| node.replace("\n") }

			moverdata[:name] = minidoc.css("div.AMSACompanySect strong").text
			text = minidoc.css("div.AMSACompanySect").text.sub(moverdata[:name], "")

			total, moverdata[:address], moverdata[:phone], moverdata[:mcno] = *text.match(/\n?([\s\S]*)\n(\(\d+\)\s+\d+\-\d+)?\n(MC No.\s+\d+)?/)
			moverdata[:distance] = minidoc.css("div.SearchRadius").text.strip
			moverdata[:zipcode] = zipcode

			movers << moverdata

			#binding.pry
		end

		return movers
	end

	def dom(html)
		doc = Nokogiri::HTML(html)
		debug.print(4, hydra.queued_requests.length, "Requests Remaining\n")
		return doc
	end

	def parse_links(html)
		doc = dom(html)
		
		debug.print(1, "Parsing moverlinks from html", File.basename(__FILE__), __LINE__)
		
		ziplinks = doc.css(".zipList a")

		links = []
		
		ziplinks.each do |link|
			link = config[:host] + link['href']
			links << link
		end

		debug.print(2, links.length, "Pages found for", File.basename(__FILE__), __LINE__)
		#binding.pry
		links
	end

	def pagination_links(html, searchparams)
		doc = dom(html)
		links = []
		string = doc.css(".pagination-results-window").children.text
		
		unless string.empty?
			matches = string.match(/(\d+)-(\d+).+ (\d+)/)
			diff = matches[2].to_i - matches[1].to_i + 1
			total = matches[3].to_i
			number = total/diff + (1 if total % diff)
			##binding.pry

			number.times do |index|
				searchparams[:start] = index * diff
				##binding.pry
				link = URI::HTTP.build(:host => config[:host], :path => config[:search_path], :query => searchparams.to_query).to_s
				links << link
				#puts link if config[:debug]
				debug.print(3, "Pagination link: ", link, File.basename(__FILE__), __LINE__)
			end
		end
		##binding.pry

		links

	end

end

class Runner
	attr_accessor :syncer

	def initialize(config)
		@syncer = YelpSync.new({category: "movers", debug_level: 2})
		#Phase 1
		states = ["AK",  "AL",  "AR",  "AS",  "AZ",  "CA",  "CO",  "CT",  "DC",  "DE",  "FL",  "GA",  "GU",  "HI",  "IA",  "ID",  "IL",  "IN",  "KS",  "KY",  "LA",  "MA",  "MD",  "ME",  "MI",  "MN",  "MO",  "MP",  "MS",  "MT",  "NC",  "ND",  "NE",  "NH",  "NJ",  "NM",  "NV",  "NY",  "OH",  "OK",  "OR",  "PA",  "PR",  "RI",  "SC",  "SD",  "TN",  "TX",  "UM",  "UT",  "VA",  "VI",  "VT",  "WA",  "WI",  "WV",  "WY"]
		#states = ["CT", "IN", "HI"]#, "DA", "GC", "FL"]

		unless config[:cache]
			syncer.write_state_links(states)
		end
		links = syncer.read_links()
		syncer.queue_links(links)
		#puts "Fresh start"
		syncer.run

		puts "Finished running"
		#syncer.exit
	end

end

r = Runner.new({cache: true})
