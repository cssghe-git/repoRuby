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
    spec    = {                                         #specific values
        debug: 'DEBUG',
        dryrun: false
    }                         

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = :INFO
    log.datetime_format = '%H:%M:%S'

# Main code
    # New instance
    log.info("🛂->Program #{$0} is starting...")
    log.debug("▶️->Initialisations")
    log.debug("⏩️->Create a new instance of class <Standards>")
    stds    = Standards.new([])                         #new instance

    # Specific options
    log.debug("⏩️->Set specfic options")
    stds.loadOpts(spec)                                 #add spec values
    opts    = stds.opts                                 #get opts values
    ### pp opts
    DRY_RUN = opts[:dryrun]
    log.level   = opts[:debug] || :INFO
    log.info("🔧 Prog: #{$0} Level: #{opts[:debug]} Mode: #{DRY_RUN ? 'DRY-RUN (simulation)' : 'PRODUCTION'}")

    # Processing
    log.debug("▶️->Main code in progress...")
    log.debug("⏩️->Load DB <m25t.Membres>")
    mbr_dbid    = stds.getDbId('m25t.Membres')
    log.debug("⏭️->MBR_DBID:#{mbr_dbid}")

    mbr_pages   = stds.db_fetch(mbr_dbid)               #get all pages
    log.info("⏭️->Membres:: Pages:#{mbr_pages.size} loaded")
    
#    exit     if DRY_RUN

    log.debug("⏩️->Select pages")
    mbr_pages.select! do |page|                         #select pages
        ok  = true
        ok &&= (stds.get_prop_value(page, 'Activité principale')=="Informatique")
        ok
    end
    log.info("⏭️->Membres:: Pages:#{mbr_pages.size} selected")

    log.warn("⏹️->Program #{$0} is done")
    