# config.ru
require 'bundler'
Bundler.require

# Workers
require './test_job.rb'

# Votre app
require "./WebHook_Processing.rb"

# Config Sidekiq
Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://localhost:6379/0' }
end

require 'sidekiq/web'

# DSL Rack : pas de Rack::Builder.new !
use Rack::Deflater

map '/' do
  run WebHook_Processing.new
end

map '/sidekiq' do
  run Sidekiq::Web
end