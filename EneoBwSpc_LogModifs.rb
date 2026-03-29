#!/usr/bin/env ruby
# frozen_string_literal: true

require "net/http"
require "json"
require "time"
require "optparse"
require "logger"
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

# ---------------------------
# Config
# ---------------------------
# Logger
    log                 = Logger.new(STDOUT)
    log.level           = :INFO
    log.datetime_format = '%H:%M:%S'

NOTION_API      = ENV.fetch("NOT_HTTPBASE")
NOTION_VERSION  = ENV.fetch("NOT_APIVER")
NOTION_TOKEN    = ENV.fetch('NOT_APITOKEN')

MOD_DATABASE_ID = "2f472117-082a-80d1-b7d7-000b1fdd413d" # m25t.Modifs_daily

STATE_FILE_DEFAULT = File.expand_path("./modifs_daily_state.json")
BUFFER_SECONDS_DEFAULT = 120
PAGE_SIZE = 100

    # Data sources to scan (Members_V25)
    SOURCES = {
        "UPD" => "27072117-082a-80ca-a7b5-000b8e391b8c", # m25t.Updates
        "MBR" => "26872117-082a-8066-99bd-000beaa5de5e", # m25t.Membres
        "MAJ" => "26872117-082a-808c-a7c4-000b69a3bf7e", # m25t.MisesAJour
        "COT" => "26872117-082a-8009-b57e-000b5a14d79e", # m25t.Cotisations
        "PRJ" => "28a72117-082a-80d4-9f55-000b2a23a6ab"  # m25t.Projets
    }.freeze

    # Title property name per data source (Notion property type = title)
    TITLE_PROP = {
        "UPD" => "Référence",
        "MBR" => "Référence",
        "MAJ" => "Référence",
        "COT" => "Référence",
        "PRJ" => "Référence"
    }.freeze

    # Activity property per data source (Notion property type = select)
    ACTIVITY_PROP = {
        "UPD" => "Activité principale",
        "MBR" => "Activité principale",
        "MAJ" => "Activité principale",
        "COT" => "Activité",          # COT uses "Activité" (select)
        "PRJ" => nil                  # Projets: no activity field
    }.freeze

# ---------------------------
# HTTP helpers
# ---------------------------
    def notion_post(path, payload)
        uri = URI("#{NOTION_API}#{path}")
        req = Net::HTTP::Post.new(uri)
        req["Authorization"]  = "Bearer #{NOTION_TOKEN}"
        req["Notion-Version"] = NOTION_VERSION
        req["Content-Type"]   = "application/json"
        req.body = JSON.dump(payload)

        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
        raise "Notion POST failed: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)

        JSON.parse(res.body)
    end

# ---------------------------
# State
# ---------------------------
    def load_state(path)
        return { "last_successful_run_at" => nil, "runs" => [] } unless File.exist?(path)
        JSON.parse(File.read(path))
        rescue JSON::ParserError
        { "last_successful_run_at" => nil, "runs" => [] }
    end

    def save_state(path, state)
        File.write(path, JSON.pretty_generate(state))
    end

# ---------------------------
# Formatting
# ---------------------------
    def build_mod_name(last_edited_at_iso, source, ref_titre)
        t = Time.parse(last_edited_at_iso).getlocal
        "#{t.strftime("%Y-%m-%d %H:%M")} | #{source} | #{ref_titre}"
    end

# ---------------------------
# Extractors
# ---------------------------
    def extract_title(page, title_prop_name)
        prop = page.dig("properties", title_prop_name)
        return "" unless prop && prop["type"] == "title"
        (prop["title"] || []).map { |t| t["plain_text"] }.join
    end

    def extract_select_name(page, prop_name)
        return nil if prop_name.nil?
        prop = page.dig("properties", prop_name)
        return nil unless prop && prop["type"] == "select"
        prop.dig("select", "name")
    end

# ---------------------------
# Query pages modified since (API last_edited_time)
# ---------------------------
    def query_modified_pages(data_source_id:, since_iso:, start_cursor: nil)
        payload = {
            page_size: PAGE_SIZE,
            filter: {
            timestamp: "last_edited_time",
            last_edited_time: { on_or_after: since_iso }
            }
        }
        payload[:start_cursor] = start_cursor if start_cursor

        notion_post("/data_sources/#{data_source_id}/query", payload)
    end

# ---------------------------
# Dedup in MOD
# key = Source + Page URL + Last edited at
# ---------------------------
    def mod_entry_exists?(source:, page_url:, last_edited_at_iso:)
        payload = {
            filter: {
            and: [
                { property: "Source", select: { equals: source } },
                { property: "Page URL", url: { equals: page_url } },
                { property: "Last edited at", date: { equals: last_edited_at_iso } }
            ]
            },
            page_size: 1
        }

        data = notion_post("/data_sources/#{MOD_DATABASE_ID}/query", payload)
        data.fetch("results").any?
    end

    def create_mod_entry!(source:, page_url:, ref_titre:, last_edited_at_iso:, run_at_iso:, activity: nil)
        name = build_mod_name(last_edited_at_iso, source, ref_titre)

        props = {
            "Name" => { title: [{ text: { content: name } }] },
            "Source" => { select: { name: source } },
            "Page URL" => { url: page_url },
            "Ref/Titre" => { rich_text: [{ text: { content: ref_titre.to_s } }] },
            "Run at" => { date: { start: run_at_iso } },
            "Last edited at" => { date: { start: last_edited_at_iso } }
        }

        # Only write Activité if we have a value (and the option exists in Notion)
        if activity && !activity.strip.empty?
            props["Activité"] = { select: { name: activity } }
        end

        payload = {
            parent: { data_source_id: MOD_DATABASE_ID },
            properties: props
        }

        notion_post("/pages", payload)
    end

    def log_if_new!(source:, page_url:, ref_titre:, last_edited_at_iso:, run_at_iso:, activity: nil)
        return false if mod_entry_exists?(source: source, page_url: page_url, last_edited_at_iso: last_edited_at_iso)

        create_mod_entry!(
            source: source,
            page_url: page_url,
            ref_titre: ref_titre,
            last_edited_at_iso: last_edited_at_iso,
            run_at_iso: run_at_iso,
            activity: activity
        )
        true
    end

# ---------------------------
# Main (CLI)
# ---------------------------
    puts
    log.info("#{$0} is starting...")
    log.info("=>Load options & values")
    options = {
        mode: false,
        state: STATE_FILE_DEFAULT,
        buffer: BUFFER_SECONDS_DEFAULT,
        since: nil,
        dry_run: false
    }

    OptionParser.new do |opts|
        opts.banner = "Usage: modifs_daily.rb [options]"

        opts.on("--auto", "No flags") { options[:auto] = false }
        opts.on("--state FILE", "State JSON file (default: #{STATE_FILE_DEFAULT})") { |v| options[:state] = v }
        opts.on("--buffer SECONDS", Integer, "Buffer seconds (default: #{BUFFER_SECONDS_DEFAULT})") { |v| options[:buffer] = v }
        opts.on("--since ISO8601", "Override since (ISO8601). Example: 2026-02-06T00:00:00+01:00") { |v| options[:since] = v }
        opts.on("--dry-run", "No writes to MOD") { options[:dry_run] = true }
    end.parse!

    env_token   = ENV.fetch("NOT_APITOKEN")
    token = options[:token] || env_token
    raise "Missing token. Use --token or set NOTION_API_TOKEN." if token.to_s.strip.empty?
    log.info("Options:#{options}")
    #
    run_at = Time.now.getlocal
    run_at_iso = run_at.iso8601

    state = load_state(options[:state])

    since_iso =
        if options[:since]
            options[:since]
        elsif state["last_successful_run_at"]
            (Time.parse(state["last_successful_run_at"]) - options[:buffer]).getlocal.iso8601
        else
            # first run: last 24h by default
            (Time.now - 24 * 3600).getlocal.iso8601
        end

    stats_found = Hash.new(0)
    inserted = 0
    errors = []

    puts "Run at:  #{run_at_iso}"
    puts "Since:   #{since_iso}"
    puts "Dry-run: #{options[:dry_run]}"
    puts "State:   #{options[:state]}"
    puts

    log.info("=>Fetch updates from sources")
    SOURCES.each do |source_key, data_source_id|
        log.info("=>Fetch from #{source_key}")
        title_prop = TITLE_PROP.fetch(source_key)
        activity_prop = ACTIVITY_PROP[source_key]
        inserted    = 0

        cursor = nil
        loop do
            log.info("=>Check batch")
            action  = "Query"
            data = query_modified_pages(data_source_id: data_source_id, since_iso: since_iso, start_cursor: cursor)
            pages = data.fetch("results")
            stats_found[source_key] += pages.length

            pages.each do |p|
                action  = "Fetch page"
                page_url = p.fetch("url")
                last_edited_at_iso = p.fetch("last_edited_time")

                ref_titre = extract_title(p, title_prop)
                ref_titre = "(sans titre)" if ref_titre.to_s.strip.empty?

                activity = extract_select_name(p, activity_prop)

                if options[:dry_run]
                    next
                end
                action  = "Log to MOD if any"
                begin
                    created = log_if_new!(
                        source: source_key,
                        page_url: page_url,
                        ref_titre: ref_titre,
                        last_edited_at_iso: last_edited_at_iso,
                        run_at_iso: run_at_iso,
                        activity: activity
                    )
                    inserted += 1 if created
                    print "Inserted: . " if inserted == 1
                    print ". "              if inserted > 1
                rescue => e
                    puts    "Error for action: #{action}"
                    errors << { source: source_key, page: page_url, error: e.message }
                end
            end

            break unless data["has_more"]
            cursor = data["next_cursor"]
        end
        log.info("#{source_key}=> #{inserted} updates")
    end

    duration_s = (Time.now - run_at).round(2)

    run_record = {
        "run_at" => run_at_iso,
        "since" => since_iso,
        "found" => stats_found,
        "inserted" => inserted,
        "errors" => errors.length,
        "duration_s" => duration_s
    }

    state["runs"] ||= []
    state["runs"] << run_record

    # mark success only if no errors (tweak if you prefer)
    state["last_successful_run_at"] = run_at_iso if errors.empty?

    log.info("=>Save new run")
    while   state['runs'].count > 5
        state['runs'].shift
    end
    save_state(options[:state], state)

    puts "Found:    #{stats_found}"
    puts "Inserted: #{inserted}"
    puts "Errors:   #{errors.length}"
    puts

    if errors.any?
        puts "--- Errors (first 10) ---"
        errors.first(10).each { |er| puts "#{er[:source]} #{er[:page]} -> #{er[:error]}" }
    end
    log.info("#{$0} is done")