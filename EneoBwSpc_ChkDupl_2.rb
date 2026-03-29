# frozen_string_literal: true
require "json"
require "csv"
require "httparty"
require "unf"
require "amatch"
require 'logger'

    # ***Environment ***
    #*******************
begin
  require "dotenv"
  Dotenv.load
rescue LoadError
end

    # ***Variables ***
    #*****************
NOTION_TOKEN = "secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3"
DB_ID        = "26872117-082a-8066-99bd-000beaa5de5e" # ID de m25t.Membres (data source)
API_BASE     = "https://api.notion.com/v1"
NOTION_VER   = "2025-09-03" # OK pour DBs data-sources

DRY_RUN = ENV["DRY_RUN"] == "true"

    HEADERS = {
    "Authorization"  => "Bearer #{NOTION_TOKEN}",
    "Notion-Version" => NOTION_VER,
    "Content-Type"   => "application/json"
    }

    # *** Fonctions ***
    #******************
    def unaccent(str)
        return "" if str.nil?
        UNF::Normalizer.normalize(str.to_s, :nfkd).gsub(/\p{Mn}/, "")
    end

    def norm_nom(s)
        unaccent(s).downcase.strip.gsub(/\s+/, " ")
    end

    def norm_prenom(s)
        unaccent(s).downcase.gsub(/[-\s’']/, "")
    end

    def jw(a, b)
        return 0.0 if a.nil? || b.nil?
        Amatch::JaroWinkler.new(a).match(b)
    end

    def notion_query_database(db_id, start_cursor: nil, page_size: 100)
        body = { page_size: page_size }
        body[:start_cursor] = start_cursor if start_cursor
        HTTParty.post("#{API_BASE}/data_sources/#{db_id}/query",
            headers: HEADERS, body: JSON.dump(body)
        )
    end

    def notion_update_page(page_id, prop_payload, reference)
        puts    "DBG>>UPDPAGE:: FOR: #{reference} => #{prop_payload}"
        HTTParty.patch("#{API_BASE}/pages/#{page_id}",
            headers: HEADERS,
            body: JSON.dump({ properties: prop_payload })
        )
    end

    def rich_text_value(str)
        { "type" => "rich_text",
            "rich_text" => [{ "type" => "text", "text" => { "content" => str.to_s } }] }
    end

    def get_prop(page, name)
        p = page.dig("properties", name)
        return nil unless p

        case p["type"]
        when "title"
            p["title"].map { _1["plain_text"] }.join
        when "rich_text"
            p["rich_text"].map { _1["plain_text"] }.join
        when "select"
            p["select"] && p["select"]["name"]
        when "multi_select"
            (p["multi_select"] || []).map { _1["name"] }.join(",")
        when "status"
            p["status"] && p["status"]["name"]
        when "date"
            p["date"] && p["date"]["start"] # ISO-8601
        when "email"
            p["email"]
        when "phone_number"
            p["phone_number"]
        when "number"
            p["number"]
        when "checkbox"
            p["checkbox"] ? "__YES__" : "__NO__"
        when "people"
            # retourne des IDs concaténés (ajustez selon votre usage)
            (p["people"] || []).map { _1["id"] }.join(",")
        when "relation"
            # retourne des page_ids concaténés (ajustez selon votre usage)
            (p["relation"] || []).map { _1["id"] }.join(",")
        when "formula"
            f = p["formula"]
            case f["type"]
            when "string"  then f["string"]
            when "number"  then f["number"]
            when "boolean" then f["boolean"] ? "__YES__" : "__NO__"
            when "date"    then f["date"] && f["date"]["start"]
            else nil
            end
        else
            # fallback: renvoie la valeur brute du sous-type
            p[p["type"]]
        end
    end

    def year_from_iso(d)
        return nil if d.to_s.empty?
        d[0,4]
    end

    def calc_block_key(nom_brut, date_iso, cdc)
        y = year_from_iso(date_iso)
        n0 = nom_brut.to_s
        initiale = n0.empty? ? "" : n0[0].downcase
        "#{initiale}:#{y}:#{cdc}"
    end

    def collect_members
        results = []
        cursor = nil
        loop do
            resp = notion_query_database(DB_ID, start_cursor: cursor)
            raise "Query error: #{resp.code} #{resp.body}" unless resp.success?
            data = resp.parsed_response
            results.concat(data["results"])
            break unless data["has_more"]
            cursor = data["next_cursor"]
        end
        results
    end

    def update_norm_fields(page_id, nom_nrm, prenom_nrm, reference)
        props = {
            "Nom nrm"    => rich_text_value(nom_nrm),
            "Prénom nrm" => rich_text_value(prenom_nrm)
        }
        resp = notion_update_page(page_id, props, reference)
        warn "Update error #{page_id}: #{resp.code} #{resp.body}" unless resp.success?
    end

    def update_duplicates_summary(page_id, text)
        props = { "Duplicates" => rich_text_value(text) }
        resp = notion_update_page(page_id, props,nil)
        warn "Dupes update error #{page_id}: #{resp.code} #{resp.body}" unless resp.success?
    end

    # Main fonction
    #++++++++++++++
    def main
        puts    "=> Start with mode: #{DRY_RUN} #{DRY_RUN ? 'DRY_RUN (simulation)' : 'PRODUCTION'}"

        puts    "=> Init: Collect members"
        pages = collect_members

        puts    "=> 1) Normalisation et extraction des champs utiles"
        # 1) Normalisation et extraction des champs utiles

        rows = pages.map do |p|
            ref      = get_prop(p, "Référence").to_s
            @refmbr  = ref

            nom_brut = get_prop(p, "Nom brut").to_s
            pre_brut = get_prop(p, "Prénom brut").to_s
            nom_nrm  = norm_nom(nom_brut)
            pre_nrm  = norm_prenom(pre_brut)
            cdc      = get_prop(p, "CDC").to_s
            dob      = get_prop(p, "Date naissance")
            {
            id: p["id"],
            ref: ref,
            nom_brut: nom_brut,
            pre_brut: pre_brut,
            nom_nrm: nom_nrm,
            pren_nrm: pre_nrm,
            cdc: cdc,
            dob: dob,
            block: calc_block_key(nom_brut, dob, cdc)
            }
        end

        puts    "=> 2) Écrire les champs normalisés (idempotent)"
        # 2) Écrire les champs normalisés (idempotent)
    #    rows.each { |r| update_norm_fields(r[:id], r[:nom_nrm], r[:pren_nrm]) }
        rows.each do |r|
            puts    "DBG>>ROW: #{r}"
        #    exit 9
            update_norm_fields(r[:id], r[:nom_nrm], r[:pren_nrm], r[:ref])
        end

        puts    "=> 3) Détection doublons via blocking"
        # 3) Détection doublons via blocking
        by_block = rows.group_by { |r| r[:block] }
        dupes = []

        by_block.each_value do |group|
            next if group.length < 2
            group.combination(2) do |a, b|
                jw_nom = jw(a[:nom_nrm], b[:nom_nrm])
                jw_pre = jw(a[:pren_nrm], b[:pren_nrm])
                bonus = 0.0
                a_year = year_from_iso(a[:dob])
                b_year = year_from_iso(b[:dob])
                bonus += 0.02 if a_year && a_year == b_year
                bonus += 0.01 if a[:cdc] && a[:cdc] == b[:cdc]
                score = 0.6 * jw_nom + 0.4 * jw_pre + bonus

                if score >= 0.95 || (jw_nom >= 0.94 && jw_pre >= 0.93)
                    dupes << {
                    a_id: a[:id], a_ref: a[:ref],
                    b_id: b[:id], b_ref: b[:ref],
                    score: score.round(4),
                    jw_nom: jw_nom.round(4),
                    jw_pre: jw_pre.round(4),
                    same_year: a_year == b_year,
                    same_cdc: a[:cdc] == b[:cdc]
                    }
                end
            end
        end

        puts    "=> 4) Export CSV des paires"
        # 4) Export CSV des paires
        CSV.open("dupes.csv", "w", col_sep: ",") do |csv|
                csv << %w[a_id a_ref b_id b_ref score jw_nom jw_pre same_year same_cdc]
                dupes.each do |d|
                    csv << [d[:a_id], d[:a_ref], d[:b_id], d[:b_ref], d[:score], d[:jw_nom], d[:jw_pre], d[:same_year], d[:same_cdc]]
                end
        end

        puts    "=> 5) Construction des résumés par page (symétrique)"
        # 5) Construction des résumés par page (symétrique)
        by_page = Hash.new { |h, k| h[k] = [] }
        dupes.each do |d|
            line_ab = "#{d[:b_ref]} [score=#{d[:score]}, nom=#{d[:jw_nom]}, prénom=#{d[:jw_pre]}#{d[:same_year] ? ', sameYear' : ''}#{d[:same_cdc] ? ', sameCDC' : ''}]"
            line_ba = "#{d[:a_ref]} [score=#{d[:score]}, nom=#{d[:jw_nom]}, prénom=#{d[:jw_pre]}#{d[:same_year] ? ', sameYear' : ''}#{d[:same_cdc] ? ', sameCDC' : ''}]"
            by_page[d[:a_id]] << line_ab
            by_page[d[:b_id]] << line_ba
        end

        puts    "=> 6) Écriture des Duplicates (ou vide si aucun)"
        # 6) Écriture des Duplicates (ou vide si aucun)
        rows.each do |r|
            summary = by_page[r[:id]]
            text = if summary.nil? || summary.empty?
                ""  # aucune paire
            else
                summary.uniq.sort.join("\n")
            end
            update_duplicates_summary(r[:id], text)
        end

        puts "Normalisations mises à jour: #{rows.size}"
        puts "Paires suspectes: #{dupes.size} -> dupes.csv"
        puts "Propriété 'Duplicates' écrite sur #{rows.size} pages"
    end

    # *** Utilisation ***
    #********************
    main