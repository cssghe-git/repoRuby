redis: redis-server
web: bundle exec puma -C puma.rb
worker: bundle exec sidekiq -r ./sidekiq_config.rb -q default