#!/usr/bin/env ruby
# frozen_string_literal: true
=begin
    DOC     Function:   ?
    DOC     Call:       ruby ? --?
    DOC     Build:      260206-1000
    DOC     Version:    1.1.1
        Bugs:       ?

=end

require 'rubygems'
require "json"
require "optparse"
require "logger"
require 'timeout'
require 'date'
require 'pp'
require 'csv'
require "tty-prompt"
#
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end
#
require_relative    'ClStandards.rb'

#   Options
#**********
    opts    = {                                         #specific options
        debug: 'DEBUG',
        dryrun: false
    }
    OptionParser.new do |o|
        o.banner = "Usage: ruby program.rb [debug=?, dryrun=?"
        o.on("--debug=DEBUG", %w[debug prod], "Debug mode") { |v| opts[:debug] = v }
        o.on("--dryrun=SIMUL", %w[true false], "Dry run mode") { |v| opts[:dryrun] = v }
    end.parse!(ARGV)

#   Variables
#************
    arr_domaines    = ['BVL', 'DOC', 'FIN', 'INF', 'OFF', 'SAN', 'RES']
    arr_dossiers    = []
    arr_types       = []
    arr_tags        = []
    arr_senders     = []
    upl_fields      = {
        'Domaine': {'type': 'select', 'prompt': 'Domaine ', 'options': arr_domaines},
        'Dossier': {'type': 'choice', 'prompt': 'Dossier ', 'options': arr_dossiers},
        'Types': {'type': 'choice', 'prompt': 'Types ', 'options': arr_types},
        'Tags': {'type': 'choice', 'prompt': 'Tags ', 'options': arr_tags}
    }

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = :DEBUG
    log.datetime_format = '%H:%M:%S'

# Main code
#**********
    #Initialisations
    #===============
    # New instances
    #++++++++++++++
    log.info("🛂->Program #{$0} is starting...")
    log.debug("▶️->Initialisations")
    log.debug("⏩️->Create a new instance of class <Standards>")

    nnew    = Standards.new([], 'New', true)                         #new instance
    nold    = Standards.new([], 'Old', true)                         #new instance
    prompt = TTY::Prompt.new

    # Specific options
    #+++++++++++++++++
    log.debug("⏩️->Set specfic options")
    opts = nold.loadOpts(opts)                                     #add spec values
    pp opts
    DRY_RUN = opts[:dryrun]
    log.level   = opts[:debug] || :INFO
    log.info("🔧 Prog: #{$0} Level: #{opts[:debug]} Mode: #{DRY_RUN ? 'DRY-RUN (simulation)' : 'PRODUCTION'}")

    # Load data files
    #++++++++++++++++
    #   DOSSIERS
    #-----------
    log.debug("⏩️->Load <DOSSIERS> ")
    dos_dbid = nnew.getDbId('Dossiers')
    log.debug("⏭️->DOS_DBID:#{dos_dbid}")
    dos_sort = [
        { "property": "Référence", "direction": "ascending"}
    ]
    start_fct   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    dos_pages   = nnew.db_fetch(dos_dbid, sort: dos_sort)   #get all pages
    stop_fct    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    elapsed_fct = ((stop_fct - start_fct)*1000).round(2)
    dos_pages_max = dos_pages.size
    log.debug("⏭️->Fetch DB:: #{dos_pages_max} pages on elapsed time: #{elapsed_fct} ms or #{(elapsed_fct / 1000).round(2)} sec")
    dos_pages.each do |page|
        properties  = nold.get_properties(page)
        arr_dossiers.push(properties['Référence']) unless arr_dossiers.include?(properties['Référence'])
    end
    
    # TAGS
    #-----
    log.debug("⏩️->Load <Tags> ")
    tag_dbid = nnew.getDbId('Tags')
    log.debug("⏭️->TAG_DBID:#{tag_dbid}")
    tag_sort = [
        { "property": "Référence", "direction": "ascending"}
    ]
    start_fct   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    tag_pages   = nnew.db_fetch(tag_dbid, sort: tag_sort)   #get all pages
    stop_fct    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    elapsed_fct = ((stop_fct - start_fct)*1000).round(2)
    tag_pages_max = tag_pages.size
    log.debug("⏭️->Fetch DB:: #{tag_pages_max} pages on elapsed time: #{elapsed_fct} ms or #{(elapsed_fct / 1000).round(2)} sec")
    tag_pages.each do |page|
        properties  = nold.get_properties(page)
        arr_tags.push(properties['Référence']) unless arr_tags.include?(properties['Référence'])
    end

    # TYPES
    #------
    log.debug("⏩️->Load <Types> ")
    typ_dbid = nnew.getDbId('Types')
    log.debug("⏭️->TYP_DBID:#{typ_dbid}")
    typ_sort = [
        { "property": "Référence", "direction": "ascending"}
    ]
    start_fct   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    typ_pages   = nnew.db_fetch(typ_dbid, sort: typ_sort)   #get all pages
    stop_fct    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    elapsed_fct = ((stop_fct - start_fct)*1000).round(2)
    typ_pages_max = typ_pages.size
    log.debug("⏭️->Fetch DB:: #{typ_pages_max} pages on elapsed time: #{elapsed_fct} ms or #{(elapsed_fct / 1000).round(2)} sec")
    typ_pages.each do |page|
        properties  = nold.get_properties(page)
        arr_types.push(properties['Référence']) unless arr_types.include?(properties['Référence'])
    end

    # SENDERS
    #--------
    log.debug("⏩️->Load <Senders> ")
    sen_dbid = nnew.getDbId('Senders')
    log.debug("⏭️->SEN_DBID:#{sen_dbid}")
    sen_sort = [
        { "property": "Référence", "direction": "ascending"}
    ]
    start_fct   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    sen_pages   = nnew.db_fetch(sen_dbid, sort: sen_sort)   #get all pages
    stop_fct    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    elapsed_fct = ((stop_fct - start_fct)*1000).round(2)
    sen_pages_max = sen_pages.size
    log.debug("⏭️->Fetch DB:: #{sen_pages_max} pages on elapsed time: #{elapsed_fct} ms or #{(elapsed_fct / 1000).round(2)} sec")
    sen_pages.each do |page|
        properties  = nold.get_properties(page)
        arr_senders.push(properties['Référence']) unless arr_senders.include?(properties['Référence'])
    end

    # Processing uploaded files
    #--------------------------
    log.debug("▶️->Main code in progress...")
    log.debug("⏩️->Load DB <FilesUpload>")
    upl_dbid    = nold.getDbId('FilesUpload')
    log.debug("⏭️->UPL_DBID:#{upl_dbid}")

    upl_filter  = {
        "property": "Statut", "status": {"equals": "Enregistré"}
    }
    upl_sort    = [
        { "property": "Reference", "direction": "ascending"}
    ]
    start_fct   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    upl_pages   = nold.db_fetch(upl_dbid, filter: upl_filter, sort: upl_sort)   #get all pages
    stop_fct    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    elapsed_fct = ((stop_fct - start_fct)*1000).round(2)
    upl_pages_max = upl_pages.size
    log.debug("⏭️->Fetch DB:: #{upl_pages_max} pages on elapsed time: #{elapsed_fct} ms or #{(elapsed_fct / 1000).round(2)} sec")

    # Process pages
    log.info("⏩️->Process pages")
    upl_page_current = 0
    upl_pages.each do |page|
        log.info(" ")
        upl_page_current += 1
        log.info("")
        log.info("⏭️->Page #{upl_page_current}/#{upl_pages_max}")
        page_id     = page['id']
        properties  = nold.get_properties(page)

        log.debug("⏭️->Process page: #{page['id']} - #{properties['Reference']}")
        log.info("=====Current fields=====")
        properties.each do |key, value|
            log.debug("⏩️->#{key}: #{value}")    unless key === 'FileContent'
        end

        log.info("=====Update fields=====")
        responses = {}
        upl_fields.each do |key, value|
            case value[:type]
            when 'select'
                responses[key] = prompt.select("Choose your #{value[:prompt]} ? ", value[:options])
            when 'choice'
                responses[key] = prompt.select("Choose your #{value[:prompt]} ? ", value[:options])
            else
                log.warn("⚠️->Unknown field type: #{value[:type]} for field: #{key}")
                next
            end
        end

log.debug("⏩️->User responses: #{responses}")

        
    end
    log.fatal("🛂->End of test #{$0}")