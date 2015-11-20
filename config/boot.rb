# set encoding to UTF-8
Encoding.default_external = Encoding::UTF_8

require 'dotenv'
Dotenv.load

require 'excon'
require 'json'
require 'pry'
require './lib/shopify'

