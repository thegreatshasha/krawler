require 'rubygems'
require 'bundler/setup'
require 'typhoeus'
require 'nokogiri'
require 'csv'
require 'benchmark'

class Object
	def to_query(key)
    require 'cgi' unless defined?(CGI) && defined?(CGI::escape)
    "#{CGI.escape(key.to_param)}=#{CGI.escape(to_param.to_s)}"
  end

	def to_param
    to_s
  end
end

class Hash
	def to_query(namespace = nil)
		collect do |key, value|
			value.to_query(namespace ? "#{namespace}[#{key}]" : key)
		end.sort * '&'
  end
end

class YelpSync
	attr_accessor :config, :analytics, :hydra, :moverlinks, :moverlinkdata

	def initialize(category = "movers", debug = false)
		@config = {
			:host => "www.yelp.com", 
			:search_path => "/search", 			
			:debug => false,
			:remaining => true,
			:category =>category
		}
		@analytics = {}
		@moverlinks = []
		@moverlinkdata = []
		@hydra = Typhoeus::Hydra.new(max_concurrency: 50)
	end

	def queue(request, &block)
		request.on_complete {|response| self.handle_response(response, &block)}
		self.hydra.queue(request)
	end

	def run
		puts "Hydra Sync Running"

		puts Benchmark.measure { self.hydra.run }
		
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
			searchparams = {find_desc: config[:category], find_loc: state}
			search_string = URI::HTTP.build(:host => config[:host], :path => config[:search_path], :query => searchparams.to_query).to_s
			
			puts "Searching", search_string if self.config[:debug]
			request = Typhoeus::Request.new(search_string, followlocation: true)
			
			puts "Parsing state", state if self.config[:debug]

			self.queue(request) { |doc|
				pagination_links = self.generate_pagination_links(doc, searchparams)
				
				self.parse_moverlinks(doc)
				#pagination_links = pagination_links[0..1]
				pagination_links.each do |link|
					
					# write them down in the queue
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

	def parse_page(response, &block)
		html = response.body
		doc = Nokogiri::HTML(html)
		puts self.hydra.queued_requests.length, "Requests Remaining\n" if self.config[:remaining]
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
				puts link if config[:debug]
			end
		end

		links

	end

end

class HashWriter
	attr_accessor :file
	
	def initialize(file = "data.csv")
		@file = file
		@config = {
			debug: false
		}
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
states = ["AK",  "AL",  "AR",  "AS",  "AZ",  "CA",  "CO",  "CT",  "DC",  "DE",  "FL",  "GA",  "GU",  "HI",  "IA",  "ID",  "IL",  "IN",  "KS",  "KY",  "LA",  "MA",  "MD",  "ME",  "MI",  "MN",  "MO",  "MP",  "MS",  "MT",  "NC",  "ND",  "NE",  "NH",  "NJ",  "NM",  "NV",  "NY",  "OH",  "OK",  "OR",  "PA",  "PR",  "RI",  "SC",  "SD",  "TN",  "TX",  "UM",  "UT",  "VA",  "VI",  "VT",  "WA",  "WI",  "WV",  "WY"]
syncer.generate_links_by_states(states)
syncer.run
syncer.generate_mover_data
syncer.run

hw = HashWriter.new
hw.write(syncer.moverlinkdata)
