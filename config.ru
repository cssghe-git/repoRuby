#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'] ||= 'development')

# Auto-charge workers
### Dir['./workers/*.rb'].each { |f| require_relative f }
require_relative './WebHook_Async.rb'

# Votre app Sinatra
require_relative './WebHook_Processing.rb'

# Sidekiq Redis (même pour client/serveur)
Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_server do |config|
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
    # Logs Sidekiq concis (juste timestamp + message)
    config.logger.formatter = proc do |severity, datetime, _progname, msg|
        "#{datetime.strftime('%H:%M:%S')} #{severity} #{msg}\n"
    end
end

require 'sidekiq/web'

# Middleware sécurité HTTPS/webhooks
use Rack::Deflater
use Rack::ShowExceptions
use Rack::Head

map '/' do
  run WebhookProcessing
end

map '/sidekiq' do
  run Sidekiq::Web
end
