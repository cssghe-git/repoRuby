#!/usr/bin/env ruby
# frozen_string_literal: true

# Affiche la fiche d’un membre + Actions (UPD/MAJ) + Cotisations + Historiques
# Export JSON optionnel: --json - (stdout) ou --json /chemin/fichier.json

require 'json'
require 'httparty'

# ==========
# CONFIG
# ==========
# Clé API Notion
NOTION_API_KEY = "secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3"

# Vrais database_id (UUID/32-hex) — PAS des URLs compressées.
# export MBR_DB_ID=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
MBR_DB_ID = "26872117-082a-8066-99bd-000beaa5de5e"
COT_DB_ID = "26872117-082a-8009-b57e-000b5a14d79e"
HIS_DB_ID = "26872117-082a-8071-be36-000b7d30fde8"
UPD_DB_ID = "27072117-082a-80ca-a7b5-000b8e391b8c"
MAJ_DB_ID = "26872117-082a-808c-a7c4-000b69a3bf7e"

# Noms de propriétés (conformes à votre schéma M25)
PROP_MEMBER_REF    = 'Référence'             # title
PROP_MBR_ACT_PRC   = 'Activité principale'   # select
PROP_MBR_ACT_SECS  = 'Activités secondaires' # multi_select
PROP_MBR_CDC       = 'CDC'                   # select
PROP_MBR_VA        = 'V-A'                   # select
PROP_MBR_TYPE_ACT  = 'Type activité'         # formula (texte)
PROP_MBR_TYPE_COT  = 'Type cotisation'       # formula (texte)

# Relations vers le membre (dans COT/UPD/MAJ)
PROP_REL_MEMBER    = 'relMembre'                        # relation

# COT
PROP_COT_STATUS    = 'Statut'             # status
PROP_COT_YEAR      = 'Année'              # number
PROP_COT_AMOUNT    = 'Cotisation pleine'  # number

# HIS (pas de relation MBR → filtre texte)
PROP_HIS_TYPE      = 'Type'               # select
PROP_HIS_REQUEST    = 'Demande'                         # select
PROP_HIS_PRIVATE    = 'Infos privées'                   # text
PROP_HIS_ENEO       = 'Infos Eneo'                      # text
PROP_HIS_DATE      = 'Date de création'   # created_time
PROP_HIS_MEMBER_BY = 'Référence'          # fallback: 'Member' (title)

# Actions (UPD/MAJ)
PROP_ACTION_TYPE   = 'Demande'            # select/multi_select
PROP_ACTION_DATE   = 'Date de création'   # created_time
PROP_ACTION_STATUS = 'Etat'               # status

# ==========
# Notion REST
# ==========
API = 'https://api.notion.com/v1'
NOTION_VERSION = "2025-09-03"

HEADERS = {
  'Authorization'   => "Bearer #{NOTION_API_KEY}",
  'Notion-Version'  => NOTION_VERSION,
  'Content-Type'    => 'application/json'
}

def notion_get(path)
  res = HTTParty.get("#{API}/#{path}", headers: HEADERS)
  raise "GET #{path} → #{res.code}: #{res.body}" unless res.code.between?(200, 299)
  JSON.parse(res.body)
end

def notion_post(path, payload)
  res = HTTParty.post("#{API}/#{path}", headers: HEADERS, body: JSON.dump(payload))
  raise "POST #{path} → #{res.code}: #{res.body}" unless res.code.between?(200, 299)
  JSON.parse(res.body)
end

def query_db(db_id, filter: nil, sorts: nil, page_size: 100, start_cursor: nil)
  body = { page_size: page_size }
  body[:filter] = filter if filter
  body[:sorts]  = sorts  if sorts
  body[:start_cursor] = start_cursor if start_cursor
  notion_post("data_sources/#{db_id}/query", body)
end

def get_page(page_id)
  notion_get("pages/#{page_id}")
end

# ==========
# Helpers
# ==========
def extract_page_id(input)
  return input if input =~ /\A[0-9a-f]{32}\z/i || input =~ /\A[0-9a-f\-]{36}\z/i
  if input.include?('notion.so') || input.include?('notion.site')
    id = input.split('-').last
    id = id.split('?').first
    return id.gsub('-', '') if id
  end
  nil
end

def title_of(page)
  prop = page['properties'].values.find { |p| p['type'] == 'title' }
  return '' unless prop
  prop['title'].map { |t| t['plain_text'] }.join
end

def plain_text(prop)
  case prop&.dig('type')
  when 'rich_text' then prop['rich_text'].map { |t| t['plain_text'] }.join
  when 'title'     then prop['title'].map { |t| t['plain_text'] }.join
  when 'select'    then prop['select']&.dig('name').to_s
  when 'status'    then prop['status']&.dig('name').to_s
  when 'number'    then prop['number']&.to_s || ''
  when 'date'
    d = prop['date'] || {}
    [d['start'], d['end']].compact.join(' → ')
  else
    ''
  end
end

def multi_select_names(prop)
  return [] unless prop && prop['type'] == 'multi_select'
  prop['multi_select'].map { |x| x['name'] }
end

# ==========
# Sélection du membre
# ==========
def find_member_by_ref(ref)
  data = query_db(MBR_DB_ID, filter: { property: PROP_MEMBER_REF, rich_text: { equals: ref } })
  data['results'].first
end

def fetch_member(input)
  if (pid = extract_page_id(input))
    get_page(pid)
  else
    find_member_by_ref(input) || abort("Membre introuvable pour identifiant/ref: #{input}")
  end
end

# ==========
# Collectes
# ==========
def collect_by_rel(db_id, page_id)
  acc, cursor = [], nil
  loop do
    data = query_db(
      db_id,
      filter: { property: PROP_REL_MEMBER, relation: { contains: page_id } },
      page_size: 100,
      start_cursor: cursor
    )
    acc.concat(data['results'])
    break unless data['has_more']
    cursor = data['next_cursor']
  end
  acc
end

def his_for_member(member_ref)
  data = query_db(
    HIS_DB_ID,
    filter: { or: [
      { property: PROP_HIS_MEMBER_BY, rich_text: { equals: member_ref } },
      { property: 'Member',           title:     { equals: member_ref } }
    ] }
  )
  data['results']
end

# ==========
# Rendu console
# ==========
def render_member_header(member)
  props   = member['properties']
  ref     = (plain_text(props[PROP_MEMBER_REF]).empty? ? title_of(member) : plain_text(props[PROP_MEMBER_REF]))
  act_prc = props.dig(PROP_MBR_ACT_PRC, 'select', 'name').to_s
  act_sec = props.dig(PROP_MBR_ACT_SECS, 'multi_select')&.map { |x| x['name'] } || []
  cdc     = props.dig(PROP_MBR_CDC, 'select', 'name').to_s
  va      = props.dig(PROP_MBR_VA, 'select', 'name').to_s
  type_a  = props.dig(PROP_MBR_TYPE_ACT, 'formula', 'string').to_s
  type_c  = props.dig(PROP_MBR_TYPE_COT, 'formula', 'string').to_s

  puts "=== Membre ==="
  puts "Page ID: #{member['id']}"
  puts "Référence:".ljust(25) + "#{ref}"
  puts "Activité principale:".ljust(25) + "#{act_prc}" unless act_prc.empty?
  puts "Activités secondaires:".ljust(25) + "#{act_sec.join(' | ')}" unless act_sec.empty?
  puts "CDC:".ljust(25) + "#{cdc}" unless cdc.empty?
  puts "V-A:.ljust(25) + "#{va}" unless va.empty?
  puts "Type activité:".ljust(25) + "#{type_a}" unless type_a.empty?
  puts "Type cotisation:".ljust(25) + "#{type_c}" unless type_c.empty?
  puts
end

def render_cotisations(cots)
  puts "=== Cotisations (#{cots.size}) ==="
  cots.sort_by! { |p| p.dig('properties', PROP_COT_YEAR, 'number').to_i }
  cots.each do |p|
    pr = p['properties']
    puts "- #{title_of(p)} | Année: #{pr.dig(PROP_COT_YEAR,'number')} | Montant: #{pr.dig(PROP_COT_AMOUNT,'number')} | Statut: #{pr.dig(PROP_COT_STATUS,'status','name')}"
  end
  puts
end

def render_historiques(hiss)
  puts "=== Historiques (#{hiss.size}) ==="
  hiss.sort_by! { |p| p.dig('properties', PROP_HIS_DATE, 'created_time').to_s }
  hiss.each do |p|
    pr  = p['properties']

    lab = (pr.dig('Référence', 'rich_text') || []).map { |t| t['plain_text'] }.join
    lab = title_of(p) if lab.empty?
    his_request = "#{pr.dig(PROP_HIS_REQUEST, 'select', 'name')}"
    his_type    = "#{pr.dig(PROP_HIS_TYPE, 'select','name')}"
    his_private = (pr.dig(PROP_HIS_PRIVATE, 'rich_text') || []).map { |t| t['plain_text'] }.join
    his_eneo    = (pr.dig(PROP_HIS_ENEO, 'rich_text') || []).map { |t| t['plain_text'] }.join

    puts "- #{pr.dig(PROP_HIS_DATE, 'created_time')} | " +
        "FOR: #{lab} => " +
        "REQ: #{his_request} | " +
        "TYP: #{his_type} \n" +
        "PRV: #{his_private} \n" +
        "ENO: #{his_eneo}"
  end
  puts
end

def render_actions(actions)
  puts "=== Actions (UPD/MAJ) (#{actions.size}) ==="
  actions.sort_by! { |p| p.dig('properties', PROP_ACTION_DATE, 'created_time').to_s }
  actions.each do |p|
    pr  = p['properties']
    typ = pr.dig(PROP_ACTION_TYPE,'select','name')
    typ ||= (pr.dig(PROP_ACTION_TYPE,'multi_select') || []).map { |x| x['name'] }.join(', ')
    puts "- #{pr.dig(PROP_ACTION_DATE,'created_time')} | #{typ} | #{pr.dig(PROP_ACTION_STATUS,'status','name')} | #{title_of(p)}"
  end
  puts
end

# ============
# JSON helpers
# ============
def member_json(member)
  props = member['properties']
  {
    page_id: member['id'],
    reference: (plain_text(props[PROP_MEMBER_REF]).empty? ? title_of(member) : plain_text(props[PROP_MEMBER_REF])),
    activite_principale: props.dig(PROP_MBR_ACT_PRC, 'select', 'name'),
    activites_secondaires: (props.dig(PROP_MBR_ACT_SECS, 'multi_select') || []).map { |x| x['name'] },
    cdc: props.dig(PROP_MBR_CDC, 'select', 'name'),
    va: props.dig(PROP_MBR_VA, 'select', 'name'),
    type_activite: props.dig(PROP_MBR_TYPE_ACT, 'formula', 'string'),
    type_cotisation: props.dig(PROP_MBR_TYPE_COT, 'formula', 'string')
  }
end

def cotisation_json(p)
  pr = p['properties']
  {
    page_id: p['id'],
    titre: title_of(p),
    annee: pr.dig(PROP_COT_YEAR, 'number'),
    montant: pr.dig(PROP_COT_AMOUNT, 'number'),
    statut: pr.dig(PROP_COT_STATUS, 'status', 'name')
  }
end

def historique_json(p)
  pr = p['properties']
  {
    page_id: p['id'],
    date_creation: pr.dig(PROP_HIS_DATE, 'created_time'),
    type: pr.dig(PROP_HIS_TYPE, 'select', 'name'),
    reference_ou_member: (pr.dig('Référence','rich_text') || []).map { |t| t['plain_text'] }.join,
    title_member: title_of(p)
  }
end

def action_json(p)
  pr = p['properties']
  typ = pr.dig(PROP_ACTION_TYPE, 'select', 'name') ||
        (pr.dig(PROP_ACTION_TYPE, 'multi_select') || []).map { |x| x['name'] }
  {
    page_id: p['id'],
    date_creation: pr.dig(PROP_ACTION_DATE, 'created_time'),
    type: typ,
    statut: pr.dig(PROP_ACTION_STATUS, 'status', 'name'),
    titre: title_of(p)
  }
end

# ==================
#   =====MAIN=====
# ==================
if __FILE__ == $0
  # Usage:
  # ruby eneobwspc_displMember.rb <MBR_Référence|MBR_page_url|MBR_page_id> [--json <path_or_->]
  abort "Usage: ruby #{__FILE__} <MBR_Référence|MBR_page_url|MBR_page_id> [--json <path_or_->]" if ARGV.empty?

#  input    = ARGV[0]
#  json_out = (ARGV[1] == '--json') ? (ARGV[2] || '-') : nil
    print   "Member ref: (Lastname-Firstname) ? "
    input   = $stdin.gets.chomp.to_s

    print   "JSON: (T(rue)/F(alse)) ? "
    json_out    = $stdin.gets.chomp.to_s.upcase
    json_out    = false     unless json_out == 'T'

  # 1) Membre
  member = fetch_member(input)
  member_id  = member['id']
  member_ref = plain_text(member['properties'][PROP_MEMBER_REF])
  member_ref = title_of(member) if member_ref.nil? || member_ref.empty?

  # 2) COT / HIS / Actions
  cot_list = collect_by_rel(COT_DB_ID, member_id)
  his_list = his_for_member(member_ref)
  act_list = collect_by_rel(UPD_DB_ID, member_id) + collect_by_rel(MAJ_DB_ID, member_id)

  # 3) Affichage console
  render_member_header(member)
  render_cotisations(cot_list)
  render_historiques(his_list)
  render_actions(act_list)

  # 4) Export JSON
  if json_out
    payload = {
      member:      member_json(member),
      cotisations: cot_list.sort_by { |p| p.dig('properties', PROP_COT_YEAR, 'number').to_i }.map { |p| cotisation_json(p) },
      historiques: his_list.sort_by { |p| p.dig('properties', PROP_HIS_DATE, 'created_time').to_s }.map { |p| historique_json(p) },
      actions:     act_list.sort_by { |p| p.dig('properties', PROP_ACTION_DATE, 'created_time').to_s }.map { |p| action_json(p) }
    }
    json_str = JSON.pretty_generate(payload)
    if json_out == '-'
      puts json_str
    else
        json_out    = "/users/Gilbert/Public/MemberLists/Works/#{input}.json"
      File.write(json_out, json_str)
      warn "JSON exporté: #{json_out}"
    end
  end
end