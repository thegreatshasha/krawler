require_relative "crawler.rb"

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
		unique_hashes = Unique.hashes({hashes: moverhashes, unique: [:name]})
		binding.pry

		puts "Finished running"
		#syncer.exit
	end

end

r = Runner.new({cache: true})