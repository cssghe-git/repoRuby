#
=begin
    
=end

require 'net/http'
require 'uri'
require 'json'

# Vos variables
access_token = "fmu1-23e44178-9b43b52d8022877f4282b2b060070f36-0-e5c5404211ee4b1be015d82c76df9e80"
state_file = 'state_email.txt'  # Fichier pour stocker la dernière valeur de state

# Charger la dernière valeur de state si elle existe
last_state = nil
if File.exist?(state_file)
  last_state = File.read(state_file).strip
end

# Préparer la requête
uri = URI.parse('https://api.fastmail.com/jmap')

# Construire la requête avec sinceState si disponible
payload = {
  "using" => ["urn:ietf:params:jmap:mail"],
  "methodCalls" => [
    ["Email/query", {
      "filter" => {
        "inMailbox" => "INBOX"
        # Ajoutez "isUnread" => true si vous ne voulez que les non lus
      },
      "sinceState" => last_state,
      "limit" => 50  # ajustez selon votre besoin
    }, "c1"]
  ]
}
puts    "Payload-Query: #{payload}"
# Envoyer la requête
url_str = 'https://api.fastmail.com/jmap'
uri = URI.parse(url_str)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
request = Net::HTTP::Post.new(uri.request_uri)
request['Authorization'] = "Bearer #{access_token}"
request['Content-Type'] = 'application/json'
request.body = JSON.dump(payload)

response = http.request(request)
puts    "Query-Response: #{response}"
if response.is_a?(Net::HTTPSuccess)
  result = JSON.parse(response.body)
  method_response = result['methodResponses'][0]
  if method_response && method_response[0] == 'Email/query'
    emails = method_response[1]['ids']
    new_state = method_response[1]['queryState']
    puts "Emails récupérés : #{emails}"
    puts "Nouveau state : #{new_state}"

    # Sauvegarder la nouvelle valeur de state
    File.open(state_file, 'w') { |file| file.write(new_state) }

    # Si vous voulez récupérer le contenu des emails
    unless emails.empty?
      # Préparer la requête pour obtenir le contenu
      payload_get = {
        "using" => ["urn:ietf:params:jmap:mail"],
        "methodCalls" => [
          ["Email/get", {
            "ids" => emails,
            "properties" => ["from", "subject", "textBody"]
          }, "c2"]
        ]
      }
      puts  "Payload-Get: #{payload_get}"
      request.body = JSON.dump(payload_get)
      response_get = http.request(request)

      if response_get.is_a?(Net::HTTPSuccess)
        email_details = JSON.parse(response_get.body)
        puts JSON.pretty_generate(email_details)
      else
        puts "Erreur lors de la récupération du contenu : #{response_get.code} #{response_get.message}"
      end
    end
  else
    puts "Aucune réponse de l'API ou erreur dans la requête."
  end
else
  puts "Erreur HTTP : #{response.code} #{response.message}"
  puts response.body
end