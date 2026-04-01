require 'sidekiq'
require 'json'

class WebhookAsync
    include Sidekiq::Worker
    sidekiq_options queue: 'default', retry: 3

    def perform(type, payload)
        logger.info "🔄 Traitement async: #{type}}"

        case type
        when 'Notion-automation'
            handle_notion(payload)
        when 'GitHub' # 
            handle_github(payload)
        else
            logger.info "Payload test: #{payload}"
        end
    end #<def>

    private

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

    def handle_github(payload)
        # Extract parts
        head_commit = payload['head_commit']
        head_commit.each do |key, value|
            logger.info ">>>#{key}: #{value}"
        end

    end
end #<class>