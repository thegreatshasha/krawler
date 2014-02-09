class Unique
	def self.hashes(config)
		#binding.pry
		hashes = config[:hashes]
		uniquefields = config[:unique]

		hashes.uniq! {|e| uniquefields.map {|field| e[field]}}
		hashes
	end
end