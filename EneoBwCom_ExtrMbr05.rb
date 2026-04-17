#!/usr/bin/env ruby
=begin
    #Program:   EneoBwCom_ExtrMbr05
    #Build:     5-2-1
    #Function:  Extract members
    #Call:      ruby EneoBwCom_ExtrMbr05.rb
    #Folder:    Public/Progs/.
    #Parameters::
    #Versions:  5-1-1   <250913-1736>
                5-2-1   <251109-1500>   remove "Date paiement" on csv
                5-2-2   <260127-0700>   complete list values for cells
=end

require 'httparty'
require 'json'
require 'csv'
require 'logger'
require 'write_xlsx'

class NotionMembersExtractor
#***************************

    NOTION_API_VERSION      = ENV.fetch("NOT_APIVER")
    NOTION_API_TOKEN        = ENV.fetch('NOT_APITOKEN')
    BASE_URL                = ENV.fetch("NOT_HTTPBASE")

    CONTAINER_DATABASE_ID   = ''
    CONFIG                  = JSON.parse(File.read(File.join(__dir__, "Data_Sources_ID2.json")))
    DBMBR_ID                = CONFIG.find { |h| h.key?("m25t.Membres") }&.fetch("m25t.Membres")

    DIRECTORY_TO_PUT    = "/users/Gilbert/Public/MemberLists/ToSend"
    DIRECTORY_TO_SAVE   = "/users/Gilbert/pCloud Drive/Benevolats/Eneo_Listes/2026/Envois/"


    COTISATION_INIT     = false                         #only for 1st time

    #
    @count_inp  = 0
    @count_out  = 0

    #
    def initialize()
    #+++++++++++++
        @token              = NOTION_API_TOKEN
        @container_db_id    = format_database_id(CONTAINER_DATABASE_ID)
        @mbr_db_id          = DBMBR_ID
        @headers = {
            'Authorization' => "Bearer #{@token}",
            'Notion-Version' => NOTION_API_VERSION,
            'Content-Type' => 'application/json'
        }
    end
  
    # Formate l'ID au format UUID
    def format_database_id(id)
    #+++++++++++++++++++++
        clean_id = id.gsub('-', '')
        "#{clean_id[0..7]}-#{clean_id[8..11]}-#{clean_id[12..15]}-#{clean_id[16..19]}-#{clean_id[20..31]}"
    end
    
  
    # Query les membres avec filtre optionnel
    def query_members(activity_filter = nil)
    #++++++++++++++++
        return nil unless @mbr_db_id
        
        query = {
            filter: {},
            sorts: [{ property: 'Référence', direction: 'ascending' }]
        }

        # Ajouter filtre activité si spécifié
        if activity_filter && activity_filter != 'Tous'
            query[:filter] = {
            or: [
                { property: 'Activité principale', select: { equals: activity_filter } },
                { property: 'Activités secondaires', multi_select: { contains: activity_filter } }
                ]
            }
        end
    
        # Filtre membres en service
        if query[:filter].empty?
            query[:filter] = { property: 'En/Hors service', checkbox: { equals: true } }
        else
            query[:filter] = {
            and: [
                query[:filter],
                { property: 'En/Hors service', checkbox: { equals: true } }

                # Insérez ici une propriété supplémentaire, n'oubliez pas la ',' 
                #       à la ligne précédente
                #
            ]
            }
        end
        
        all_members     = []
        has_more        = true
        start_cursor    = nil
        
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
        has_more = response['has_more']
        start_cursor = response['next_cursor']
        end

        @count_inp  = all_members.count
        all_members
    end
  
    # Récupère les détails d'une page
    def get_page_details(page_id)
    #+++++++++++++++++++
        response = HTTParty.get(
            "#{BASE_URL}/pages/#{page_id}",
            headers: @headers
        )
        response.success? ? response : nil
    end
  
    # Extrait les propriétés
    def extract_properties(page)
    #+++++++++++++++++++++
        props = {}
        page['properties'].each do |key, value|
            props[key] = extract_property_value(value)
        end
        props
    end
  
    # Extrait la valeur d'une propriété
    def extract_property_value(prop)
    #+++++++++++++++++++++++++
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
            value   = prop['formula']&.dig('string')
            value.split(':')[1]     unless value.nil?
        else
            nil
        end
    end

    # Enter display format
    def enterDisplayFormat()
    #+++++++++++++++++++++
        lst_format  = {
            'Fiche' => 'F',
            'Liste' => 'L',
            'Reset' => 'R',
            'CSV'   => 'C',
            'XLSX'  => 'X',
            'C'     => 'Csv',
            'F'     => 'Fiche',
            'L'     => 'Liste',
            'R'     => 'Reset',
            'X'     => 'Xlsx'
        }
        lst_format.each do |key, value|
            puts    "Format: #{key} => #{value}"
        end
        print   "Please select the format by letter => "
        format_key  = $stdin.gets.chomp.to_s.upcase
        format_key  = 'Reset'   if format_key.empty?
        puts    "=>Format: #{lst_format[format_key]} selected"
        return  lst_format[format_key]
    end

    # Enter encoder format
    def enterEncoderFormat()
    #+++++++++++++++++++++
        enc_format  = {
            'U' =>  'UTF-8',
            'W' => 'CP1252'
        }
        enc_format.each do |key, value|
            puts    "Format: #{key} => #{value}"
        end
        print   "Please select the encoder by letter {U(TF-8)/W(indows)} [W] => "
        format_key  = $stdin.gets.chomp.to_s.upcase
        format_key  = 'W'   if format_key.empty?
        puts    "=>Encoder: #{enc_format[format_key]} selected"
        return  enc_format[format_key]
    end

    def enterContentFormat()
    #+++++++++++++++++++++
        con_format  = {
            'F' => 'Full',
            'P' => 'Paiem'
        }
        con_format.each do |key, value|
        end
        print   "Please select the content by letter {F(ull)/P(artial)} [F] => "
        content_key = $stdin.gets.chomp.to_s.upcase
        content_key = 'F'   if content_key.empty?
        puts    "=>Content: #{con_format[content_key]} selected"
        return  con_format[content_key]
    end #<def>

    # Enter activity
    def enterActivity()
    #++++++++++++++++
        lst_activity    = [
            'Amicale_des_Archers',
            'Aquagym_1',
            'Aquagym_2',
            'Aquagym_3',
            'Art_Floral',
            'Danse',
            'Dessin',
            'Gymnastique_1',
            'Gymnastique_2',
            'Informatique',
            'Marcheurs_du_Jeudi',
            'Marche_Nordique',
            'Pilates',
            'Randonneurs_du_Brabant',
            'Scrapbooking',
            'TaiChi',
            'Tennis_de_Table',
            'Vie_Active'
        ]
        lst_activity.each_with_index do |act, index|
            puts    "#{index+1} => #{act}"
        end
        print   "Please select the activity by N° => "
        actindex    = $stdin.gets.chomp.to_i
        exit    9   if actindex == 0
        actselect   = lst_activity[actindex-1]
        puts    "=>Activity selected: #{actselect}"

        return  actselect
    end

    # Exporte en CSV
    def export_to_csv(members, filename, activity_name = 'Tous', display_format='X', encoder_format = 'X')
    #++++++++++++++++
        puts    "=>Export to .csv with ENCODER: #{encoder_format}"
        # Create rows
        csv_out = []
        members.each do |member|
            props = extract_properties(member)
            
            # Format
            props['Demande']        = ''    if display_format == 'R'
            props['Cotisation']     = '0'   if COTISATION_INIT
            props['Date naissance'] = props['Date naissance'][8..9]+"-"+props['Date naissance'][5..6]+"-"+props['Date naissance'][0..3]   unless props['Date naissance'].nil?
            props['Date sortie']    = props['Date sortie'][8..9]+"-"+props['Date sortie'][5..6]+"-"+props['Date sortie'][0..3]   unless props['Date sortie'].nil?
            props['Date décès']     = props['Date décès'][8..9]+"-"+props['Date décès'][5..6]+"-"+props['Date décès'][0..3]   unless props['Date décès'].nil?
            puts    "=>Membre: #{props['Référence']}"
            # Save
            csv_out << [
                props['Demande'],
                props['Référence'],
                props['CDC'],
                props['Activité principale'],
                props['Activités secondaires']&.join(', '),
                props['Civilité'],
                props['Adresse'],
                props['Gsm'],
                props['Fixe'],
                props['Email'],
                props['Date naissance'],
                props['Cotisation'],
                props['V-A'],
                props['Date sortie'],
                props['Date décès'],
                props['Contrôles']
            ]
        end
        @count_out  = csv_out.count
        index   = 0
        # Save to file
        File.open(filename, 'w', encoding: 'UTF-8') do |f|
            f.write("\uFEFF")  # Insère le BOM au début
            
            csv = CSV.new(f, col_sep: ';', encoding: encoder_format)
            # En-têtes
            csv << [
                'Demande',
                'Référence', 'CDC', 
                'Activité principale', 'Activités secondaires',
                'Civilité', 'Adresse', 'Gsm', 'Fixe', 'Email',
                'Date naissance', 'Cotisation', 
                'V-A',
                'Date sortie', 'Date décès',
                'Contrôles'
            ]
            # Données
            while index < @count_out
                csv << csv_out[index]
                index   += 1
            end
        end
        puts "✓ Export CSV créé: #{filename}"
    end #<def>

    # Exporte en xlsx
    def export_to_xlsx(members, filename, activity_name = 'Tous', display_format='X', encoder_format = 'X', content_format = 'F')
    #+++++++++++++++++
        puts    "=>Export to .xlsx for: #{activity_name} with ENCODER: #{encoder_format} CONTENT: #{content_format}"
        # Create rows
        csv_out     = []                                #contains all rows
        members.each do |member|
            props = extract_properties(member)          #properties for 1 mbr
            
            # Format
            props['Demande']        = ''    if display_format == 'R'
            props['Cotisation']     = '0'   if COTISATION_INIT
            props['Date naissance'] = props['Date naissance'][8..9]+"-"+props['Date naissance'][5..6]+"-"+props['Date naissance'][0..3]   unless props['Date naissance'].nil?
            props['Date sortie']    = props['Date sortie'][8..9]+"-"+props['Date sortie'][5..6]+"-"+props['Date sortie'][0..3]   unless props['Date sortie'].nil?
            props['Date décès']     = props['Date décès'][8..9]+"-"+props['Date décès'][5..6]+"-"+props['Date décès'][0..3]   unless props['Date décès'].nil?
            puts    "=>Membre: #{props['Référence']}"
            # Content ?
        #    puts    "DBG>>>#{props['Activité principale']} - #{props['Activité principale'].class}"
        #    pp props['Activité principale']
            next    if content_format == 'Paiem' and props['Activité principale'].nil?
            next    if content_format == 'Paiem' and !props['Activité principale'].include?(activity_name)
            next    if content_format == 'Paiem' and !props['Cotisation'].include?('18')
            # Save
            csv_out << [                                #append row
                props['Demande'],
                props['Référence'],
                props['CDC'],
                props['Activité principale'],
                props['Activités secondaires']&.join(', '),
                props['Civilité'],
                props['Adresse'],
                props['Gsm'],
                props['Fixe'],
                props['Email'],
                props['Date naissance'],
                props['Cotisation'],
                props['V-A'],
                props['Date sortie'],
                props['Date décès'],
                props['Contrôles']
            ]
        end
        @count_out  = csv_out.count

        # Save to file
        # 1-Créer un nouveau classeur
        workbook = WriteXLSX.new(filename)

        # 2.1-Ajouter une feuille avec un nom spécifique
        worksheet = workbook.add_worksheet('Membres')
        # 2.2-Définir la largeur de chaque colonne
        worksheet.set_column(0,0,15)                    #demande
        worksheet.set_column(1,1,20)                    #reference
        worksheet.set_column(2,2,5)                     #CDC
        worksheet.set_column(3,3,20)                    #act prc
        worksheet.set_column(4,4,20)                    #act sec
        worksheet.set_column(5,5,10)                    #civilite
        worksheet.set_column(6,6,25)                    #adresse
        worksheet.set_column(7,7,15)                    #gsm
        worksheet.set_column(8,8,15)                    #fixe
        worksheet.set_column(9,9,20)                    #email
        worksheet.set_column(10,10,15)                  #date naissance
        worksheet.set_column(11,11,10)                  #cotisation
        worksheet.set_column(12,12,5)                   #v-a
        worksheet.set_column(13,13,15)                  #date sortie
        worksheet.set_column(14,14,15)                  #date décès
        worksheet.set_column(15,15,20)                  #contrôles
        # 2.3-Définir les styles
        style_wrap  = workbook.add_format(wrap_text:true)
        style_bold  = workbook.add_format(bold:true)

        # 3-Définir les listes déroulantes
        listes_choix    = [
                            [],                         #0
                            [],                         #1
                            [                           #2-CDC
                            "BLA", "BLC", "BLH",
                            "CLB", "CSE",
                            "EXT",
                            "GEN", "GNP", "JOD", "LAS",
                            "NIV",
                            "OTT", "PEW", "REB", "RIX",
                            "SDA", "SEN", "TUB",
                            "VIL", "VLV",
                            "WAL", "WAT", "WAV"
                            ],
                            [                           #3-ACTPRC
                            "Amicale_des_Archers",
                            "Aquagym_1", "Aquagym_2", "Aquagym_3",
                            "Art_Floral", "Danse", "Dessin",
                            "Gymnastique_1", "Gymnastique_2",
                            "Informatique",
                            "Marche_Nordique", "Marcheurs_du_Jeudi",
                            "Pilates", "Randonneurs_du_Brabant",
                            "Scrapbookin", "TaiChi",
                            "Tennis_de_Table", "Vie_Active"
                            ],
                            [                           #4-ACTSECS
                            "Amicale_des_Archers",
                            "Aquagym_1", "Aquagym_2", "Aquagym_3",
                            "Art_Floral", "Danse", "Dessin",
                            "Gymnastique_1", "Gymnastique_2",
                            "Informatique",
                            "Marche_Nordique", "Marcheurs_du_Jeudi",
                            "Pilates", "Randonneurs_du_Brabant",
                            "Scrapbookin", "TaiChi",
                            "Tennis_de_Table", "Vie_Active"
                            ],
                            [                           #5-CIVILITE
                            "M.", "Mme"
                            ],
                            [],                         #6
                            [],                         #7
                            [],                         #8
                            [],                         #9
                            [],                         #10
                            [                           #11-COTISATION
                            "0", "9", "18"
                            ],
                            [                           #12-V-A
                            "V", "A", "VA"
                            ],
                            [],                         #13
                            [],                         #14
                            []                          #15
                        ]
        liste_cols      = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
                            'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P'
                        ]

        # 4-En-têtes
        #           Titres                              index
        headers = [
                    "Demande",                          #0
                   "Référence",                         #1
                   "CDC",                               #2 - liste
                   "Activité principale",               #3 - liste
                   "Activités secondaires",             #4 - liste
                   "Civilité",                          #5 - liste
                   "Adresse",                           #6
                   "Gsm",                               #7
                   "Fixe",                              #8
                   "Email",                             #9
                   "Date naissance",                    #10
                   "Cotisation",                        #11 - liste
                   "V-A",                               #12 - liste
                   "Date sortie",                       #13
                   "Date décès",                        #14
                   "Contrôles"                          #15
                ]
        worksheet.write_row(0, 0, headers, style_bold)

        #5-rows
        index   = 0
        row     = 1
        csv_out.each do |data|
            col = 1
            for col in 1..15
                case col
                when 2, 3, 5, 11, 12                    #liste
                    worksheet.write(row, col, "#{data[col]}")
                    cell_ref = "#{liste_cols[col]}#{row}" # cell (A..P 1..N)
                    worksheet.data_validation(cell_ref, {
                                    validate: 'list',
                                    source: listes_choix[col],
                                    dropdown: true,
                                    input_message: 'Sélectionnez une option',
                                    input_title: 'Liste déroulante'
                                    })
                when 4                                  #liste + style
                    temp    = data[col].gsub(/\s+/, "")
                    worksheet.write(row, col, temp, style_wrap)
                    cell_ref = "#{liste_cols[col]}#{row}" # cell (A..P 1..N)
                    worksheet.data_validation(cell_ref, {
                                    validate: 'list',
                                    source: listes_choix[col],
                                    dropdown: true,
                                    input_message: 'Sélectionnez une option',
                                    input_title: 'Liste déroulante'
                                    })
                else                                    #normal
                    worksheet.write(row, col, "#{data[col]}")
                end
            end
            row += 1
        end
        #6-close
        workbook.close
    end #<def>

    # Affiche les membres dans la console
    def display_members(members, activity_name = 'Tous', display_format = 'X')
    #++++++++++++++++++
        puts "\n=== Membres - #{activity_name} ==="
        puts "#{members.count} membre(s) trouvé(s)\n"

        members.each do |member|
            props = extract_properties(member)
            
            if display_format == 'L'
                puts    "#{props['Référence']} =>" + 
                    " CDC:#{props['CDC']} #" +
                    " ActPrc:#{props['Activité principale']} #" +
                    " ActSecs:props['Activités secondaires] #" +
                    " Email:#{props['Email']} #"
            else
                puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                puts "#{props[:Référence]}"
                puts "  CDC: #{props[:CDC]}"
                puts "  Activité principale: #{props['Activité principale']}"
                puts "  Activités secondaires: #{props['Activités secondaires']&.join(', ')}" if props['Activités secondaires']&.any?
                puts "  Email: #{props[:Email]}" if props[:Email]
                puts "  Gsm: #{props[:Gsm]}" if props[:Gsm]
                puts "  Naissance: #{props['Date naissance'][8..9]}-#{props['Date naissance'][5..6]}-#{props['Date naissance'][0..3]}" unless props['Date naissance'].nil?
                puts "  Contrôles: #{props[:Contrôles]}"
            end
        end

        puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"   if display_format == 'F'
  end
  
    # Exécution
    #==========
    def run(activity_filter = nil, export_csv = false, display_format = 'X', encoder_format = 'X', content_format = 'F')
    #++++++
        puts "=== Extraction des membres ===Format: #{display_format} - Encodage: #{encoder_format} - Content: #{content_format}"

        unless @mbr_db_id
            puts "✗ Data Source MBR non trouvé"
            return
        end

        # Query les membres
        activity_name = activity_filter || 'Tous'
        puts "\nFiltre activité: #{activity_name}"

        members = query_members(activity_filter)

        if members.empty?
            puts "=>Aucun membre trouvé"
            return
        end

        # Afficher ou exporter
        puts    "=== Export ou affichage des membres ==="
        if export_csv
            timestamp = Time.now.strftime('%y%m%d_%H%M')
            if display_format == 'CSV'
                filename = "#{DIRECTORY_TO_PUT}/M25-ListeMembres_#{activity_name.gsub(' ', '_')}-Envoi_#{timestamp}.csv"
                export_to_csv(members, filename, activity_name, display_format, encoder_format)
            else
                filename = "#{DIRECTORY_TO_PUT}/M25-ListeMembres_#{activity_name.gsub(' ', '_')}-Envoi_#{timestamp}.xlsx"
                export_to_xlsx(members, filename, activity_name, display_format, encoder_format, content_format)
            end
        else
            puts    "=>Display as #{display_format}"
            display_members(members, activity_name, display_format)
        end

        puts    "=>Counters:: INP:#{@count_inp} - OUT:#{@count_out}\n"
    end
end #<class>

# Utilisation
#++++++++++++
    if __FILE__ == $0

# Logger
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    logger.datetime_format = '%H:%M:%S'
    logger.info "🔧 Mode: PRODUCTION"

    # Exemples d'utilisation :

    # 1. Afficher tous les membres
    # extractor = NotionMembersExtractor.new(NOTION_API_TOKEN, CONTAINER_DATABASE_ID)
    # extractor.run

    # 2. Afficher les membres d'une activité
    # extractor = NotionMembersExtractor.new(NOTION_API_TOKEN, CONTAINER_DATABASE_ID)
    # extractor.run('Informatique')

    # 3. Exporter tous les membres en CSV
    # extractor = NotionMembersExtractor.new(NOTION_API_TOKEN, CONTAINER_DATABASE_ID)
    # extractor.run(nil, true)

    # 4. Exporter une activité en CSV
        extractor = NotionMembersExtractor.new()

        while   true
            logger.info "*** Choix de l'option ***"
            puts "Choisissez une option :"
            puts "1. Afficher tous les membres"
            puts "2. Afficher une activité spécifique"
            puts "3. Exporter tous les membres (CSV)"
            puts "4. Exporter une activité (CSV)"
            puts "49 Exporter toutes les activités (CSV)"
            print "Votre choix (1-4): "

            choice = $stdin.gets.chomp.to_i

            case choice
            when 1
                logger.info "=> 1. Afficher tous les membres"
                display_format  = extractor.enterDisplayFormat()
                extractor.run(nil, false, display_format)
            when 2
                logger.info "=> 2. Afficher une activité spécifique"
                activity        = extractor.enterActivity()
                display_format  = extractor.enterDisplayFormat()
                extractor.run(activity, false, display_format)
            when 3
                logger.info "=> 3. Exporter tous les membres (CSV)"
                encoder_format  = extractor.enterEncoderFormat()
                display_format  = extractor.enterDisplayFormat()
                extractor.run(nil, true, display_format, encoder_format)
            when 4
                logger.info "=> 4. Exporter une activité (CSV)"
                activity        = extractor.enterActivity()
                encoder_format  = extractor.enterEncoderFormat()
                display_format  = extractor.enterDisplayFormat()
                content_format  = extractor.enterContentFormat()
            #    puts    "DBG>>>Activity:#{activity}-Encoder:#{encoder_format}-Display:#{display_format}-Content:#{content_format}"
                extractor.run(activity, true, display_format, encoder_format, content_format)
            when    49
            else
                logger.info "=> Choix invalide"
                puts "Choix invalide"
                break
            end
        end
    end