=begin
    Script:     EneoBwSpc_ChkFields
    Function:   Check specific fields on each table
    Call:       ruby script.rb =>
        echo "Gestionnaire" | ruby script.rb --json Data_Sources_ID.json
        echo "ActPrc"       | ruby script.rb --json Data_Sources_ID.json --examples 5 --missing 20
            examples:   max lines to display
            missing:    max lines to display
=end

#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "optparse"

NOTION_TOKEN   = 'secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3'
NOTION_VERSION = '2025-09-03'
BASE = "https://api.notion.com/v1"

DRY_RUN = false

# Options
    # Default
    options = {
    json_file: "Data_Sources_ID.json",
    max_examples: 5,
    max_missing: 50,
    all_values: false,
    max_relation_titles: 30
    }
    # from call command
    OptionParser.new do |opts|
    opts.on("--json FILE", "Fichier data_sources.json") { |v| options[:json_file] = v }
    opts.on("--examples N", Integer, "Nb max d'exemples de valeurs") { |v| options[:max_examples] = v }
    opts.on("--missing N", Integer, "Nb max de pages vides listées") { |v| options[:max_missing] = v }
    opts.on("--all-values", "Affiche toutes les valeurs non vides (verbeux)") { options[:all_values] = true }
    opts.on("--relmax N", Integer, "Nb max de titres affichés pour une relation") { |v| options[:max_relation_titles] = v }
    end.parse!

# Logger
require 'logger'
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    logger.datetime_format = '%H:%M:%S'
    logger.info "🔧 Mode: #{DRY_RUN ? 'DRY-RUN (simulation)' : 'PRODUCTION'}"

    # Get values
#    field = STDIN.read.to_s.strip
    print   "Introduisez le nom du champ à vérifier ? "
    field   = $stdin.gets.chomp.strip   if field.nil?
    abort "Entrée vide. Attendu: NomDePropriete (ex: Gestionnaire)" if field.empty?
    # Get IDs
    data_sources = JSON.parse(File.read(options[:json_file]))

#
# Classes
#********
class NotionClient
    def initialize(token:, notion_version:)
        @token = token
        @notion_version = notion_version
    end

    def retrieve_data_source(id)
        get_json("#{BASE}/data_sources/#{id}")
    end

    def query_data_source(id, start_cursor: nil, page_size: 100)
        body = { page_size: page_size }
        body[:start_cursor] = start_cursor if start_cursor
        post_json("#{BASE}/data_sources/#{id}/query", body)
    end

    def retrieve_page(page_id)
        get_json("#{BASE}/pages/#{page_id}")
    end

    private

    def headers
        {
            "Authorization" => "Bearer #{@token}",
            "Notion-Version" => @notion_version,
            "Content-Type" => "application/json",
            "Accept" => "application/json"
        }
    end

    def get_json(url)
        uri = URI(url)
        req = Net::HTTP::Get.new(uri, headers)
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
        raise "HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)
    end

    def post_json(url, payload)
        uri = URI(url)
        req = Net::HTTP::Post.new(uri, headers)
        req.body = JSON.generate(payload)
        res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(req) }
        raise "HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)
    end
end #<class>

#
# Functions
#**********
    def page_title_any(page)
        props = page["properties"] || {}
        title_prop = props.values.find { |p| p.is_a?(Hash) && p["type"] == "title" }
        return "(sans titre)" unless title_prop

        arr = title_prop["title"] || []
        txt = arr.map { |x| x["plain_text"] }.compact.join
        txt.empty? ? "(sans titre)" : txt
    end

    def format_value(prop_value)
        return nil if prop_value.nil?

        type = prop_value["type"]
        v = prop_value[type]

        case type
        when "title"
            txt = Array(v).map { |x| x["plain_text"] }.join
            txt.empty? ? nil : txt

        when "rich_text"
            txt = Array(v).map { |x| x["plain_text"] }.join
            txt.empty? ? nil : txt

        when "number"
            v.nil? ? nil : v

        when "checkbox"
            v == true ? "true" : (v == false ? "false" : nil)

        when "select"
            v.nil? ? nil : v["name"]

        when "multi_select"
            arr = Array(v).map { |x| x["name"] }.compact
            arr.empty? ? nil : arr.join(", ")

        when "status"
            v.nil? ? nil : v["name"]

        when "email", "url", "phone_number"
            v.to_s.empty? ? nil : v

        when "date"
            return nil if v.nil?
            v["end"] ? "#{v["start"]} → #{v["end"]}" : v["start"]

        when "people"
            arr = Array(v).map { |u| u["name"] || u["id"] }.compact
            arr.empty? ? nil : arr.join(", ")

        when "relation"
            arr = Array(v)
            arr.empty? ? nil : { "__relation__" => arr }

        when "files"
            arr = Array(v).map { |f| f["name"] }.compact
            arr.empty? ? nil : arr.join(", ")

        else
            v.nil? ? nil : "[#{type}]"
        end
    end

    def relation_titles(client, relation_array, cache, max_titles:)
        ids = Array(relation_array).map { |r| r["id"] }.compact
        return nil if ids.empty?

        titles = []
        ids.first(max_titles).each do |pid|
            if cache.key?(pid)
                titles << cache[pid]
                next
            end
            page = client.retrieve_page(pid)
            t = page_title_any(page)
            cache[pid] = t
            titles << t
        end

        more = ids.size > max_titles ? " …(+#{ids.size - max_titles})" : ""
        titles.join(" | ") + more
    end

#
# Main code
#**********
    logger.info "=" * 50
    logger.info "🌹 Start of script"

    # Init instance
    client = NotionClient.new(token: NOTION_TOKEN, notion_version: NOTION_VERSION)

    relation_cache = {}

    puts "Champ: #{field}"
    puts

    # Loop data_sources
    #------------------
    data_sources.each do |ds|
        ds_id = ds.fetch("id")
        ds_name = ds["name"] || ds_id

        begin
            # Retrieve data_sources infos
            meta = client.retrieve_data_source(ds_id)

            pp meta
            exit 9
            
            schema = meta["properties"] || meta["schema"] || {}

            puts "=== #{ds_name} (#{ds_id}) ==="

            unless schema.key?(field)
                puts "Champ ABSENT"
                puts
                next    # next data_source
            end

            puts "Champ PRESENT"
            puts "Type: #{schema[field]["type"] rescue "?"}"

            # Process all records
            total = 0
            with_value = 0
            missing_pages = []
            value_examples = []

            cursor = nil
            loop do
                # Get all pages of current data_source
                q = client.query_data_source(ds_id, start_cursor: cursor, page_size: 100)
                results = q["results"] || []

                results.each do |page|
                    total += 1
                    pv = page.dig("properties", field)
                    val = format_value(pv)

                    # garde-fou (ton bug précédent)
                    if val.is_a?(Symbol)
                        raise "BUG: val est un Symbol=#{val.inspect} (pv.type=#{pv && pv["type"]})"
                    end

                    if val.is_a?(Hash) && val.key?("__relation__")
                        val = relation_titles(client, val["__relation__"], relation_cache, max_titles: options[:max_relation_titles])
                    end

                    if val.nil?
                        if missing_pages.size < options[:max_missing]
                            missing_pages << { "url" => page["url"], "title" => page_title_any(page) }
                        end
                    else
                        with_value += 1
                        if options[:all_values] || value_examples.size < options[:max_examples]
                            value_examples << { "url" => page["url"], "title" => page_title_any(page), "value" => val }
                        end
                    end
                end

                break unless q["has_more"]
                cursor = q["next_cursor"]
                break if cursor.nil?
            end

            # Display results
            puts "Stats: #{with_value}/#{total} pages avec valeur"

            unless value_examples.empty?
                puts "- Exemples de valeurs (#{value_examples.size}):"
                value_examples.each do |ex|
                    puts "  - #{ex["title"]} | #{ex["value"]} | #{ex["url"]}"
                end
            end

            if total > with_value
                puts "- Pages SANS valeur (échantillon #{missing_pages.size}):"
                missing_pages.each do |p|
                    puts "  - #{p["title"]} | #{p["url"]}"
                end
            end

            puts
        rescue => e
            puts "ERREUR: #{e.message}"
            puts
        end
    end

    logger.info "🥵 End of script"
    logger.info "=" * 50
