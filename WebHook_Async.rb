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
### require "rack/contrib"
require "cgi"
require "securerandom"
require "redis"
require 'sidekiq'
require_relative "./WebHook_StoreSql.rb"
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

redis_url = "redis://127.0.0.1:6379/0"

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end

    class WebhookWorker
        include Sidekiq::Worker

        sidekiq_options retry: 10, queue: :webhooks

        def perform(from, event_json)
            event       = JSON.parse(event_json)
            event_id    = event.fetch("id")
            pp event

            return "ERR:already exist"   if processed_event?(event_id)

            case from
            when    'Notion'
                puts    "Processing Notion webhook event: #{event_id}"
            end

            mark_processed!(event_id)

            return "OK: processed"
        end
    end