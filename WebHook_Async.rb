require 'sidekiq'
require 'json'

class WebhookAsync
    include Sidekiq::Worker
    sidekiq_options queue: 'default', retry: 3

    #
    # Main method
    #************
    #
    def perform(type, payload)
        logger.info ">>>"
        logger.info "🔄 Traitement async: #{type}}"
        logger.info ">>>*****************<<<"

        case type
        when 'Notion-automation'
            handle_notion(payload)
        when 'GitHub' # 
            handle_github(payload)
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
        end #<SW1>
    end #<def>

    #
    # From Notion
    #************
    def handle_notion(payload)
        # Extract parts
        source      = payload['source']
        data        = payload['data']
        object      = data['object']
        properties  = data['properties']

        # Configure fields
        prop_hash   = {}
        properties.each do |key, value|
            prop_hash[key]  = get_prop_value(field: value)
        end

        # display
        logger.info "📝 Notion mise à jour - page: #{data['id']}"
        logger.info ">>>Reference: #{prop_hash['Référence'] || 'None'}"
        prop_hash.each do |fld|
            logger.info ">>>#{fld}: #{prop_hash[fld]}"
        end
        logger.info ">>>"

    end #<def>

    #
    # From Githubb
    #*************
    def handle_github(payload)
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
        pp payload
        # Extract parts
        schema= payload['schema'] || 'unknown schema'
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

        # display
        logger.info "📧 Email reçu - le: #{date}"
        logger.info ">>>De: #{sender}"
        logger.info ">>>À: #{to}"
        logger.info ">>>Sujet: #{subject}"
        logger.info ">>>Texte: #{text}"

    end #<def>

    #
    # From test
    #**********
    def handle_test(payload)
        logger.info "Payload test: #{payload}"
    end #<def>
end #<class>