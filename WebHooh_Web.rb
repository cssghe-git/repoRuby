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
            via localnet => webhook => https://uabojmzplh.localto.net
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


    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <GET> request for <notion_request>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    get "/notion_request" do
        payload = env
        puts ">>>DBG>Payload/env => "
        pp payload

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
        payload = env
        puts ">>>DBG>Payload/env => "
        pp payload

=begin
        payload = request.body && JSON.parse(request.body.read || '{}')
        ### pp payload
       source  = payload['source']

        # Log + sécurité basique
        ### pp payload  #to search fields
        logger.info "Webhook reçu: #{source['type'] || 'unknown'} from #{request.ip}"

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('Notion-automation', payload)
=end

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<post>

end #<class>
