# frozen_string_literal: true
=begin
    Function:   updates MBR from UPD
    Call:       ruby EneoBwCo_UpdMbrIA.rb --act-Mode --CDC --act --only --limit --since apply
    Parameters:
        --act-Mode: merge, 
        --cdc:      XXX
        --act:      activity
        --only:     n
        --limit:    max requests
        --since:    from date
    Build;      260110-1400
    Version:    1.0.1
    Bugs:       nnn / yymmdd / text
=end

require "json"
require "httparty"
require "optparse"
require "logger"
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

# ==============================
# Config Notion
# ==============================
API = "https://api.notion.com/v1"
NOTION_VER = "2025-09-03"
NOTION_TOKEN = "secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3"

HDR = {
  "Authorization"  => "Bearer #{NOTION_TOKEN}",
  "Notion-Version" => NOTION_VER,
  "Content-Type"   => "application/json"
}

DB_UPD = "27072117-082a-80ca-a7b5-000b8e391b8c"   # m25t.Updates    https://www.notion.so/cssghe/26872117082a8084aa68c4dd00ac80bf?v=27072117082a805699d1000ce70941b0&source=copy_link
DB_MBR = "26872117-082a-8066-99bd-000beaa5de5e"   # m25t.Membres
DB_HIS = "26872117-082a-8071-be36-000b7d30fde8"   # m25t.Historiques
DB_LOG = "2af72117-082a-8052-9435-000bed9e4127"   # m25t.Actions
DB_ACT = "26972117-082a-8069-b6b3-000b1e2bb287"   # m25t.Activités

# ==============================
# CLI options
# ==============================
OPTS = {
  act_mode: "merge",   # merge|replace pour ActSecs
  cdc: "NIV",          # ex: NIV
  act: nil,            # ex: Informatique
  only: nil,           # ex: ["Modification","Arrêt"]
  limit: 200,          # ex: 100
  since: nil           # ex: "2025-11-01"
}
OptionParser.new do |o|
  o.banner = "Usage: ruby processor_upd_to_mbr.rb [options] [apply]"
  o.on("--act-mode=MODE", %w[merge replace], "merge|replace pour ActSecs") { |v| OPTS[:act_mode] = v }
  o.on("--cdc=CDC", "Filtre CDC exact") { |v| OPTS[:cdc] = v }
  o.on('--act=ACTIVITE', 'Filtre Activité principale=ACT ou secondaires contient ACT') { |v| OPTS[:act] = v }
  o.on('--only=N1,N2', Array, 'Limiter aux Demandes listées') { |v| OPTS[:only] = v.map!(&:strip) }
  o.on('--limit=N', Integer, 'Traiter au plus N UPD') { |v| OPTS[:limit] = v }
  o.on('--since=YYYY-MM-DD', 'UPD créées depuis cette date (UTC)') { |v| OPTS[:since] = v }
end.parse!(ARGV)
###DRY = (ARGV.last != "apply")
DRY = ENV.fetch("DRY_RUN",true)
DRY = false if DRY=="false"
DRY = true  if DRY=="true"

DRY = false

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = Logger::INFO
    log.datetime_format = '%H:%M:%S'
    log.info("🔧 Prog: #{$0} Mode: #{DRY ? 'DRY-RUN (simulation)' : 'PRODUCTION'}")


# ==============================
# Notion helpers
# ==============================
    def db_query(db_id, filter: nil, sort: nil, start_cursor: nil, page_size: 100)
        puts    "DBG>>#{__method__}>FILTER:#{filter} - SORT:#{sort}"
        body = { page_size: page_size }
        body[:filter]   = filter    if filter
        body[:sorts]    = sort      if sort
        body[:start_cursor] = start_cursor if start_cursor
        r = HTTParty.post("#{API}/data_sources/#{db_id}/query", headers: HDR, body: JSON.dump(body))
        raise "DB query #{db_id} failed: #{r.code} #{r.body}" unless r.success?
        r.parsed_response
    end

    def page_create(db_id, props)
        puts    "DBG>>#{__method__}> on: #{db_id} with : "
        r = HTTParty.post("#{API}/pages", headers: HDR, body: JSON.dump({ parent: { data_source_id: db_id }, properties: props }))
        raise "Create failed: #{r.code} #{r.body}" unless r.success?
        r.parsed_response
    end

    def page_update(page_id, props)
        puts    "DBG>>#{__method__}>PROP:"; pp props
        r = HTTParty.patch("#{API}/pages/#{page_id}", headers: HDR, body: JSON.dump({ properties: props }))
        raise "Update #{page_id} failed: #{r.code} #{r.body}" unless r.success?
        r.parsed_response
    end

    def page_get(page_id)
        puts    "DBG>>#{__method__}>"
        r = HTTParty.get("#{API}/pages/#{page_id}", headers: HDR)
        r.success? ? r.parsed_response : nil
    end

    def get_prop(page, name)
        puts    "DBG>>#{__method__}>#{name}"
        p = page.dig("properties", name)
        return nil unless p

        case p["type"]
        when "title"         then p["title"].map { _1["plain_text"] }.join
        when "rich_text"     then p["rich_text"].map { _1["plain_text"] }.join
        when "select"        then p["select"] && p["select"]["name"]
        when "multi_select"  then (p["multi_select"] || []).map { _1["name"] }
        when "status"        then p["status"] && p["status"]["name"]
        when "date"          then p["date"] && p["date"]["start"]
        when "email"         then p["email"]
        when "phone_number"  then p["phone_number"]
        when "checkbox"      then p["checkbox"]
        when "number"        then p["number"]
        when "relation"      then (p["relation"] || []).map { _1["id"] }
        when "people"        then (p["people"]   || []).map { _1["id"] }
        when "formula"
            f = p["formula"]; return nil unless f
            case f["type"]
            when "string"  then f["string"]
            when "number"  then f["number"]
            when "boolean" then f["boolean"]
            when "date"    then f["date"] && f["date"]["start"]
            end
        else
            p[p["type"]]
        end
    end

# ==============================
# Encoders de propriétés
# ==============================
    def blank?(v)
        v.nil? || v.to_s.strip.empty?
    end

    def rt(str)
        return nil if blank?(str)

        { "type"=>"rich_text",
        "rich_text"=>[{ "type"=>"text","text"=>{ "content"=>str.to_s } }] }
    end

    def title(str)       = { "type"=>"title","title"=>[{"type"=>"text","text"=>{"content"=>str.to_s}}] }
###    def title(str)  = { "id"=> "title", "name"=> str, "type"=> "title", "title"=> {}}
    def sel(v)           = { "type"=>"select","select"=> v ? {"name"=>v} : nil }
    def ms(arr)          = { "type"=>"multi_select","multi_select"=> Array(arr).compact.map{|n| {"name"=>n} } }
    def chk(b)           = { "type"=>"checkbox","checkbox"=> !!b }
    def relation(ids)    = { "type"=>"relation","relation"=> Array(ids).compact.uniq.map{|id| {"id"=>id} } }
    def mail(v)
        return nil if blank?(v)
        { "type"=>"email","email"=> v.to_s }
    end
    def phone(v)
        return nil if blank?(v)
        { "type"=>"phone_number","phone_number"=> v.to_s }
    end
    def date_iso(s)
        d   = convert_date(s)
        r   = { "type"=>"date","date"=> d ? {"start"=> d} : nil }
        return  r
    end
    def convert_date(date_str)  
        # Gère DD/MM/YYYY → YYYY-MM-DD
        return date_str if date_str =~ /^\d{4}-\d{2}-\d{2}$/ # Déjà au bon format

        if date_str =~ %r{^(\d{2})/(\d{2})/(\d{4})$}
            return  "#{$3}-#{$2}-#{$1}"
        elsif   date_str =~ %r{^(\d{2})/(\d{2})/(\d{2})$}
            return  "20#{$3}-#{$2}-#{$1}"
        else
            return  date_str # Retourne tel quel si format non reconnu
        end
        #GHE#   date_out    = "#{date_str[6,4]}-#{date_str[3,2]}-#{date_str[0,2]}"
        return  
    end

# ==============================
# Normalisation pour diff lecture-avant-patch
# ==============================
    def val_from_prop(prop_hash)
        puts    "DBG>>#{__method__}>"; pp prop_hash
        return nil unless prop_hash && prop_hash["type"]

        t = prop_hash["type"]
        case t
        when "rich_text"    then prop_hash["rich_text"].map{|x| x.dig("plain_text") }.join
        when "title"        then prop_hash["title"].map{|x| x.dig("plain_text") }.join
        when "select"       then prop_hash["select"]&.dig("name")
        when "multi_select" then (prop_hash["multi_select"] || []).map{|x| x["name"]}.sort
        when "date"         then prop_hash["date"]&.dig("start")
        when "checkbox"     then !!prop_hash["checkbox"]
        when "email"        then prop_hash["email"]
        when "phone_number" then prop_hash["phone_number"]
        when "relation"     then (prop_hash["relation"] || []).map{|x| x["id"]}.sort
        else
            prop_hash[t]
        end
    end

    def normalize_target_value(_prop_name, encoder_payload)
        puts    "DBG>>#{__method__}>#{_prop_name}"
        return nil unless encoder_payload && encoder_payload["type"]

        case encoder_payload["type"]
        when "rich_text"    then encoder_payload["rich_text"].map{|x| x.dig("text","content")}.join
        when "title"        then encoder_payload["title"].map{|x| x.dig("text","content")}.join
        when "select"       then encoder_payload["select"]&.dig("name")
        when "multi_select" then (encoder_payload["multi_select"] || []).map{|x| x["name"]}.sort
        when "date"         then encoder_payload["date"]&.dig("start")
        when "checkbox"     then !!encoder_payload["checkbox"]
        when "email"        then encoder_payload["email"]
        when "phone_number" then encoder_payload["phone_number"]
        when "relation"     then (encoder_payload["relation"] || []).map{|x| x["id"]}.sort
        else
            encoder_payload[encoder_payload["type"]]
        end
    end

    def shrink_patch_by_diff(current_mbr_page, patch)
        puts    "DBG>>#{__method__}>"; pp patch
        return patch unless current_mbr_page

        props_now = current_mbr_page["properties"] || {}
        filtered = {}
        patch.each do |k, payload|
            now_val = val_from_prop(props_now[k])
            new_val = normalize_target_value(k, payload)
            if now_val.is_a?(String) && new_val.is_a?(String)
                filtered[k] = payload unless now_val.strip == new_val.strip
            else
                filtered[k] = payload unless now_val == new_val
            end
        end
        filtered
    end

# ==============================
# Caches & résolutions
# ==============================
    def load_acts_cache
        puts    "DBG>>#{__method__}>"
        cache, cur = {}, nil
        loop do
            data = db_query(DB_ACT, start_cursor: cur)
            data["results"].each do |page|
                name = get_prop(page, "Référence").to_s
                cache[name] = page["id"] unless name.empty?
            end
            break unless data["has_more"]; cur = data["next_cursor"]
        end
        cache
    end

    def resolve_actprc_id(upd, acts_cache)
        puts    "DBG>>#{__method__}>"
        ap = get_prop(upd, "Activité principale")
        return nil if ap.to_s.empty?
        acts_cache[ap]
    end

    def resolve_actsecs_ids(upd, acts_cache)
        puts    "DBG>>#{__method__}>"
        (get_prop(upd, "Activités secondaires") || []).map { |name| acts_cache[name] }.compact.uniq
    end

    def resolve_mbr(upd)
        puts    "DBG>>#{__method__}>"
        ids = get_prop(upd, "relMembre")
        return ids.first if ids && !ids.empty?

        ref = get_prop(upd, "Référence").to_s
        return nil if ref.empty?

        data = db_query(DB_MBR, filter: { "property"=>"Référence", "title"=>{ "equals"=> ref } })
        data["results"].first&.dig("id")
    end

# ==============================
# Chargement UPD à traiter (Etat ∈ {Enregistré, En cours})
# ==============================
    def load_upd_candidates
        puts    "DBG>>#{__method__}>"
        res, cur = [], nil
        base_filter = {
        "or": [
            { "property"=>"Etat","status"=>{"equals"=>"Enregistré"} }
        ]
        }
        base_sort = [
                { "property": "Activité principale", "direction": "ascending" },
                { "property": "Référence", "direction": "ascending" }
        ]
        loop do
            data = db_query(DB_UPD, start_cursor: cur, filter: base_filter, sort: base_sort)
            batch = data["results"]

            batch.select! do |p|
                # process according to flags
                ok = true
                ok &&= (get_prop(p,"CDC") == OPTS[:cdc]) if OPTS[:cdc]
                if OPTS[:act]
                    ap = get_prop(p,"Activité principale").to_s
                    as = Array(get_prop(p,"Activités secondaires"))
                    ok &&= (ap == OPTS[:act] || as.include?(OPTS[:act]))
                end
                ok &&= OPTS[:only].include?(get_prop(p,"Demande").to_s) if OPTS[:only]
                if OPTS[:since]
                    created = p["created_time"] || get_prop(p,"Date de création")
                    ok &&= created && created >= "#{OPTS[:since]}T00:00:00Z"
                end
                ok
            end

            res.concat(batch)
            break unless data["has_more"]
            break if OPTS[:limit] && res.size >= OPTS[:limit]
            cur = data["next_cursor"]
        end
        # limit according to flag
        res = res.first(OPTS[:limit]) if OPTS[:limit] && res.size > OPTS[:limit]
        res
    end

# ==============================
# Validation par Demande (sans exigence EHS)
# ==============================
    def validate_required!(demande, upd)
        puts    "DBG>>#{__method__}>#{demande}"
        if demande.include?("Nouveau principal")
            req = {
                "CDC"=>get_prop(upd,"CDC"),
                "Activité principale"=>get_prop(upd,"Activité principale"),
                "Civilité"=>get_prop(upd,"Civilité"),
                "Adresse"=>get_prop(upd,"Adresse"),
                "Date naissance"=>get_prop(upd,"Date naissance")
            }
            contact_ok = [get_prop(upd,"Gsm"), get_prop(upd,"Fixe"), get_prop(upd,"Email")].any? { |v| !(v.nil? || v.to_s.empty?) }
            missing = req.select { |_,v| v.nil? || v.to_s.empty? }.keys
            missing << "Gsm/Fixe/Email (au moins un)" unless contact_ok
            raise "Champs obligatoires manquants: #{missing.join(", ")}" unless missing.empty?

        elsif demande.include?("Nouveau secondaire")
            req = {
                "CDC"=>get_prop(upd,"CDC"),
                "Activités secondaires"=>get_prop(upd,"Activités secondaires"),
                "Civilité"=>get_prop(upd,"Civilité")
            }
            missing = req.select { |_,v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }.keys
            raise "Champs obligatoires manquants: #{missing.join(", ")}" unless missing.empty?

        elsif demande.include?("Ajout secondaire")
            req = { "CDC"=>get_prop(upd,"CDC"), "Activités secondaires"=>get_prop(upd,"Activités secondaires") }
            missing = req.select { |_,v| v.nil? || (v.respond_to?(:empty?) && v.empty?) }.keys
            raise "Champs obligatoires manquants: #{missing.join(", ")}" unless missing.empty?

        elsif demande.include?("Suppression principal")
        # pas d'obligations supplémentaires

        elsif demande.include?("Suppression secondaire")
            raise "Suppression secondaire à traiter manuellement"

        elsif demande.include?("Arrêt")
            raise "Champs obligatoires manquants: Date sortie" if (get_prop(upd,"Date sortie").to_s.empty?)

        elsif demande.include?("Décès")
            raise "Champs obligatoires manquants: Date décès" if (get_prop(upd,"Date décès").to_s.empty?)

        elsif demande.include?("Modification")
        # aucune obligation

        else
            raise "Demande non supportée: #{demande}"
        end
    end

# ==============================
# Création MBR “Nouveau …” (EHS forcé)
# ==============================
    def create_mbr_from_upd(upd, acts_cache)
        puts    "DBG>>#{__method__}>"
        ref   = get_prop(upd,"Référence").to_s
        civ   = get_prop(upd,"Civilité")
        addr  = get_prop(upd,"Adresse")
        gsm   = get_prop(upd,"Gsm")
        fixe  = get_prop(upd,"Fixe")
        email = get_prop(upd,"Email")
        dob   = get_prop(upd,"Date naissance")
        cdc   = get_prop(upd,"CDC")
        demande = get_prop(upd,"Demande").to_s.strip

        ehs_flag = !["Arrêt","Décès"].include?(demande) # true par défaut, false si Arrêt/Décès

        props = {
            "Référence"        => title(ref),
            "Civilité"         => sel(civ),
            "Adresse"          => rt(addr),
            "Gsm"              => phone(gsm),
            "Fixe"             => phone(fixe),
            "Email"            => mail(email),
            "Date naissance"   => date_iso(dob),
            "CDC"              => sel(cdc),
            "En/Hors service"  => chk(ehs_flag)
        }.delete_if { |_,v| v.nil? }

        if (ap_id = resolve_actprc_id(upd, acts_cache))
            props["ActPrc"] = relation([ap_id])
        end
        if (sec_ids = resolve_actsecs_ids(upd, acts_cache)).any?
            props["ActSecs"] = relation(sec_ids)
        end

        page_create(DB_MBR, props)["id"]
    end

# ==============================
# Projection UPD → patch MBR (EHS forcé)
# ==============================
    def build_mbr_patch(demande, upd, acts_cache, current_mbr)
        puts    "DBG>>#{__method__}>#{demande} - "
        props = {}
        case demande
        when "Nouveau principal"
            props["CDC"] = sel(get_prop(upd,"CDC"))
            props["Date naissance"] = date_iso(get_prop(upd,"Date naissance"))
            props["En/Hors service"] = chk(true)

            if (ap_id = resolve_actprc_id(upd, acts_cache))
                props["ActPrc"] = relation([ap_id])
            end
            if (sec_ids = resolve_actsecs_ids(upd, acts_cache)).any?
                props["ActSecs"] = relation(sec_ids)
            end

            {   "Adresse"=>->(v){ rt(v) }, 
                "Gsm"=>->(v){ phone(v) }, 
                "Fixe"=>->(v){ phone(v) },
                "Email"=>->(v){ mail(v) }, 
                "Cotisation"=>->(v){ sel(v) }, 
                "V-A"=>->(v){ sel(v) } 
                }.each do |k,enc|
                    v = get_prop(upd,k)
                    puts    "DBG>>>PRC: #{k} => #{v}"
                    next if v.to_s.empty?
                    props[k] = enc.call(v)
                end

        when "Nouveau secondaire"
            props["CDC"] = sel(get_prop(upd,"CDC"))
            props["Civilité"] = sel(get_prop(upd,"Civilité"))
            props["En/Hors service"] = chk(true)

            sec_ids = resolve_actsecs_ids(upd, acts_cache)
            props["ActSecs"] = relation(sec_ids) if sec_ids.any?

            {   "Adresse"=>->(v){ rt(v) }, 
                "Gsm"=>->(v){ phone(v) }, 
                "Fixe"=>->(v){ phone(v) },
                "Email"=>->(v){ mail(v) }, 
                "Cotisation"=>->(v){ sel(v) }, 
                "V-A"=>->(v){ sel(v) } 
            }.each do |k,enc|
                v = get_prop(upd,k)
                puts    "DBG>>>SEC: #{k} => #{v}"
                next if v.to_s.empty?
                props[k] = enc.call(v)
            end

        when "Ajout secondaire"
            props["CDC"] = sel(get_prop(upd,"CDC"))
            new_ids = resolve_actsecs_ids(upd, acts_cache)
            if OPTS[:act_mode] == "merge" && current_mbr
                existing = current_mbr.dig("properties","ActSecs","relation")&.map{|r| r["id"]} || []
                props["ActSecs"] = relation(existing + new_ids)
            else
                props["ActSecs"] = relation(new_ids)
            end
            # EHS: ne pas modifier (reste tel quel)

        when "Suppression principal"
            props["ActPrc"] = relation([])
            # EHS: ne pas modifier

        when "Arrêt"
            props["Date sortie"] = date_iso(get_prop(upd,"Date sortie"))
            props["En/Hors service"] = chk(false)

        when "Décès"
            props["Date décès"] = date_iso(get_prop(upd,"Date décès"))
            props["En/Hors service"] = chk(false)

        when "Modification"
            {
            "Adresse"    => ->(v){ rt(v) },
            "Gsm"        => ->(v){ phone(v) },
            "Fixe"       => ->(v){ phone(v) },
            "Email"      => ->(v){ mail(v) },
            "Cotisation" => ->(v){ sel(v) },
            "V-A"        => ->(v){ sel(v) }
            }.each do |k,enc|
            v = get_prop(upd,k)
                puts    "DBG>>>MOD: #{k} => #{v}"
                next    if v.to_s.empty?
                props[k] = enc.call(v)
            end
            # EHS: jamais modifié en Modification
        end

        props.delete_if { |_,v| v.nil? }
    end

# ==============================
# Tracing HIS & LOG
# ==============================
    def log_his(ref_upd, demande, type, infos_priv="", infos_eneo="")
        props = {
            "Member"       => title(ref_upd),
            "Référence"    => rt(ref_upd),
            "Demande"      => sel(demande),
            "Type"         => sel(type),
            "Infos privées"=> rt(infos_priv),
            "Infos Eneo"   => rt(infos_eneo)
        }
        page_create(DB_HIS, props)
        rescue => e
            warn "HIS failed: #{e.message}"
    end

    def log_action(source:, kind:, details:)
        props = {
            "Nom de l'action"    => title(details[:title] || "UPD→MBR"),
            "Source"             => sel(source),
            "Type d'action"      => sel(kind),
            "Détails"            => rt(details[:body].to_s),
            "Statut d'archivage" => { "type"=>"status","status"=>{"name"=>"A vérifier"} }
            }
        ###  page_create(DB_LOG, props)
        rescue => e
            warn "LOG failed: #{e.message}"
    end

# ==============================
# Append “Dernière opération” (MBR & UPD)
# ==============================
    def get_text_prop(page_hash, prop_name)
        puts    "DBG>>#{__method__}>#{prop_name}"
        p = page_hash&.dig("properties", prop_name)
        return "" unless p

        case p["type"]
        when "rich_text" then p["rich_text"].map { _1["plain_text"] }.join
        when "title"     then p["title"].map     { _1["plain_text"] }.join
        else ""
        end
    end

    def op_summary_line(ref_upd:, demande:, mbr_id:, changed_keys:)
        stamp = Time.now.utc.iso8601
        changes = changed_keys.any? ? changed_keys.join(", ") : "(aucun changement)"
        "[#{stamp}] #{demande} #{ref_upd} -> MBR=#{mbr_id} | #{changes}"
    end

# ==============================
# Traitement d'une UPD
# ==============================
    def process_one(upd, acts_cache,log)
        log.info("=> => #{__method__}>Start")
        ref_upd = get_prop(upd,"Référence").to_s
        demande = get_prop(upd,"Demande").to_s

        # Court-circuit: Demande vide → Non traité
        if demande.empty? or demande.size < 5
            if DRY
                puts "[DRY] Demande vide → marquer Non traité ref=#{ref_upd}"
            else
                fresh_upd    = page_get(upd["id"])
                old_text_upd = get_text_prop(fresh_upd, "Dernière opération")
                line         = op_summary_line(ref_upd: ref_upd, demande: "(Demande vide)", mbr_id: "-", changed_keys: [])
                new_text_upd = [old_text_upd, line].reject(&:empty?).join("\n")
                page_update(upd["id"], { "Dernière opération" => rt(new_text_upd) })
                page_update(upd["id"], { "Etat" => { "type"=>"status","status"=>{"name"=>"Non traité"} } })
                log_action(source: "UPD", kind: "Validation",
                            details: { title: "Demande vide #{ref_upd}", body: "UPD marquée Non traité" })
            end
            return
        end
        puts "*"
        log.info("=> => #{__method__}>Validation for => REF: #{ref_upd} REQ: #{demande}")
        validate_required!(demande, upd)

        log.info("=> => #{__method__}>Get MBR ID for => REF:#{ref_upd}")
        mbr_id = resolve_mbr(upd)

        if ["Nouveau principal","Nouveau secondaire"].include?(demande)
            raise "MBR déjà existant pour #{ref_upd}" if mbr_id
            if DRY
                puts "[DRY] Création MBR pour #{demande} ref=#{ref_upd}"
            else
                mbr_id = create_mbr_from_upd(upd, acts_cache)
            end
        else
            raise "MBR introuvable pour #{ref_upd}" unless mbr_id
        end

        log.info("=> => #{__method__}>Load Mbr data")
        current_mbr = (!DRY && mbr_id) ? page_get(mbr_id) : nil

        log.info("=> => #{__method__}>Build for => REF:#{ref_upd} REQ:#{demande}")
        patch = build_mbr_patch(demande, upd, acts_cache, current_mbr)
        patch = shrink_patch_by_diff(current_mbr, patch) unless DRY

        log.info("=> => #{__method__}>Update MBR & HIS & LOG")
        if DRY
            puts "[DRY] #{demande} ref=#{ref_upd} MBR=#{mbr_id || '(nouveau)'} props=#{patch.keys.join(",")}"
        else
            if patch.empty?
                log_his(ref_upd, demande, "Avant opération", "", "UPD→MBR (déjà à jour)")
                log_his(ref_upd, demande, "Après opération", "", "UPD→MBR (aucun changement)")
            else
                log_his(ref_upd, demande, "Avant opération", "", "UPD→MBR")
                
                # Update MBR
                page_update(mbr_id, patch)

                log_his(ref_upd, demande, "Après opération", "", "UPD→MBR OK")
            end

            # Append MBR
            log.info("=> => #{__method__}>MBR:Last request")
            fresh_mbr = page_get(mbr_id)
            old_text_mbr  = get_text_prop(fresh_mbr, "Dernière opération")
            line          = op_summary_line(ref_upd: ref_upd, demande: demande, mbr_id: mbr_id, changed_keys: patch.keys)
            new_text_mbr  = [old_text_mbr, line].reject(&:empty?).join("\n")
            page_update(mbr_id, { "Dernière opération" => rt(new_text_mbr) })

            # Append UPD
            log.info("=> => #{__method__}>UPD:Last request")
            fresh_upd = page_get(upd["id"])
            old_text_upd = get_text_prop(fresh_upd, "Dernière opération")
            new_text_upd = [old_text_upd, line].reject(&:empty?).join("\n")
            page_update(upd["id"], { "Dernière opération" => rt(new_text_upd) })

            # Clôture UPD + LOG
            log.info("=> => #{__method__}>Close UPD request")
            page_update(upd["id"], { "Etat" => { "type"=>"status","status"=>{"name"=>"Terminé"} } })

            log.info("=> => #{__method__}>LOG")
            log_action(source: "UPD", kind: "Modification",
                    details: { title: "#{demande} #{ref_upd}",
                                body: "MBR=#{mbr_id} -> #{patch.keys.any? ? patch.keys.join(', ') : '(aucun changement)'}" })
        end
    end

# ==============================
# Main
# ==============================
    def main(log)
        log.info("#{__method__}>")
        reply_all   = 'N'
        acts_cache  = load_acts_cache
        log.info("=> #{__method__}>Acts=>Read:#{acts_cache.size}")
        upd_pages   = load_upd_candidates
        log.info("=> #{__method__}>Mbrs=>Read: #{upd_pages.size}")

        upd_pages.each do |upd|
            reference   = get_prop(upd,"Référence").to_s
            demande     = get_prop(upd,"Demande").to_s
            log.info("=> #{__method__} Page: #{reference} - #{demande}")

            begin
                if demande.include?("Suppression secondaire")
                    puts "[SKIP] Suppression secondaire (manuel) ref=#{get_prop(upd,"Référence")}"
                    next
                end
                log.info("=> #{__method__}>Process page")
                process_one(upd, acts_cache,log)
            rescue => e
                warn "[ERR] #{get_prop(upd,"Référence")}: #{e.message} <<<<<===ERR===<<<<<"
                log_action(source: "UPD", kind: "Validation",
                            details: { title: "Erreur #{demande}", body: e.message }) unless DRY
            end

            if reply_all != 'A'
                reply   = 'N'
                print   "Next (Y, A, Q) [Q] ? "
                reply_all   = $stdin.gets.chomp.upcase
                reply   = 'Y'   if reply_all=='A' or reply_all=="Y"
                break   if reply != 'Y'
            end
        end
        puts(DRY ? "Terminé (dry-run)" : "Terminé avec le mode Production")
    end
#
    main(log)
#
=begin
    main =>
        load_acts_cache
        load_upd_candidates
            get_prod Demande
            process_one
                search MBR
                page_get (MBR)
                build_mbr_patch         result => patch
                shrink_patch_by_diff    result => patch
                page_update MBR patch
                page_update MBR Dernière opération
=end