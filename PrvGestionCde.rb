# frozen_string_literal: true

require "json"
require "time"
require "httparty"
require "pp"
require "csv"
require "optparse"
require "logger"
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end


# ------------------------------------------------------------
# Configuration Notion (data sources + propriétés)
# ------------------------------------------------------------

NOTION_TOKEN    = ENV.fetch("NOT_TOKEN")
NOTION_VERSION  = ENV.fetch("NOT_APIVER_OLD")
BASE_URL        = ENV.fetch("NOT_HTTPBASE")

# Data sources (vos tables)
DS_ART = "83149842df7d4665952c0a82c9f03e82"  # 🧺 ment.ARTicles https://www.notion.so/cssghe/83149842df7d4665952c0a82c9f03e82?v=823ad744b7d94ac3b9a9c995f5dca6d1&source=copy_link
DS_COM = "ded0c1b51aae40738bfd6422fe37a21f"  # 🛍️ ment.COMandes https://www.notion.so/cssghe/ded0c1b51aae40738bfd6422fe37a21f?v=c27705e5157044368f0d4ac5b1c1089d&source=copy_link
DS_LIG = "77fe71e3f2ba433ba258ecbf22aa8804"  # 📦 ment.LIGnes   https://www.notion.so/cssghe/77fe71e3f2ba433ba258ecbf22aa8804?v=a8259e68891b4583a5689245a69db9cd&source=copy_link
DS_REL = "2e772117082a80bab452e33d38736784"  # ment.RefLignes   https://www.notion.so/cssghe/2e772117082a80bab452e33d38736784?v=2e772117082a805da224000cd99a039c&source=copy_link
DS_REP = "ddfdadc7c19e4bce8605f23231faea29"  # 🍽️ ment.REPas    https://www.notion.so/cssghe/ddfdadc7c19e4bce8605f23231faea29?v=b0659366b60840a3bbde133954d41fa8&source=copy_link
DS_PAR = "30272117082a80e38511c23b4394a4f5"  # ment.Parametres  https://www.notion.so/30272117082a80e38511c23b4394a4f5?v=30272117082a809dbd6a000c02a0d35a&source=copy_link
DS_REC = "2e672117082a80eab65cefdefb55185b"  # ment.Recettes    https://www.notion.so/cssghe/2e672117082a80eab65cefdefb55185b?v=2e672117082a80ffbf6c000cb0961a9b&source=copy_link

# Parametres
PRM_PROP_NOM        = "Référence"
PRM_PROP_REFERENCE  = "Ensemble"                # Référence pour une commande

# Repas
REP_PROP_ART1           = "Article"             # relation -> ARTicles
REP_PROP_QTE1           = "Quantité"            # number
REP_PROP_ART2           = "Article"             # relation -> ARTicles
REP_PROP_QTE2           = "Quantité"            # number
REP_PROP_REC_DEJEUNER   = "Déjeuner"
REP_PROP_REC_DINER      = "Diner"
REP_PROP_REC__DESSERT   = "Dessert"
REP_PROP_REC_SOUPER     = "Souper"

# Articles
PROP_ART_TITLE  = "Référence"       # title
PROP_ART_STOCK  = "Stock"           # number
PROP_ART_SEUIL  = "Seuil"           # number
PROP_ART_A_CMD  = "A commander"     # formula (bool)

# Recettes
PROP_REC_ART1   = "Article1"
PROP_REC_QTE1   = "Quantité1"
PROP_REC_ART2   = "Article2"
PROP_REC_QTE2   = "Quantité2"
PROP_REC_ART3   = "Article3"
PROP_REC_QTE3   = "Quantité3"
PROP_REC_ART4   = "Article4"
PROP_REC_QTE4   = "Quantité4"
PROP_REC_ART5   = "Article5"
PROP_REC_QTE5   = "Quantité5"

# Commandes
PROP_COM_TITLE  = "Référence"       # title

# Lignes
PROP_LIG_TITLE      = "Référence"           # title
PROP_LIG_ARTICLE    = "Article"             # relation -> ARTicles
PROP_LIG_QTY_SAISIE = "Quantité (saisie)"   # number
PROP_LIG_REFERENCE  = "Reference"           # reference=> categorie:article

# RefLignes
PROP_REL_TITLE      = "Référence"   # title
PROP_REL_COMMANDE   = "Commande"    # relation -> COMandes
PROP_REL_LIGNES     = "Lignes"      # relation -> LIGnes
PROP_REL_ENSEMBLE   = "Ensemble"    #formule

# ------------------------------------------------------------
# Client Notion minimal (HTTParty)
# ------------------------------------------------------------

class Notion
    include HTTParty
    base_uri BASE_URL

    def initialize(token:, version:)
    #-------------
        @headers = {
            "Authorization" => "Bearer #{token}",
            "Notion-Version" => version,
            "Content-Type" => "application/json"
        }
    end

    def query_database(database_id, body = {})
    #------------------
        post("/databases/#{database_id}/query", body)
    end

    def retrieve_page(page_id)
    #----------------
        self.class.get("/pages/#{page_id}", headers: @headers)
    end

    def create_page(parent_database_id:, properties:)
    #--------------
        puts    "DBG>>>ID:#{parent_database_id}"
        body = { parent: { database_id: parent_database_id }, properties: properties }
        post("/pages", body)
    end

    def update_page(page_id:, properties:)
    #--------------
        body = { properties: properties }
        patch("/pages/#{page_id}", body)
    end

#----------
#  private
#-----------

    def post(path, body_hash)
    #-------
        resp = self.class.post(path, headers: @headers, body: JSON.dump(body_hash))
        raise "HTTP #{resp.code}: #{resp.body}" unless resp.code.between?(200, 299)
        JSON.parse(resp.body)
    end

    def patch(path, body_hash)
    #--------
        resp = self.class.patch(path, headers: @headers, body: JSON.dump(body_hash))
        raise "HTTP #{resp.code}: #{resp.body}" unless resp.code.between?(200, 299)
        JSON.parse(resp.body)
    end

    def get_title(notion, page_id)
    #------------
        page = notion.retrieve_page(page_id)
        raise "HTTP #{page.code}: #{page.body}" unless page.code.between?(200, 299)
        json = JSON.parse(page.body)
        json.dig("properties", "Référence", "content").to_s
    end

    def get_stock(notion, article_page_id)
    #------------
        page = notion.retrieve_page(article_page_id)
        raise "HTTP #{page.code}: #{page.body}" unless page.code.between?(200, 299)
        json = JSON.parse(page.body)
        json.dig("properties", PROP_ART_STOCK, "number").to_f
    end

    def set_stock(notion, article_page_id, new_stock)
    #------------
        notion.update_page(
            page_id: article_page_id,
            properties: {
                PROP_ART_STOCK => prop_number(new_stock.to_f)
            }
        )
    end

    def add_stock(notion, article_page_id, delta)
    #------------
        current = get_stock(notion, article_page_id)
        set_stock(notion, article_page_id, current + delta.to_f)
    end
end
# End of class

# ------------------------------------------------------------
# Helpers propriétés Notion
# ------------------------------------------------------------

    def prop_title(text)
    #-------------
        { title: [{ text: { content: text.to_s } }] }
    end

    def prop_number(n)
    #-------------
        { number: n }
    end

    def prop_relation(ids)
    #----------------
        { relation: Array(ids).map { |id| { id: id } } }
    end

# ------------------------------------------------------------
# Extraction JSON (pages)
# ------------------------------------------------------------

    def number_prop(page, name)
    #--------------
        page.dig("properties", name, "number")
    end

    def title_plain(page, name)
    #--------------
        arr = page.dig("properties", name, "title") || []
        arr.map { |t| t["plain_text"].to_s }.join
    end

    def text_prop(page, name)
    #------------
        page.dig("properties", name, "content")
    end

    def formula_bool(page, name)
    #---------------
        f = page.dig("properties", name, "formula")
        return false unless f

        return f["boolean"] unless f["boolean"].nil?
        return (f["number"].to_f != 0) unless f["number"].nil?
        return  (f["string"]).to_s  unless f["string"].nil?
        s = f["string"].to_s.downcase
        %w[true vrai yes 1].include?(s)
    end

# ------------------------------------------------------------
# Règle Quantité à commander
# ------------------------------------------------------------

    def qty_to_order(stock:, seuil:, a_commander:)
    #---------------
        if seuil.to_f > stock.to_f
            [0, seuil.to_f - stock.to_f].max
        elsif a_commander
            1
        else
            0
        end
    end

# -------
# Extracteur Recettes
#--------
# -------
    def load_recettes(notion)
    #----------------
    #   OUT:    arr_ingredients {recid => {article => qte, ...} , ... }
    #
        res = notion.query_database(DS_REC)
        recettes = res.fetch("results")

        arr_ingredients = {}
        recettes.each do |rec|
            rec_title   = title_plain(r, PROP_REC_TITLE)
            rec_id      = rec['id']
            rec_art1    = rec.dig("properties", PROP_REC_ART1, "relation")
            rec_qte1    = rec.dig("properties", PROP_REC_QTE1, "number")
            rec_art2    = rec.dig("properties", PROP_REC_ART2, "relation")
            rec_qte2    = rec.dig("properties", PROP_REC_QTE2, "number")
            rec_art3    = rec.dig("properties", PROP_REC_ART3, "relation")
            rec_qte3    = rec.dig("properties", PROP_REC_QTE3, "number")
            rec_art4    = rec.dig("properties", PROP_REC_ART4, "relation")
            rec_qte4    = rec.dig("properties", PROP_REC_QTE4, "number")
            rec_art5    = rec.dig("properties", PROP_REC_ART5, "relation")
            rec_qte5    = rec.dig("properties", PROP_REC_QTE5, "number")

            arr_ingredients[rec_id] = [ [rec_art1, rec_qte1],
                                        [rec_art2, rec_qte2],
                                        [rec_art3, rec_qte3],
                                        [rec_art4, rec_qte4],
                                        [rec_art5, rec_qte5],
                                    ]
        end
    end #<def>

# -------
# Extracteur REPas
# -------
    def relation_ids(page, prop_name)
    #---------------
        rel = page.dig("properties", prop_name, "relation")
        return [] unless rel.is_a?(Array)
        rel.map { |x| x["id"] }.compact
    end

    def formula_number(page, prop_name)
    #-----------------
        page.dig("properties", prop_name, "formula", "number")
    end

    def formula_relation_ids(page, prop_name)
    #-----------------------
        # Cas typique: formula.array = [{"type"=>"relation", "relation"=>{"id"=>...}}, ...]
        arr = page.dig("properties", prop_name, "formula", "array")
        return [] unless arr.is_a?(Array)

        arr.map do |item|
            item.dig("relation", "id") || item["id"]
        end.compact
    end

# ------
# Fonctions
# -----
    def apply_repas_consumption!(notion)
    #---------------------------
        rec_name    = [
                        REP_PROP_REC_DEJEUNER,
                        REP_PROP_REC_DINER,
                        REP_PROP_REC_DESSERT,
                        REP_PROP_REC_SOUPER
                    ]
        res = notion.query_database(DS_REP)
        pages = res.fetch("results")

        totals = Hash.new(0.0) # article_page_id => qty_to_subtract

        pages.each do |p|
            # en fonction de la recette
            rec_name.each do |rec|
                ids = relation_ids(p, rec)
                if ids.any?
                    ingredients = arr_ingredients[ids]  #=> [a,q],[],...(5)
                    ingredients.each do [ingr]
                        totals[ingr[0]] += ingr[1].to_f
                    end
                end
            end
            # en fonction Y / D
            ids = relation_ids(p, REP_PROP_ART1)
            if ids.any?
                q = p.dig("properties", REP_PROP_QTE1, "number")
                q = 1 if q.nil? || q.to_f <= 0
                ids.each { |id| totals[id] += q.to_f }
                next
            end
            # en fonction Crud / Pot
            ids = relation_ids(p, REP_PROP_ART2)
            if ids.any?
                q = p.dig("properties", REP_PROP_QTE2, "number")
                q = 1 if q.nil? || q.to_f <= 0
                ids.each { |id| totals[id] += q.to_f }
                next
            end

        #    # fallback recette (si Articles non rempli)
        #    rec_ids = formula_relation_ids(p, REP_PROP_REC_ART1)
        #    rec_qte = formula_number(p, REP_PROP_REC_QTE1).to_f
        #    next if rec_ids.empty? || rec_qte.zero?
        #    rec_ids.each { |id| totals[id] += rec_qte }

        end

        puts "=> Repas → articles impactés: #{totals.size}"

        totals.each do |article_id, qty|
            current = notion.get_stock(notion, article_id)
            new_val = current - qty
            notion.set_stock(notion, article_id, new_val)
            puts "=> Article: #{article_id}: #{current} -> #{new_val} ( -#{qty} )"
        end
    end

# ------------------------------------------------------------
# Export CSV des lignes de commande
# ------------------------------------------------------------
# Exporte les lignes (LIGnes) liées à la commande via RefLignes.
# Fichier créé dans le dossier courant.
    def export_commande_csv!(notion, cmd_id, path: nil)
    #----------------------
        # 1) Query RefLignes filtrées sur la relation Commande = cmd_id
        filter = {
            filter: {
            property: PROP_REL_COMMANDE,
            relation: { contains: cmd_id }
            }
        }
        res = notion.query_database(DS_REL, filter)
        refs = res.fetch("results")
        # Map LIGne -> RefLigne (une RefLignes peut contenir plusieurs LIGnes)
        lig_to_ref = {}
        refs.each do |r|
            ref_title = title_plain(r, PROP_REL_TITLE)
            ligs = r.dig("properties", PROP_REL_LIGNES, "relation") || []
            ligs.each do |x|
                lid = x["id"]
                lig_to_ref[lid] ||= []
                lig_to_ref[lid] << ref_title
            end
        end
        ligne_ids = lig_to_ref.keys
        filename = path || "commande_#{cmd_id[0, 8]}.csv"
        CSV.open(filename, "w", col_sep: ";") do |csv|
            csv << ["CommandeID", "LigneID", "Article", "Quantite_saisie", "RefLigne"]
            ligne_ids.each do |lid|
                page = notion.retrieve_page(lid)
                raise "HTTP #{page.code}: #{page.body}" unless page.code.between?(200, 299)
                lig = JSON.parse(page.body)
                # Article (relation)
                art_id = (lig.dig("properties", PROP_LIG_ARTICLE, "relation") || []).first&.fetch("id", nil)
                art_name = ""
                if art_id
                    ap = notion.retrieve_page(art_id)
                    raise "HTTP #{ap.code}: #{ap.body}" unless ap.code.between?(200, 299)
                    aj = JSON.parse(ap.body)
                    art_name = title_plain(aj, PROP_ART_TITLE)
                end
                qty = lig.dig("properties", PROP_LIG_QTY_SAISIE, "number")
                qty = qty.nil? ? "" : qty
                ref_titles = lig_to_ref[lid] || []
                ref_cell = ref_titles.uniq.join("|")
                csv << [cmd_id, lid, art_name, qty, ref_cell]
            end
        end
    #    puts "CSV exporté: #{filename} (#{ligne_ids.size} lignes)"
        return  ligne_ids.size
    end

# ------------------------------------------------------------
# Process
# ------------------------------------------------------------
# Logger
    log                 = Logger.new(STDOUT)
    log.level           = Logger::INFO
    log.datetime_format = '%H:%M:%S'
    log.info("🔧 Prog: #{$0} is starting...")

# Variables
#----------
    ensemble    = 'None'

# Code
#=====
    log.info("Initialisations")
    notion = Notion.new(token: NOTION_TOKEN, version: NOTION_VERSION)

    # Ensemble
    #+++++++++
    log.info("Extraction de la référence d'Enseble")
    res = notion.query_database(DS_PAR)
    parametres      = res.fetch("results")
    params          = parametres.map do |p|
        id          = p.fetch("id")
        name        = title_plain(p, PRM_PROP_NOM)
        ensemble    = formula_bool(p, PRM_PROP_REFERENCE)
        break   if name=="Ensemble"
    end
    log.info("Ensemble du jour: #{ensemble}")

    # Commande
    #+++++++++
    log.info("Création COMande…")
    cmd_title = "CMD #{Time.now.iso8601}"
    cmd_page = notion.create_page(
        parent_database_id: DS_COM,
        properties: {
            PROP_COM_TITLE => prop_title(cmd_title)
        }
    )
    cmd_id = cmd_page.fetch("id")
    log.info("Commande crée: #{cmd_title}")

    # Recettes
    #+++++++++
    log.info("On enregistre les recettes")
    load_recettes(notion)

    # Repas
    #++++++
    log.info("On tient compte des repas")
    apply_repas_consumption!(notion)

    log.info("Lecture ARTicles…")
    res = notion.query_database(DS_ART)
    articles = res.fetch("results")

    candidates = articles.map do |p|
        id = p.fetch("id")
        name = title_plain(p, PROP_ART_TITLE)
        stock = number_prop(p, PROP_ART_STOCK) || 0
        seuil = number_prop(p, PROP_ART_SEUIL) || 0
        acmd = formula_bool(p, PROP_ART_A_CMD)

        qty = qty_to_order(stock: stock, seuil: seuil, a_commander: acmd)
        next nil if qty <= 0

        log.info("Article en commande: #{name} Qte: #{qty}")

        { id: id, name: name, qty: qty, stock: stock, seuil: seuil, a_cmd: acmd }
    end.compact
    log.info("Nombre d'Articles à commander: #{candidates.size}")

    # Lignes & RefLignes
    #+++++++++++++++++++
    log.info("Création LIGnes + RefLignes…")
    created = 0
    # Loop all articles
    candidates.each_with_index do |a, idx|
        # create ligne
        lig = notion.create_page(
            parent_database_id: DS_LIG,
            properties: {
                PROP_LIG_TITLE => prop_title(a[:name]),
                PROP_LIG_ARTICLE => prop_relation([a[:id]]),
                PROP_LIG_QTY_SAISIE => prop_number(a[:qty])
            }
        )
        lig_id = lig.fetch("id")
        lig_ref = formula_bool(lig, PROP_LIG_REFERENCE)

        # check si Refligne existe, si oui => add, si non on crée
        ref_id  = ''
        res = notion.query_database(DS_REL)
        reflignes       = res.fetch("results")
        items           = reflignes.map do |p|
            ref_id      = p.fetch("id")
            name        = title_plain(p, PROP_REL_TITLE)
            chkemsemble = formula_bool(p, PROP_REL_ENSEMBLE)
            next    unless chkensemble==ensemble
            break   if name==lig_ref
        end.compact
        if items.size==0    #pas de refligne
        ###ref = "REL-#{cmd_id[0, 8]}-#{idx + 1}"
            notion.create_page(
                parent_database_id: DS_REL,
                properties: {
                    PROP_REL_TITLE => prop_title(lig_ref),
                    PROP_REL_COMMANDE => prop_relation([cmd_id]),
                    PROP_REL_LIGNES => prop_relation([lig_id])
                }
            )
            created += 1
        else
            notion.update_page(
                page_id: ref_id,
                properties: {
                    PROP_REL_LIGNES => prop_relation(lig_id)
                }

            )
        end
    end

    log.info("OK: Lignes & RefLignes créées.")

    # CSV
    #++++
    log.info("Création du fichier csv")
    lignes  = export_commande_csv!(notion, cmd_id, path: "commande.csv")
    log.info("Csv créé: #{lignes} lgnes")

    # Exit
    #+++++
    log.info("🔧 Prog: #{$0} is done")
