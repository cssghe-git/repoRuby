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
#********
    spec    = {                                         #specific values
        json: "Fichier_data_search.json",
        debug: 'DEBUG',
        dryrun: false
    }
    OPTS    = {
        json: "data_search.json",
        dryrun: false
    }                                              #options values
    # from command line
    OptionParser.new do |opts|
        opts.on("--json FILE", "Fichier_data_search.json") { |v| OPTS[:json_file] = v }
        opts.on("--debug INFO",String,"Debug mode"){|v| OPTS[:debug] = v }
        opts.on("--dryrun true","Siulation or not") { |v| OPTS[:fct] = v }
    end.parse!  #<OptionParser>

# Logger
    LOG                 = Logger.new(STDOUT)
    LOG.level           = Logger:INFO
    LOG.datetime_format = '%H:%M:%S'

#
# Variables
#**********
#
    search_table_id = ""

    json_data       = []                        #json data
    arr_pages       = []                        #array of pages
#
# Functions
#**********
#
#
# Main code
#**********
#
    # New instance
    LOG.info("🛂->Program #{$0} is starting...")
    LOG.debug("▶️->Initialisations")
    LOG.debug("⏩️->Create a new instance of class <Standards>")
    stds    = Standards.new([])                         #new instance

    # Specific OPTS
    LOG.debug("⏩️->Set specfic options")
    stds.loadOpts(spec)                                 #add spec values
    OPTS    = stds.opts                                 #get opts values
    ### pp OPTS
    LOG.level   = OPTS[:debug] || Logger:INFO
    LOG.info("🔧 Prog: #{$0} Level: #{OPTS[:debug]} Mode: #{OPTS[:dryrun] ? 'DRY-RUN (simulation)' : 'PRODUCTION'}")

    # Load json file
    LOG.debug("⏩️->Load json file")
    if FILE.exist?(OPTS[:json])
        LOG.debug("📂->File #{OPTS[:json]} exists")
        json_data   = JSON.parse(File.read(OPTS[:json]))    #load json data
    else
        LOG.error("❌->File #{OPTS[:json]} does not exist")
        exit(1)
    end
    LOG.debug("📂->File #{OPTS[:json]} loaded")
    lastrun  = json_data["lastrun"] || "never"

    # Processing
    LOG.debug("▶️->Main code in progress...")

    LOG.info("⏩️->Loop on <Area>")
    json_data["areas"].each do |key1, area|
        LOG.info("⏩️->Area: #{key1}")

        LOG.info("⏩️->Loop on <Sub>")
        area.each do |key2, sub|
            LOG.info("⏩️->Sub: #{key2}")
            
            LOG.info("⏩️->Loop on <Folder>")
            sub.each do |key3, folder|
                LOG.info("⏩️->Folder: #{key3}")

                # Get all pages for this <Folder>
                filter = {
                    "Date de création" => {"operator": "after", "value": lastrun}
                }
                sort = [
                    {"field": "Date de création", "direction": "descending"}
                ]
                arr_pages = []                          #reset array of pages
                arr_pages = stds.fetch(["table_id"], "type": "new", "filter": filter, "sort": sort)
                arr_ids = arr_pages.map { |page| page["id"] } #array of page ids
                LOG.info("🔍->#{arr_pages.size} new pages found for this folder since #{lastrun}")

                # Build Search-title
                # Loop all pages for this <Folder>
                arr_pages.each do |page|
                    LOG.info("⏩️->Page: #{page}")
                    search_title    = ""
                    folder.each do |field|
                        LOG.info("⏩️->Field: #{field}")
                        res = stds.get_prop_value()
                        search_title    += "#{res}#" if field != "title"
                    end
                    search_title    = search_title.gsub()(/#$/, "") #remove last #
                    LOG.info("🔍->Search title: #{search_title}")
                    # Create page with this search title
                    body = {
                         "Reference" => stds.title(),
                         "Pages" => stds.relation(arr_ids)
                    }
                    stds.createpage(search_title, body)

                    exit 9
                end
            end
        end
    end


    LOG.info("")