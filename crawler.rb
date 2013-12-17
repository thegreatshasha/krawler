reload!

class YelpSync
	attr_accessor :config, :analytics, :hydra, :moverlinks, :moverlinkdata

	def initialize
		@config = {
			:host => "www.yelp.com", 
			:search_path => "/search",
			:debug => true
		}
		@analytics = {}
		@moverlinks = []
		@moverlinkdata = []
		@hydra = Typhoeus::Hydra.new(max_concurrency: 20)
	end

	def queue(request, &block)
		request.on_complete {|response| self.handle_response(response, &block)}
		self.hydra.queue(request)
	end

	def run
		puts "Hydra Sync Running"
		self.hydra.run
		puts "Hydra Sync Finished running"
	end

	def handle_response(response, &block)
		if response.success?
	    # hell yeah
	    self.parse_page(response, &block)
	  elsif response.timed_out?
	    # aw hell no
	    puts "got a time out"
	  elsif response.code == 0
	    # Could not get an http response, something's wrong.
	    puts "response.return_message"
	  else
	    # Received a non-successful http response.
	    puts "HTTP request failed: " + response.code.to_s
		end
	end
	
	def generate_links_by_states(states)
		states.each do |state|
			searchparams = {find_desc: "movers", find_loc: state.code}
			search_string = URI::HTTP.build(:host => config[:host], :path => config[:search_path], :query => searchparams.to_query).to_s
			
			puts "Searching", search_string if self.config[:debug]
			request = Typhoeus::Request.new(search_string, followlocation: true)
			
			puts "Parsing state", state if self.config[:debug]

			self.queue(request) { |doc|
				pagination_links = self.generate_pagination_links(doc, searchparams)
				
				self.parse_moverlinks(doc)
				#pagination_links = pagination_links[0..1]
				pagination_links.each do |link|
					
					# write them down in the redid queue
					newreq = Typhoeus::Request.new(link, followlocation: true)

					self.queue(newreq) { |bizdoc|
						
						self.parse_moverlinks(bizdoc)
						#puts biz_links
					}
				end
			}
		end
	end

	def generate_mover_data
		self.moverlinks.each do |mover_profile_link|
			request = Typhoeus::Request.new(mover_profile_link, followlocation: true)
			self.queue(request) { |doc|
				moverdata = self.parse_mover_profile(doc)
				self.moverlinkdata << moverdata
			}
		end
	end

	def parse_mover_profile(doc)
		moverdata = {
			name: doc.css("h1").text,
			address: doc.css("address").text,
			phone: doc.css("[itemprop='telephone']").text,
			numberofreviews: doc.css("[itemprop='reviewCount']").text,
			homepage: doc.css("#bizUrl a").text,
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

	def parse_page(response, &block)
		html = response.body
		doc = Nokogiri::HTML(html)
		puts self.hydra.queued_requests.length, "Requests Remaining\n" if self.config[:debug]
		yield doc
	end

	def parse_moverlinks(doc)
		biz_links = doc.css("a.biz-name[href^='/biz']")
		
		biz_links.each do |biz|
			puts "Link is", biz['href'], "\n" if self.config[:debug]
			self.moverlinks << self.config[:host] + biz['href']
		end
	end

	def generate_pagination_links(doc, searchparams)
		string = doc.css(".pagination-results-window").children.text
		matches = string.match(/(\d+)-(\d+).+ (\d+)/)
		diff = matches[2].to_i - matches[1].to_i + 1
		total = matches[3].to_i
		number = total/diff
		links = []
		
		number.times do |index|
			searchparams[:start] = (index + 1) * diff
			link = URI::HTTP.build(:host => config[:host], :path => config[:search_path], :query => searchparams.to_query).to_s
			links << link
			puts link if config[:debug]
		end

		links

	end

	def add_mover_link
	end

end

class HashWriter
	attr_accessor :file
	
	def initialize(file = "data.csv")
		@file = file
	end

	def write(hashes)
		column_names = hashes.first.keys

		s=CSV.generate do |csv|
		  csv << column_names
		  hashes.each do |x|
		    csv << x.values
		  end
		end

		File.write(self.file, s)
	end
end

syncer = YelpSync.new
states = State.all[2..2]
syncer.generate_links_by_states(states)
syncer.run
syncer.generate_mover_data
syncer.run

hw = HashWriter.new
hw.write(syncer.moverlinkdata)

