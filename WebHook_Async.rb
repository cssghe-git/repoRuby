require 'sidekiq'
require 'json'


class WebhookAsync
    include Sidekiq::Worker
    sidekiq_options queue: 'default', retry: 3

    #
    # Main method
    #************
    #
    # Dispatch according to type of request (from who)
    def perform(type, payload, x_array = nil)
        logger.info ">>>"
        logger.info "🔄 Traitement async: #{type}}"
        logger.info ">>>*****************<<<"

        case type                                       #dispatch according to type/fro of webhook
        when 'Notion-automation'
            handle_notion(payload, x_array)
        when 'GitHub'
            handle_github(payload)
        when 'Fastmail'
            handle_fastmail(payload)
        when 'Notion-request'
            handle_notion_request(payload)
        else
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
    def append_to_file(fields={})
        File.open('/users/Gilbert/Public/MemberLists/ToKeep/webhooks_log.txt', 'a') do |f|
            f.puts ">>>Data @ #{Time.now}:"
            f.puts "Webhook data: #{fields || 'unknown prms'}"
            f.puts "<<<End of data>>>"
        end
    end

    #
    # From Notion - WebHook (automation)
    #**********************
    def handle_notion(payload, x_array = nil)
        # Display payload
        #   pp payload
        
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
        prms['URI'] = "notion_webhook"
        prms['page_id'] = data['id']
        prms['properties'] = prop_hash
        append_to_file(prms)

    end #<def>

    #
    # From Notion - request (POST)
    #****************************
    def handle_notion_request(payload)
        logger.info "Payload Notion request"
        # Extract parts
        uuid            = payload['request_id'] || 'unknown uuid'
        request_method  = payload['REQUEST_METHOD'] || 'unknown method'
        request_path    = payload['PATH_INFO'] || 'unknown path'
        request_uri     = payload['REQUEST_URI'] || 'unknown uri'

        # Extract parameters
        params = request_uri.split('?').last || ''
        arr_params = params.split('&')
        arr_prm = {}
        arr_params.each do |par|
            par2 = par.split('=') if par.include?('=')
            arr_prm[par2[0]] = par2[1] if par2
        end
        function        = arr_params[0] || 'unknown function'
        callback_url    = arr_prm['callback'] || 'None'
        name            = arr_prm['nom'] || 'unknown name'
        # Log details
        logger.info ">>>Details for Request ID: #{uuid}"
        logger.info ">>>Method: #{request_method}"
        logger.info ">>>Path: #{request_path}"
        logger.info ">>>URI: #{request_uri}"
        logger.info ">>>Params: #{params}"
        logger.info ">>>Extracted params: #{arr_params}"
        logger.info ">>>Callback URL: #{callback_url}"
        logger.info ">>>Request: #{function} for #{name}"

        # make a response
        result = "OK"
        #   HTTP.post(callback_url, json: { status: 'done', result: result })    

    end #<def>

    #
    # From Githubb
    #*************
    def handle_github(payload)
        # pp payload
        # Extract parts
        head_commit = payload['head_commit']
        head_commit.each do |key, value|
            logger.info ">>>#{key}: #{value}"
        end
        logger.info ">>>"

    end #<def>

    #
    # From Fastmail
    #**************
    def handle_fastmail(payload)
        logger.info "Payload fastmail: "
        ### pp payload
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

    end #<def>

    #
    # From test
    #**********
    def handle_test(payload)
        logger.info "Payload test: #{payload}"
    end #<def>
end #<class>