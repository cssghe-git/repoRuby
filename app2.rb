# app.rb
=begin

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

post "/email_webhook" do
  request.body.rewind
  raw = request.body.read

  begin
    payload = JSON.parse(raw)
  rescue JSON::ParserError
    status 400
    return "invalid JSON"
  end

  puts ">>>>>>>>>>*****<✳️<Payload :>✳️>*****<<<<<<<<<<"
  puts raw
  puts ">>>>>>>>>>*****<✳️<Payload end>✳️>*****<<<<<<<<<<"

  headers = payload["headers"] || {}
  text    = payload["text"]    || {}
  files   = payload["files"]   || []

  # From / To (listas de chaînes)
  from_list = headers["from"] || []
  to_list   = headers["to"]   || []

  from_email = from_list.first
  to_email   = to_list.first

  from = from_email
  to   = to_email

  subject    = headers["subject"]
  message_id = headers["message_id"]
  date_str   = headers["date"]
  date       = date_str ? Time.parse(date_str) : Time.now

  body_text  = text["content"] || ""
  quote_text = text["quote"]   || ""

  body_all = "Text:: #{body_text} - Quote:: #{quote_text}"

  meta_all = "Files: #{files.count}"

  mail = {
    from:       from,
    to:         to,
    subject:    subject,
    text:       body_text,
    body:       body_all,
    meta:       meta_all,
    date:       date,
    message_id: message_id
  }

  puts ">>>>>>>>>>*****<✳️<Mail : >✳️>*****<<<<<<<<<<"
  puts "**Sender:      #{mail[:from]}"
  puts "**Receiver:    #{mail[:to]}"
  puts "**Subject:     #{mail[:subject]}"
  puts "**Date:        #{mail[:date]}"
  puts "**Body:        #{mail[:body][0, 200]}"
  puts "**Meta:        #{mail[:meta]}"
  puts "**ID:          #{mail[:message_id]}"
  puts ">>>>>>>>>>*****<✳️<Mail end >✳️>*****<<<<<<<<<<"

  create_email_page(mail)

  status 200
  "ok"
end
