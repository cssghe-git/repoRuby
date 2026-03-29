#
=begin
    Program:    EneoBwSpc_UpdFields
    Functions:  Update any fields on m25t.Membres
    Input:      field name
                csv file with updates
    Output:     m25t.Membres updated
    Flags:      --dry-run = true or false
    Analyse:
        stds new instance
        get mbr_id value from jsonfile
        request field
        loop all rows
            search member
            compare field values
            if not same:
                update member
            end
        end
=end
#
# Require
require 'httparty'
require 'json'
require 'csv'
require 'logger'
require "mail"
require "cgi"
require "time"
require 'optparse'

require_relative    'ClStandards.rb'
require_relative    'Mod_m25t_Members.rb'

begin
  require "dotenv"; Dotenv.load
rescue LoadError
end
#
# Notion symbols
NOTION_TOKEN    = ENV.fetch("NOT_APITOKEN")
NOTION_VERSION  = ENV.fetch("NOT_APIVER")
NOTION_URI      = ENV.fetch("NOT_HTTPBASE")

# Configuration
CONFIG          = JSON.parse(File.read(File.join(__dir__, "Data_Sources_ID2.json")))
MBR_SOURCE_ID   = CONFIG.find { |h| h.key?("m25t.Membres") }&.fetch("m25t.Membres")

# Options
    # Default
    options = {
        exec:       ENV.fetch("EXEC","P"),
        debug:      ENV.fetch("DEBUG","INFO"),
        username:   ENV.fetch("SMTP_USER","None"),
        password:   ENV.fetch("SMTP_PWD","None"),
        fileinp:    ENV.fetch('FILE',"None"),
        dry_run:    ENV.fetch("DRY_RUN", true)
    }
    # from call command
    OptionParser.new do |opts|
        opts.on("--input FILE", "csv input file") { |v| options[:fileinp] = v }
        opts.on("--dry-run VAL", "Simulation / production") { |v| options[:dry_run] = v }
    end.parse!

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = Logger::INFO
    log.datetime_format = '%H:%M:%S'

#
# Variables
#**********

#
# Functions
#**********

    def enterField(log: nil)
    #+++++++++++++
    #
    print   "Enter field name excactely ? "
    reply   = $stdin.gets.chomp.to_s
    return  reply
    end #<def>

    def csvLoad(log: nil, file: nil)
    #++++++++++
    #   OUT:    csv_rows [row, ...] row=> {col=>data} 
    csv_rows    = CSV.read(file, headers: true, col_sep: ';') # open & load
#    tableau_de_lignes = CSV.read('fichier.csv', headers: true).map do |row|
#        row.to_h
#    end    
    return  csv_rows
    end #<def>
#
# Main code
#**********
    #Initialize
    log.info("Program #{$0} is starting on Simulation: #{options[:dry_run]}")
    log.info(">Get fields to update")
    fld_name    = enterField(log: log)                       # get field name
    exit    if fld_name.nil?

    log.info(">Initialize")
    stds    = Standards.new()                           # new instance

    log.info(">Load Membres")
    prms    = M25t_Membres.infos()                      # get file infos
    membres = M25t_Membres.load()                       # {ref=>data}
    log.info(">>Membres loaded: #{membres.size}")

    log.info(">Load csv file")
    # Use current user's home directory and provided input filename
    file    = File.expand_path(File.join("~/Public/Private/Works", options[:fileinp]))
    csv_rows    = csvLoad(log: log, file: file)                   # [row, ...]row{col=>data}
    log.info(">>Rows loaded: #{csv_rows.size}")
    
    log.info(">Loop all rows")
    csv_rows.map do |row|  #<L1>
        flag_new    = false
        row.to_h
        csv_ref     = "#{row['Nom']&.strip}-#{row['Prénom']&.strip}"  # extract reference
        csv_field   = row[fld_name]                     # extract field requested from CSV
        next    if csv_field.nil?
        mbr_data    = membres[csv_ref]                  # load data (1 row)
        if mbr_data.nil?
            log.warn(">>Member not found: #{csv_ref}")
            flag_new    = true
        end

        if flag_new == false    #<IF2> Member exists => update field
            mbr_field   = stds.get_prop_value(mbr_data, fld_name)  # get old field value
        #    log.info(">>Check for: #{csv_ref} => old: #{mbr_field} new: #{csv_field}")
            next    if csv_field == mbr_field               # next if no update
            log.info(">>Update value for: #{csv_ref} => old: #{mbr_field} new: #{csv_field}")

            mbr_id      = mbr_data['id']                     # get page ID
            fld_type    = prms[:fields][fld_name]           # get field type
            case    fld_type    #SW2>
            when    'rich_text'
                fld_property    = stds.text(csv_field)
            end #<SW2>
            stds.page_update(mbr_id, {fld_name => stds.text(csv_field)}) unless options[:dry_run] == "true"
        else    #<IF2>
            
        end #<IF2>
    end #<L1>
