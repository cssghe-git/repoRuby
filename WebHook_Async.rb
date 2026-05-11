#!/usr/bin/env ruby
#
=begin

=end

require 'sidekiq'
require 'json'
require 'httparty'
require "active_support/security_utils"
#
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

#
# Define class for processing webhooks asynchronously with Sidekiq
#
class WebhookAsync
    include Sidekiq::Worker
    sidekiq_options queue: 'default', retry: 3

    #
    # Main method
    #************
    #
    # Dispatch according to type of request (from who)
    def perform(type = 'None', payload = {}, x_array = nil, raw_body = nil)

        build = "260511-0726"  #to identify code version in logs

        logger.info ">>>"
        logger.info "🔄 Traitement async:: VRP: #{build} for: #{type}"
        logger.info ">>>******************************************<<<"

        # Dispatch according to type/from of webhook
        case type                                       
        when 'Notion-automation'    #from Notion - WebHook (automation) - old version
            handle_notion(payload, x_array)

        when 'GitHub'               #from Github
            handle_github(payload)

        when 'Fastmail'             #from Fastmail 
            handle_fastmail(payload)

        when 'Notion-request'       #from Notion - request (POST) - webhook integration - new version
            handle_notion_request(payload, raw_body)

        when 'Notion-busycal'       #from Notion - busycal (POST)
            handle_notion_busycal(payload)
            
        else                        #tests
            handle_test(payload)
        end
    end #<def>

    private

    #
    # Functions
    #**********
    #
    # Extract field value for Notion
    def get_prop_value(field: nil)
    #+++++++++++++++++
    #   field: fieldname
        return  "None"  if field.nil?

        case    field['type']   #<SW1>              #dispatch according type of field
        when    "title"         then field["title"].map { _1["plain_text"] }.join
        when    'select'        then field["select"] && field["select"]["name"]
        when    'multi_select'  then (field["multi_select"] || []).map { _1["name"] }
        when    "rich_text"     then field["rich_text"].map { _1["plain_text"] }.join
        when    "status"        then field["status"] && field["status"]["name"]
        when    "date"          then field["date"] && field["date"]["start"]
        when    "email"         then field["email"]
        when    "phone_number"  then field["phone_number"]
        when    "checkbox"      then field["checkbox"]
        when    "number"        then field["number"]
        when    "relation"      then (field["relation"] || []).map { _1["id"] }
        when    "people"        then (field["people"]   || []).map { _1["id"] }
        when    "formula"
            f = field["formula"]
            return nil unless f
            case f["type"]
            when    "string"  then f["string"]
            when    "number"  then f["number"]
            when    "boolean" then f["boolean"]
            when    "date"    then f["date"] && f["date"]["start"]
            end
        else
            field[field["type"]]
        end #<SW1>
    end #<def>

    #
    # Append to file
    # **************
    def append_to_file(fields: {})
        return if fields.empty?

        # Define file path based on field value (if any)
        file_switch = fields['file_switch'] || 0
        fields_json = {}
        case file_switch
        when 0
            file_path = '/users/Gilbert/Public/MemberLists/ToKeep/webhooks_log.txt'
        when 'json'
            file_path = "/users/Gilbert/Public/MemberLists/ToKeep/webhooks_log_#{fields['file_path']}_#{Time.now.strftime('%Y-%m-%d')}.json"
            fields_json = JSON.pretty_generate(fields)
        else            
            file_path = "/users/Gilbert/Public/MemberLists/ToKeep/webhooks_log_#{fields['file_path']}_#{Time.now.strftime('%Y-%m-%d')}.txt"
        end

        # Append data to file, text format or Json format
        File.open(file_path, 'a') do |f|
            f.puts ">>>Data @ #{Time.now}:"
            f.puts "Webhook data: #{fields || 'none'}"  if fields_json.empty?
            f.puts "Webhook data: #{fields_json}"       unless fields_json.empty?
            f.puts "<<<End of data>>>"
            f.puts ">>>"
        end
    end

    #
    # Check signature
    #*****************
    def check_signature(signature: nil, raw_body: nil)
    #
        return false if signature.nil?
        return false if raw_body.nil?

        # Retrieve the verification_token from initial request
        verification_token = ENV['NOT_WEBHOOK_VERIFY'] || 'secret_oDGXV4Lvg8oX6e1x2MrXveF7UlEPlIKito7G89Wxdxy'

        digest = OpenSSL::HMAC.hexdigest("SHA256", verification_token, raw_body)
        calculated_signature = "sha256=#{digest}"

        # Constant-time comparison
        is_trusted_payload = ActiveSupport::SecurityUtils.secure_compare(
            calculated_signature,
            signature
            )

        unless is_trusted_payload
            # Ignore the event
            logger.warn "⚠️ Signature mismatch - check payload"
        end
        return is_trusted_payload
    end
    #
    # Display page
    #*************
    def display_page(page_id: nil)
        return if page_id.nil?

        # Notion API request parameters
        not_url = ENV['NOT_HTTPBASE'] || 'https://api.notion.com/v1'
        not_hdr = {
            'Authorization'     => ENV['NOT_WEBHOOK_TOKEN'] ||'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',
            'Notion-Version'    => ENV['NOT_APINEW'] || '2026-03-11',
            'Content-Type'      => 'application/json'
        }
        # http request
        res = HTTParty.get("#{not_url}/pages/#{page_id}", headers: not_hdr)
        response = res.success? ? res.parsed_response : nil
        return if response.nil?

        # display
        logger.info "📄 Page: #{response['id']}"
        logger.info ">>>Created time: #{response['created_time']}"
        logger.info ">>>Last edited time: #{response['last_edited_time']}"
        logger.info ">>>Properties ⇟"
        props = response['properties'] || {}
        props.each do |key, value|
            logger.info ">>>>>>#{key}: #{get_prop_value(field: value)}"
        end
     end

    #*****#####*****#####*****#####*****#####*****#####*****
    #
    # From Notion - WebHook (old automation)
    #**********************
    def handle_notion(payload, x_array = nil)
        # Extract fields & log it
        #        
        # Extract parts
        source      = payload['source']
        data        = payload['data']
        object      = data['object']
        properties  = data['properties']

        # Extract X fields
        x_from_object   = x_array[:x_from_object] || 'unknown object'
        x_from_page     = x_array[:x_from_page] || 'unknown page'
        x_signature     = x_array[:x_signature] || 'unknown signature'
        pp x_array

        # Configure fields
        prop_hash   = {}
        properties.each do |key, value|
            prop_hash[key]  = get_prop_value(field: value)
        end

        # display
        logger.info "📝 Notion automation - page: #{data['id']}"
        logger.info ">>>Reference: #{prop_hash['Référence'] || 'None'}"
        prop_hash.each do |fld|
            logger.info ">>>#{fld}: #{prop_hash[fld]}"
        end
        logger.info ">>>"

        # Append to file
        prms = {}
        prms['file_switch'] = 'None'
        prms['file_path']   = 'notion_automation'
        prms['URI']         = "notion_automation"
        prms['page_id']     = data['id']
        prms['properties']  = prop_hash
        append_to_file(fields: prms)

    end #<def>

    #
    # From Notion - request (POST) - webhook integration
    #****************************
    def handle_notion_request(payload = {}, raw_body = {})
        #raw_body contains ENV fields (headers) - for logging and security checks
        #"secret_oDGXV4Lvg8oX6e1x2MrXveF7UlEPlIKito7G89Wxdxy"
        #"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"
        #
        logger.info "Payload Notion request"
        pp payload      unless payload.empty?
        return          if payload.empty?

        # Check signature
        signature   = payload['notion_signature'] || 'unknown signature'
        rc          = check_signature(signature: signature, raw_body: raw_body)
        logger.info ">>>Signature check: #{rc ? 'OK' : 'FAILED'}"

        # Extract parts
        timestamp       = payload['timestamp'] || 'unknown timestamp'
        uuid            = payload['request_id'] || 'unknown uuid'
        entity          = payload['entity'] || nil
        entity_id       = entity['id'] || 'unknown entity id'
        entity_type     = entity['type'] || 'unknown entity type'
        type            = payload['type'] || 'unknown type'
        data            = payload['data'] || {}
        parent_id       = data['parent_id'] || 'unknown parent id'
        parent_type     = data['parent_type'] || 'unknown parent type'  #page, database,

        logger.info ">>>Request for #{entity_type}: #{entity_id} - type: #{type}"
        # Process according to type of entity & type of action
        case entity_type
        when 'page'
        #    logger.info ">>>Request for #{entity_type}: #{entity_id} - type: #{type}"
            case type
            when 'page.created'
                display_page(page_id: entity_id)

            when "page.properties_updated"
                display_page(page_id: entity_id)

            else
                logger.info ">>>Request for: #{entity_type} => type: #{parent_type}"
            end

        when 'view'
        #    logger.info ">>>Request for #{entity_type}: #{entity_id} - type: #{type}"
            # Add your logic here to handle view request
            # type can be: 1-view.updated, 2-view.created, 
            # if 1: data['updated_fields']["?"]
            # if 2: data['view_type']

        when 'data_source'
        #    logger.info ">>>Request for #{entity_type}: #{entity_id}"
            # Add your logic here to handle data source request
            # type can be: 1-data_source.schema_updated, 
            # if 1: data['updated_properties'][['name':], ['action':]]

        when 'person'
        #    logger.info ">>>Request for #{entity_type}: #{entity_id} - type: #{type}"
            # Add your logic here to handle person request

        when 'block'
        #    logger.info ">>>Request for #{entity_type}: #{entity_id} - type: #{type}"
            # Add your logic here to handle block request
            # type can be : 1-database.created, 

        when 'database'
        #    logger.info ">>>Request for #{entity_type}: #{entity_id} - type: #{type}"
            # Add your logic here to handle database request

        else
            logger.warn ">>>Unknown entity type: #{entity_type}"
        end

        # Append to file
        prms = {}
        prms['file_switch'] = 'json'
        prms['file_path']   = 'notion_request'
        prms['URI']         = "notion_request"
        prms['page_id']     = entity_id
        prms['entity_type'] = entity_type
        prms['type']        = type
        prms['data']        = data
        append_to_file(fields: prms)
    end #<def>

    #
    # From Notion - busycal
    #****************************
    def handle_notion_busycal(payload = {})
        logger.info "Payload Notion busycal"
#        pp payload      unless payload.empty?
        return          if payload.empty?

        # Extract parts
        uuid            = payload['request_id'] || 'unknown uuid'
        request_method  = payload['REQUEST_METHOD'] || 'unknown method'
        request_path    = payload['PATH_INFO'] || 'unknown path'
        request_uri     = payload['REQUEST_URI'] || 'unknown uri'

        # Append to file
        prms = {}
        prms['file_path']   = 'notion_busycal'
        prms['file_switch'] = 'None'
        prms['URI']         = "notion_busycal"
        prms['method']      = request_method
        prms['path']        = request_path
        prms['url']         = request_uri
        append_to_file(fields: prms)
    end #<def>

    #
    # From Githubb
    #*************
    def handle_github(payload = {})
        logger.info "Payload Github"
#        pp payload      unless payload.empty?
        return          if payload.empty?

        # Extract parts
        head_commit = payload['head_commit']
        head_commit.each do |key, value|
            logger.info ">>>#{key}: #{value}"
        end
        logger.info ">>>"

        # Append to file
        prms = {}
        prms['file_switch'] = 'None'
        prms['file_path']   = 'github_request'
        prms['URI']         = "github_request"
        prms['commits']     = head_commit
        append_to_file(fields: prms)

    end #<def>

    #
    # From Fastmail
    #**************
    def handle_fastmail(payload = {})
        logger.info "Payload fastmail: "
    #    pp payload      unless payload.empty?
        return          if payload.empty?

        # Extract parts
        schema      = payload['schema'] || 'unknown schema'
        event       = payload['event'] || 'unknown event'
        message     = payload['message'] || 'unknown message'
        body        = message['body'] || {}

        # Add your logic here
        sender          = message['from'] || 'unknown sender'
        subject         = message['subject'] || 'unknown subject'
        date            = message['date'] || 'unknown date'
        to              = message['to'] || 'unknown recipient'

        attachements    = body['attachments'] || {}
        text            = body['text'] || {}

        contents = body.map {|c| contents[c] = c}

        # display
        logger.info "📧 Email reçu - le: #{date}"
        logger.info ">>>De: #{sender}"
        logger.info ">>>À: #{to}"
        logger.info ">>>Sujet: #{subject}"
        logger.info ">>>Texte: #{text}"
        if contents.size > 0
            contents.each do |c|
                logger.info "#{c}"
            end
        end

        # Append to file
        prms = {}
        prms['file_switch'] = 'json'
        prms['file_path']   = 'fastmail_request'
        prms['URI']         = "fastmail_request"
        prms['date']        = date
        prms['from']        = sender
        prms['to']          = to
        prms['subject']     = subject
        prms['text']        = text
        append_to_file(fields: prms)

    end #<def>

    #
    # From test
    #**********
    def handle_test(payload)
        logger.info "Payload test: #{payload}"
    end #<def>
end #<class>