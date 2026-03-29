#
=begin
    #Program:   EneoBwSpc_ChkCotFull
    #Build:     5-1-1
    #Function:  Set 'Cotisations'
    #Call:      ruby EneoBwSpc_ChkCotFull.rb
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
#*****************
# Class
class   Cot_Checks
#*****************

# Class variables
#****************
    @not_hdr    = {}                                    #Header for each request

# Methods
#********
    # Initialize
    def initialize()
    #=============
    #   INP:    ?
    #   OUT:    ?
    #   FUNCT:  init new instance
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
    #   OUT:    [page, page...]
    #   FUNCT:  load all cotisations selected
    #
        puts    "DBG>>>#{__method__}> "
        puts    "DBG>>>Filter: #{filter} - Sort: #{sort}"
        res             = []
        current_cursor  = nil
        page            = {}

        loop do #<L1>                                   #loop all pages
            puts    "DBG>>>Request query for COT"
            data    = query_cot(start_cursor: current_cursor, filter: filter, sort: sort)
            batch   = data["results"]                   #extract 'results' only
            puts    "Read: #{batch.size} pages"

            puts    "DBG>>>Selected: #{batch.size} pages"
            res.concat(batch)
            break unless page["has_more"]
            current_cursor  = page["next_cursor"]
        end #<L1>
        puts    "Return: #{res.size} pages"

        return  res
    end #<def>

    # Update COT
    def update_cot(page_id, etat)
    #=============
    #   INP:    ?
    #   OUT:    ?
    #   FUNCT:  set states on COT pages
    #
        puts    "DBG>>#{__method__}>Etat:#{etat}"
        props   = {"1-En paiement" => chk(true)}    if etat == 'En paiement'

        if etat == 'Payée'
            props   = {
                "3-Confirmation" => chk(true),
                "Etat" => sta('Payée')
            }
        end

        props   = {}      if etat == 'Consolidé'
        
        r = HTTParty.patch("#{NOTION_URI}/pages/#{page_id}", headers: @not_hdr, body: JSON.dump({ properties: props }))
        raise "Update #{page_id} failed: #{r.code} #{r.body}" unless r.success?
        r.parsed_response
    end #<def>

    # For update property
    def sel(v)  = { "type"=>"select", "select"=> v ? {"name"=>v} : nil }
    def sta(v)  = { "type"=>"status", "status"=> v ? {"name"=>v} : nil }
    def chk(b)  = { "type"=>"checkbox", "checkbox"=> !!b }
    def relnull(v)  = { "type"=>"relation", "relation"=> []}

    #======

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
    
    # Enter Activity
    def enter_activity()
    #=================
    #   INP:    ?
    #   OUT:    ?
    #   FUNCT:  get activity to process
    #
        lst_activity    = [
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
        lst_activity.each_with_index do |act, index|
            puts    "#{index+1} => #{act}"
        end
        print   "Please select the activity by N° => "
        actindex    = $stdin.gets.chomp.to_i
        exit    9   if actindex == 0
        actselect   = lst_activity[actindex-1]
        puts    "=>Activity selected: #{actindex} -> #{actselect}"

        return  actselect
    end #<def>

    # Process page
    def display_cot(arr_cot)
    #==============
    #   INP:    ?
    #   OUT:    ?
    #   FUNCT:  display all pages
    #
        puts    "DBG>>#{__method__}>"
        arr_cot.each do |page|
            type        = get_prop(page,'Type')
            reference   = get_prop(page,'Référence')
            etat        = get_prop(page,'Etat')
            puts    "<>"
            puts    "DBG>>>REF: #{reference} -> Type: #{type}"
            case    type
            when    'Totaux'
                #    pp  page
                puts    "#{type}=>Etat:#{etat} | Status:#{get_prop(page,'Status')} | COT:#{get_prop(page,'Nbr cotisations')} | #{get_prop(page,'Total réduit')}"
                puts    "- - -REL=>ACT:#{get_prop(page,'relActivité')} | #{get_prop(page,'relAllacts')} | Cont:#{get_prop(page,'ContainerCOT')}"
                puts    "- - -ENF=>#{get_prop(page,'rlbEnfant')}"
            when    'Paiement'
                puts    "#{type}=>Etat:#{etat} | Status:#{get_prop(page,'Status')} | COT:#{get_prop(page,'Nbr cotisations')} | #{get_prop(page,'Total réduit')}"
                puts    "- - -REL=>ACT:#{get_prop(page,'relActivité')} | #{get_prop(page,'relAllacts')} | Cont:#{get_prop(page,'ContainerCOT')}"
                puts    "- - -ENF=>#{get_prop(page,'rlbEnfant')}"
            when    'Child'
                puts    "#{type}=>Etat:#{etat} | Status:#{get_prop(page,'Status')} | COT:#{get_prop(page,'Nbr cotisations')} | #{get_prop(page,'Total réduit')}"
                puts    "- - -REL=>ACT:#{get_prop(page,'relActivité')} | #{get_prop(page,'relAllacts')} | Cont:#{get_prop(page,'ContainerCOT')}"
                puts    "- - -MBR=>#{get_prop(page,'relMembre')} | PAR:#{get_prop(page,'relParent')}"
            end
        end
    end #<def>

end #<class>

#**********
# Main code
#**********
    log.info("#{$0} is starting...")
    # Init
    log.info("Create Notion instance")
    not_inst = Cot_Checks.new()                         #Notion instance

    log.info("Get activity & step")
    activity    = not_inst.enter_activity()

    log.info("Load COT")
    cot_filter  = {
        "and":   [
            { "property": "Etat",       "status": { "does_not_equal": "z-Archivage" }},
            { "property": "Activité",   "select": { "equals": activity }}
        ]
    }
    cot_sort    = [
        { "property": "Activité", "direction": "ascending"},
        { "property": "Référence", "direction": "ascending"}
    ]
    array_cot   = not_inst.load_cot_candidates(filter: cot_filter, sort: cot_sort)
    log.info("COT: Read:#{array_cot.size} pages")

    # Process
    log.info("Display pages")
    not_inst.display_cot(array_cot)


# Exit
    log.info("#{$0} done")
