require "uri"

event = "Pharmacie 07/05/2026 10 /Automator"
notes = "Acheter les médicaments requis"

path = [
  URI.encode_www_form_component(event)
]
puts    "DESCR: #{event} - NOTE: #{notes}}"
puts    "PATH: #{path}"

system("open", "busycalevent://new/#{path}")