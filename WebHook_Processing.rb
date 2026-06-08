#!/usr/bin/env ruby
#
=begin
        WebhookProcessing.rb
        Function => on port 4567 - Recevoir les webhooks de Notion, GitHub, Fastmail, etc. et les mettre en file d'attente pour traitement asynchrone
        Build:  260522-1533
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
require "rack/utils"

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
    # Webhook (Notion)
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

    begin
        # Log + sécurité basique
        ### pp payload  #to search fields
        logger.info "Webhook reçu: #{source['type'] || 'unknown'} from #{request.ip} "

        request_id              = SecureRandom.uuid
        payload['request_id']   = request_id

        # Enqueue async IMMÉDIATEMENT
        WebhookAsync.perform_async('Notion-automation', payload, x_array)
    rescue => e
        logger.warn "Erreur lors du traitement du notion_webhook: #{e.message}"
    end
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

    request.body.rewind
    raw_body = request.body.read
    ### $stdout.puts "RAW:#{raw_body}"
    ### $stdout.puts "ENV:#{env.inspect}"

    received_signature = request.env["HTTP_X_NOTION_SIGNATURE"]&.to_s&.strip
    received_signature = received_signature.sub(/\Asha256=/, "")

    verification_token = ENV['NOT_WEBHOOK_VERIFY']  #'secret_?'
    calculated_signature = OpenSSL::HMAC.hexdigest("SHA256", verification_token, raw_body)
    is_trusted = ActiveSupport::SecurityUtils.secure_compare(calculated_signature, received_signature)

    ### $stdout.puts "raw_body.bytesize: #{raw_body.bytesize}"
    ### $stdout.puts "received_signature: #{received_signature[0..65]}"
    ### $stdout.puts "calculated_signature: #{calculated_signature[0..65]}"
    ### $stdout.puts "same length: #{received_signature.bytesize == calculated_signature.bytesize}"
    ###$stdout.puts "is_trusted: #{is_trusted}"
    $stdout.puts "SIGN::Token:#{verification_token} - Received:#{received_signature} - Calculated:#{calculated_signature} - Trusted: #{is_trusted}"

    request.body.rewind
    payload = JSON.parse(raw_body)    
    payload['request_id']       = SecureRandom.uuid
    payload['notion_signature'] = is_trusted
    ### $stdout.puts payload.inspect

    # enqueue ASAP
    WebhookAsync.perform_async('Notion-request', payload, raw_body, raw_body)

    elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(1)
    $stdout.puts ">>>DBG>Notion_Request done in #{elapsed_ms}ms"

    [200, { 'Content-Type' => 'application/json' },
        [{ text: 'Webhook-notion_request', status: 'received', queued: true }.to_json]]
    end #<post>
end #<class>
