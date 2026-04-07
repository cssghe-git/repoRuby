require 'sinatra/base'
require 'json'
require 'logger'

class WebhookProcessing < Sinatra::Base
    configure :production, :development do
        set :host_authorization, { permitted_hosts: [] }
        set :logger, Logger.new(STDOUT)
        enable :logging
    end


    Sidekiq.strict_args!(false)

    # Test endpoints
    get '/' do
        '✅ Webhook receiver OK - GET / pour tester'
    end

    get '/favicon.ico' do
        '✅ Webhook receiver OK - GET /favicon.ico pour tester'
    end

#    get '/notion_request' do
#        '✅ Webhook receiver OK - GET /notion_request pour tester'
#    end

    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <notion_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    # Webhook principal (Notion)
    post '/notion_webhook' do
        payload = request.body && JSON.parse(request.body.read || '{}')
        ### pp payload
       source  = payload['source']

        # Log + sécurité basique
        ### pp payload  #to search fields
        logger.info "Webhook reçu: #{source['type'] || 'unknown'} from #{request.ip}"

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('Notion-automation', payload)

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<post>

    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <github_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    post "/github_webhook" do
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
    # Process <Post> request for <tests_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    post "/tests_webhook" do
        payload = request.body && JSON.parse(request.body.read || '{}')
        ### pp payload

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('Tests', payload)

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<post>
end #<class>
