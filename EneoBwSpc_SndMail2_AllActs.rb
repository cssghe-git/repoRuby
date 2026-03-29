# frozen_string_literal: true
#
=begin
    Function:   send mails to all activities if requested
    Call:       ruby EneoBwSpc_SndMail2_AllActs.rb --exec=B/P --debug=INFO
=end

require "json"
require "httparty"
require "mail"
require "cgi"
require "time"
require 'optparse'

require 'logger'
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

NOTION_TOKEN    = "secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3"
NOTION_VERSION  = "2025-09-03"
NOTION_URI      = "https://api.notion.com/v1"

CONFIG = JSON.parse(File.read(File.join(__dir__, "Data_Sources_ID2.json")))
DATA_SOURCE_ID = CONFIG.find { |h| h.key?("m25t.Activités") }&.fetch("m25t.Activités")
DRY_RUN = true
ATTACH_DIR = "/users/Gilbert/Public/MemberLists/Works"
ENVBUILD    = ENV.fetch("BUILD","None")

    options = {
        exec:       ENV.fetch("EXE","P"),
        debug:      ENV.fetch("DEBUG","INFO"),
        username:   ENV.fetch("SMTP_USER","None"),
        password:   ENV.fetch("SMTP_PWD","None")
    }
    # from command line
    OptionParser.new do |opts|
        opts.on("--exec B",String,"Processing mode") do |v| options[:exec] = v end
        opts.on("--debug INFO",String,"Debug mode"){|v| options[:debug] = v}
    end.parse!  #<OptionParser>

    # --- Logger ---
require 'logger'
    log                 = Logger.new(STDOUT)
    log.level           = Logger::INFO
    log.datetime_format = '%H:%M:%S'
    log.info "🔧 Mode: #{DRY_RUN ? 'DRY-RUN (simulation)' : 'PRODUCTION'} - ENV:#{ENVBUILD} ..."

    log.info("#{$0} is starting...")

    # --- SMTP (à adapter) ---
    log.info("Init=> set SMTP link")
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

# Class define
#=============
class NotionClient
        include HTTParty
        base_uri NOTION_URI

    def initialize(token:)
        @headers = {
            "Authorization" => "Bearer #{token}",
            "Notion-Version" => NOTION_VERSION,
            "Content-Type" => "application/json"
        }
    end

    # API Notion
    #===========
    # Query a data_source
    def query_data_source(data_source_id:, start_cursor: nil)
        body = {}
        body[:start_cursor] = start_cursor if start_cursor
        self.class.post("/data_sources/#{data_source_id}/query", headers: @headers, body: body.to_json)
    end
    # Retrieve a block
    def retrieve_block(block_id)
        self.class.get("/blocks/#{block_id}", headers: @headers)
    end

    # Retrieve block children
    def list_block_children(block_id, start_cursor: nil)
        q = {}
        q[:start_cursor] = start_cursor if start_cursor
        self.class.get("/blocks/#{block_id}/children", headers: @headers, query: q)
    end
    # Update page
    def update_page_date_envoi(page_id, iso_datetime)
        body = {
            properties: {
                "Date envoi" => {
                    date: { start: iso_datetime }
                }
            }
        }
        self.class.patch("/pages/#{page_id}", headers: @headers, body: body.to_json)
    end
end #<class>

# Internal methods
#=================
    def extract_prop(page, prop_name)
        prop = page.dig("properties", prop_name)
        return nil unless prop

        case prop["type"]
        when "title"
            (prop["title"] || []).map { |t| t["plain_text"] }.join
        when "email"
            prop["email"]
        when "url"
            prop["url"]
        when "checkbox"
            prop["checkbox"]
        else
            nil
        end
    end #<def>

    def parse_recipients(email_field)
        email_field.to_s
            .split(",")
            .map(&:strip)
            .reject(&:empty?)
    end

    def notion_url_to_block_id(url)
        s = url.to_s
        return nil if s.strip.empty?
        id = s.scan(/[0-9a-fA-F]{32}/).first
        id
    end

    def rich_text_to_plain(rt)
        (rt || []).map { |x| x["plain_text"] }.join
    end

    def block_to_html(block)
        type = block["type"]

        case type
        when "paragraph"
            txt = rich_text_to_plain(block.dig("paragraph", "rich_text"))
            return "" if txt.strip.empty?
            "<p>#{CGI.escapeHTML(txt)}</p>\n"

        when "heading_1", "heading_2", "heading_3"
            txt = rich_text_to_plain(block.dig(type, "rich_text"))
            return "" if txt.strip.empty?
            tag = { "heading_1"=>"h1", "heading_2"=>"h2", "heading_3"=>"h3" }[type]
            "<#{tag}>#{CGI.escapeHTML(txt)}</#{tag}>\n"

        when "bulleted_list_item"
            txt = rich_text_to_plain(block.dig("bulleted_list_item", "rich_text"))
            return "" if txt.strip.empty?
            "<ul><li>#{CGI.escapeHTML(txt)}</li></ul>\n"

        when "numbered_list_item"
            txt = rich_text_to_plain(block.dig("numbered_list_item", "rich_text"))
            return "" if txt.strip.empty?
            "<ol><li>#{CGI.escapeHTML(txt)}</li></ol>\n"

        else
            ""
        end
    end

    def fetch_block_and_children_as_html(notion, block_id)
        root = notion.retrieve_block(block_id)
        raise "Notion retrieve_block error: #{root.code} #{root.body}" unless root.code.between?(200, 299)
        root_block = root.parsed_response

        html = +""
        html << block_to_html(root_block)

        if root_block["has_children"]
            cursor = nil
            loop do
                resp = notion.list_block_children(block_id, start_cursor: cursor)
                raise "Notion children error: #{resp.code} #{resp.body}" unless resp.code.between?(200, 299)
                data = resp.parsed_response

                (data["results"] || []).each do |b|
                    html << block_to_html(b)
                end

                cursor = data["next_cursor"]
                break unless data["has_more"]
            end
        end

        html
    end

    def find_single_attachment_optional(ref)
        return nil if ref.to_s.strip.empty?

        pattern = File.join(ATTACH_DIR, "*#{ref}*")
        matches = Dir.glob(pattern).select { |p| File.file?(p) }

        return nil if matches.empty?               # => pas de PJ, on envoie quand même
        return matches.first if matches.size == 1  # => PJ OK

        system("say 'Attention, sélection obligatoire'")
        puts  "Plusieurs fichiers correspondent à '#{ref}': #{matches.join(", ")}"
        index = 0
        matches.each do |item|
            puts    "#{index + 1} => #{item}"
            index   += 1
        end
        print "Please enter your choice ? "
        reply = $stdin.gets.chomp.to_i
        return    nil if reply == 0
        return    nil if reply > index
        return    matches[index-1]
    end

    def send_email(to_list:, subject:, html_body:, attachment_path:)
        Mail.deliver do
            from    ENV.fetch("MAIL_FROM", "benevolat@heintje.be")
            to      to_list
            subject subject

            html_part do
                content_type "text/html; charset=UTF-8"
                body html_body
            end

            add_file attachment_path if attachment_path
        end
    end

# Main code
#==========
    # Init
    log.info("Init=>New instance of Notion api")
    notion = NotionClient.new(token: NOTION_TOKEN)

    # Attachment file
    print   "Enter left part of filename to attach : ? "
    ref_attach  = $stdin.gets.chomp.to_s
#    return  if ref_attach.empty?

    # Start
    log.info("Loop all pages")

    # Loop all persons
    cursor = nil
    loop do
        # Extract all pages
        resp = notion.query_data_source(data_source_id: DATA_SOURCE_ID, start_cursor: cursor)
        raise "Notion query error: #{resp.code} #{resp.body}" unless resp.code.between?(200, 299)
        data = resp.parsed_response

        # process 1 page
        (data["results"] || []).each do |page|
            # extratc properties
            page_id   = page["id"]
            ref       = extract_prop(page, "Référence")              # title[^notion-4]
            texte_url = extract_prop(page, "Texte")                  # url[^notion-4]
            email_raw = extract_prop(page, "Email responsable(s)")   # email[^notion-4]
            send_flag = extract_prop(page, "Envoi email")            # checkbox[^notion-4]

            log.info("--Process #{ref} page")
            # checks
            next unless send_flag
            next if texte_url.to_s.strip.empty?
            next if email_raw.to_s.strip.empty?

            recipients = parse_recipients(email_raw)
            next if recipients.empty?

            log.info("-- --Get text bloc & sub-blocks")
            # Extract text to mail
            block_id = notion_url_to_block_id(texte_url)
            raise "Texte URL ne contient pas d'ID bloc exploitable (Référence=#{ref}): #{texte_url}" if block_id.nil?
            # Convert inti html formar
            html = fetch_block_and_children_as_html(notion, block_id)
            next if html.to_s.strip.empty?
            log.info("-- -- --Text bloc & sub-blocks => #{html[0..100]}")

            log.info("-- --Get attachment file if any")
            # load attachment
            attachment = find_single_attachment_optional(ref_attach)
            log.info("-- -- -- Attachment file => #{attachment}")

            log.info("-- --Send email")
            # Send mail
            subject = "Eneo-Nivelles – #{ref}"
            send_email(to_list: recipients, subject: subject, html_body: html, attachment_path: attachment)
            log.info("-- -- --Email sent to => #{recipients}")

            log.info("-- --Update page with send date")
            # Update page
            now_iso = Time.now.iso8601
            upd = notion.update_page_date_envoi(page_id, now_iso)
            raise "Update Date envoi failed: #{upd.code} #{upd.body}" unless upd.code.between?(200, 299)

            log.info("-- sleep a while")
            sleep (5)                                   #wait 5 secs
        end #<loop>

        # next range of pages if any
        cursor = data["next_cursor"]
        break unless data["has_more"]
    end

    # Exit
    log.info("#{$0} is done, byebye")
