# app.rb
=begin
    Payload:    "message"
                    =>  "message_id", "message_id_type", 
                        "subject", "date", "from", "to", 
                        "reply_to", "headers"
                "body"
                    =>  "attachments", "text", "html"
                "meta"
                    =>  "source", "raw_size_bytes", "received at"
=end

require "sinatra"
require "json"
require "time"
require "notion-ruby-client"
require "thin"
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end
#
# Set default values
#*******************
configure :development do
  set :host_authorization, { permitted_hosts: [] }
end

set :bind, "0.0.0.0"
set :port, 4567

NOTION  = Notion::Client.new(token: ENV.fetch("NOT_APITOKEN"))
DB_ID   = ENV.fetch("DB_EMAILS")
#
# Main code
#**********
    #
    get "/" do
        "MailWebHooks → Sinatra OK"
    end

    # Mode: GET
    #==========
    get "/email_webhook" do
        # Extract request
        request.body.rewind
        raw = request.body.read

        # Process body content
        begin
            payload = JSON.parse(raw)
        rescue JSON::ParserError
            status 400
            return "invalid JSON"
        end
        #   pp  payload

        # Extract message
        msg = payload["message"] || {}
        #   pp  msg

        # Display request
        puts    "**Request : 🔻"
        puts    "**#{msg}"
        puts    "**End of request**"

        # Make response
        response    = { status: "200 - Request:ok - Reply:OK", time: Time.now.iso8601, text: "Response text" }.to_json 

        # Display response
        puts    ">>>>>>>>>>*****>🆘>Response<🆘<*****<<<<<<<<<<"
        puts    "**#{response}"
        puts    ">>>>>>>>>>*****>🆘>Response<🆘<*****<<<<<<<<<<"

        # Return http code
        status 200
        content_type :json
        response
    end

    # Mode: POST
    #===========
    post "/email_webhook" do
        # Extract request
        request.body.rewind
        raw = request.body.read

        # Process body content
        begin
            payload = JSON.parse(raw)
        rescue JSON::ParserError
            status 400
            return "invalid JSON"
        end
        puts    ">>>>>>>>>>*****>🆘>Payload<🆘<*****<<<<<<<<<<"
        #   pp  payload

        # Extract entities
        msg     = payload["message"] || {}
        puts    "[MESSAGE KEYS] #{msg.keys.inspect}"
        body    = payload["body"] || {"text"=> "None", "html"=> "None"}
        puts    "[BODY KEYS] #{body.keys.inspect}"
        meta    = payload["meta"] || {"text"=> "None", "html"=> "None"}
        puts    "[META KEYS] #{meta.keys.inspect}"
        puts    ">>>>>>>>>>*****>🆘>Payload<🆘<*****<<<<<<<<<<"

        # Extract some fields for <message>
        # => sender
        from_entry  = (msg["from"] || []).first || {}
        from_email  = from_entry["email"]
        from_name   = from_entry["name"]
        # => receiver
        to_entry    = (msg["to"] || []).first || {}
        to_email    = to_entry["email"]
        to_name     = to_entry["name"]
        # => message_id
        id_num      = msg["message_id"].to_s || "0"
        # => message_id_type
        id_type     = msg["message_id_type"] || "None"
        id_all      = "ID::#{id_num} - Type::#{id_type}"
        # => reply_to
        # => headers

        # Extract some fields for <body>
        # => text
        text_text   = body["text"] || "None"
        text_html   = body["html"] || "None"
        text_all    = "Text:: #{text_text} - Html:: #{text_html}"
        # => body
        body_text   = body["text"] || "None"
        body_html   = body["html"] || "None"
        body_all    = "Text:: #{body_text} - Html:: "
        # => attachments

        # Extract some fields for <meta>
        # => meta
        meta_text   = meta["text"] || "None"
        meta_html   = meta["html"] || "None"
        # => source
        meta_source = meta["source"] || "None"
        # => raw_size_bytes
        meta_size   = meta["raw_size_bytes"] || "0 bytes"
        # => received at
        meta_rcvd   = meta["received at"] || "None"
        meta_all    = "Text::#{meta_text} - Html::#{meta_html} - Source::#{meta_source} - Size::#{meta_size} - Rcv@:#{meta_rcvd}"

        # Create body to Notion API
        mail = {
            from:       from_name && !from_name.empty? ? "#{from_name} <#{from_email}>" : from_email,
            to:         to_name && !to_name.empty? ? "#{to_name} <#{to_email}>" : to_email,
            subject:    msg["subject"],
            text:       text_all,
            body:       body_all,
            meta:       meta_all,
            date:       (msg["date"] && Time.parse(msg["date"])) || Time.now,
            message_id: msg["message_id"]
        }

        # Display some fields
        puts    ">>>>>>>>>>*****>🆘>E-mail<🆘<*****<<<<<<<<<<"
        puts    "**Sender:      #{mail[:from]}"
        puts    "**Receiver:    #{mail[:to]}"
        puts    "**Subject:     #{mail[:subject]}"
        puts    "**Date:        #{mail[:date]}"
        puts    "**Body:        #{mail[:body]}"
        puts    "**Meta:        #{mail[:meta]}"
        puts    "**ID:          #{mail[:message_id]}"
        puts    "**Text (500):  #{mail[:text][0, 500]}"
        puts    ">>>>>>>>>>*****>🆘>E-mail<🆘<*****<<<<<<<<<<"

        # Notion API to create page
        create_email_page(mail)

        # Return http code
        status 200
        "ok"
    end

    def create_email_page(mail)
    #++++++++++++++++++++
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
                    { "text" => { "content" => (mail[:body] || "None")[0, 1900] } }
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
