# puma.rb

# Environment
environment ENV.fetch('RACK_ENV') { 'production' }

# Nombre de processus (workers)
workers Integer(ENV['WEB_CONCURRENCY'] || 3)

# Nombre de threads par worker
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

# Port d'écoute (par défaut 4567)
port ENV['PORT'] || 4567

# Précharger l'application (améliore la performance)
preload_app!

# Fichier PID
pidfile ENV.fetch("PIDFILE") { "tmp/pids/puma.pid" }

# Fichiers de logs
stdout_redirect 'log/puma.stdout.log', 'log/puma.stderr.log', true

# Reconnexion à Redis et autres initialisations lors du démarrage d'un worker
on_worker_boot do
  require 'bundler/setup'
  Bundler.require(:default, ENV['RACK_ENV'] || 'development')
  require_relative './WebHook_Async.rb'
  require_relative './WebHook_Processing.rb'

  # Reconnecter à Redis si nécessaire
  Sidekiq.configure_client do |config|
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  end

  Sidekiq.configure_server do |config|
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
    # Configurer le logger Sidekiq si besoin
    config.logger.formatter = proc do |severity, datetime, _progname, msg|
      "#{datetime.strftime('%H:%M:%S')} #{severity} #{msg}\n"
    end
  end
end