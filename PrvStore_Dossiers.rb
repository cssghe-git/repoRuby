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

# ==============================
# CLI options
# ==============================
# Options
    OPTS    = {                                         #specific options
        debug: 'DEBUG',
        dryrun: false
    }                         
    CONFIG  = JSON.parse(File.read(ENV.fetch("NOT_JSON_DBIDS")))

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = :INFO
    log.datetime_format = '%H:%M:%S'

# Variables
    arr_dbnames = [
        'BVL',
        'FIN',
        'INF',
        'OFF',
        'SAN'

    ]
    arr_dbids = {}

# ==============================
# MAIN code
# ==============================

    # New instance
    log.warn("🛂->Program #{$0} is starting...")
    log.debug("▶️->Initialisations")
    log.debug("⏩️->Create a new instance of class <Standards>")
    stds    = Standards.new([])                         #new instance

    log.info("🔧 Prog: #{$0} Level: #{opts[:debug]} Mode: PRODUCTION")

    log.debug("▶️->Main code in progress...")
    # Loop all DBs
    arr_dbnames.each do |dbname|
        arr_dbids[dbname] = CONFIG.find { |h| h.key?(dbname) }&.fetch(dbname)
    end

    # Loop all DBs
    arr_dbnames.each do |dbname|
        log.debug("⏩️->Load DB <#{dbname}>")
        db_id = arr_dbids[dbname]
    end



    log.warn("⏹️->Program #{$0} is done")
    