#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'] ||= 'development')

# Auto-charge workers
### Dir['./workers/*.rb'].each { |f| require_relative f }
require_relative './webhook_async.rb'

# Votre app Sinatra
require_relative './webhook_processing.rb'

# Sidekiq Redis (même pour client/serveur)
Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
Sidekiq.configure_server do |config|
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
    config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
end
# Logs Sidekiq concis (juste timestamp + message)
Sidekiq.logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%H:%M:%S')} #{severity} #{msg}\n"
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
