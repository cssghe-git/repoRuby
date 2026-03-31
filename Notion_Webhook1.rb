# app.rb
=begin
    Webhook processing on "Post" request
    ************************************
    call by : ngrok on port 4567
    url : https://progenitorial-fredda-headlong.ngrok-free.dev/notion_webhook
    private headers : X_?
        X_FROM => sender of webhook
        X_?
=end

require "sinatra"
require "json"
require "time"
require "notion-ruby-client"
require "thin"
require "rack/contrib"
require "cgi"
require "securerandom"
require "sidekiq"

begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

use Rack::JSONBodyParser

#
# Set default values
#*******************
    # Sinatra configuration
    configure :production, :development do
        set :host_authorization, { permitted_hosts: [] }
        enable :logging
    end

    # My configuration
#
# Helpers
#********
    helpers do
        # Load json file with some parameters
        def load_json
            JSON.parse(File.read("Webhooks.json"))["secrets"]

        end

        # Make new ident
        def pref(pref: "WHx")
        #+++++++
        #   pref:   prefixe
            time = Time.now.utc.strftime("%j%H%M%S")
            rand_part = SecureRandom.alphanumeric(4).upcase  # ex: "A9F3"
            return  "#{pref}-#{time}-#{rand_part}"
        end

        # Vérif simplifiée de la signature, à adapter à la vraie spec Notion
        def valid_signature(from: nil, sign: nil)
        #++++++++++++++++++
            return false if sign.nil?

            my_sign = "CssGhe#Sign"                     if from == 'Notion'
            my_sign = '5QVQaAXQEImm8Sc2ATOow4Cww3tkun'  if from == 'Fastmail'
            my_sign = "GitHub#Sign"                     if from == 'GitHub' 
            my_sign == sign
        end #<def>

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
    end #<helpers>
#
# Main code
#**********
    #
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <notion_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    post "/notion_webhook" do
        puts    "\n>>>"
        puts    ">>>===== Webhook for </notion_webhook> ====="
        puts    ">>>"
        content_type :json

        # Request
        ### pp  headers
        ### pp  params      #source, data

        # Headers-Env
        headers_hash    = request.env.select { |k, _| k}#headers
        break           unless params.has_key?('data')
        data            = params['data']
        break           unless data.has_key?('properties')
        properties      = data['properties']

        # Trace
        ### puts    ">>>==== Notion webhook ===="
        ### puts    "ENV:: #{JSON.pretty_generate(headers_hash)}"
        ### puts    ">>>---- Checks ----"
        ### puts    ">>>SIGN: #{valid_signature(sign: headers_hash['HTTP_X_SIGN'])}"

        # Properties
        ### puts    JSON.pretty_generate(properties)
        prop_hash   = {}
        properties.each do |key, value|
            prop_hash[key]  = get_prop_value(field: value)
        end

        # Fields according to <Application> & <Object>
        applic_hash = {
            '<Notes - Gestion des finances>'    => {
                'Button: <WebHook>' => [
                    'title'
                ],
                'next object'       => [
                    'field1',
                    'field2'
                ]
            },
            '<m25t.Membres>'                    => {
                '<Table update>'    => [
                    'Référence',
                    'Activité principale',
                    'Activités secondaires'
                ],
                'next object'       => [
                    'field1',
                    'field2'
                ]
            }
        }
        ### puts    "FLDS:: #{applic_hash}"
        # Load fields requested
        fields_hash     = {}
        if applic_hash.key?(headers_hash['HTTP_X_FROM_PAGE'])
            if applic_hash[headers_hash['HTTP_X_FROM_PAGE']].key?(headers_hash['HTTP_X_FROM_OBJECT'])
                fields_array    = applic_hash[headers_hash['HTTP_X_FROM_PAGE']][headers_hash['HTTP_X_FROM_OBJECT']]
                fields_array.each do |fld|
                    fields_hash[fld]    = prop_hash[fld]
                end
            end
        end
        ### puts    "PROP:: #{fields_array} -> #{fields_hash}"

        # Print fields
        ### puts    ">>>---- Webhook fields ----"
        ### puts    ">>>>>>> Headers :"
        ### puts    ">>>by Host:         #{headers_hash['HTTP_HOST']}"
        puts    ">>>From:            #{headers_hash['HTTP_USER_AGENT']}"
        puts    ">>>Application:     #{headers_hash['HTTP_X_FROM_PAGE']}"
        puts    ">>>Object:          #{headers_hash['HTTP_X_FROM_OBJECT']}"
        puts    ">>>Sign:            #{valid_signature(from: 'Notion', sign: headers_hash['HTTP_X_SIGN'])}"
        ### puts    ">>>>>>> Source :"
        puts    ">>>Type of webhook: #{params['source']['type']}"
        ### puts    ">>>>>>> Data :"
        puts    ">>>Type of object:  #{params['data']['object']}"
        puts    ">>>ID of object:    #{params['data']['id']}"
        ### puts    ">>>>>>> Properties :"
        if fields_hash.size > 0
            fields_hash.each    do |key, value|
                len = 40 - key.size
                puts    ">>>#{key}:" + " "*len + "#{value}"
            end
        end

        #
        puts    "\n>>>Response"
        status 200
        content_type :json
        { ok: true }.to_json
    end

    get "/" do
        "CssGhe webhook listener OK"
    end
    #
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <email_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    post "/email_webhook" do
        puts    "\n>>>>>>"
        puts    ">>>===== Webhook for </email_webhook> ====="
        puts    ">>>>>>"
        content_type :json

        # Request
    #    puts    "Headers::"
    #    pp  headers
    #    puts    "Params::"
    #    pp  params      #meta, page, incident / component, component_update

        # Headers-Env
        headers_hash    = request.env.select { |k, _| k}#headers
        ### puts    "ENV:: #{JSON.pretty_generate(headers_hash)}"

        # Extra fields
        applic_hash = {
            'incident'      => ['none'],
            'component'     => ['component_update'],
            'maintenance'   => ['none'],
            'event'         => ['none'],
            'message'       => ['body']
        }
        fields_hash     = {}
        applic_hash.each do |key, value|
            if params.key?(key)
                fields_hash[key]    = params[key]
                value.each do |key2|
                    fields_hash[key2]   = params[key2]   unless key2 == 'none'
                end
            end
        end

        # Message
        if params.key?("message")
            msg = params["message"]          # IndifferentHash ou Hash

            message_hash = {}
            message_hash["subject"]   = msg["subject"].to_s
            message_hash["date"]      = msg["date"].to_s

            # from / to / reply_to sont souvent des tableaux de hashes
            # ex: [{ "email"=>"me@example.com", "name"=>"Me" }]
            from  = msg["from"]
            to    = msg["to"]
            reply = msg["reply_to"]

            message_hash["from"]     = msg["from"]&.first&.dig("email").to_json     # ou formatage plus fin
            message_hash["to"]       = msg["from"]&.first&.dig("to").to_json        # ou joins etc.
            message_hash["reply_to"] = msg["from"]&.first&.dig("reply_to").to_json

            # corps du message : souvent "text" ou "html" dans message
            raw_body = msg["html"] || msg["text"] || params["body"]['text']
            raw_body ||= ""

            message_hash["body"] = raw_body.to_s
        end

        # Print fields
        ### puts    ">>>---- Webhook fields ----"
        ### puts    ">>>>>>> Headers :"
        puts    ">>>by Host:         #{headers_hash['HTTP_HOST']}"
        puts    ">>>Agent:           #{headers_hash['HTTP_USER_AGENT']}"
        puts    ">>>From:            #{headers_hash['HTTP_X_FROM']}"
        puts    ">>>Applic:          #{headers_hash['HTTP_X_FROM_PAGE']}"
        puts    ">>>Object:          #{headers_hash['HTTP_X_FROM_OBJECT']}"
        puts    ">>>Sign:            #{valid_signature(from: 'Fastmail', sign: headers_hash['HTTP_X_SIGN'])}"

        ### puts    ">>>>>>> Properties :"
        if params.key?('message')
            ### puts    ">>>Message:"
            message_hash.each   do |key, value|
                len = 40 - key.size
                puts    ">>>#{key}:" + " "*len + "#{value[0,100]}"
            end
        else
            if fields_hash.size > 0
                fields_hash.each    do |key, value|
                    len = 40 - key.size
                    puts    ">>>#{key}:" + " "*len + "#{value[0,100]}"
                end
            end
        end
    end
    #
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <github_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    post "/github_webhook" do
        puts    "\n>>>>>>"
        puts    ">>>===== Webhook for </github_webhook> ====="
        puts    ">>>>>>"
        content_type :json

        # Headers-Env
        headers_hash    = request.env.select { |k, _| k}#headers
        ###puts    "ENV:: #{JSON.pretty_generate(headers_hash)}"
        ### pp params

        # Repositiry
        repository  = params['repository']
        full_name   = params['full_name']
        updated_at  = params['updated_at']
        commits     = params['commits']

        # Print fields
        ### puts    ">>>---- Webhook fields ----"
        ### puts    ">>>>>>> Headers :"
        puts    ">>>Request by :   #{headers_hash['HTTP_USER_AGENT']}"
        ### puts    ">>>>>>> Properties :"
        ### puts    ">>>Commits :"
        commits.each_with_index do |commit, index|
            puts    ">>>  #{index + 1}. #{commit['message']}"
        end

    end

#
=begin
    my URL: https://progenitorial-fredda-headlong.ngrok-free.dev/notion_webhook
    my URL: https://progenitorial-fredda-headlong.ngrok-free.dev/email_webhook
    my URL: https://progenitorial-fredda-headlong.ngrok-free.dev/github_webhook

=end