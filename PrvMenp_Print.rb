# frozen_string_literal: true
#
=begin
    DOC     Function:   ?
    DOC     Call:       ruby ? --?
    DOC     Build:      260206-1000
    DOC     Version:    1.1.1
        Bugs:       ?

=end

require 'rubygems'
require "json"
require "httparty"
require "optparse"
require "logger"
require 'timeout'
require 'date'
require 'pp'
require 'csv'
require "unf"
#
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end
#
require_relative    'ClStandards.rb'

# Options
    options = {
        debug:      'DEBUG',
        request:    'Inventaire'
        dry_run:    false
    }

    OptionParser.new do |opts|
        opts.banner = "Usage: PrvMenp.Print.rb [options]"

        opts.on("-d","--debug", String, "Logger level") { |v| options[:debug] = v }     #choix de la valeur
        opts.on("-r","--request", String, "Print ?") { |v| options[:request] = v}       #choix de la valeur
        opts.on("--dry-run", "Simulation") { options[:dry_run] = true }                 #true id define
    end.parse!

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = :INFO
    log.datetime_format = '%H:%M:%S'

#********************
# Main code
#********************
    log.info("")