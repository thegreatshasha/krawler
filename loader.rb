# Require the necessary gems
require 'rubygems'
require 'bundler/setup'
require 'typhoeus'
require 'nokogiri'
require 'csv'
require 'benchmark'
require 'cgi'
#require 'allocation_stats'
require 'pry'

# Require necessary files and helpers
require_relative 'helpers/debug.rb'
require_relative 'helpers/reader.rb'
require_relative 'helpers/writer.rb'
require_relative 'helpers/browserheader.rb'
require_relative 'helpers/unique.rb'

# Require object extensions
require_relative 'overrides/hash.rb'
require_relative 'overrides/object.rb'
#require_relative 'overrides/typhoeus.rb'
