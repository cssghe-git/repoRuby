# frozen_string_literal: true
=begin
DOC     Function:   class to execute Notion api
DOC     Methods:    get_dbid(), db_query(), db_fetch(),
DOC                 page_create(), page_update(), page_get(),
DOC                 get_properties(), form_properties()
DOC     Build:      260111-2045
DOC     Version:    1.1.1
    Bugs:       ?
=end

require "json"
require "httparty"

class   API_Notion
#*****************
# === CONFIGURATION ===
NOTION_TOKEN        = "secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3"
NOTION_API_BASE_URL = "https://api.notion.com/v1"
NOTION_API_VERSION  = "2025-09-03"

DATA_SOURCES        = true  #false
DRY_RUN             = true  #true=simulation false=production

# === Class vars ===

# === Instance vars ===
    @headers            = {}
    @data_sources_id    = {}
    @dry_run            = true
    @pages              = []                            #all pages
    @properties         = {}                            #all properties

# === Methods ===
    # Initialize
    def initialize(data_sources_file, dryrun = DRY_RUN )
        @headers    = {
            "Authorization"  => "Bearer #{NOTION_TOKEN}",
            "Notion-Version" => NOTION_API_VERSION,
            "Content-Type"   => "application/json"
        }
        @dry_run            = dryrun
        @data_sources_id    = JSON.parse(File.read(data_sources_file)).to_a
    end #<def>

    # Extract db ID from data_sources
    def get_dbid(key)
    #++++++++++
    #   OUT:    db_id
    #
        @data_sources_id.each do |item|
            if key.include?(item['name'])
                return  item[key]
            end
        end
        return  nil
    end #<def>

    # Query DB
    def db_query(db_id, filter: nil, start_cursor: nil, sort: nil, page_size: 100)
    #+++++++++++
    #   OUT:    response (max 100 pages)
    #
        body                = { page_size: page_size }
        body[:filter]       = filter        if filter
        body[:sort]         = sort          if sort
        body[:start_cursor] = start_cursor  if start_cursor

        res = HTTParty.post("#{NOTION_API_BASE_URL}/data_sources/#{db_id}/query", headers: @headers, body: JSON.dump(body))
        raise "DB query #{db_id} failed: #{res.code} #{res.body}" unless res.success?

        res.parsed_response
    end #<def>

    # Fetch DB
    def db_fetch(db_id, filter: nil, sort: nil)
    #+++++++++++
    #   OUT:    all pages
    #
        @pages          = []
        start_cursor    = nil
        
        loop do #<L1>
            # get a lot of pages
            response = db_query(db_id, filter: filter, start_cursor: start_cursor, sort: sort)
            # concat pages selected
            @pages.concat(pages || [])
            # no more ?
            break unless response["has_more"]
            start_cursor = response["next_cursor"]
        end #<L1>
        
        @pages                                          #all pages
    end #<def>

    def db_select(pages=[])
    #++++++++++++
    #
        pages.select |page|
            ok  = yield   page                          #check 1 page => true or false
        end 
        return  pages                                   #pages selected
    end #<def>

    # Create page
    def page_create(db_id, props)
    #++++++++++++++
    #   OUT:    response
    #
        res = HTTParty.post("#{NOTION_API_BASE_URL}/pages", headers: @headers, body: JSON.dump({ parent: { data_source_id: db_id }, properties: props }))
        raise "Create failed: #{res.code} #{res.body}" unless res.success?
        res.parsed_response
    end

    # Update page
    def page_update(page_id, props)
    #++++++++++++++
    #   OUT:    response
    #
        res = HTTParty.patch("#{NOTION_API_BASE_URL}/pages/#{page_id}", headers: @headers, body: JSON.dump({ properties: props }))
        raise "Update #{page_id} failed: #{res.code} #{res.body}" unless res.success?
        res.parsed_response
    end

    # Get page
    def page_get(page_id)
    #+++++++++++
    #   OUT:    response or nil
    #
        res = HTTParty.get("#{NOTION_API_BASE_URL}/pages/#{page_id}", headers: @headers)
        res.success? ? res.parsed_response : nil
    end

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
        p = page.dig("properties", name)
        return nil unless p

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
    
    # Format all properties
    def title(str)      = { "type"=>"title","title"=>[{"type"=>"text","text"=>{"content"=>str.to_s}}] }
    def select(v)       = { "type"=>"select","select"=> v ? {"name"=>v} : nil }
    def mulsel(arr)     = { "type"=>"multi_select","multi_select"=> Array(arr).compact.map{|n| {"name"=>n} } }
    def date_iso(s)     = { "type"=>"date","date"=> s ? {"start"=>s} : nil }
    def chkb(b)         = { "type"=>"checkbox","checkbox"=> !!b }
    def relation(ids)   = { "type"=>"relation","relation"=> Array(ids).compact.uniq.map{|id| {"id"=>id} } }
    def status(val)     = { "type"=>"status","status"=>{"name"=>val_to_s}}
    def num(val)        = { "type"=>"number","number"=>val_to_i}
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

end #<class>