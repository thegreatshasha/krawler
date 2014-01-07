class Hash
	def to_query(namespace = nil)
		collect do |key, value|
			value.to_query(namespace ? "#{namespace}[#{key}]" : key)
		end.sort * '&'
	end
end