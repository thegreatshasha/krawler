require 'typhoeus'
require 'rss'
require 'nokogiri'
require_relative 'debug.rb'

class Proxyhelper
	@@rss_feed = "http://www.xroxy.com/proxyrss.xml"
	@@debug = DebugHelper.new(1)

	def self.run
		req = Typhoeus::Request.new(@@rss_feed)

		req.on_complete {|res|
			self.handle_response(req, res)
		}

		req.run
	end

	def self.handle_response(req, res)
		###binding.pry
		if res.success?
			##binding.pry
		    # hell yeah
		    @@debug.print(3, "Success", req.url)
		    
		    proxies = self.parse_rss(res.body)

		    self.test_proxies(proxies)

  		# The error case
		else
			#####binding.pry
			if res.timed_out?
			    # aw hell no
			    @@debug.print(3, "got a time out", File.basename(__FILE__), __LINE__)
			elsif res.code == 0
			    # Could not get an http response, something's wrong.
			    @@debug.print(3, "response.return_message", File.basename(__FILE__), __LINE__)
			else
			    # Received a non-successful http response.
			    @@debug.print(3, "HTTP request failed: " + res.code.to_s, File.basename(__FILE__), __LINE__)
			    @@debug.print(2,"Reamining: ", hydra.queued_requests.length,  File.basename(__FILE__), __LINE__)

			end

		end
	end

	def self.parse_rss(rsstext)
		xml = Nokogiri::XML.parse(rsstext)
		
		proxies = xml.xpath('//channel//item//prx:proxy')

		proxy_hashes =	proxies.map do |proxy|
							proxy = {
								port: proxy.xpath('prx:port').inner_text,
								ip: proxy.xpath('prx:ip').inner_text,
								type: proxy.xpath('prx:type').inner_text,
								latency: proxy.xpath('prx:latency').inner_text.to_i
							}

						end

		proxy_hashes.sort_by {|proxy| proxy[:latency]}
	end

	def self.test_proxies(proxies)
		proxies.each do |proxy|
			case proxy[:type]

			when "Socks5"
				proxystring = "socks5://#{proxy[:ip]}:#{proxy[:port]}"
			when "Socks4"
				proxystring = "socks4://#{proxy[:ip]}:#{proxy[:port]}"
			when "Transparent", "Distorting", "Anonymous"
				proxystring = "http://#{proxy[:ip]}:#{proxy[:port]}"
			end

			puts "Testing #{proxystring}"

			req = Typhoeus::Request.new("google.com", :proxy => proxystring)

			req.on_success do |res|
				puts "Success with proxy #{proxystring}"
			end
		end
	end
end

Proxyhelper.run