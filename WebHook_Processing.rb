#!/usr/bin/env ruby
#
=begin
        WebhookProcessing.rb
        Function => on port 4567 - Recevoir les webhooks de Notion, GitHub, Fastmail, etc. et les mettre en file d'attente pour traitement asynchrone
        GET => 
            / : pour tester que le serveur est en ligne
            /favicon.ico : 
            /cssghe-tests : pour tester que le serveur est en ligne
            /?
        POST =>
            /cssghe-tests : pour tester que le serveur reçoit les POSTs
            /notion_webhook : pour recevoir les webhooks de Notion (automatisations - old)
            /github_webhook : pour recevoir les webhooks de GitHub
            /email_webhook : pour recevoir les webhooks de Fastmail
            /notion_request : pour recevoir les webhooks de Notion en mode 'CssGhe_Webhooks'
        Traitement =>
            Enregistrer le payload dans Redis (optionnel, pour debug ou historique)
            Enqueue le payload dans Sidekiq pour traitement asynchrone immédiat
        URLs =>
            via ngrok => https://progenitorial-fredda-headlong.ngrok-free.dev/?
            via localnet => webhook => https://uabojmzplh.localto.net/?
        TESTS =>
            curl -v 'https://progenitorial-fredda-headlong.ngrok-free.dev/cssghe-tests'
=end

require 'sinatra/base'
require 'json'
require 'logger'
require 'securerandom'
require 'redis'
require 'openssl'

class WebhookProcessing < Sinatra::Base
    configure :production, :development do
        set :host_authorization, { permitted_hosts: [] }
        set :logger, Logger.new(STDOUT)
        enable :logging
    end

    set :protection, false
    set :body_parser, nil

    Sidekiq.strict_args!(false)

    # Test endpoints
    get '/' do
        '✅ Webhook receiver OK - GET / for tests only'
    end

    get '/favicon.ico' do
        '✅ Webhook receiver OK - GET /favicon.ico pour tester'
    end

    get '/cssghe-tests' do
        '✅ Webhook receiver OK - GET /cssghe-tests pour tester'
    end

    post '/cssghe-tests' do

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('Tests')

        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
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
        token   = payload['verification_token']
        x_array[:x_token] = token || 'unknown token'

        # Log + sécurité basique
        ### pp payload  #to search fields
        logger.info "Webhook reçu: #{source['type'] || 'unknown'} from #{request.ip} "

        request_id              = SecureRandom.uuid
        payload['request_id']   = request_id

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('Notion-automation', payload, x_array)

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<post>

    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <Notion_busycal>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    post "/notion_busycal" do
        $stdout.puts ">>>DBG>Notion_BusyCal => "
        payload = request.body && JSON.parse(request.body.read || '{}')
        ### pp payload

        request_id              = SecureRandom.uuid
        payload['request_id']   = request_id

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('Notion-busycal', payload)

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<post>

    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <github_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    post "/github_webhook" do
        $stdout.puts ">>>DBG>Github_Webhook => "
        payload = env
        puts ">>>DBG>Payload/env => "
        pp payload

        payload = request.body && JSON.parse(request.body.read || '{}')
        ### pp payload

        request_id              = SecureRandom.uuid
        payload['request_id']   = request_id

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
        $stdout.puts ">>>DBG>Email_Webhook => "
        payload = request.body && JSON.parse(request.body.read || '{}')
        ### pp payload

        request_id              = SecureRandom.uuid
        payload['request_id']   = request_id

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('Fastmail', payload)

        # Réponse 200 rapide (fire & forget)
        [200, { 'Content-Type' => 'application/json' }, 
            [{ status: 'received', queued: true }.to_json]]
        
    end #<post>

    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <notion_request>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #   from webhook integration: CssGhe_Webhooks
    #
    post "/notion_request" do
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    $stdout.puts ">>>DBG>Notion_Request"

    request.body.rewind # Rewind the body to read it again
    raw_body = request.body.read


    payload = request.body && JSON.parse(raw_body || '{}')
    $stdout.puts payload.inspect

    request_id = SecureRandom.uuid

    payload['request_id']       = request_id
    payload['notion_signature'] = request.env['HTTP_X_NOTION_SIGNATURE'] || 'unknown signature'

    # enqueue ASAP
    WebhookAsync.perform_async('Notion-request', payload, nil, raw_body)

    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)
    $stdout.puts ">>>DBG>Notion_Request done in #{elapsed_ms}ms"

    [200, { 'Content-Type' => 'application/json' },
        [{ text: 'Webhook-notion_request', status: 'received', queued: true }.to_json]]
    end #<post>
end #<class>
