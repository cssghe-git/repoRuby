# frozen_string_literal: true
#
=begin
    DOC     Function:   ?
    DOC     Call:       ruby ? --?
    DOC     Build:      260206-1000
    DOC     Version:    1.1.1
        Bugs:       ?

    Analyse:
        -lecture Comptes pour obtenir les relations
        -lecture csv extraits banque    => arr_extraits
        -lecture mouvements planifiés   => arr_mvtsplan
        -lecture csv extraits crédits   => arr_crédits
        -calcul budget hebdomadaire     => budget_hebo
        --loop csv extraits
            ---modification N° extrait => nnnnnn_s (s:1à9)
            ---recherche correspondance dans mouvements planifiés
                => montant
                => description
            ---si oui :
                ----création mouvement réalisé type planifié
            ---si non :
                ----création mouvement réalisé type hebdomadaire
        --end
        --loop csv crédits
            --modification N° extrait => Extr_ID
            --création mouvement réalisé type hebdomadaire si non existant
        --end
        --loop csv liquidités
            --création mouvement réalisé type hebdomadaire
        --end
        --loop mouvements réalisés hebdomadaires
            ---sélection des mouvements
            ---total des mouvements
        --end
        --calcul gain/perte
        --impression (pdf)
            ---titre = Semaine N° ?
            ---gain/perte
            ---mouvements
    end

=end

require 'rubygems'
require "json"
require "httparty"
require "optparse"
require "logger"
require 'timeout'
require 'date'
require 'pp'
require 'csv'
require "unf"
require "pdfkit"
#
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end
#
require_relative    'ClStandards.rb'
require_relative    'Mod_SelectFile.rb'

# Options   #1-> ENV    #2-> opts   #3-> flags
    opts    = {
        debug: ENV.fetch('DEBUG', 'DEBUG'),
        dryrun: ENV.fetch('DRY_RUN', true)
    }                         
    OptionParser.new do |o|
        o.banner = "Usage: ruby PrvBudget_Calculs.rb [options] [apply]"
        o.on('--debug=DEBUG', 'Logger level value') { |v| opts[:debug] = v }
        o.on('--simul', 'Production or Simulation') { |v| opts[:dryrun] = v }
    end.parse!(ARGV)
    DRY_FLAG    = (ARGV.last == "sim")

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = :INFO
    log.datetime_format = '%H:%M:%S'

#********
# Symbols
#********
# Files
EXTRBQE_FILE    = "/users/Gilbert/Library/Mobile Documents/com~apple~CloudDocs/Downloads/Reconciliation/"
EXTRCRE_FILE    = "/users/Gilbert/Library/Mobile Documents/com~apple~CloudDocs/Downloads/Reconciliation/"

# Columns
TBQE_NUMCOMPTE      = 0
TBQE_EXTRAIT        = 4
TBQE_DATE           = 5
TBQE_DESCRIPTION    = 6
TBQE_MONTANT        = 8

TCRE_CARTECREDIT    = 0
TCRE_DATEOPER       = 3
TCRE_DATEREGL       = 4
TCRE_MONTANT        = 5
TCRE_CREDIT         = 6
TCRE_DEBIT          = 7
TCRE_COMMERCANT     = 12
TCRE_COMMENT        = 15

TLIQ_LIBELLE        = 0

TPLN_LIBELLE        = 0

TREL_LIBELLE        = 'Libellé'                         #title
TREL_DATE           = 'Date exécution'                  #date
TRL_MONTANT         = 'Montant'                         #number
TREL_NOTES          = 'Notes'                           #text
TREL_TYPE           = 'Type'                            #select
#**********
# Variables
#**********
    @arr_extraits   = []    #[{k=>v, k=>v, ...}, {}, ...]
    @arr_credits    = []
    @arr_mvtsplan   = {}
    @arr_mvtshebdo  = []
    @arr_comptes    = {}    #{Libellé=>ID, ...}
    @arr_hebdo      = []
    @arr_liquidites = []
    
    @mvtsreal_id    = ''
    @mvtsplan_id    = ''
    @mvtscpte_id    = ''
    @mvtstiers_id   = ''

    @budget_hebdo   = 420

    @rel_cbc        = ''
    @rel_visa       = ''
    @rel_mcard      = ''


#**********
# Fonctions
#**********
    def loadcomptes_IDS(log, stds)
    #====================
    #   OUT:    
    #
        log.debug("☢️->Method: #{__method__}")
        @arr_comptes    = {}
        mouvements      = []
        sort            = [{ property: 'Libellé', direction: 'ascending' }]
        mouvements      = stds.db_fetch(@mvtscpte_id, type: 'Old', sort: sort)
        mouvements.each do |mvt|    #<L1>
            libelle = stds.get_prop_value(mvt, 'Libellé')
            id      = mvt['id']
            @arr_comptes[libelle]   = id
        end #<L1>
        return  @arr_comptes
    end #<def>

    def loadtiers_IDS(log, stds)
    #================
        log.debug("☢️->Method: #{__method__}")
        @arr_tiers       = {}
        mouvements      = []
        sort            = [{ property: 'Libellé', direction: 'ascending' }]
        mouvements      = stds.db_fetch(@mvtstiers_id, type: 'Old', sort: sort)
        mouvements.each do |mvt|    #<L1>
            libelle = stds.get_prop_value(mvt, 'Libellé')
            id      = mvt['id']
            @arr_tiers[libelle]  = id
        end #<L1>
        return  @arr_tiers
    end #<def>

    def loadcsv_banque(log)
    #=================
    #   OUT:    @arr_extraits
    #
        log.debug("☢️->Method: #{__method__}")
        @arr_extraits    = []
        file_select     = SelectFile.select_pages()     #select 1 file
        @arr_extraits    = CSV.table(file_select, headers: false, return_headers: false, col_sep: ',', encoding: "UTF-8", liberal_parsing: true)
        #   pp @arr_extraits
        return  @arr_extraits
    end #<def>

    def loadcsv_credits(log)
    #==================
    #   OUT:    @arr_credits
    #
        log.debug("☢️->Method:#{__method__}")
        @arr_credits = []
        file_select = SelectFile.select_pages()         #select 1 file
        @arr_credits = CSV.table(file_select, headers: false, return_headers: false, col_sep: ',', encoding: "UTF-8", liberal_parsing: true)
        #   pp @arr_credits
        return  @arr_credits
    end #<def>

    def loadcsv_liquidités(log)
    #=====================
    #
        log.debug("☢️->Method:#{__method__}")
        @arrLiquidites  = []
        file_select = SelectFile.select_pages()         #select 1 file
        @arr_liquidites = CSV.table(file_select, headers: false, return_headers: false, col_sep: ',', encoding: "UTF-8", liberal_parsing: true)
        return  @arr_liquidites
    end #<def>

    def loadmvts_planifiés(log, stds)
    #=====================
    #   OUT:    @arr_mvtsplan
    #
        log.debug("☢️->Method:#{__method__}")
        @arr_mvtsplan    = {}
        mouvements      = []
        sort            = [{ property: 'Libellé', direction: 'ascending' }]
        mouvements      = stds.db_fetch(@mvtsplan_id, type: 'Old', sort: sort)
        mouvements.each do |mvt|    #<L1>
            libelle = stds.get_prop_value(mvt, 'Libellé')
            @arr_mvtsplan[libelle]   = mvt
        end #<L1>
        #DBG    puts    "DBG>>>@arr_mvtsplan :"
        #DBG    pp @arr_mvtsplan
        return  @arr_mvtsplan
    end #<def>

    def calculbudget_hebdo(log)
    #=====================
    #
    end #<def>

    def processingextraits_bancaires(log, stds)
    #===============================
    #
        log.debug("☢️->Method:#{__method__}")
        index       = 1
        flag        = true                              #default
        compte_id   = @rel_cbc                          #default
        tiers_id    = @arr_tiers['Private']             #default

        # loop all extraits
        @arr_extraits.each do |extr| #<L1>
            break   if extr[TBQE_NUMCOMPTE].nil?
            next    if extr[TBQE_NUMCOMPTE] == 'Numéro de compte'    #skip header if any

            # some fields
            log.debug("☢️->#{extr[TBQE_DESCRIPTION]} =>")
            # Compte->
            compte_id   = @rel_cbc                          #default
            compte_id   = @rel_mcard    if extr[TBQE_DESCRIPTION][0..30].include?("DECOMPTE CARTE DE CREDIT CBC ")
            # Tiers->
            tiers_id    = @arr_tiers['Private']             #default
            string  = extr[TBQE_DESCRIPTION].upcase
            @arr_tiers.each do |key, value|  #<L2>
                if string.include?(key.upcase)
                    @tiers_id   = value
                    break
                end
            end #<L2>

            # loop all mvts planifiés
            flag        = true
            @arr_mvtsplan.each do |key, value|   #<L2>
                next    if key.nil?
            #    log.debug("BQE: #{extr[TBQE_DESCRIPTION]} <-> REC: #{key}")
                if extr[TBQE_DESCRIPTION].include?(key) #<IF3>
                    # create mvtreal_plan
                    type    = 'Récurrent'
                    log.debug("☢️->Create MvtReal_Plan Type: #{type}")
                    props   = {
                        'Libellé'           => stds.title(key),
                        'Compte'            => stds.relation(compte_id),
                        'Date exécution'    => stds.date_iso(extr[TBQE_DATE]),
                        'Montant'           => stds.num(extr[TBQE_MONTANT].to_i),
                        'Notes'             => stds.text(extr[TBQE_DESCRIPTION]),
                        'Tiers'             => stds.relation(@tiers_id),
                        'Type'              => stds.select(type)
                    }
                    creation_mvtreal(log, stds, props)

                    flag    = false
                    break
                end #<IF3>
            end #<L2>

            if flag #<IF2>
                # create mvtreal_hebdo
                type    = 'Hebdomadaire'
                log.debug("☢️->Create MvtReal_Hebdo Type: #{type}")
                ref     = "#{extr[TBQE_EXTRAIT]}#{index}"
                props   = {
                    'Libellé'           => stds.title(ref),
                    'Compte'            => stds.relation(compte_id),
                    'Date exécution'    => stds.date_iso(extr[TBQE_DATE]),
                    'Montant'           => stds.num(extr[TBQE_MONTANT].to_i),
                    'Notes'             => stds.text(extr[TBQE_DESCRIPTION]),
                    'Tiers'             => stds.relation(@tiers_id),
                    'Type'              => stds.select(type)
                }
                creation_mvtreal(log, stds, props)

                # save hebdo for compute
                @arr_hebdo.push(extr)    unless type == 'Récurrent'
                index   += 1
            end #<IF2>
        end #<L1>
        return  @arr_hebdo
    end #<def>

    def processingextraits_crédits(log, stds)
    #=============================
        log.debug("☢️->Method:#{__method__}")

        # loop all extraits
        @arr_credits.each do |extr|  #<L1>
            log.debug("Crédit: #{extr[TCRE_COMMERCANT]}")
            next    if extr[TCRE_CARTECREDIT] == "carte de crédit"
            # check if process it
            puts    extr[TCRE_COMMERCANT]
            print   "Can I process it (Y/N)[N] ? "
            reply   = $stdin.gets.chomp.to_s.upcase
            next    if reply != 'Y'

            # create mvtreal_hebdo
            log.debug("☢️->Create MvtReal_Hebdo")
            type    = 'Hebdomadaire'
            props   = {
                'Libellé'           => stds.title(extr[TCRE_COMMERCANT]),
                'Compte'            => stds.relation(@rel_mcard),
                'Date exécution'    => stds.date_iso(extr[TCRE_DATEOPER]),
                'Montant'           => stds.num(extr[TCRE_MONTANT].to_i.round(2)),
                'Notes'             => stds.text(extr[TCRE_COMMENT]),
                'Type'              => stds.select(type)
            }
            creation_mvtreal(log, stds, props)

            # save hebdo for compute
            @arr_hebdo.push(extr)    unless type == 'Récurrent'
        end #<L1>
        return  @arr_hebdo
    end #<def>

    def processingextraits_liquidites(log, std)
    #================================
    #
        log.debug("☢️->Method:#{__method__}")
        # loop all extraits
        @arr_liquidites.each do |extr|  #<L1>
            log.debug("Liquide: #{extr[TLIQ_LIBELLE]}")
            next    if extr[TLIQ_LIBELLE] == "Libellé"
            # check if process it
            puts    extr[TLIQ_LIBELLE]
            print   "Can I process it (Y/N)[N] ? "
            reply   = $stdin.gets.chomp.to_s.upcase
            next    if reply != 'Y'
        end #<L1>
        return  @arr_hebdo
    end #<def>

    def creation_mvtreal(log, stds, props)
    #===================
    #
        log.debug("☢️->Method:#{__method__}")
        stds.page_create(@mvtsreal_id, props)   
        pp props                                

    end #<def>

    def processingmouvements_hebdomadaires(log)
    #=====================================
    #
        log.debug("☢️->Method:#{__method__}")
        total   = 0
        @arr_hebdo.each do |mvt|
            libelle     = mvt[0]
            if libelle.include?('BE94')
                montant     = mvt[TBQE_MONTANT].to_i
            else
                montant = mvt[TCRE_MONTANT].to_i.round(2)
            end
            total   += montant
        end
        return  total
    end #<def>

    def calcul_gain_perte(log, total)
    #====================
    #
        log.debug("☢️->Method:#{__method__}")
        result  = @budget_hebdo + total
        log.warn("🌹->Résultat: #{result > 0 ? 'Gain de ' : 'Perte de '} #{result}€")
        return  result
    end #<def>

    def save_pdf(log, result)
    #===========
    #
        log.debug("☢️->Method:#{__method__}")
        # Header
        html    = '<html><head></head><body><h1>Résultat de la semaine</h1>'
        html    += '<table><caption>tableau</caption<thead><tr><th scop="col">Description</th><th scope="col">Montant</th></tr></thead><tbody>'
        # Body 
        @arr_hebdo.each do |mvt|
            libelle     = mvt[0]
            if libelle.include?('BE94')
                description = mvt[TBQE_DESCRIPTION]
                montant     = mvt[TBQE_MONTANT].to_i
            else
                description = mvt[TCRE_COMMERCANT]
                montant = mvt[TCRE_MONTANT].to_i.round(2)
            end
            html    += "<tr><td>#{description}</td><td>#{montant}</td></tr>"
            html    += "<tr><td>' '</td><td>' '</td></tr>"
        end
        # Trailer
        html    += '</tbody><tfoot>'
        html    += '<tr><th scope = "row">Gain-perte</th><td>'
        html    +=  "#{result}"
        html    += '</td></tfoot></table>'
        html    += '</body></head>'

        pdf = PDFKit.new(html, page_size:"A4", print_media_type: true)
        pdf.to_file("Resultat de la semaine.pdf")

    end #<def>

#********************
#           Main code **********
#********************

    log.info("🛂->Program #{$0} is starting...")
    log.debug("☢️->Initialisations")

    # Create new instance
    log.debug("☢️->Create a new instance of class <Standards>")
    stds    = Standards.new([], 'Old')                  #new instance

    # Specific options
    log.debug("☢️->Set specfic options")
    stds.loadOpts(opts)                                 #add spec values
    opts    = stds.opts()                               #get opts values
#    opts[:dryrun]   = DRY_FLAG  unless !DRY_FLAG
        print   "Confirmez-vous le mode <Production> (Y/N[N] ? )"
        reply   = $stdin.gets.chomp.to_s.upcase
        opts[:dryrun] = true  unless reply == 'Y'

    log.debug("☢️->Set Logger level")
    log.level   = opts[:debug] || :INFO
    log.info("🔧 Prog: #{$0} Level: #{opts[:debug]} Mode: #{opts[:dryrun]==true ? 'DRY-RUN (simulation)' : 'PRODUCTION'} Simul: #{DRY_FLAG}")

    # Notion DBs id
        @mvtsreal_id    = stds.getDbId("aidf.Mouvements réalisés")
        @mvtsplan_id    = stds.getDbId("aidf.Mouvements planifiés")
        @mvtscpte_id    = stds.getDbId("aidf.Comptes")
        @mvtstiers_id   = stds.getDbId("aidf.Tiers")

    # Processing
    log.info("▶️->Main code in progress...")

    # Load Comptes pour les relations
    log.info("⏩️->load <Comptes>")
    @arr_comptes     = loadcomptes_IDS(log, stds)
    log.debug("☢️->Count: #{@arr_comptes.size}")
    @rel_cbc        = @arr_comptes['CBC-Commun']
    @rel_visa       = @arr_comptes['Visa']
    @rel_mcard      = @arr_comptes['MasterCard']

    # Load Tiers pour les relations
    log.info("⏩️->load <Tiers>")
    @arr_tiers   = loadtiers_IDS(log, stds)
    log.debug("☢️->Count: #{@arr_tiers.size}")

    # load mouvements planifiés
    log.info("⏩️->load <Mouvements planifiés>")
    @arr_mvtsplan    = loadmvts_planifiés(log, stds)
    log.debug("☢️->Count: #{@arr_mvtsplan.size}")

    # load csv banque
    log.info("⏩️->Load csv <Extraits bancaires>")
    @arr_extraits    = loadcsv_banque(log)
    log.debug("☢️->Count: #{@arr_extraits.size}")

    # load csv crédits
    log.info("⏩️->Load csv <Extraits crédits>")
    @arr_credits     = loadcsv_credits(log)
    log.debug("☢️->Count: #{@arr_credits.size}")

    # load Liquidités
    log.info("⏩️->Load <Liquidités>")
#    @arr_liquidites = loadcsv_liquidités(log)
    log.debug("☢️->Count: #{@arr_liquidites.size}")
    
    # calcul budget hebdomadaire
    log.info("⏩️->Calcul budget hebdomadaire")
    #budget_hebdo    = calculbudget_hebdo(log)

    # Traitement <Extraits bancaires>
    log.info("⏩️->Processing <Extraits bancaires>")
    @arr_mvtshebdo   = processingextraits_bancaires(log, stds)
    log.debug("☢️->Count: #{@arr_mvtshebdo.size}")

    # Traitement <Extraits crédits>
    log.info("⏩️->Processing <Extraits crédits>")
    processingextraits_crédits(log, stds)
    log.debug("☢️->Count: #{@arr_mvtshebdo.size}")

    # Traitement <Extraits liquidites>
    log.info("⏩️->Processing <Extraits crédits>")
    processingextraits_liquidites(log, stds)
    log.debug("☢️->Count: #{@arr_mvtshebdo.size}")

    # Traitement <Mouvements hebdomadaires>
    log.info("⏩️->Processing <Mouvements hebdomadaires>")
    total   = processingmouvements_hebdomadaires(log)

    # Calcul gain / perte
    log.info("⏩️->Compute result")
    result  = calcul_gain_perte(log, total)

    # Save to pdf
    log.info("⏩️->Save to pdf")
    save_pdf(log, result)

    # Exit
    log.info("🛂->Program #{$0} is done")