# frozen_string_literal: true
=begin
    Fonctions : mettre en concordance : 
        -"Activité principale" et "ActPrc"
        -"Activités secondaires" et ActSecs
        -Gestionnaires
    Exécution :
        -SPC_DRY_RUN dans .env
        -ruby EneoBwSoc_MbrCheck_IA.rb
    Logique :
        -lecture des activités pour obtenir leur ID
        -lecture de tous les membres en service
        -m-à-j du membre
=end

require "json"
require "httparty"
#
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

NOTION_TOKEN    = ENV.fetch("NOT_APITOKEN") # secret_...
NOTION_VERSION  = ENV.fetch("NOT_APIVER") # version

MEMBRES_DB_ID   = "26872117-082a-8066-99bd-000beaa5de5e"     # m25t.Membres
ACTIVITES_DB_ID = "26972117-082a-8069-b6b3-000b1e2bb287"   # m25t.Activités

DRY_RUN         = ENV.fetch("SPC_DRY_RUN", "true").downcase == "true"  # default: true

@suivant = false # set to true to skip confirmation prompts

class Notion
  include HTTParty
  base_uri "https://api.notion.com/v1"

  def initialize(token:)
    @headers = {
      "Authorization" => "Bearer #{token}",
      "Notion-Version" => NOTION_VERSION,
      "Content-Type" => "application/json"
    }
  end

  def query_database(database_id, filter: nil, page_size: 100)
    results = []
    start_cursor = nil

    loop do
      body = { page_size: page_size }
      body[:filter] = filter if filter
      body[:start_cursor] = start_cursor if start_cursor

      resp = self.class.post("/data_sources/#{database_id}/query", headers: @headers, body: body.to_json)
      raise "Query failed #{resp.code}: #{resp.body}" unless resp.code.between?(200, 299)

      data = resp.parsed_response
      results.concat(data["results"])
      break unless data["has_more"]

      start_cursor = data["next_cursor"]
    end

    results
  end

  def update_page(page_id, properties:)
    body = { properties: properties }
    resp = self.class.patch("/pages/#{page_id}", headers: @headers, body: body.to_json)
    raise "Update failed #{resp.code}: #{resp.body}" unless resp.code.between?(200, 299)
    resp.parsed_response
  end
end

def page_id(page) = page["id"]

def title_plain(prop)
  arr = prop&.dig("title") || []
  arr.map { |t| t.dig("plain_text") }.join
end

def select_name(prop) = prop&.dig("select", "name")

def multi_select_names(prop)
  (prop&.dig("multi_select") || []).map { |o| o["name"] }.compact
end

def checkbox_true?(prop) = prop&.dig("checkbox") == true

def people_ids(prop)
  (prop&.dig("people") || []).map { |p| p["id"] }.compact
end

def relation_ids(prop)
  (prop&.dig("relation") || []).map { |r| r["id"] }.compact
end

def same_set?(a, b)
  a.compact.uniq.sort == b.compact.uniq.sort
end

def normalize_secondaries(names)
  names = names.map { |n| n.to_s.strip }.reject(&:empty?)
  names = names.reject { |n| n.casecmp("None").zero? }
  names.uniq.first(5)
end

notion = Notion.new(token: NOTION_TOKEN)

puts "DRY_RUN=#{DRY_RUN} (set DRY_RUN=false pour écrire)"

# 1) Charger activités => map "Référence" -> { page_id, managers[] }
activities = notion.query_database(ACTIVITES_DB_ID)
activity_by_name = {}

activities.each do |act|
  props = act["properties"]
  name = title_plain(props["Référence"]).strip
  next if name.empty?

  activity_by_name[name] = {
    page_id: page_id(act),
    managers: people_ids(props["Gestionnaire"])
  }
end

puts "Activités chargées: #{activity_by_name.size}"

# 2) Charger membres "En/Hors service" = true
members_filter = {
  property: "En/Hors service",
  checkbox: { equals: true }
}
members_sort = { "Référence" => "ascending" }

members = notion.query_database(MEMBRES_DB_ID, filter: members_filter)
puts "Membres candidats: #{members.size}"

changed = 0
skipped = 0
unchanged = 0

members.each_with_index do |mbr, idx|
  props = mbr["properties"]
  mbr_ref = title_plain(props["Référence"]).strip

  prc_name = select_name(props["Activité principale"])
  sec_names = normalize_secondaries(multi_select_names(props["Activités secondaires"]))

  # Existant (pour comparer)
  current_actprc_ids = relation_ids(props["ActPrc"])       # devrait être 0..1
  current_actsecs_ids = relation_ids(props["ActSecs"])
  current_manager_ids = people_ids(props["Gestionnaire"])

  # Résolution activité principale
  prc_activity = prc_name && activity_by_name[prc_name]
  unless prc_activity
    puts "[#{idx + 1}/#{members.size}] #{mbr_ref}: Activité principale introuvable: #{prc_name.inspect} => SKIP"
    skipped += 1
    next
  end

  desired_actprc_ids = [prc_activity[:page_id]]

  # Résolution secondaires (on ignore introuvables mais on les trace)
  desired_actsecs_ids = []
  missing_secs = []

  sec_names.each do |n|
    act = activity_by_name[n]
    if act
      desired_actsecs_ids << act[:page_id]
    else
      missing_secs << n
    end
  end

  # Gestionnaires désirés
  desired_manager_ids = []
  desired_manager_ids.concat(prc_activity[:managers])
  sec_names.each do |n|
    act = activity_by_name[n]
    desired_manager_ids.concat(act[:managers]) if act
  end
  desired_manager_ids = desired_manager_ids.uniq

  # Détection diff
  need_actprc = !same_set?(current_actprc_ids, desired_actprc_ids)
  need_actsecs = !same_set?(current_actsecs_ids, desired_actsecs_ids)
  need_managers = !same_set?(current_manager_ids, desired_manager_ids)

  if !(need_actprc || need_actsecs || need_managers)
    unchanged += 1
    next
  end

  changed += 1

  puts "\n[#{idx + 1}/#{members.size}] #{mbr_ref}"
  puts "  Activité principale: #{prc_name}"
  puts "  Secondaires (max 5): #{sec_names.join(", ")}"
  puts "  Secondaires introuvables: #{missing_secs.join(", ")}" unless missing_secs.empty?
  puts "  Diff:"
  puts "    ActPrc:  #{prc_name}  : #{current_actprc_ids.inspect}  ->  #{desired_actprc_ids.inspect} : #{need_actprc ? "CHANGE" : "OK"}"
  puts "    ActSecs: #{sec_names} : #{current_actsecs_ids.sort.inspect}  ->  #{desired_actsecs_ids.sort.inspect} : #{need_actsecs ? "CHANGE" : "OK"}"
  puts "    Gest.:   #{current_manager_ids.sort.inspect}  ->  #{desired_manager_ids.sort.inspect} : #{need_managers ? "CHANGE" : "OK"}"

  next if DRY_RUN

    if @suivant == false
        print "Membre(s) suivant(s) : (Quitter, <Ret> pour 1 membre, Tous pour tous les membres restants) ? "
        answer = STDIN.gets.chomp.downcase
        break if answer == "q"
        @suivant = true if answer == "t"
    end

    update_props = {}
    update_props["ActPrc"] = { relation: desired_actprc_ids.map { |pid| { id: pid } } } if need_actprc
    update_props["ActSecs"] = { relation: desired_actsecs_ids.map { |pid| { id: pid } } } if need_actsecs
    update_props["Gestionnaire"] = { people: desired_manager_ids.map { |uid| { id: uid } } } if need_managers

    notion.update_page(page_id(mbr), properties: update_props)
    puts "  => UPDATED"
end

puts "\nRésumé:"
puts "  changed:   #{changed}"
puts "  unchanged: #{unchanged}"
puts "  skipped:   #{skipped}"
puts "  total:     #{members.size}"