#!/usr/bin/env ruby
=begin
=end

require 'httparty'
require 'json'
require 'csv'
require 'logger'

class NotionMembersExtractor
#***************************

    NOTION_API_VERSION  = '2025-09-03'
    NOTION_API_TOKEN    = 'secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3'
    BASE_URL            = 'https://api.notion.com/v1'

    DIRECTORY_TO_PUT    = "/users/Gilbert/Public/MemberLists/ToSend"
    DIRECTORY_TO_SAVE   = "/users/Gilbert/pCloud Drive/Benevolats/Eneo_Listes/2026/Envois/"
    COTISATION_INIT     = true                            #only for 1st time

    #
    @count_inp  = 0
    @count_out  = 0

    #
    def initialize(token, container_db_id)
    #+++++++++++++
        @token = token
        @container_db_id = format_database_id(container_db_id)
        @mbr_db_id = '26872117-082a-8066-99bd-000beaa5de5e'
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
            ]
            }
        end
        
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
            'Reset' => 'R'
        }
        lst_format.each do |key, value|
            puts    "Format: #{key} => #{value}"
        end
        print   "Please select the format by letter => "
        format_key  = $stdin.gets.chomp.to_s
        format_key  = 'Reset'   if format_key.empty?
        puts    "=>Format: #{lst_format[format_key]}"
        return  lst_format[format_key]
    end

    # Enter encoder format
    def enterEncoderFormat()
    #+++++++++++++++++++++
        enc_format  = {
            'U' =>  'UTF-8',
            'W' =>  'CP1252',
            'X' =>  'XYZ'
        }

        return  'X'                                     # 2 formats 

        enc_format.each do |key, value|
            puts    "Format: #{key} => #{value}"
        end
        print   "Please select the encoder by letter (U/W) [X] => "
        format_key  = $stdin.gets.chomp.to_s.upcase
        format_key  = 'X'   if format_key.empty?
        puts    "=>Encoder: #{enc_format[format_key]}"
        return  enc_format[format_key]
    end

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
        puts    "=>Export to .csv with 2 formats : UTF-8 & CP1252"
        # Create array with rows
        csv_out = []
        members.each do |member|    #<l1>
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
        end #<L1>
        @count_out  = csv_out.count

        # Save as UTF-8
        index   = 0
        fileutf8    = filename.gsub("$","U8")
        File.open(fileutf8, 'w', encoding: 'UTF-8') do |f|  #<L1>
            f.write("\uFEFF")  # Insère le BOM au début
            
            # Append csv data
            csv = CSV.new(f, col_sep: ';', encoding: 'UTF-8')
            # Header
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
            # Data
            while index < @count_out    #<L2>
                csv << csv_out[index]
                index   += 1
            end #<L2>
        end #<L1>
        puts "✓ Export CSV créé: #{fileutf8}"

        # Save as CP1252
        index   = 0
        filecp12    = filename.gsub("$","CP")
        File.open(filecp12, 'w', encoding: 'CP1252') do |f| #<L1>
    #        f.write("\uFEFF")  # Insère le BOM au début
            
            # Append csv data
            csv = CSV.new(f, col_sep: ';', encoding: 'Windows-1252')
            # Header
            csv << [
                'Demande',
                'Référence'.encode("Windows-1252", invalid: :replace, undef: :replace, replace: ""),
                'CDC', 
                'Activité principale'.encode("Windows-1252", invalid: :replace, undef: :replace, replace: ""),
                'Activités secondaires'.encode("Windows-1252", invalid: :replace, undef: :replace, replace: ""),
                'Civilité'.encode("Windows-1252", invalid: :replace, undef: :replace, replace: ""),
                'Adresse', 'Gsm', 'Fixe', 'Email',
                'Date naissance', 'Cotisation', 
                'V-A',
                'Date sortie',
                'Date décès'.encode("Windows-1252", invalid: :replace, undef: :replace, replace: ""),
                'Contrôles'.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "")
            ]
            # Data
            csv_out.each do |row|   #<L2>
                row_encoded = row.map do |field|    #<L3>
                    if field.is_a?(String)  #<IF4>
                        # Encode
                        field.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
                    else    #<IF4>
                        # Convert to string & encode
                        field.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?")
                    end #<IF4>
                end #<L3>
                csv << row_encoded
            end #<L2>
            index   += 1
        end #<L1> close file
        puts "✓ Export CSV créé: #{filecp12}"
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
    def run(activity_filter = nil, export_csv = false, display_format = 'X', encoder_format = 'X')
    #++++++
        puts "=== Extraction des membres ===Format: #{display_format} - Encodage: #{encoder_format}"

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
            filename = "#{DIRECTORY_TO_PUT}/M25-ListeMembres_#{activity_name.gsub(' ', '_')}-Env$_#{timestamp}.csv"
            export_to_csv(members, filename, activity_name, display_format, encoder_format)

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

    NOTION_TOKEN = ENV['NOTION_TOKEN'] || 'secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3'
    CONTAINER_DATABASE_ID = ''
# Logger
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    logger.datetime_format = '%H:%M:%S'
    logger.info "🔧 Mode: PRODUCTION"

    # Exemples d'utilisation :

    # 1. Afficher tous les membres
    # extractor = NotionMembersExtractor.new(NOTION_TOKEN, CONTAINER_DATABASE_ID)
    # extractor.run

    # 2. Afficher les membres d'une activité
    # extractor = NotionMembersExtractor.new(NOTION_TOKEN, CONTAINER_DATABASE_ID)
    # extractor.run('Informatique')

    # 3. Exporter tous les membres en CSV
    # extractor = NotionMembersExtractor.new(NOTION_TOKEN, CONTAINER_DATABASE_ID)
    # extractor.run(nil, true)

    # 4. Exporter une activité en CSV
        extractor = NotionMembersExtractor.new(NOTION_TOKEN, CONTAINER_DATABASE_ID)

        logger.info "*** Choix de l'option ***"
        puts "Choisissez une option :"
        puts "1. Afficher tous les membres"
        puts "2. Afficher une activité spécifique"
        puts "3. Exporter tous les membres (CSV)"
        puts "4. Exporter une activité (CSV)"
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
            extractor.run(activity, true, display_format, encoder_format)
        else
            logger.info "=> Choix invalide"
            puts "Choix invalide"
        end
    end