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

    # Test endpoint
    get '/' do
        '✅ Webhook receiver OK - POST /webhook pour tester'
    end

    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <notion_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    # Webhook principal (Notion)
    post '/notion_webhook' do
        payload = request.body && JSON.parse(request.body.read || '{}')
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
        WebhookAsync.perform_async('Github', payload)

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<post>
end #<class>
