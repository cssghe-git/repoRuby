#
=begin
        WebhookProcessing.rb
        Function => on port 4567 - Recevoir les webhooks de Notion, GitHub, Fastmail, etc. et les mettre en file d'attente pour traitement asynchrone
        GET => 
            / : pour tester que le serveur est en ligne
            /favicon.ico : 
            /notion_request : pour recevoir les requêtes de Notion for request (ex: recherche de données)
        POST =>
            /notion_webhook : pour recevoir les webhooks de Notion (automatisations)
            /github_webhook : pour recevoir les webhooks de GitHub
            /email_webhook : pour recevoir les webhooks de Fastmail
            /notion_request : pour recevoir les requêtes de Notion for request (ex: recherche de données)
        Traitement =>
            Enregistrer le payload dans Redis (optionnel, pour debug ou historique)
            Enqueue le payload dans Sidekiq pour traitement asynchrone immédiat
        URLs =>
            via ngrok => https://progenitorial-fredda-headlong.ngrok-free.dev/?
            via localnet => webhook => https://uabojmzplh.localto.net/?
=end

require 'sinatra/base'
require 'json'
require 'logger'
require 'securerandom'
require 'redis'

class WebhookProcessing < Sinatra::Base
    configure :production, :development do
        set :host_authorization, { permitted_hosts: [] }
        set :logger, Logger.new(STDOUT)
        enable :logging
    end


    Sidekiq.strict_args!(false)

    # Test endpoints
    get '/' do
        '✅ Webhook receiver OK - GET / for tests only'
    end

    get '/favicon.ico' do
        '✅ Webhook receiver OK - GET /favicon.ico pour tester'
    end


    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <GET> request for <notion_request>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    get "/notion_request" do
        payload = env
        puts ">>>DBG>Notion_Request>Payload/env => "

        # UUID
        request_id = SecureRandom.uuid
        payload['request_id'] = request_id

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('Notion-request', payload)

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<get>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <notion_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    # Webhook principal (Notion)
    post '/notion_webhook' do
        env_part = env
        $stdout.puts ">>>DBG>Notion_Webhook>Env_Part => "
        $stdout.puts env_part.inspect

        # Extract X fields
        x_array = {}
        x_array[:x_from_object]   = env['HTTP_X_NOTION_FROM_OBJECT'] || 'unknown object'
        x_array[:x_from_page]     = env['HTTP_X_NOTION_FROM_PAGE'] || 'unknown page'
        x_array[:x_signature]     = env['HTTP_X_SIGN'] || 'unknown signature'
    
        # Extract data
        payload = request.body && JSON.parse(request.body.read || '{}')
        source  = payload['source']

        # Log + sécurité basique
        ### pp payload  #to search fields
        logger.info "Webhook reçu: #{source['type'] || 'unknown'} from #{request.ip}"

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('Notion-automation', payload, x_array)

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<post>

    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <github_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    post "/github_webhook" do
        payload = env
        puts ">>>DBG>Payload/env => "
        pp payload

        payload = request.body && JSON.parse(request.body.read || '{}')
        ### pp payload

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('GitHub', payload)

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<post>

    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <fastmail_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    post "/email_webhook" do
        payload = request.body && JSON.parse(request.body.read || '{}')
        ### pp payload

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('Fastmail', payload)

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<post>

    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <notion_request>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    post "/notion_request" do
        payload = env
        $stdout.puts ">>>DBG>Notion_Request>Payload/env => "
        $stdout.puts payload.inspect

        # UUID
        request_id = SecureRandom.uuid
        payload['request_id'] = request_id

        # Enqueue async IMMÉDIATEMENT
    ###    WebhookAsync.perform_async('Notion-request', payload)

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<post>
end #<class>
