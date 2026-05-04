# frozen_string_literal: true

# Tests pdf contents

require 'pp'
require 'logger'
require 'awesome_print'
require 'pry'

require_relative 'Mod_Dissect_Pdf'
inside Dissect_Pdf

# Code
debug = false
bind = false
case    ARGV[0]
when    'debug'
    debug = true
when    'bind'
    bind = true
when    'both'
    debug = true
    bind = true
end

fullpath = '/users/Gilbert/Public/Private/Works/Achats_de_Medicaments.pdf'
ipdf = Dissect.new(file: fullpath)
puts 'PAGES:'
ipdf.arr_pages.each_with_index do |page, index|
    ap "PAGE: #{index}-#{page}", plain: false
end

meta_data = ipdf.get_metadata
binding.pry if bind
puts 'METADATA:'
ap meta_data, color: { variable: :blue, string: :yellowish }

category = ipdf.get_category
puts 'CATEGORY:'
ap category, color: { variable: :cyanish }

puts 'End of script'
