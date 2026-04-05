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

    OptionParser.new do |o|
  o.banner = "Usage: ruby processor_upd_to_mbr.rb [options] [apply]"
  o.on("--act-mode=MODE", %w[merge replace], "merge|replace pour ActSecs") { |v| OPTS[:act_mode] = v }
  o.on("--cdc=CDC", "Filtre CDC exact") { |v| OPTS[:cdc] = v }
  o.on('--act=ACTIVITE', 'Filtre Activité principale=ACT ou secondaires contient ACT') { |v| OPTS[:act] = v }
  o.on('--only=N1,N2', Array, 'Limiter aux Demandes listées') { |v| OPTS[:only] = v.map!(&:strip) }
  o.on('--limit=N', Integer, 'Traiter au plus N UPD') { |v| OPTS[:limit] = v }
  o.on('--since=YYYY-MM-DD', 'UPD créées depuis cette date (UTC)') { |v| OPTS[:since] = v }
end.parse!(ARGV)
###DRY = (ARGV.last != "apply")

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
    
###    exit     if DRY_RUN

    log.debug("⏩️->Select pages")
    mbr_pages.select! do |page|                         #select pages
        ok  = true
        ok &&= (stds.get_prop_value(page, 'Activité principale')=="Informatique")
        ok
    end
    log.info("⏭️->Membres:: Pages:#{mbr_pages.size} selected")

    log.warn("⏹️->Program #{$0} is done")
    