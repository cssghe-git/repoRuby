# frozen_string_literal: true
#
=begin
    DOC     Function:   ?
    DOC     Call:       ruby ? --?
    DOC     Build:      260206-1000
    DOC     Version:    1.1.1
        Bugs:       ?
    DOC     -lecture ACT 
            -lecture MBR si En/Hors service cochée
            -loop tous les records
            -m-à-j forcées :
                -ActPrc : relation Activité principale
                -ActSecs : relations Activités secondaires
                -Gestionnaires : personnes responsables par rapport Activités principale et Activités secondaires
            -m-à-j MBR : les 3 champs
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

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = :INFO
    log.datetime_format = '%H:%M:%S'

#
# Classe
#*******

#
# Main code
#**********
    # Initialisations
    #================
    log.info("🛂->Program #{$0} is starting...")
    log.debug("▶️->Initialisations")
    log.debug("⏩️->Create a new instance of class <Standards>")

    # New instance
    stds    = Standards.new([])                         #new instance

    # DRY_RUN
    print "Production (False) ou Simulation (True) [F] ? "
    DRY_RUN = (gets.chomp.downcase != "f")
    log.info("🔧 Prog: #{$0} Mode: #{DRY_RUN ? 'Simulation' : 'Production'}")

    # Processing
    #===========
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
    