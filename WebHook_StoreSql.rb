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
require "sqlite3"
require "redis"
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

### use Rack::JSONBodyParser

    DB = SQLite3::Database.new("webhook_events.sqlite3")
    DB.results_as_hash = true

    DB.execute <<~SQL
    CREATE TABLE IF NOT EXISTS processed_events (
        event_id TEXT PRIMARY KEY,
        processed_at TEXT NOT NULL
    )
    SQL

    def processed_event?(event_id)
        row = DB.get_first_row("SELECT event_id FROM processed_events WHERE event_id = ?", [event_id])
        !row.nil?
    end

    def mark_processed!(event_id)
        DB.execute(
            "INSERT OR IGNORE INTO processed_events (event_id, processed_at) VALUES (?, datetime('now'))",
            [event_id]
        )
    end
