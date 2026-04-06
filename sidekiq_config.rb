#!/usr/bin/env ruby
require 'bundler/setup'
Bundler.require(:default, ENV['RACK_ENV'] ||= 'development')

require_relative './webhook_async.rb'

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  config.logger.formatter = proc do |severity, datetime, _progname, msg|
    "#{datetime.strftime('%y-%m-%d-%H:%M:%S')} #{severity} #{msg}\n"
  end
end