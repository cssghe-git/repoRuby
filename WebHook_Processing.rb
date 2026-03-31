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
require_relative "./Webhook_Async.rb"
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

### use Rack::JSONBodyParser
#
# Set default values
#*******************
    # Sinatra configuration
    configure :production, :development do
        set :host_authorization, { permitted_hosts: [] }
        enable :logging
    end

    # My configuration
    @prefix     = ''
#
# Helpers
#********
    helpers do
        # Make new ident
        def pref(pref: "WHx")
        #+++++++
        #   pref:   prefixe
            time = Time.now.utc.strftime("%j%H%M%S")
            rand_part = SecureRandom.alphanumeric(4).upcase  # ex: "A9F3"
            return  "#{pref}-#{time}-#{rand_part}"
        end

    end #<helpers>

#
# Main code
#**********
    #
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    # Process <Post> request for <notion_webhook>
    # ++++++++++++++++++++++++++++++++++++++++++++++++
    #
    post "/notion_webhook" do
        puts    "\n>>>"
        puts    ">>>===== Webhook for </notion_webhook> ====="
        puts    ">>>"
        content_type :json

        payload         = request.body.read
        headers_hash    = request.env.select { |k, _| k}#all fields
        ### pp headers_hash

        require 'sidekiq/api'
        begin
            info = Sidekiq.redis { |conn| conn.info }
            puts "Sidekiq Redis connection info: "
        rescue => e
            "Erreur Redis: #{e.message}"
        end
        TestJob.perform_async("test webhook")

        WebhookWorker.perform_async("Notion", headers_hash.to_json)

        status 200
        content_type :json
        { ok: true }.to_json
    end