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
begin
  require "cli/ui"
  CLI::UI::StdoutRouter.enable
  CLI::UI::Frame.divider('═')
rescue LoadError
end
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
        debug_bool: "OFF",
        dryrun: "OFF"
    }

#   Variables
#************
    arr_domaines    = ['BVL', 'DOC', 'FIN', 'INF', 'OFF', 'SAN', 'RES']
    arr_dossiers    = {}
    arr_types       = {}
    arr_tags        = {}
    arr_senders     = {}
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
    nnew = nil
    nold = nil
    prompt = nil
    def ui_step(title)
      if defined?(CLI::UI)
        CLI::UI::Frame.open(title) { yield }
      else
        puts "==== #{title} ===="
        yield
      end
    end

    def ui_info(message)
      if defined?(CLI::UI)
        CLI::UI::fmt("{{info}}#{message}{{/info}}")
      else
        message
      end
    end

    def ui_ok(message)
      if defined?(CLI::UI)
        CLI::UI::fmt("{{green:✓}} #{message}")
      else
        message
      end
    end

    def ui_spin(title)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = nil
      if defined?(CLI::UI)
        CLI::UI::Spinner.spin(title) do
          result = yield
        end
      else
        puts "#{title}..."
        result = yield
      end
      elapsed_sec = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(2)
      puts ui_ok("#{title} terminé en #{elapsed_sec}s")
      result
    end
    #Initialisations
    #===============
    # New instances
    #++++++++++++++
    ui_step("PrvDocuments_Updates") do
        log.info("🛂->Program #{$0} is starting...")
        puts ui_info("Initialisation des objets et des options")
        log.debug("▶️->Initialisations")
        log.debug("⏩️->Create a new instance of class <Standards>")

        nnew    = Standards.new([], 'New', true)                         #new instance
        nold    = Standards.new([], 'Old', true)                         #new instance
        prompt = TTY::Prompt.new

        # Specific options
        #+++++++++++++++++
        log.debug("⏩️->Set specfic options")
        opts = nold.loadOpts(opts)                                     #add spec values
        OptionParser.new do |o|
            o.banner = "Usage: ruby program.rb [debug=?, dryrun=?"
            o.on("--debug=DEBUG", %w[ON OFF], "Debug mode") { |v| opts[:debug_bool] = v }
            o.on("--dryrun=SIMUL", %w[ON OFF], "Dry run mode") { |v| opts[:dryrun] = v }
        end.parse!(ARGV)
        pp opts
        DEBUG = opts[:debug_bool]
        DRY_RUN = opts[:dryrun]
        log.level   = opts[:debug] || :INFO
        log.info("🔧 Prog: #{$0} Level: #{DEBUG} Mode: #{DRY_RUN ? 'DRY-RUN (simulation)' : 'PRODUCTION'}")
        puts ui_ok("Initialisation terminée")
    end

    # Load data files
    #++++++++++++++++
    #   DOSSIERS
    #-----------
    ui_step("Chargement des référentiels") do
        log.debug("⏩️->Load <DOSSIERS> ")
        dos_dbid = nnew.getDbId('Dossiers')
        log.debug("⏭️->DOS_DBID:#{dos_dbid}")
        dos_sort = [
            { "property": "Référence", "direction": "ascending"}
        ]
        start_fct   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        dos_pages   = ui_spin("Chargement Dossiers") { nnew.db_fetch(dos_dbid, sort: dos_sort) }   #get all pages
        stop_fct    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        elapsed_fct = ((stop_fct - start_fct)*1000).round(2)
        dos_pages_max = dos_pages.size
        log.debug("⏭️->Fetch DB:: #{dos_pages_max} pages on elapsed time: #{elapsed_fct} ms or #{(elapsed_fct / 1000).round(2)} sec")
        count = 9
        dos_pages.each do |page|
            pp page if count < 1
            count += 1
            properties  = nold.get_properties(page)
            arr_dossiers[properties['Référence']] = page['id'] unless arr_dossiers.include?(properties['Référence'])
        end
        puts ui_ok("Dossiers chargés: #{arr_dossiers.size}")
        ###pp arr_dossiers
    
        # TAGS
        #-----
        log.debug("⏩️->Load <TAGS> ")
        tag_dbid = nnew.getDbId('Tags')
        log.debug("⏭️->TAG_DBID:#{tag_dbid}")
        tag_sort = [
            { "property": "Référence", "direction": "ascending"}
        ]
        start_fct   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        tag_pages   = ui_spin("Chargement Tags") { nnew.db_fetch(tag_dbid, sort: tag_sort) }   #get all pages
        stop_fct    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        elapsed_fct = ((stop_fct - start_fct)*1000).round(2)
        tag_pages_max = tag_pages.size
        log.debug("⏭️->Fetch DB:: #{tag_pages_max} pages on elapsed time: #{elapsed_fct} ms or #{(elapsed_fct / 1000).round(2)} sec")
        count = 9
        tag_pages.each do |page|
            pp page if count < 1
            count += 1
            properties  = nold.get_properties(page)
            arr_tags[properties['Référence']] = page['id'] unless arr_tags.include?(properties['Référence'])
        end
        puts ui_ok("Tags chargés: #{arr_tags.size}")

        # TYPES
        #------
        log.debug("⏩️->Load <TYPES> ")
        typ_dbid = nnew.getDbId('Types')
        log.debug("⏭️->TYP_DBID:#{typ_dbid}")
        typ_sort = [
            { "property": "Référence", "direction": "ascending"}
        ]
        start_fct   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        typ_pages   = ui_spin("Chargement Types") { nnew.db_fetch(typ_dbid, sort: typ_sort) }   #get all pages
        stop_fct    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        elapsed_fct = ((stop_fct - start_fct)*1000).round(2)
        typ_pages_max = typ_pages.size
        log.debug("⏭️->Fetch DB:: #{typ_pages_max} pages on elapsed time: #{elapsed_fct} ms or #{(elapsed_fct / 1000).round(2)} sec")
        count = 9
        typ_pages.each do |page|
            pp page if count < 1
            count += 1
            properties  = nold.get_properties(page)
            arr_types[properties['Référence']] = page['id'] unless arr_types.include?(properties['Référence'])
        end
        puts ui_ok("Types chargés: #{arr_types.size}")

        # SENDERS
        #--------
        log.debug("⏩️->Load <SENDERS> ")
        sen_dbid = nnew.getDbId('Senders')
        log.debug("⏭️->SEN_DBID:#{sen_dbid}")
        sen_sort = [
            { "property": "Référence", "direction": "ascending"}
        ]
        start_fct   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        sen_pages   = ui_spin("Chargement Senders") { nnew.db_fetch(sen_dbid, sort: sen_sort) }   #get all pages
        stop_fct    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        elapsed_fct = ((stop_fct - start_fct)*1000).round(2)
        sen_pages_max = sen_pages.size
        log.debug("⏭️->Fetch DB:: #{sen_pages_max} pages on elapsed time: #{elapsed_fct} ms or #{(elapsed_fct / 1000).round(2)} sec")
        count = 0
        sen_pages.each do |page|
            pp page if count < 1
            count += 1
            properties  = nold.get_properties(page)
            arr_senders[properties['Référence']] = page['id'] unless arr_senders.include?(properties['Référence'])
        end
        puts ui_ok("Senders chargés: #{arr_senders.size}")
    end

    # Processing uploaded files
    #--------------------------
    ui_step("Traitement des fichiers uploadés") do
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
        upl_pages   = ui_spin("Chargement FilesUpload") { nold.db_fetch(upl_dbid, filter: upl_filter, sort: upl_sort) }   #get all pages
        stop_fct    = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        elapsed_fct = ((stop_fct - start_fct)*1000).round(2)
        upl_pages_max = upl_pages.size
        log.debug("⏭️->Fetch DB:: #{upl_pages_max} pages on elapsed time: #{elapsed_fct} ms or #{(elapsed_fct / 1000).round(2)} sec")
        puts ui_ok("Fichiers à traiter: #{upl_pages_max}")

        # Process pages
        log.info("⏩️->Process pages")
        upl_page_current = 0
        upl_pages.each do |page|
            if defined?(CLI::UI)
                CLI::UI::Frame.open("Page #{upl_page_current + 1}/#{upl_pages_max}") do
                    log.info(" ")
                end
            end
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

            log.info("=====Rewrite fields=====")
            props = {
                "Domaine": nold.select(responses["Domaine"]),
                "Dossier": nold.relation(responses["Dossier"]),
                "Type": nold.relation(responses["Types"]),
                "Tags": nold.relation(responses["Tags"])
            }
            res = nold.page_update(page_id, props)
        end
    end
    log.fatal("🛂->End of test #{$0}")