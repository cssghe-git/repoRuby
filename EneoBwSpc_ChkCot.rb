#
=begin
    #Program:   EneoBwSpc_ChkCot
    #Build:     5-1-1
    #Function:  Check Cotisations & report
    #Call:      ruby EneoBwSpc_ChekCot.rb
    #Folder:    Public/Progs/.
    #Parameters::
    #Versions:  5-1-0   <260127-2000>
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

begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

# Notion symbols
NOTION_TOKEN    = ENV.fetch("NOT_APITOKEN")
NOTION_VERSION  = ENV.fetch("NOT_APIVER")
NOTION_URI      = ENV.fetch("NOT_HTTPBASE")

# Configuration
CONFIG          = JSON.parse(File.read(File.join(__dir__, "Data_Sources_ID2.json")))
ACT_SOURCE_ID   = CONFIG.find { |h| h.key?("m25t.Activités") }&.fetch("m25t.Activités")
COT_SOURCE_ID   = CONFIG.find { |h| h.key?("m25t.Cotisations") }&.fetch("m25t.Cotisations")

# Options
    options = {
        exec:       ENV.fetch("EXEC","P"),
        debug:      ENV.fetch("DEBUG","INFO"),
        username:   ENV.fetch("SMTP_USER","None"),
        password:   ENV.fetch("SMTP_PWD","None")
    }

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = Logger::INFO
    log.datetime_format = '%H:%M:%S'

# SMTP
    Mail.defaults do
        delivery_method :smtp, {
            address: "smtp.fastmail.com",
            port: 587,
            user_name: options[:username],
            password: options[:password],
            authentication: "PLAIN",
            enable_starttls_auto: true
        }
    end

# Notion common header
NOTION_HDR = {
    "Authorization"  => "Bearer #{NOTION_TOKEN}",
    "Notion-Version" => NOTION_VERSION,
    "Content-Type"   => "application/json"
}

# Class
class   Cot_Checks
#*****************

# Instance variables
#*******************
    @not_hdr    = {}                                    #Header for each request
    @count_nais = 0

# Methods
#********
    # Initialize
    def initialize()
    #=============
    #   INP:    ?
    #   OUT:    ?
    #   FUNCT:  ?
    #
        @not_hdr    = NOTION_HDR
    end #<def>

    # Query on COT
    def query_cot(filter: nil, sort: nil, start_cursor: nil, page_size: 100)
    #============
    #   INP:    filter, sort
    #   OUT:    arr_cotisations: []
    #   FUNCT:  load array from COT pages
    #
        puts    "DBG>>#{__method__}>FILTER:#{filter} - SORT:#{sort}"
        body = { page_size: page_size }
        body[:filter]   = filter    if filter
        body[:sorts]    = sort      if sort
        body[:start_cursor] = start_cursor if start_cursor

        r = HTTParty.post("#{NOTION_URI}/data_sources/#{COT_SOURCE_ID}/query", headers: @not_hdr, body: JSON.dump(body))
        raise "DB query #{COT_SOURCE_ID} failed: #{r.code} #{r.body}" unless r.success?
        r.parsed_response

    end #<def>

    # Load COT candisates
    def load_cot_candidates(filter: nil, sort: nil)
    #======================
    #   INP:    ?
    #   OUT:    ?
    #   FUNCT:  ?
    #
        puts    "DBG>>#{__method__}>"
        res, current_cursor = [], nil

        loop do #<L1>                                   #loop all pages
            data    = query_cot(start_cursor: current_cursor, filter: filter, sort: sort)
            batch   = data["results"]                   #extract 'results' only

            batch.select! do |page|    #<L2>            #sélections
                ok          = true                      #set default à OK
                reference   = get_prop(page, 'Référence')
                type        = get_prop(page, 'Type')
                ok &&= ["Totaux", "Paiement", "Consolidé"].include?(type)
            end #<L2>

            res.concat(batch)
            break unless data["has_more"]
            current_cursor  = data["next_cursor"]
        end #<L1>

        return  res
    end #<def>

    # Get property
    def get_prop(page, name)
    #===========
    #   INP:    ?
    #   OUT:    ?
    #   FUNCT:  get a property
    #
        ###puts    "DBG>>#{__method__}>#{name}"
        p = page.dig("properties", name)
        return nil unless p

        case p["type"]
        when "title"         then p["title"].map { _1["plain_text"] }.join
        when "rich_text"     then p["rich_text"].map { _1["plain_text"] }.join
        when "select"        then p["select"] && p["select"]["name"]
        when "multi_select"  then (p["multi_select"] || []).map { _1["name"] }
        when "status"        then p["status"] && p["status"]["name"]
        when "date"          then p["date"] && p["date"]["start"]
        when "email"         then p["email"]
        when "phone_number"  then p["phone_number"]
        when "checkbox"      then p["checkbox"]
        when "number"        then p["number"]
        when "relation"      then (p["relation"] || []).map { _1["id"] }
        when "people"        then (p["people"]   || []).map { _1["id"] }
        when "formula"
            f = p["formula"]; return nil unless f
            case f["type"]
            when "string"  then f["string"]
            when "number"  then f["number"]
            when "boolean" then f["boolean"]
            when "date"    then f["date"] && f["date"]["start"]
            end
        else
            p[p["type"]]
        end
    end #<def>

    # display COT values
    def display_cot(array_cot)
    #==============
    #   INP:    ?
    #   OUT:    ?
    #   Funct:  display COT values
    #
        prv_activity    = 'None'
        cnt_encode      = 0
        cnt_attente     = 0
        cnt_paye        = 0
        #
        array_cot.each do |page|
            # extract porperties
            reference   = get_prop(page, 'Référence')
            type        = get_prop(page, 'Type')
            activity    = get_prop(page, 'Activité')
            etat        = get_prop(page, 'Etat')
            status      = get_prop(page, 'Status')
            status      = status[4..15]                     #skip 'TOT:'
            status_spl  = status.split('|')
            encode      = status_spl[0].to_i
            attente     = status_spl[1].to_i
            paye        = status_spl[2].to_i

            #counters
            cnt_encode  += encode
            cnt_attente += attente
            cnt_paye    += paye

            # State
            state   = "?"
            if paye > 0
                state   = "OK, merci"
            elsif attente > 0
                state   = "Où est le paiement ?"
            elsif encode > 0
                state   = "Le réveil a sonné !"
            end

            #display each page
            puts    "<>"    unless prv_activity == activity
            prv_activity    = activity
            str             = "REF:#{reference}"
            str_len         = 35-str.size
            suppl           = " "* str_len
            puts    str + suppl + "=> #{encode} | #{attente} | #{paye}  ==> State: #{state}"
        #    puts    " => Encodés:#{encode} - En attente:#{attente} - Payés:#{paye}"
        end
        # display counters
        puts    "<<<>>>"
        puts    "Counters: Encodés:#{cnt_encode} - En attente:#{cnt_attente} - Payés:#{cnt_paye}"
    end #<def

end #<class>

# Main code
#**********
    log.info("#{$0} is starting...")
    # Init
    log.info("Create Notion instance")
    not_inst = Cot_Checks.new()                         #Notion instance

    log.info("Load COT")
    cot_filter  = {
        "or":   [
            { "property": "Type", "select": {"equals": "Totaux"}},
            { "property": "Type", "select": {"equals": "Paiement"}},
            { "property": "Type", "select": {"equals": "Child"}},
        ]
    }
    cot_sort    = [
        { "property": "Activité", "direction": "ascending"},
        { "property": "Référence", "direction": "ascending"}
    ]
    array_cot   = not_inst.load_cot_candidates(filter: cot_filter, sort: cot_sort)
    log.info("COT: Read:#{array_cot.size}")

    # Process
    ### pp array_cot
    log.info("Display pages")
    not_inst.display_cot(array_cot)

# Exit
    log.info("#{$0} done")
