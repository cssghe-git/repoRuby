#!/usr/bin/env ruby
#
=begin
    Program:    EneoBwCom_ExtrOffice05
    Function:   extract MBR for office
    Call:       ruby 'prog'.rb --debug=Y/N, --list=1/2/3/4, --date=YYYYMMDD apply
    Parameters: P1: debug => Y or N
                P2: list Nr (0 = request)
    Build:      0-0-1   <251029-1252>
=end

# Requires
require 'httparty'
require 'json'
require 'csv'
require 'logger'
require 'optparse'

begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

# ==============================
# Options
# ==============================
    OPTS = {
        debug:    ENV.fetch("DEBUG", "INFO"),            # Y/N
        dbids:    ENV.fetch("",nil),
        list:     ENV.fetch("OFF_LIST", 9),           # ex: 9
        lstdate_1:  ENV.fetch("OFF_DATE_1", "2026-12-31"),# pas de date == date du jour
        lstdate_2:  ENV.fetch("OFF_DATE_2", "2026-12-31"),# pas de date == date du jour
        lstdate_3:  ENV.fetch("OFF_DATE_3", "2026-12-31"),# pas de date == date du jour
        lstdate_4:  ENV.fetch("OFF_DATE_4", "2026-12-31"),# pas de date == date du jour
        errors:   ENV.fetch("OFF_ERRORS", "N"),       # Y/N save or not errors
        dryrun:   ENV.fetch("DRY_RUN",true)           # simulation
    }
=begin
OptionParser.new do |o|
  o.banner = "Usage: ruby EneoBwCom_ExtrOffice05.rb [options] [apply]"
  o.on("--debug=N", "False | True pour Debug")  { |v| OPTS[:debug] = v }
  o.on("--list=0", "Filtre Liste Num.")         { |v| OPTS[:list] = v }
  o.on("--date=", "Date de la liste")           { |v| OPTS[:lstdate] = v }
end.parse!(ARGV)
=end

    DRY_RUN         = OPTS[:dryrun]
    OPTS[:debug]    = true
    pp OPTS

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = Logger::INFO
    log.datetime_format = '%H:%M:%S'
    log.info("<>")
    log.warn( "🔧 Mode: #{DRY_RUN ? 'DRY_RUN (simulation)' : 'PRODUCTION'}")

# Constants
    NOTION_API_VERSION  = '2025-09-03'
    NOTION_API_TOKEN    = 'Bearer secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3'
    BASE_URL            = 'https://api.notion.com/v1'

    # Configuration
    CONFIG              = JSON.parse(File.read(ENV.fetch("NOT_JSON_DBIDS")))
    MBR_DB_ID           = CONFIG.find { |h| h.key?("m25t.Membres") }&.fetch("m25t.Membres")
    DIRECTORY_TO_PUT    = ENV.fetch("OFF_CSV_DIR","")

    # current date
    now = Time.now
    now_formatted   = now.strftime("%Y-%m-%d")

    # next vars must be updated according to List Nr
    LIST_NUMBER         = OPTS[:list].to_i              #1 to 4
    LIST_NAME           = "Liste_#{LIST_NUMBER}"
    LIST_0_DATE         = "2026-01-01"
    LIST_1_DATE         = "#{OPTS[:lstdate_1]}"   #must be updated by argv
    LIST_1              = "Liste_#{LIST_NUMBER} @ #{now_formatted}" if LIST_NUMBER == 1
    LIST_2_DATE         = "#{OPTS[:lstdate_2]}"   #must be updated by argv
    LIST_2              = "Liste_#{LIST_NUMBER} @ #{now_formatted}" if LIST_NUMBER == 2
    LIST_3_DATE         = "#{OPTS[:lstdate_3]}"   #must be updated by argv
    LIST_3              = "Liste_#{LIST_NUMBER} @ #{now_formatted}" if LIST_NUMBER == 3
    LIST_4_DATE         = "#{OPTS[:lstdate_4]}"   #must be updated by argv
    LIST_4              = "Liste_#{LIST_NUMBER} @ #{now_formatted}" if LIST_NUMBER == 4
    COTISATION_VALUE_1  = '18'
    COTISATION_VALUE_2  = '9'
    CHECK_DATE          = LIST_0_DATE   if LIST_NUMBER == 1
    CHECK_DATE          = LIST_1_DATE   if LIST_NUMBER == 2
    CHECK_DATE          = LIST_2_DATE   if LIST_NUMBER == 3
    CHECK_DATE          = LIST_3_DATE   if LIST_NUMBER == 4

    #filenames
    CSVFILE_OUTPUT  = "#{DIRECTORY_TO_PUT}/NIV-#{LIST_NAME}@#{Time.now.strftime("%Y-%m-%d-%H%M")}.csv"
    CSVFILE_ERRORS  = "#{DIRECTORY_TO_PUT}/ERR-#{LIST_NAME}@#{Time.now.strftime("%Y-%m-%d-%H%M")}.csv"
 
#
# ==============================
# Class
# ==============================
class   ExtractorMBR
#*******************
#
# Instance Variables
#
    # Initialize
    def initialize()
    #+++++++++++++
        @token = ""
        @mbr_db_id  = MBR_DB_ID 

        @headers    = {
            'Authorization'     => NOTION_API_TOKEN,
            'Notion-Version'    => NOTION_API_VERSION,
            'Content-Type'      => 'application/json'
        }
        @count_deces    = 0
        @count_sortie   = 0
        @count_nouveau  = 0
        @count_modif    = 0
        @count_cotis    = 0
        @count_naiss    = 0
    end #<def>

    # Extract pages
    def extractPages(check_date)
    #+++++++++++++++
    #   INP:
    #   OUT:    pages_selected as []
    #
        # make filter & sort
        #       filter records updated after le previous list date
        query = {
            filter: {
                and: [
                    { or: [
                        { property: 'Modifs Privées', date: { "after": check_date } },
                        { property: 'Modifs Eneo', date: { "after": check_date } },
                        { property: 'Date paiement', date: { "after": check_date } }
                    ] },
                    { property: 'CDC', select: { "equals": "NIV" } }
                ]
            },
            sorts: [{ property: 'Référence', direction: 'ascending' }]
        }

        # extract pages
        all_members = []
        has_more = true
        start_cursor = nil

        while has_more
            query[:start_cursor] = start_cursor if start_cursor

            response = HTTParty.post(
                "#{BASE_URL}/data_sources/#{@mbr_db_id}/query",
                headers: @headers,
                body: query.to_json
            )

            unless response.success?
                puts "Erreur query: #{response['message']}"
                break
            end

            all_members.concat(response['results'])
            has_more        = response['has_more']
            start_cursor    = response['next_cursor']
        end

        #return
        all_members
    end #<def>

    # Extrait les propriétés
    def extract_properties(page)
    #+++++++++++++++++++++
    #   INP:    page
    #   OUT:    props {}
    #
        # load hash
        props = {}
        props['page_id']    = page['id']
        page['properties'].each do |key, value|
            props[key] = extract_property_value(value)
        end

        # return
        props
    end #<def>
  
    # Extrait la valeur d'une propriété
    def extract_property_value(prop)
    #+++++++++++++++++++++++++
    #   INP:    property type
    #   OUT:    property value
    #
        # switch according to type
        case prop['type']
        when 'title'
            prop['title']&.first&.dig('text', 'content')
        when 'rich_text'
            prop['rich_text']&.first&.dig('text', 'content')
        when 'select'
            prop['select']&.dig('name')
        when 'multi_select'
            prop['multi_select']&.map { |opt| opt['name'] }
        when 'status'
            prop['status']&.dig('name')
        when 'email'
            prop['email']
        when 'phone_number'
            prop['phone_number']
        when 'checkbox'
            prop['checkbox']
        when 'date'
            prop['date']&.dig('start')
        when 'unique_id'
            prop['unique_id']&.dig('number')
        when 'formula'
            type    = prop['formula']&.dig('type')
            prop['formula']&.dig(type)
        else
            nil
        end
    end #<def>

    # Select pages accoding to list Nr
    def selectPage(prop='')
    #+++++++++++++
    #   INP:    properties []
    #   OUT:    array {code=>true or false, cause=>?}
    #               code: true if to send
    #               cause:  sortie, décès, nouveau, modification
    #
        # init
        result  = {}
        result['code']  = 'N'                           #not to send
        result['cause'] = 'None'                        #no reason
        list_code   = "0"                               #statut secrétariat

        mbrcheck    = "*"

        # common part
        nomprenom           = prop['Référence'].split("-")
        result['Nom']       = nomprenom[0]
        prenom              = "#{nomprenom[1]}"
        prenom              = "#{nomprenom[1]}-#{nomprenom[2]}" unless nomprenom[2].nil?
        result['Prénom']    = prenom
        result['Adresse']   = prop['Adresse']
        result['Gsm']       = prop['Gsm']
        result['Fixe']      = prop['Fixe']
        result['Mails']     = prop['Email']
        result['Naissance'] = prop['Date naissance']
        result['Eneo']      = prop['Type activité']         if prop['Type activité'] == 'Eneo'
        result['EneoSport'] = prop['Type activité']         if prop['Type activité'] == 'EneoSport'
        result['CDC Pr']    = prop['CDC']                   unless prop['CDC'] == 'EXT'
        result['CDC Sc']    = 'NIV'                         unless prop['CDC'] == 'NIV'
        result['ActPrc']    = prop['Activité principale']   if prop['CDC'] == 'NIV'
        result['ActPrc']    = prop['Activités secondaires'] unless prop['CDC'] == 'NIV'
        result['Seagma']    = prop['Seagma']
        list_value          = prop['Statut secrétariat']    unless prop['Statut secrétariat'].size==0
        list_code           = list_value[list_value.size-2] unless prop['Statut secrétariat'].size==0

        puts    "DBG>PROPS before test ▼"   if prop['Référence'] == mbrcheck
        pp  prop  if prop['Référence'] == mbrcheck

        # Statut
        result['Statut secrétariat']    = prop['Statut secrétariat']

        # Init
        result['Décès']         = ' '
        result['Ancien']        = ' '
        result['Membre']        = ' '
        result['Nouveau']       = ' '
        result['Modification']  = ' '
        result['code']          = 'N'

        # Checks 
        1.times do                                      #loop at first reason
            # décès
            unless prop['Date décès'].nil?
                result['En/Hors service']   = false
                result['code']  = 'Y'
                result['cause'] = 'Décès'
                list_code       = 1
                @count_deces    += 1
                break
            end

            # sortie
            unless prop['Date sortie'].nil?
                result['En/Hors service']   = false
                result['code']  = 'Y'
                result['cause'] = 'Ancien'
                list_code       = 2
                @count_sortie   += 1
                break
            end

            # membre (cotisation)
            @count_naiss    += 1    unless !prop['Date naissance'].nil?
            if (prop['Cotisation'] == COTISATION_VALUE_1 or
                prop['Cotisation'] == COTISATION_VALUE_2) and
                !prop['Date paiement'].nil? and
                !prop['Date naissance'].nil?
                result['code']  = 'Y'
                result['cause'] = 'Membre'
                list_code       = 3
                @count_cotis    += 1

                # nouveau
                puts    "DBG>Seagma during test: #{prop['Seagma']}" if prop['Référence'] == mbrcheck
                if prop['Seagma'].nil?
                    result['Nouveau']   = 'Y'
                    @count_nouveau  += 1
                    break
                end

                # modification
                unless prop['Modifs Privées'].nil?
#                    result['code']  = 'Y'
#                    result['cause'] = 'Modification'
                    result['Modification']  = 'Y'
                    @count_modif    += 1
                end
            else
                break
            end
=begin
            # nouveau
            puts    "DBG>Seagma during test: #{prop['Seagma']}" if prop['Référence'] == mbrcheck
            unless  prop['Seagma'].nil?
                result['code']      = 'Y'
                result['cause']     = 'Nouveau'
                list_code       = 4
                break
            end

            # modification
            unless prop['Modifs Privées'].nil?
                result['code']  = 'Y'
                result['cause'] = 'Modification'
                break
            end
=end
        end

        # specific part
        cause   = result['cause']
        case    LIST_NUMBER
        when    1, 2
            case    cause
            when    'Décès'
                result[cause]   = 'Y'
            when    'Ancien'
                result[cause]   = 'Y'
            when    'Membre'
                 if prop['Date paiement'] > CHECK_DATE
                    result['Cotis-1']   = prop['Cotisation']    if prop['Cotisation'] == COTISATION_VALUE_1
                    result['Cotis-2']   = prop['Cotisation']    if prop['Cotisation'] == COTISATION_VALUE_2
                    result['CPE']       = prop['Type cotisation']
                    result[cause]   = 'Y'
                else
                    return  false
                end
            when    "Nouveau"
                result[cause]   = 'Y'
            when    'Modification'
                result[cause]   = 'Y'
            end
            puts    "{TRT}>REF: #{prop['Référence']} => NOM: #{result['Nom']}-#{result['Prénom']} : CAUSES: D:#{result['Décès']}+A:#{result['Ancien']}+B:#{result['Membre']}+N:#{result['Nouveau']}+M:#{result['Modification']} - CODE: #{result['code']}"    if result['code'] == 'Y'
            puts    "DBG>>>DatePaiement: #{prop['Date paiement']}"  if result['code'] == 'Y' and OPTS[:errors]=='Y'
        when    2
            #L =liste_nr
            #déjà 'décès' => code L#1
            #déjà 'anciens' => L#2
            #déjà 'cotisant' => L#3
            #déjà 'nouveau' => L#4
            # Décès => pas code_1 & Date_décès > dernière date_liste
            # Ancien => pas code_2 & Date_sortie > dernière date_liste
            # Membre => pas code_3 & Date_paiement > dernière date_liste
            # Nouveau => pas code_4
            # Modification => Date_modifs > dernière date_liste
        when    3
        when    4
        else
            return false
        end
        puts    "DBG>Result after test ▼"   if prop['Référence'] == mbrcheck
        pp  result  if prop['Référence'] == mbrcheck

        # update page: 'Statut secrétariat'
        list_sta    = "#{LIST_NUMBER}/#{list_code}"
        updatePage(prop['page_id'], list_sta)   if result['code'] == 'Y'

        return  result
    end #<def>

    # update page
    def updatePage(page_id=nil, list_name=nil)
    #+++++++++++++
    #   Function:   update page for 'Statut secrétariat', 'Modifs Privées', 'Modifs Eneo'
    #   INP:    list name
    #   OUT:    page updated
    #
        prop    = {}
        # Statut secrétariat
    #    prop['Statut secrétariat']  = { 'multi_select' => [ {'name' => list_name} ] }   unless list_name.nil?
        case LIST_NUMBER
        when    1
            prop['Statut secrétariat']  = { 'multi_select' => [ {'name' => list_name},
                                                                {'name' => LIST_1} ] }
        when    2
            prop['Statut secrétariat']  = { 'multi_select' => [ {'name' => list_name},
                                                                {'name' => LIST_2} ] }
        when    3
            prop['Statut secrétariat']  = { 'multi_select' => [ {'name' => list_name},
                                                                {'name' => LIST_3} ] }
        when    4
            prop['Statut secrétariat']  = { 'multi_select' => [ {'name' => list_name},
                                                                {'name' => LIST_4} ] }
        end

        puts    "DBG>>>Statut secrétariat: /1=Décès, /2=Sortie, /3=Membre, /4=Nouveau => #{prop['Statut secrétariat']}" if OPTS[:errors]=='Y'

        return  if DRY_RUN
    #    return  #for tests
        

        # En/Hors service

        # Modifs privées
        prop['Modifs Privées']  = {'date' => nil} 
        # Modifd eneo
        prop['Modifs Eneo']  = {'date' => nil} 


        # Update
        payload = { "properties" => prop }
        response = HTTParty.patch(
            "#{BASE_URL}/pages/#{page_id}",
            headers: @headers,
            body: payload.to_json
        )

        if response.success?
            puts "  ✓ Membre mis à jour: #{list_name}"
        else
            puts "  ✗ Erreur: #{response['message']}"
        end
    end #<def>

    # Export to csv
    def saveToCsv(pages_selected='')
    #++++++++++++
    #   INP:    page selected []
    #   OUT:    csv file
    #
        count_csv   = 0
        CSV.open(CSVFILE_OUTPUT, 'w', col_sep: ';', encoding: 'UTF-8') do |csv|
            # En-têtes
            csv << [
                'Seagma',
                'Nom', 'Prénom', 
                'Naissance', 'Adresse', 'Fixe', 'Gsm', 'Mails',
                'Cotis-1', 'Cotis-2', 'CPE',
                'Eneo', 'EneoSport', 'V-A',
                'CDC Pr', 'CDC Sc',
                'Nouveau', 'Modification', 'Ancien', 'Décès',
                'ActPrc'
            ]
            # Données
            pages_selected.each do |member|
                # extract properties
                props = extract_properties(member)
                
                # select according to list nr
                result  = selectPage(props)
            #    pp result
                next    if result['code'] != 'Y'    #next page if false
                count_csv   += 1

                # Format
                result['Naissance'] = result['Naissance'][8..9]+"-"+result['Date naissance'][5..6]+"-"+result['Date naissance'][0..3]   unless result['Date naissance'].nil?

                # record
                csv << [
                    result['Seagma'],
                    result['Nom'],
                    result['Prénom'],
                    result['Naissance'],
                    result['Adresse'],
                    result['Fixe'],
                    result['Gsm'],
                    result['Mails'],
                    result['Cotis-1'],
                    result['Cotis-2'],
                    result['CPE'],
                    result['Eneo'],
                    result['EneoSport'],
                    result['V-A'],
                    result['CDC Pr'],
                    result['CDC Sc'],
                    result['Nouveau'],
                    result['Modification'],
                    result['Ancien'],
                    result['Décès'],
                    result['ActPrc']

                ]
            end
        end

        puts "✓ Export CSV créé: #{CSVFILE_OUTPUT} (#{count_csv} membres)"

        return  count_csv
    end #<def>

    # Processing
    def run(check_date,log)
    #++++++
    #
        log.info "{INF}=== MBR extract for Office ==="
        log.warn    "{TRT}=== Extract pages ==="    if OPTS[:debug]
        pages_extracted  = extractPages(check_date)

        if pages_extracted.empty?
            log.warn "{ERR}Aucun membre trouvé"
            return
        else
            log.info "{TRT}>MBR: #{pages_extracted.count} records read"
        end

        log.warn    "{TRT}=== Filter pages ==="     if OPTS[:debug]
        pages_selected  = []
        errors_selected = []

        pages_extracted.each do |page|
            props = extract_properties(page)
            pages_selected.push(page)   if selectPage(props)
        #    break   if props['Référence'] == "Binnemans-Jean-Pierre"
        end

        if pages_selected.empty?
            log.warn "{ERR}Aucun membre sélectionné"
            return
        else
            log.info "{TRT}>FILTER: #{pages_selected.count} records selected"
            log.info("*")
        end

        log.info "{INF}=== Create csv file ==="
        count_csv   = saveToCsv(pages_selected)

        log.info("Date naissance vide:#{@count_naiss}")
        log.info("Counters:Décès:#{@count_deces} Sortie:#{@count_sortie} Nouveau:#{@count_nouveau} Cotis:#{@count_cotis} Modif:#{@count_modif}")
        log.info("CSV:#{count_csv} - MBR:#{pages_extracted.count} - SEL:#{pages_selected.count}")
    end #<def>

end #<class>

#
# ==============================
#   Utilisation
# ==============================
#
   if __FILE__ == $0

        log.info("{INF}Start of script <EneoBwCom_ExtrOffice05>")
        log.warn("{DBG}Parameters:: Debug:#{OPTS[:debug]} & List:#{OPTS[:list]} # #{CHECK_DATE} on mode: #{DRY_RUN ? 'DRY_RUN (simulation)' : 'PRODUCTION'}")

        # get new instance
        inst    = ExtractorMBR.new()                    #get new instance

        # get DRY_RUN
        print   "DRY_RUN:#{DRY_RUN} - Production (Y/N)[N] ? "
        reply   = $stdin.gets.chomp.to_s.upcase
        DRY_RUN = false if reply == 'Y'

        #processing
        inst.run(CHECK_DATE, log)                #processing

        log.info "{INF}Enf of script"
   end  #<>
