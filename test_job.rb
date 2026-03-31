require 'sidekiq'

class TestJob
  include Sidekiq::Worker

  def perform(message)
    puts "TestJob exécuté avec: #{message}"
    # Log ou traitement réel ici
  end
end