# appfastmail.rb
=begin

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
        o.on('--sleep=N', Integer, 'Timeout') { |v| OPTIONS[:sleep] = v }
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

#
# Variables
#**********
    arr_mailids = []

#
# Functions
#**********
    def jmap_request(api_url, body)
    #+++++++++++++++
    #   send a request to server
    #
        puts    "DBG>Request: #{body}"
        uri = URI(api_url)
        req = Net::HTTP::Post.new(uri)
        req["Content-Type"]  = "application/json; charset=utf-8"
        req["Accept"]        = "application/json"
        req["Authorization"] = "Bearer #{FASTMAIL_TOKEN}"
        req.body             = JSON.dump(body)

        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
            res     = http.request(req)
            raise "JMAP error: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
            puts    "DBG>Response: #{res.body}"
            JSON.parse(res.body)
        end
    end

    def get_session
    #++++++++++++++
    #   get a "session_id"
    #
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
    #++++++++++++++++++++
    #   create a new page on aidt.E-mails
    #
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
            # Décommente si tu ajoutes une propriété "MessageID" dans ta DB Notion
            # "MessageID" => {
            #   "rich_text" => [
            #     { "text" => { "content" => (mail[:message_id] || "")[0, 1900] } }
            #   ]
            # }
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
    #+++++++++++++++++++
    #   print email
    #
        # Display some fields
        puts    ">>>>>>>>>>*****>🆘>E-mail<🆘<*****<<<<<<<<<<"
        puts    "**Sender:      #{export[:from]}"
        puts    "**Receiver:    #{export[:to]}"
        puts    "**Subject:     #{export[:subject]}"
        puts    "**Date:        #{export[:date]}"
        puts    "**Body:        #{export[:body]}"
        puts    "**Meta:        #{export[:meta]}"
        puts    "**ID:          #{export[:message_id]}"
        puts    "**Text (500):  #{export[:text][0, 1000]}"
        puts    ">>>>>>>>>>*****>🆘>E-mail<🆘<*****<<<<<<<<<<"
    end

    def wait(seconds, interruptible, log)
    #+++++++++++++++
    #   sleep 
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

    def build_payload_from_email(mail)
    #+++++++++++++++++++++++++++
    #   format payload & export
    #
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

    def handle_email(mail, log)
    #+++++++++++++++
    #   dispatch for output
    #
        # format payload & export
        payload, export = build_payload_from_email(mail)

        # dispatch
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

    def load_state()
    #+++++++++++++
        return nil unless File.exist?(STATE_FILE)
        JSON.parse(File.read(STATE_FILE))["mailid"]
    end

    def save_state(state)
    #+++++++++++++
        File.write(STATE_FILE, JSON.dump({ "mailid" => state }))
    end

#
# Main code
#++++++++++
    log.info("#{$0} is starting...")
    log.info("step 1: Get session values : apiUrl et accountId")
    session    = get_session
    api_url    = session["apiUrl"]   # ex: https://api.fastmail.com/jmap/api/
    account_id = session["primaryAccounts"]["urn:ietf:params:jmap:mail"]

    log.info("Session:: apiUrl: #{api_url} - accountId: #{account_id}")
    
    log.info("setp 2: Get mailbox INBOX ID")
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

    res_mailbox = jmap_request(api_url, body_mailbox)
    mailbox_resp = res_mailbox["methodResponses"].find { |m| m[0] == "Mailbox/get" }[1]
    mailboxes    = mailbox_resp["list"]

    # search INBOX
    inbox = mailboxes.find { |m| m["role"] == "inbox" } || mailboxes.find { |m| m["name"] == "Inbox" }
    raise "INBOX not found" unless inbox

    inbox_id = inbox["id"]
    log.info("INBOX id: #{inbox_id}")
    puts ""

    count_loop  = 0
    flag_loop   = true
    log.warn("Start of loop until exit required")

    while   flag_loop
        count_loop  += 1
        log.info(">")
        log.info("loop: #{count_loop}=>step 3: Get last emails + text via bodyValues")
        body_email = {
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
                ],
                [
                    "Email/get",
                    {
                        "accountId"           => account_id,
                        "#ids"                => { "resultOf" => "c1", "name" => "Email/query", "path" => "/ids/*" },
                        "properties"          => ["id","subject","from","to","receivedAt","textBody","htmlBody","bodyValues"],
                        "bodyProperties"      => ["partId","type","size"],
                        "fetchTextBodyValues" => true,
                        "maxBodyValueBytes"   => 20000
                    },
                    "c2"
                ]
            ]
        }

        res_email = jmap_request(api_url, body_email)
    #    pp res_email
        
        method_responses = res_email["methodResponses"]
        email_query = method_responses.find { |m| m[0] == "Email/query" }
        raise "Email/query not found" if email_query.nil?

        query_resp = email_query[1]
        ids        = query_resp["ids"] || []
        log.info("loop: #{count_loop}=>Query returned #{ids.size} ids: #{ids.inspect}")

        # check if any email
        if ids.empty?
            log.warn("No emails to fetch, pls wait & try again")
        else

            log.info("loop: #{count_loop}=>step 4: Extract emails")
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
                            "ids"                 => ids,  # ici un vrai tableau d’IDs
                            "properties"          => ["id","subject","from","to","receivedAt","textBody","htmlBody","bodyValues"],
                            "bodyProperties"      => ["partId","type","size"],
                            "fetchTextBodyValues" => true,
                            "maxBodyValueBytes"   => 20000
                        },
                        "c2"
                    ]
                ]
            }

            res_email_get = jmap_request(api_url, body_email_get)
            method_responses_get = res_email_get["methodResponses"]

            email_get = method_responses_get.find { |m| m[0] == "Email/get" }
            raise "Email/get not found in methodResponses" if email_get.nil?

            email_resp = email_get[1]
            emails     = email_resp["list"] || []

            log.info("Found #{emails.size} emails")

            # 4) Pousser chaque mail vers Sinatra /email_webhook
            emails.each do |mail|
                # check if already processed
                next    if arr_mailids.include?(mail['id'])
                arr_mailids.push(mail['id'])

                # process mail
                handle_email(mail, log)

            end
        end

        #sleep or quit
        answer  = wait(OPTIONS[:sleep],true,log)
        if answer == 'q'
            log.warn(">>>Forced exit<<<")
            flag_loop   = false
        end
    end
