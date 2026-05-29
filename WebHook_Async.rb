#!/usr/bin/env ruby
#
=begin

=end

require 'sidekiq'
require 'json'
require 'httparty'
require 'logger'
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
    def perform(type = 'None', payload = {}, raw_body = nil, raw_hdr = nil)

        build = "260524_0839"  #to identify code version in logs
        logger.datetime_format = '%H:%M:%S'

        logger.info ">>>"
        logger.info "🔄 Traitement async:: VRP: #{build} for: #{type}"
        logger.info ">>>******************************************<<<"

        # Dispatch according to type/from of webhook
        case type                                       
        when 'Notion-automation'    #from Notion - WebHook (automation) - old version
            handle_notion(payload, row_body)

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
            file_path = '/users/Gilbert/Public/Private/ToLogs/webhooks_log.txt'
        when 'json'
            file_path = "/users/Gilbert/Public/Private/ToLogs/webhooks_log_#{fields['file_path']}_#{Time.now.strftime('%Y-%m-%d')}.json"
            fields_json = JSON.pretty_generate(fields)
        else            
            file_path = "/users/Gilbert/Public/Private/ToLogs/webhooks_log_#{fields['file_path']}_#{Time.now.strftime('%Y-%m-%d')}.txt"
        end

        # Append data to file, text format or Json format
        File.open(file_path, 'a') do |f|
            f.puts ">>>Data @ #{Time.now}:"
            f.puts "Webhook data: #{fields || 'none'}"  if fields.empty?
            f.puts "Webhook data: #{fields_json}"       unless fields_json.empty?
            f.puts "<<<End of data>>>"
            f.puts ">>>"
        end
    end

    #
    # Display Data/Page
    #******************
    def display_page(prms: {})
        return      'Unknown'       unless display_common(prms: prms)
        page_id     = prms['page_id'] || nil
        get_type    = prms['get_type'] || 'None'
        data        = prms['data'] || {}
        uuid        = prms['uuid'] || 'unknown'

        # Notion API request parameters
        not_url = ENV['NOT_HTTPBASE'] || 'https://api.notion.com/v1'
        not_hdr = {
            'Authorization'     => ENV['NOT_WEBHOOK_TOKEN'] ||'unknown',
            'Notion-Version'    => ENV['NOT_APINEW'] || '2026-03-11',
            'Content-Type'      => 'application/json'
        }
        # Process page according to get_type
        case get_type
        when 'page'
            # Extract page data
            res = HTTParty.get("#{not_url}/pages/#{page_id}", headers: not_hdr)
            res_page = res.success? ? res.parsed_response : nil
            if res_page.nil?
                logger.info "#{uuid}>Failed to retrieve data for page_id: #{page_id} - response: #{res.body}"
                return 'Unknown'
            end

            # Extract parent data
            parent = data['parent']
            if parent['type'] == 'database'
                db_id = parent['id']
                res = HTTParty.get("#{not_url}/databases/#{db_id}", headers: not_hdr)
                res_parent = res.success? ? res.parsed_response : nil
                if res_parent.nil?
                    logger.info "#{uuid}>Failed to retrieve data for db: #{db_id} - response: #{res.body}"
                    return 'Unknown'
                else
                ###    logger.info "#{uuid}>Parent:#{res_parent}"
                end
            end

        when 'database'
            res = HTTParty.get("#{not_url}/databases/#{page_id}", headers: not_hdr)
        when 'data_source'
            res = HTTParty.get("#{not_url}/data_sources/#{page_id}", headers: not_hdr)
        when 'file_upload'
            res = HTTParty.get("#{not_url}/file_uploads/#{page_id}", headers: not_hdr)
        else
            logger.warn ">>>Unknown get_type: #{get_type}"
            return  'Unknown'
        end


        # Extract Author / User
        authors = extract_authors(prms: prms)

        # Display
        logger.info "<#{uuid}>📄 DB: #{res_parent['title'][0]['text']['content']}"
        logger.info "<#{uuid}>📄 Page: #{page_id}"
        logger.info "<#{uuid}>>>>Created time: #{res_page['created_time']}"
        logger.info "<#{uuid}>>>>Last edited time: #{res_page['last_edited_time']}"
        logger.info "<#{uuid}>>>>Authors: #{authors}"
        logger.info "<#{uuid}>>>>Properties ⇟"
        props = res_page['properties'] || {}
        props_exlude = ['Couverture']
        props.each do |key, value|
            next if props_exlude.include?(key)
            logger.info "<#{uuid}>>>>>>#{key}: #{get_prop_value(field: value)}"
        end
        res_page['authors'] = authors

        response = res_page
        return response
    end

    #
    # Display view
    #**************
    def display_view(prms: {})
        return      'Unknown'unless display_common(prms: prms)
        page_id     = prms['page_id'] || nil
        get_type    = prms['get_type'] || 'None'

        # Notion API request parameters
        not_url = ENV['NOT_HTTPBASE'] || 'https://api.notion.com/v1'
        not_hdr = {
            'Authorization'     => ENV['NOT_WEBHOOK_TOKEN'] ||'unknown',
            'Notion-Version'    => ENV['NOT_APINEW'] || '2026-03-11',
            'Content-Type'      => 'application/json'
        }
        # http request according to get_type
        case get_type
        when 'view'
            res = HTTParty.get("#{not_url}/views/#{page_id}", headers: not_hdr)
        else
            logger.warn ">>>Unknown get_type: #{get_type}"
            return  'Unknown'
        end

        response = res.success? ? res.parsed_response : nil
        return  'Unknown' if response.nil?

        # Extract Author / User
        authors = extract_authors(prms: prms)

        uuid    = prms['uuid'] || 'unknown'
        # Display
        logger.info "<#{uuid}>📄 Page: #{response['id']}"
        logger.info "<#{uuid}>>>>Created time: #{response['created_time']}"
        logger.info "<#{uuid}>>>>Last edited time: #{response['last_edited_time']}"
        logger.info "<#{uuid}>>>>Authors: #{authors}"

        logger.info "<#{uuid}>>>>name: #{response['name']}"
        logger.info "<#{uuid}>>>>type: #{response['type']}"
        configuration = response['configuration'] || {}
        return response     unless configuration.any?
        #pp configuration
        group_by = configuration['group_by'] || {}
        logger.info "<#{uuid}>>>>Configuration:"
        logger.info "<#{uuid}>>>>>>property: #{group_by['property_name']}"
        logger.info "<#{uuid}>>>>>>type: #{group_by['type']}"
        logger.info "<#{uuid}>>>>>>group_by: #{group_by['group_by']}"
        logger.info "<#{uuid}>>>>>>sort: #{group_by['sort']}"

        return response
    end

    #
    # Display file uploaded
    #**********************
    def display_file_upload(prms: {})
        return      unless display_common(prms: prms)
        get_type = prms['get_type'] || 'None'

    end

    #
    # Common part for Display anything
    #*********************************
    def display_common(prms: {})
        # Extract parameters
        page_id     = prms['page_id'] || nil
        return  false       if page_id.nil?
        api_version = prms['api_version'] || '2020-01-01'
        return  false   if api_version == '2020-01-01'  #to avoid processing old version of webhook
        return  true
    end

    #
    # Extract authors
    #****************
    def extract_authors(prms: {})
        # Exxtract values
        authors_id      = prms['authors_id'] || 'unknown authors id'
        authors_type    = prms['authors_type'] || 'unknown authors type'
        return 'Bot'    if authors_type == 'bot'

        # Notion API request parameters
        not_url = ENV['NOT_HTTPBASE'] || 'https://api.notion.com/v1'
        not_hdr = {
            'Authorization'     => ENV['NOT_WEBHOOK_TOKEN'] ||'unknown',
            'Notion-Version'    => ENV['NOT_APINEW'] || '2026-03-11',
            'Content-Type'      => 'application/json'
        }    
        # HTTP request to get authors details    
        res = HTTParty.get("#{not_url}/users/#{authors_id}", headers: not_hdr)
        response = res.success? ? res.parsed_response : nil
        return  'Unknown'   if response.nil?

        return response['name'] || 'None'
    end

    #************************
    #   Webhooks processing *
    #************************
    #
    #                   ****************************
    #                   From Notion - request (POST) - webhook integration
    #                   ****************************
    #
    def handle_notion_request(payload = {}, raw_body = {})
        #
        # Extract values & display if needed
        #+++++++++++++++++++++++++++++++++++
        timestamp       = payload['timestamp'] || nil
        uuid_full       = payload['request_id'] || nil
        uuid            = uuid_full.split('-')[0]  #to have a shorter uuid for display
        return          if payload.empty?

        # Check signature
        #++++++++++++++++
        signature   = payload['notion_signature']
        logger.info "<#{uuid}>Check signature: #{signature}"

        # Extract parts - level 1
        #++++++++++++++++++++++++
        authors         = payload['authors'][0] || nil  unless payload['authors'].nil? || payload['authors'].empty?
        api_version     = payload['api_version'] || nil
        entity          = payload['entity'] || nil
        type            = payload['type'] || nil
        data            = payload['data'] || nil
        flag_ok         = [timestamp, uuid, api_version, entity, type].all? { |part| !part.nil? }
        return      unless flag_ok

        # Extract parts - level 2
        #++++++++++++++++++++++++
        entity_id       = entity['id'] || 'unknown entity id'
        entity_type     = entity['type'] || 'unknown entity type'
        authors_id      = authors['id'] || 'unknown authors id'
        authors_type    = authors['type'] || 'unknown authors type'  #person, integration
        # For display
        prms = {}
        prms['page_id']     = entity_id
        prms['api_version'] = api_version
        prms['authors_id']  = authors_id
        prms['authors_type']= authors_type
        prms['uuid']        = uuid
        prms['data']        = data
        authors             = "Error"

        # Process according to type of entity & type of action
        #+++++++++++++++++++++++++++++++++++++++++++++++++++++
        logger.info "<#{uuid}>Request for #{entity_type}: #{entity_id} - type: #{type}"
        # Display
        #++++++++
        response = {}
        case entity_type
        when 'page'
        #    response = 'None'
            prms['get_type'] = 'page'
            case type
            when 'page.created'
                response = display_page(prms: prms)
            #    logger.info "<#{uuid}>Response: #{response}"
                return      if response == 'Unknown'  #to avoid processing old version of webhook

            when "page.properties_updated"
                response = display_page(prms: prms)
            #    logger.info "<#{uuid}>Response: #{response}"
                return      if response == 'Unknown'  #to avoid processing old version of webhook

            else
                logger.info ">>>Request for: #{entity_type} => type: #{type}"
            end

        when 'view'
            logger.info "<#{uuid}>Payload Notion request"
            pp payload      #unless payload.empty?
            response = 'Unknown'
            prms['get_type'] = 'view'
            case type
            when 'view.updated'
                response = display_view(prms: prms)
                return      if response == 'Unknown'  #to avoid processing old version of webhook

            when 'view.created'
                response = display_view(prms: prms)
                return      if response == 'Unknown'  #to avoid processing old version of webhook

            when 'view.deleted'
                response = display_view(prms: prms)
                return      if response == 'Unknown'  #to avoid processing old version of webhook

            else
                logger.info ">>>Request for: #{entity_type} => type: #{type}"
            end

        when 'person'

        when 'database'
            logger.info "<#{uuid}>Payload Notion request"
            pp payload      #unless payload.empty?
            prms['get_type'] = 'database'
            case type
            when 'database.created', 'database.content_updated', 'database.schema_updated',
                'database.deleted'
            else
                logger.info ">>>Request for: #{entity_type} => type: #{type}"
            end

        when 'data_source'
            logger.info "<#{uuid}>Payload Notion request"
            pp payload      #unless payload.empty?
            prms['get_type'] = 'data_source'
            case type
            when 'data_source.created', 'data_source.content_updated', 'data_source.schema_updated', 'data_source.deleted'
            else
                logger.info ">>>Request for: #{entity_type} => type: #{type}"
            end

        when 'file_upload'
            logger.info "<#{uuid}>Payload Notion request"
            pp payload      #unless payload.empty?
            prms['get_type'] = 'file_upload'
            case type
            when 'file_upload.created'
                #display_file_upload(prms: prms)

            when 'file_upload.completed'
                #display_file_upload(prms: prms)

            else
                logger.info "<#{uuid}>Request for: #{entity_type} => type: #{type}"
            end
        else
            logger.info "<#{uuid}>Payload Notion request"
            pp payload      #unless payload.empty?
            logger.warn "<#{uuid}>Unknown entity type: #{entity_type}"
        end

        # Append to file
        #++++++++++++++++
        # Load parameters
        prms = {}
        prms['file_switch'] = 'json'                    #format of file to save (json or text)
        prms['file_path']   = "notion_request"          #filename
        prms['URI']         = "notion_request"          #URI
        prms['page_id']     = entity_id                 #page ID
        prms['entity_type'] = entity_type
        prms['type']        = type
        prms['data']        = data
        prms['authors']     = response['authors']

        props = response['properties'] || {}
        props.each do |key, value|
            prms[key] = get_prop_value(field: value)
        end

        # Append to file
        append_to_file(fields: prms)
    end #<def>

    #                           From Notion - WebHook (old automation)
    #                           **********************
    #
    def handle_notion(payload, x_array = nil)
        pp payload

        # Extract fields & log it
        #
        # Extract parts
        timestamp   = payload['timestamp'] || nil
        uuid        = payload['request_id'] || nil
        source      = payload['source']
        data        = payload['data']
        object      = data['object']
        properties  = data['properties']

        # Extract X fields
        x_from_object   = x_array[:x_from_object] || 'unknown object'
        x_from_page     = x_array[:x_from_page] || 'unknown page'
        x_signature     = x_array[:x_signature] || 'unknown signature'
        #pp x_array

        # Configure fields
        prop_hash   = {}
        properties.each do |key, value|
            prop_hash[key]  = get_prop_value(field: value)
        end

        # display
        logger.info "<#{uuid}>📝 Notion automation - page: #{data['id']}"
        logger.info "<#{uuid}>>>>Reference: #{prop_hash['Référence'] || 'None'}"
        prop_hash.each do |fld|
            logger.info "<#{uuid}>>>>#{fld}: #{prop_hash[fld]}"
        end
        logger.info ">#{uuid}>>"

        # Append to file
        prms = {}
        prms['file_switch'] = 'None'
        prms['file_path']   = 'notion_automation'
        prms['URI']         = "notion_automation"
        prms['page_id']     = data['id']
        prms['properties']  = prop_hash
        append_to_file(fields: prms)

    end #<def>

    #                           ********************
    #                           From Notion - busycal
    #                           *********************
    def handle_notion_busycal(payload = {})
        logger.info "Payload Notion busycal"
        pp payload
        return          if payload.empty?

        # Extract parts
        timestamp       = payload['timestamp'] || nil
        uuid            = payload['request_id'] || nil
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

    #                           ***********
    #                           From Github
    #                           *************
    def handle_github(payload = {})
        logger.info "Payload Github"
        pp payload
        return          if payload.empty?

        # Extract parts
        timestamp   = payload['timestamp'] || nil
        uuid        = payload['request_id'] || nil
        head_commit = payload['head_commit'] || {}
        if !head_commit.empty?
            head_commit.each do |key, value|
                logger.info "<#{uuid}>>>>#{key}: #{value}"
            end
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

    #                           *************
    #                           From Fastmail
    #                           *************
    def handle_fastmail(payload = {})
        logger.info "Payload fastmail: "
    #    pp payload
        return          if payload.empty?

        # Extract parts
        timestamp   = payload['timestamp'] || nil
        uuid        = payload['request_id'] || nil
        schema      = payload['schema'] || 'unknown schema'
        event       = payload['event'] || 'unknown event'
        message     = payload['message'] || 'unknown message'

        # Add your logic here
        body    = message['body'] || {}
        sender  = message['from'][0]['email'] || 'unknown sender'
        subject = message['subject'] || 'unknown subject'
        date    = message['date'] || 'unknown date'
        to      = message['to'] || 'unknown recipient'

    #    return      if body.empty?

        attachements    = body['attachments'] || {}
        text            = body['text'] || {}

        contents = body.map {|c| contents[c] = c}

        # display
        logger.info "📧 Email reçu - le: #{date}"
        logger.info ">>>De: #{sender}"
        logger.info ">>>À: #{to}"
        logger.info ">>>Sujet: #{subject}"
        logger.info ">>>Texte: #{text}"
    #    if contents.size > 0
    #        contents.each do |c|
    #            logger.info "#{c}"
    #        end
    #    end

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