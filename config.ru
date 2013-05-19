require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

require './main'
run Sinatra::Application