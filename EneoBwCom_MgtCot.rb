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
        dryrun: true
    }                         

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = :INFO
    log.datetime_format = '%H:%M:%S'

# Class
class   CotMgt
#*************
#   contains all methods for this program
#
# Instance variables

# Methods
    # Create new instance
    def initialize()
    #=============
    end #<def>

    # Get processing type
    def getProcessing(opts)
    #================
    #   OUT:    processus type into opts['proctype']
        proctype    = {
            '1'=>  'Request email with amount to pay',
            '2'=>  'Request updating <Date paiement>',
            '3'=>  'Display <Paiements> & <Totaux> pages',
            '4'=>  'Display all pages except <Archivage>'
        }
        opts['procstep'] = '9'                          #default reply
        puts    "<>"
        proctype.each do |key, value|   #<l1>           #display all steps
            puts    "#{key} => #{value}"
        end #<l1>
        print   "Enter your choice ? "
        reply   = $stdin.gets.chomp.to_s
        reply   = 9 unless proctype.key?(reply)
        puts    "Selected choice: #{proctype[reply]}"
        puts    "<>"
        opts['procstep'] = reply.to_i
    end #<def>

    # Get Activity
    def getActivity(opts)
    #==============
    #   OUT:    Activity
        lst_activities  = [
            'Amicale_des_Archers',
            'Aquagym_1',
            'Aquagym_2',
            'Aquagym_3',
            'Art_Floral',
            'Danse',
            'Dessin',
            'Gymnastique_1',
            'Gymnastique_2',
            'Informatique',
            'Marcheurs_du_Jeudi',
            'Marche_Nordique',
            'Pilates',
            'Randonneurs_du_Brabant',
            'Scrapbooking',
            'TaiChi',
            'Tennis_de_Table',
            'Vie_Active'
        ]
        opts['activity'] = 'Exit'                       #default reply
        puts    "<>"
        lst_activities.each_with_index do |act, index|
            puts    "#{index+1} => #{act}"
        end
        puts    "<>"
        print   "Please select the activity by N° => "
        reply   = $stdin.gets.chomp.to_i
        exit    9   if reply == 0
        activity    = lst_activities[reply-1]
        puts    "=>Activity selected: #{reply} -> #{activity}"
        puts    "<>"
        opts['activity'] = activity
    end #<def>


end #<class
#
#
#**********
# Main code
#**********
    log.info("🛂->Program #{$0} is starting...")
    log.debug("▶️->Initialisations")

    # New <stds> instance
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

    # New COT instance
    log.debug("⏩️->Create a new instance of class <cotMgt>")
    cot = CotMgt.new()

    # Processing
    log.debug("▶️->Main code in progress...")

    log.info("Select Activity")
    cot.getActivity(opts)

    log.info("Select Step")
    cot.getProcessing(opts)
    
    log.info("⏩️->Get COT pages")
    log.debug("⏩️->Get DB ID")
    cot_id  =stds.getDbId("m25t.Cotisations")

    log.debug("⏩️->Create filter & sort")
    cot_filter  = {
        "and":  [
            { "property": "Activité", "select": { "equals": opts['activity'] }}
        ]
    }
    cot_sort    = [
        { "property": "Référence", "direction": "ascending"}
    ]
    log.debug("⏩️->Load all pages filtered")
    all_pages   = stds.db_fetch(cot_id, filter: cot_filter, sort: cot_sort)
    log.debug("⏩️->Pages loaded: #{all_pages.size}")

    sel_pages   = all_pages
    log.debug("⏩️->Select all pages according to Step: #{opts['procstep']}")
    sel_pages.select! do |page| #<L1>
        ok  = true
        case    opts['procstep'] #<S2>
        when    1                                       #compute amount
            ok &&= (stds.get_prop_value(page, 'Type')=="Child")
            ok &&= (stds.get_prop_value(page, 'Etat')=="Encodée")
        when    2
            ok &&= (stds.get_prop_value(page, 'Etat')!="z-Archivage")
        when    3
            type    = stds.get_prop_value(page, 'Type')
            ok &&= (type=="Paiement" or type=="Totaux")
        when    4
            ok &&= (stds.get_prop_value(page, 'Etat')!="z-Archivage")
        end #<S2>
    end #<L1>
    log.debug("⏩️->Pages selected: #{sel_pages.size}")

    log.info("⏩️->Process according to Step: #{opts['procstep']}")
    log.debug("⏩️->Init vars")
    pai_amount      = 0
    pai_count       = 0
    tot_relation    = ''

    log.debug("⏩️->Loop pages & ? according to Step: #{opts['procstep']}")
    log.info("⏩️->Step: #{opts['procstep']} phase A")
    sel_pages.each do |page|    #<L1>
        case    opts['procstep']    #<S2>
        when    1
            cotistype   = stds.get_prop_value(page, 'Tags')
            cotisval1   = stds.get_prop_value(page, 'Cotisation pleine')
            cotisval2   = stds.get_prop_value(page, 'Cotisation réduite')
            pai_amount  += cotistype=='Cotisation pleine' ? cotisval1 : cotisval2
            pai_count   += 1
            page_id     = page['id']
            body        = {
                "1-En paiement"=> stds.chkb(true)
            }
            response    = stds.page_update(page_id, body)   unless opts['dryrun']
        when    2
        when    3
            reference   = stds.get_prop_value(page, 'Référence')
            type        = stds.get_prop_value(page, 'Type')
            if type == "Totaux" #<IF3>
                puts    "#{reference}=> #{stds.get_prop_value(page, 'Status')}"
            else    #<IF3>
                nbr = stds.get_prop_value(page, 'Nbr cotis payées')
                val = stds.get_prop_value(page, 'Total réduit payées')
                puts    "#{reference}=> #{nbr} #{val}"
                pai_count   += nbr
                pai_amount  += val
            end #<IF3>
        when    4
            reference   = stds.get_prop_value(page, 'Référence')
            type        = stds.get_prop_value(page, 'Type')
            etat        = stds.get_prop_value(page, 'Etat')
                puts    "#{reference}=> #{etat}"
            pai_count   += 1
        end #<S2>
    end #<L1>

    log.debug("⏩️->Updates according to Step")
    log.info("⏩️->Step: #{opts['procstep']} phase B")
    case    opts['procstep']    #<S1>
    when    1
        log.debug("⏩️->Step 1=>Count:#{pai_count} Amount:#{pai_amount}")
    when    2
    when    3
        log.debug("⏩️->Step 3=>Count:#{pai_count} Amount:#{pai_amount}")
    when    4
        log.debug("⏩️->Step 4=>Count:#{pai_count}")
    end #<S1>
    #
        log.warn("⏹️->Program #{$0} is done")
#<EOP>
#
=begin
    Step 1  Select : Type 'Chid'
            Phase A =>  set field '1' to true
                        DB automation => field 'Etat' = 'En paiement ?'
            Phase B =>  send email with list, count & amount
=end