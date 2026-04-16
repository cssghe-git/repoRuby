#
=begin

=end
#
# Require
require 'logger'
require 'json'
require 'httparty'
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end
#
# Class
#******
class   Standards
#++++++++++++++++
#
#   Actions:    ?

#
# Class variables
#================
    @@Instances = 0
# Logger
    @@log                 = Logger.new(STDOUT)
    @@log.level           = Logger::INFO
    @@log.datetime_format = '%H:%M:%S'
#
# Instances variables
#====================
    @opts   = {
        debug:          ENV.fetch('DEBUG', 'INFO'),
        exec:           ENV.fetch('EXEC', 'S'),
        dryrun:         ENV.fetch('DRY_RUN', true),
        not_apitoken:   ENV.fetch('NOT_APITOKEN', 'None'),
        not_apiver:     ENV.fetch('NOT_APIVER', 'None'),
        not_httpbase:   ENV.fetch('NOT_HTTPBASE', 'None'),
        not_jsondbids:  ENV.fetch('NOT_JSON_DBIDS', 'None'),
        mail_from:      ENV.fetch('MAIL_FROM', 'none@noone.be'),
        smtp_user:      ENV.fetch('SMTP_USER', 'xyz'),
        smtp_pwd:       ENV.fetch('SMTP_PWD', 'zyx')
    }
    @data_sources   = []                                #[[id=>?, name=>?]...]
    @data_source_id = {}                                #{name=> id, ...}
    @dbids          = []
    @dry_run        = true                              #default to 'simulation'
    @pages          = []
    @properties     = {}

    @not_hdr        = {}
    @not_url        = ''
    @not_ver        = 'New'

#
# Code
#*****
    # Getter & Setter
    #++++++++++++++++
    attr_accessor   :opts, :dry_run

    # Methodes
    #+++++++++

    def initialize(options=[], old='New')
    #=============
#        # Common Options from ENV
        @opts   = {
            debug:          ENV.fetch('DEBUG', 'INFO'),
            exec:           ENV.fetch('EXEC', 'S'),
            dryrun:         ENV.fetch('DRY_RUN', false),
            not_apitoken:   ENV.fetch('NOT_APITOKEN', 'None'),
            not_apiver:     ENV.fetch('NOT_APIVER', 'None'),
            not_apiver_old: ENV.fetch('NOT_APIVER_OLD', 'None'),
            not_httpbase:   ENV.fetch('NOT_HTTPBASE', 'None'),
            not_jsondbids:  ENV.fetch('NOT_JSON_DBIDS', 'None'),
            mail_from:      ENV.fetch('MAIL_FROM', 'none@none.be'),
            smtp_user:      ENV.fetch('SMTP_USER', 'xyz'),
            smtp_pwd:       ENV.fetch('SMTP_PWD', 'zyx')
        }
        # Add another options from ENV
        options.each do |opt|
            @opts[opt]  = ENV.fetch(opt,'None')         #@opts['debug'] = ENV.fetch("debug")
        end

        # Variables
        @dbids      = JSON.parse(File.read(@opts[:not_jsondbids]))  #load json file dbids
        @dry_run    = @opts[:dryrun]

        # Notion variables
        @not_ver    = old
        if @not_ver == 'New'
            @not_hdr    = {
                'Authorization'     => @opts[:not_apitoken],
                'Notion-Version'    => @opts[:not_apiver],
                'Content-Type'      => 'application/json'
            }
            @not_base   = 'data_sources'
        else
            @not_hdr    = {
                'Authorization'     => @opts[:not_apitoken],
                'Notion-Version'    => @opts[:not_apiver_old],
                'Content-Type'      => 'application/json'
            }
            @not_base   = 'databases'
        end
        @not_url    = @opts[:not_httpbase]

        # Class
        @@Instances += 1
    end #<def>


    # load specific options
    def loadOpts(options={})
    #===========
    #   INP:    {key: value}
    #
        options.each do |key, value|
            @opts[key]  = value
        end
    end #<dev>

    #====================
    # Notion methods
    #====================
    # Load Data_sources IDs
    def load_DsIds()
    #=============
    #
        res = HTTParty.post("#{@not_url}/databases/#{db_id}", headers: @not_hdr, body: JSON.dump(body))
        raise "DB query #{db_id} failed: #{res.code} #{res.body}" unless res.success?
        @data_sources   = res["data_sources"]
        @data_sources.each do |source|
            @data_source_id[source['name']] = source['id']
        end
        pp @data_source_id
    end #<def

    # Return db id from json file
    def getDbId(dbname=nil)
    #=============
    #
        return  @dbids.find { |h| h.key?(dbname) }&.fetch(dbname)
    end #<def>

    # Query DB
    def db_query(db_id, type: nil, filter: nil, start_cursor: nil, sort: nil, page_size: 100)
    #+++++++++++
    #   OUT:    response (max 100 pages)
    #
        body                = { page_size: page_size }
        body[:filter]       = filter        if filter
        body[:sorts]        = sort          if sort
        body[:start_cursor] = start_cursor  if start_cursor
        ### puts    "DBG>>>#{@not_hdr} - #{@not_url}/#{@not_base}/#{db_id}/query"
        
        res = HTTParty.post("#{@not_url}/#{@not_base}/#{db_id}/query", headers: @not_hdr, body: JSON.dump(body))
        raise "DB query #{db_id} failed: #{res.code} #{res.body}" unless res.success?
    #    DBG    puts    "DBG>>>Result query :"
    #    DBG    pp res
        res.parsed_response
    end #<def>

    # Fetch DB
    def db_fetch(db_id, type: nil, filter: nil, sort: nil)
    #+++++++++++
    #   OUT:    all pages
    #
        @pages          = []
        start_cursor    = nil
        batch_sel       = []
        
        loop do #<L1>
            # get a lot of pages
            response    = db_query(db_id, type: type, filter: filter, start_cursor: start_cursor, sort: sort)
            batch       = response['results']

            # select
            batch.select! do |page|
                true
            end

            # concat pages selected
            @pages.concat(batch || [])

            # no more ?
            break unless response["has_more"]
            start_cursor = response["next_cursor"]
        end #<L1>
        
        return  @pages                                  #all pages
    end #<def>

    # Create page
    def page_create(db_id, props)
    #++++++++++++++
    #   OUT:    response
    #
        if @not_ver == 'New'
            res = HTTParty.post("#{@not_url}/pages", headers: @not_hdr, body: JSON.dump({ parent: { data_source_id: db_id }, properties: props }))
            raise "Create failed: #{res.code} #{res.body}" unless res.success?
        else
            res = HTTParty.post("#{@not_url}/pages", headers: @not_hdr, body: JSON.dump({ parent: { database_id: db_id }, properties: props }))
            raise "Create failed: #{res.code} #{res.body}" unless res.success?
        end
        res.parsed_response
    end

    # Update page
    def page_update(page_id, props)
    #++++++++++++++
    #   OUT:    response
    #
        res = HTTParty.patch("#{@not_url}/pages/#{page_id}", headers: @not_hdr, body: JSON.dump({ properties: props }))
        raise "Update #{page_id} failed: #{res.code} #{res.body}" unless res.success?
        res.parsed_response
    end #<def>

    # Get page
    def page_get(page_id)
    #+++++++++++
    #   OUT:    response or nil
    #
        res = HTTParty.get("#{@not_url}/pages/#{page_id}", headers: @not_hdr)
        res.success? ? res.parsed_response : nil
    end #<def>

    # Get all properties
    def get_properties(page)
    #+++++++++++++++++
    #   OUT:    all properties for 1 page
        @properties = {}
        page['properties'].each do |key, value| #<L1>
            @properties[key]    = get_prop_value(page, key)
        end #<L1>

        @properties                                     #all properties {key => value}
    end #<def>

    # Get property value by name
    def get_prop_value(page, name)
    #+++++++++++++++++
    #   OUT:    property value
    #
        return nil unless page
        p = page.dig("properties", name)
        return nil unless p

        # get value according to type
        case p["type"]  #<S1>
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
        when "files"         then p["files"].map { |f| f.dig("file","url") || f.dig("external","url") }
    ###    when "files"         then p["files"].map { |f| f.dig("name") }
        when "url"           then p["url"]
        when "formula"
            f = p["formula"]
            return nil unless f
            case f["type"]  #<S2>
            when "string"  then f["string"]
            when "number"  then f["number"]
            when "boolean" then f["boolean"]
            when "date"    then f["date"] && f["date"]["start"]
            end #<S2>
        else    #<S1>
            p[p["type"]]
        end #<S1>
    end #<def>

    def read_relation_all(page_id, prop_id)
    #++++++++++++++++++++
    #   OUT:    all relation ids for 1 field
    #
        ids = []
        cursor = nil

        loop do
            url = "#{API}/pages/#{page_id}/properties/#{prop_id}"
            url += "?start_cursor=#{cursor}" if cursor

            r = HTTParty.get(url, headers: @not_hdr)
            raise r.body unless r.success?
            j = r.parsed_response

            ids.concat((j["results"] || []).map { |it| it.dig("relation", "id") }.compact)
            break unless j["has_more"]
            cursor = j["next_cursor"]
        end

        ids.uniq
    end

    # Format all properties according to type
    def title(str)      = { "type"=>"title","title"=>[{"type"=>"text","text"=>{"content"=>str.to_s}}] }
    def select(v)       = { "type"=>"select","select"=> v ? {"name"=>v} : nil }
    def mulsel(arr)     = { "type"=>"multi_select","multi_select"=> Array(arr).compact.map{|n| {"name"=>n} } }
    def chkb(b)         = { "type"=>"checkbox","checkbox"=> !!b }
    def relation(ids)   = { "type"=>"relation","relation"=> Array(ids).compact.uniq.map{|id| {"id"=>id} } }
    def status(val)     = { "type"=>"status","status"=>{"name"=>val.to_s}}
    def num(val)        = { "type"=>"number","number"=>val.to_i}
    def file_int(arr)   = {
                            "type" => "files",
                            "files" => Array(arr).compact.map do |url|
                                {
                                    "name" => url.split('/').last.split('?').first,
                                    "type" => "external",
                                    "external" => { "url" => url }
                                }
                            end
                        }
    def date_iso(d)
        s   = convert_date(d) 
        { "type"=>"date","date"=> s ? {"start"=>s} : nil }
    end
    def text(str)
        return nil if str.empty?
        { "type"=>"rich_text",
        "rich_text"=>[{ "type"=>"text","text"=>{ "content"=>str.to_s } }] }
    end    
    def mail(v)
        return nil if blank?(v)
        { "type"=>"email","email"=> v.to_s }
    end
    def phone(v)
        return nil if blank?(v)
        { "type"=>"phone_number","phone_number"=> v.to_s }
    end

    def convert_date(date_str)  
        return date_str if date_str =~ /^\d{4}-\d{2}-\d{2}$/ # Déjà au bon format

        if date_str =~ %r{^(\d{2})/(\d{2})/(\d{4})$}
            return  "#{$3}-#{$2}-#{$1}"
        elsif   date_str =~ %r{^(\d{2})/(\d{2})/(\d{2})$}
            return  "20#{$3}-#{$2}-#{$1}"
        else
            return  date_str # Retourne tel quel si format non reconnu
        end
        return  
    end

    # End of format methods

    #====================
    # CSV methods
    #====================

    def csv_load()
    #+++++++++++
    #

    end #<def>
    
end #<class>