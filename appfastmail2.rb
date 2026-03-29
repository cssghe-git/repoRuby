# appfastmail_v2.rb
=begin
  V2 : utilise Email/changes + queryState pour ne traiter que les nouveaux mails.
  Modes : tests (par défaut), print, notion, sinatra.
=end

require "json"
require "net/http"
require "uri"
require "time"
require "timeout"
require "optparse"
require "notion-ruby-client"
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end
require "logger"

#-----------------------------
# Options
#-----------------------------
    OPTIONS = {
    mode: "tests",
    sleep: 60
    }
    OptionParser.new do |o|
        o.banner = "Usage: ruby appfastmail_v2.rb [options]"
        o.on("--mode=MODE", %w[tests print notion sinatra], "tests|print|notion|sinatra") { |v| OPTIONS[:mode] = v }
        o.on('--limit=N', Integer, 'Timeout') { |v| OPTIONS[:sleep] = v }
    end.parse!(ARGV)

#-----------------------------
# Constantes
#-----------------------------
LOGGER_LEVEL        = ENV.fetch("DEBUG","INFO")
FASTMAIL_TOKEN      = ENV.fetch("FASTMAIL_TOKEN")
SESSION_URL         = ENV.fetch("FASTMAIL_SESSION_URL", "https://api.fastmail.com/jmap/session")
SINATRA_WEBHOOK_URL = ENV.fetch("SINATRA_WEBHOOK_URL", "").strip
NOTION              = Notion::Client.new(token: ENV.fetch("NOT_APITOKEN"))
DB_ID               = ENV.fetch("DB_EMAILS")
STATE_FILE          = "email_state.json"

#-----------------------------
# Logger
#-----------------------------
    log                 = Logger.new(STDOUT)
    log.level           = Logger::INFO
    log.datetime_format = '%H:%M:%S'
    log.info("🔧 Mode: #{OPTIONS[:mode]}")

#-----------------------------
# Helpers
#-----------------------------
    def jmap_request(api_url, body)
        uri = URI(api_url)
        req = Net::HTTP::Post.new(uri)
        req["Content-Type"]  = "application/json; charset=utf-8"
        req["Accept"]        = "application/json"
        req["Authorization"] = "Bearer #{FASTMAIL_TOKEN}"
        req.body             = JSON.dump(body)

        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
            res = http.request(req)
            raise "JMAP error: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
            JSON.parse(res.body)
        end
    end

    def get_session
        uri = URI(SESSION_URL)
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Bearer #{FASTMAIL_TOKEN}"
        req["Accept"]        = "application/json"

        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
            res = http.request(req)
            raise "Session error: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
            JSON.parse(res.body)
        end
    end

    def create_email_page(mail)
        NOTION.create_page(
            parent: { database_id: DB_ID },
            properties: {
            "Reference" => {
                "title" => [
                { "text" => { "content" => (mail[:subject] || "(sans sujet)") } }
                ]
            },
            "From" => {
                "rich_text" => [
                { "text" => { "content" => (mail[:from] || "None") } }
                ]
            },
            "To" => {
                "rich_text" => [
                { "text" => { "content" => (mail[:to] || "None")[0, 1000] } }
                ]
            },
            "Email Meta" => {
                "rich_text" => [
                { "text" => { "content" => (mail[:meta] || "None")[0, 1900] } }
                ]
            },
            "Email Body" => {
                "rich_text" => [
                { "text" => { "content" => (mail[:text] || "None")[0, 1900] } }
                ]
            },
            "Date" => {
                "date" => { "start" => mail[:date].iso8601 }
            },
            },
            children: [
            {
                "object" => "block",
                "type" => "paragraph",
                "paragraph" => {
                "rich_text" => [
                    {
                    "type" => "text",
                    "text" => {
                        "content" => (mail[:text] || "")[0, 1950]
                    }
                    }
                ]
                }
            }
            ]
        )
    end

    def print_email_page(export)
        puts ">>>>>>>>>>*****>🆘>E-mail<🆘<*****<<<<<<<<<<"
        puts "**Sender:      #{export[:from]}"
        puts "**Receiver:    #{export[:to]}"
        puts "**Subject:     #{export[:subject]}"
        puts "**Date:        #{export[:date]}"
        puts "**Body:        #{export[:body]}"
        puts "**Meta:        #{export[:meta]}"
        puts "**ID:          #{export[:message_id]}"
        puts "**Text (500):  #{export[:text][0, 1000]}"
        puts ">>>>>>>>>>*****>🆘>E-mail<🆘<*****<<<<<<<<<<"
    end

    def wait(seconds, interruptible, log)
        if interruptible
            log.info("Waiting #{seconds} seconds... (Press 'q' and Enter to quit)")
            begin
                Timeout.timeout(seconds) do
                    input = $stdin.gets&.chomp
                    return input
                end
            rescue Timeout::Error
                return nil
            end
        else
            sleep(seconds)
            return nil
        end
    end

    def load_state
        return nil unless File.exist?(STATE_FILE)
        JSON.parse(File.read(STATE_FILE))["mailsids"]
    end

    def save_state(state)
        File.write(STATE_FILE, JSON.dump({ "mailsids" => state }))
    end

    def build_payload_from_email(mail)
        from_list = mail["from"] || []
        to_list   = mail["to"]   || []

        from_name  = from_list.first && from_list.first["name"]
        from_email = from_list.first && from_list.first["email"]
        to_name    = to_list.first && to_list.first["name"]
        to_email   = to_list.first && to_list.first["email"]

        from_str = from_name && !from_name.to_s.empty? ? "#{from_name} <#{from_email}>" : from_email
        to_str   = to_name && !to_name.to_s.empty? ? "#{to_name} <#{to_email}>" : to_email

        text_body_parts = mail["textBody"]   || []
        body_values     = mail["bodyValues"] || {}

        full_text = text_body_parts.map { |part|
            part_id = part["partId"]
            bv      = body_values[part_id] || {}
            bv["value"] || ""
        }.join("\n\n")

        payload = {
            "headers" => {
            "from"       => [from_str],
            "to"         => [to_str],
            "subject"    => mail["subject"],
            "date"       => mail["receivedAt"],
            "message_id" => mail["id"]
            },
            "text" => {
            "content" => full_text,
            "quote"   => ""
            },
            "files_count" => 0,
            "files"       => []
        }

        export = {
            from:       from_str,
            to:         to_str,
            subject:    mail["subject"],
            text:       full_text,
            body:       full_text,
            meta:       "Source::Fastmail JMAP",
            date:       mail["receivedAt"] && Time.parse(mail["receivedAt"]) || Time.now,
            message_id: mail["id"]
        }

        [payload, export]
    end

    def send_to_sinatra(payload, log)
        return if SINATRA_WEBHOOK_URL.empty?
        uri = URI(SINATRA_WEBHOOK_URL)
        req = Net::HTTP::Post.new(uri)
        req["Content-Type"] = "application/json"
        req.body            = JSON.dump(payload)

        Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
            res = http.request(req)
            log.info "Pushed email #{payload["headers"]["message_id"]} => #{res.code}"
        end
    end

    def handle_email(mail, log)
        payload, export = build_payload_from_email(mail)

        case OPTIONS[:mode]
        when "print"
            log.info("Print email from #{export[:from]}")
            print_email_page(export)
        when "notion"
            log.info("Create Notion page from #{export[:from]}")
            create_email_page(export)
        when "sinatra"
            log.info("Sinatra webhook from #{export[:from]}")
            send_to_sinatra(payload, log)
        else # "tests"
            log.info("Test mode - email #{export[:subject].inspect} (no action)")
        end
    end

#-----------------------------
# Main
#-----------------------------
    log.info("#{$0} is starting...")
    #-----------------------------
    # First request : get session
    #-----------------------------
    log.info("step 1: Récupérer session, apiUrl et accountId")
    session    = get_session
    api_url    = session["apiUrl"]   # ex: https://api.fastmail.com/jmap/api/
    account_id = session["primaryAccounts"]["urn:ietf:params:jmap:mail"]
    log.info("apiUrl: #{api_url} - accountId: #{account_id}")

    #-----------------------------
    # Second request : get mailbox <INBOX> ID
    #-----------------------------
    log.info("step 2: Récupérer l’ID de la mailbox INBOX")
    body_mailbox = {
        "using" => [
            "urn:ietf:params:jmap:core",
            "urn:ietf:params:jmap:mail"
        ],
        "methodCalls" => [
            [
            "Mailbox/get",
            { "accountId" => account_id },
            "c1"
            ]
        ]
    }
    res_mailbox   = jmap_request(api_url, body_mailbox)
    mailbox_resp  = res_mailbox["methodResponses"].find { |m| m[0] == "Mailbox/get" }[1]
    mailboxes     = mailbox_resp["list"]
    inbox         = mailboxes.find { |m| m["role"] == "inbox" } || mailboxes.find { |m| m["name"] == "Inbox" }
    raise "INBOX not found" unless inbox
    inbox_id    = inbox["id"]
    log.info("INBOX id: #{inbox_id}")
    puts

    #-----------------------------
    # Premier run : Email/query + Email/get pour bootstrap + queryState
    #-----------------------------
    last_state = load_state
    if last_state.nil?
        log.warn("No previous state, doing initial Email/query (bootstrap)")
        body_email_query = {
            "using" => [
                "urn:ietf:params:jmap:core",
                "urn:ietf:params:jmap:mail"
            ],
            "methodCalls" => [
            [
                "Email/query",
                {
                "accountId" => account_id,
                "filter"    => { "inMailbox" => inbox_id },
                "sort"      => [ { "property" => "receivedAt", "isAscending" => false } ],
                "limit"     => 10
                },
                "c1"
            ]
            ]
        }

        res_email_query = jmap_request(api_url, body_email_query)
        email_query     = res_email_query["methodResponses"].find { |m| m[0] == "Email/query" }[1]
        ids             = email_query["ids"] || []
        query_state     = email_query["queryState"]
        save_state(query_state)
        log.info("Initial queryState saved: #{query_state}")
        log.info("Bootstrap: #{ids.size} emails")

        unless ids.empty?
            body_email_get = {
            "using" => [
                "urn:ietf:params:jmap:core",
                "urn:ietf:params:jmap:mail"
            ],
            "methodCalls" => [
                [
                "Email/get",
                {
                    "accountId"           => account_id,
                    "ids"                 => ids,
                    "properties"          => ["id","subject","from","to","receivedAt","textBody","htmlBody","bodyValues"],
                    "bodyProperties"      => ["partId","type","size"],
                    "fetchTextBodyValues" => true,
                    "maxBodyValueBytes"   => 20000
                },
                "c2"
                ]
            ]
            }

            res_email_get  = jmap_request(api_url, body_email_get)
            email_get_resp = res_email_get["methodResponses"].find { |m| m[0] == "Email/get" }[1]
            emails         = email_get_resp["list"] || []
            emails.each { |mail| handle_email(mail, log) }
        end
    else
        log.info("Existing state found, skip bootstrap: #{last_state}")
    end

    #-----------------------------
    # Boucle incrémentale Email/changes
    #-----------------------------
    count_loop = 0
    flag_loop  = true
    log.warn("Start of Email/changes loop until exit required")

    while flag_loop
        count_loop += 1
        last_state = load_state
        log.info("loop #{count_loop}: Email/changes sinceState=#{last_state}")

        body_changes = {
            "using" => [
                "urn:ietf:params:jmap:core",
                "urn:ietf:params:jmap:mail"
            ],
            "methodCalls" => [
            [
                "Email/changes",
                {
                "accountId"  => account_id,
                "sinceState" => last_state,
                "maxChanges" => 50
                },
                "c1"
            ]
            ]
        }

        res_changes  = jmap_request(api_url, body_changes)
        responses    = res_changes["methodResponses"]
        log.info("loop #{count_loop}: methodResponses=#{responses.inspect}")

        changes_tuple = responses.find { |m| m[0] == "Email/changes" }
        error_tuple   = responses.find { |m| m[0] == "error" }

        if changes_tuple.nil?
            if error_tuple
                error = error_tuple[1] || {}
                log.warn("loop #{count_loop}: Email/changes error type=#{error["type"]} desc=#{error["description"]}")

                if error["type"] == "cannotCalculateChanges"
                    log.warn("sinceState invalide, re-bootstrap avec Email/query (SANS retraiter l'historique)")

                    body_email_query = {
                        "using" => [
                            "urn:ietf:params:jmap:core",
                            "urn:ietf:params:jmap:mail"
                        ],
                        "methodCalls" => [
                        [
                            "Email/query",
                            {
                            "accountId" => account_id,
                            "filter"    => { "inMailbox" => inbox_id },
                            "sort"      => [ { "property" => "receivedAt", "isAscending" => false } ],
                            "limit"     => 10
                            },
                            "c1"
                        ]
                        ]
                    }

                    res_email_query = jmap_request(api_url, body_email_query)
                    email_query     = res_email_query["methodResponses"].find { |m| m[0] == "Email/query" }[1]
                    query_state     = email_query["queryState"]

                    # NE PAS traiter ids ici, juste se recaler
                    save_state(query_state)
                    log.info("Re-bootstrap: nouveau queryState=#{query_state}, historique ignoré")

                    # on passe directement au prochain tour de boucle (Email/changes repart de ce nouvel état)
                    answer = wait(OPTIONS[:sleep], true, log)
                    flag_loop = false if answer == "q"
                    next
                end

            else
                log.warn("loop #{count_loop}: no Email/changes no error in methodResponses")
            end

            answer = wait(OPTIONS[:sleep], true, log)
            flag_loop = false if answer == "q"
            next
        end

        # ---- cas normal: on a un Email/changes ----
        changes_resp  = changes_tuple[1]
        created_ids   = changes_resp["created"]   || []
        updated_ids   = changes_resp["updated"]   || []
        destroyed_ids = changes_resp["destroyed"] || []
        new_state     = changes_resp["newState"]

        log.info("loop #{count_loop}: created=#{created_ids.size}, updated=#{updated_ids.size}, destroyed=#{destroyed_ids.size}")

        if created_ids.any?
            body_email_get = {
            "using" => [
                "urn:ietf:params:jmap:core",
                "urn:ietf:params:jmap:mail"
            ],
            "methodCalls" => [
                [
                "Email/get",
                {
                    "accountId"           => account_id,
                    "ids"                 => created_ids,
                    "properties"          => ["id","subject","from","to","receivedAt","textBody","htmlBody","bodyValues"],
                    "bodyProperties"      => ["partId","type","size"],
                    "fetchTextBodyValues" => true,
                    "maxBodyValueBytes"   => 20000
                },
                "c2"
                ]
            ]
            }

            res_email_get  = jmap_request(api_url, body_email_get)
            email_get_resp = res_email_get["methodResponses"].find { |m| m[0] == "Email/get" }[1]
            emails         = email_get_resp["list"] || []
            emails.each { |mail| handle_email(mail, log) }
        else
            log.info("loop #{count_loop}: no new emails")
        end

        save_state(new_state)

        answer = wait(OPTIONS[:sleep], true, log)
        flag_loop = false if answer == "q"
    end
