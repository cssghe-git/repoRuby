=begin
#   Program:    PrvUploadToNotion Dossiers
#   Parameters: P1 => debug => Y or N
#               P2 => Loop => L or null
#               P3 => nil
#               P4 => file from finder or F to select
#
#   Function:   upload 1 file to Notion.DB & attach to 'Dossier'
#   Build:      0.0.1   <251026-0907>
#
#
=end

require 'rubygems'
require 'net/http'
require 'net/smtp'
require 'rest-client'
require 'httparty'
require 'mime/types'
require 'timeout'
require 'uri'
require 'json'
require 'csv'
require 'pp'

require_relative    'Mod_SelectFile.rb'

NOTION_TOKEN            = 'secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3'
NOTION_API_VERSION      = '2025-09-03'
NOTION_API_VERSION_OLD  = '2022-06-28'
BASE_URL                = 'https://api.notion.com/v1'

ID_FILE_DB              = '20172117082a809784efeb6f051f8e0c'    #upload
ID_ACTION_DB            = '32972117082a80308f29fdce26746200'    #Action utilisateurs 
ID_DOSS_DB              = '34472117082a80b2a596d4863a40b6f9'    #https://www.notion.so/cssghe/34472117082a80b2a596d4863a40b6f9?v=34472117082a8043bc90000c8317b8fd&source=copy_link
ID_TAGS_DB              = '32a72117082a80ea8dabf4523ddbe769'    #https://www.notion.so/cssghe/32a72117082a80ea8dabf4523ddbe769?v=34472117082a80f596fd000c551c2274&source=copy_link
ID_TYPE_DB              = '34472117082a80eb939fd3f66a0fe282'    #https://www.notion.so/cssghe/34472117082a80eb939fd3f66a0fe282?v=34472117082a80ff8996000c4dce4b46&source=copy_link
ID_DOCS_DB              = '0'    #Documents
ID_DOCS_BVL             = '2c372117-082a-8033-b77a-000b4e5b6fb6'
ID_DOCS_FIN             = '2c272117-082a-80ea-a31a-000b9f58c855'
ID_DOCS_INF             = '2c172117-082a-808d-8936-000b3ad03c19'
ID_DOCS_OFF             = '2c372117-082a-805a-9cca-000b6c71d553'
ID_DOCS_SAN             = '2c372117-082a-8020-bd2a-000b4ec7a18b'
ID_DOCS_DOC             = '33172117-082a-802c-b4aa-000b97e72313'

#
# Variables globales
#*******************
    @arr_fileinfos  = {}    #{directory=> ?,path=> ?, filename=> ?, 
                            #size=> ?, type=> ?, data=> ?, fullpath=> ?, 
                            #content=> ?, tags=> ?, code=> ?, part=> ?, 
                            #id=> ?}
    @arr_parameters = {}    #
    @arr_fields_req = {}    #
    @arr_fields_val = {}    #

    @dossier_id     = ''    #
    @tk_initdir     =   '/users/Gilbert/Public'

    #           Class
    #           *****

class   UploadFileToNotion
#*************************
#

    def initialize()
    #+++++++++++++
    #   create new instance
    #   INP:    ?
    #   OUT:    instance
    #
        @token              = NOTION_TOKEN
        @arr_fileinfos      = {}
        @arr_parameters     = {}
        @arr_fields_req     = {}
    ###    @obj_choices        = OBJ_CHOICES
        @headers = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION,
            'Content-Type'      => 'application/json'
        }
        # internal values
        @max_size       = 10000
        @old_num        = 0
        @old_dir        = 'exit'
        @old_area       = 'down'
        @old_object     = 'doc'
        @type_include   = ['txt', 'pdf', 'json', 'csv',
                            'docx', 'xlsx', 'pptx',
                            'gif', 'heic', 'jpeg', 'jpg', 'png', 'svg', 'ico',
                            'mp3', 'mp4', 'm4a', 'wav',
                            'xxx']
        @old_level1, @old_level2, @old_level3, @old_level4  = 'None'
    end #<def>

    def getParameters()
    #++++++++++++++++
    #   get parameters
    #   INP:    ARGV
    #   OUT:    @arr_parameters => {debug=> ?, P2=> ?, P3=> ?, file=> ?}
    #
        @arr_parameters['debug']    = ARGV[0]
        @arr_parameters['P2']       = ARGV[1]
        @arr_parameters['P3']       = ARGV[2]
        @arr_parameters['file']     = ARGV[3]

        @arr_parameters
    end #<def>

    def loadDossiers()
    #+++++++++++++++
    #   INP:    ?
    #   OUT:    ?
    #
        # Settings
        myheaders = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION_OLD,
            'Content-Type'      => 'application/json'
        }
        query = {
        #    filter: {},
            sorts: [{ property: 'Nom', direction: 'ascending' }]
        }
        all_pages       = []
        has_more        = true
        start_cursor    = nil

        # Read all pages
        while has_more  #<L1>
            query[:start_cursor] = start_cursor if start_cursor

            response = HTTParty.post(
                "#{BASE_URL}/databases/#{ID_DOSS_DB}/query",
                headers: myheaders,
                body: query.to_json
            )

            unless response.success?    #<IF2>
                puts "=> #{__method__} : Erreur query: #{response['message']}"
                pp  response
                break
            end #<IF2>

            all_pages.concat(response['results'])
            has_more        = response['has_more']
            start_cursor    = response['next_cursor']
        end #<L1>

        # Dispatch about type
        @arr_dossiers = {}
        all_pages.each do |page|    #<L1>
            page_id             = page['id']
            properties          = page['properties']
            ### pp page['properties']
            value               = properties['Nom']
            nom                 = value["title"].map { _1["plain_text"] }.join
           @arr_dossiers[nom]   = [page_id]
        end #<L1>
    end #<def>

    def loadTags()
    #+++++++++++
    #   INP:    ?
    #   OUT:    ?
    #
        # Settings
        myheaders = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION_OLD,
            'Content-Type'      => 'application/json'
        }
        query = {
        #    filter: {},
            sorts: [{ property: 'Référence', direction: 'ascending' }]
        }
        all_pages       = []
        has_more        = true
        start_cursor    = nil

        # Read all pages
        while has_more  #<L1>
            query[:start_cursor] = start_cursor if start_cursor

            response = HTTParty.post(
                "#{BASE_URL}/databases/#{ID_TAGS_DB}/query",
                headers: myheaders,
                body: query.to_json
            )

            unless response.success?    #<IF2>
                puts "=> #{__method__} : Erreur query: #{response['message']}"
                pp  response
                break
            end #<IF2>

            all_pages.concat(response['results'])
            has_more        = response['has_more']
            start_cursor    = response['next_cursor']
        end #<L1>

        # Dispatch about type
        @arr_tags = {}
        @arr_tags_l1, @arr_tags_l2, @arr_tags_l3, @arr_tags_l4 = [], [], [], []
        all_pages.each do |page|    #<L1>
            page_id     = page['id']
            properties  = page['properties']
            ### pp page['properties']
            value   = properties['Référence']
            nom     = value["title"].map { _1["plain_text"] }.join
            value   = properties['Area']
            l1      = value['checkbox']
            value   = properties['Dossier']
            l2      = value['checkbox']
            value   = properties['Tag']
            l3      = value['checkbox']
            value   = properties['Type']
            l4      = value['checkbox']
            @arr_tags[nom]  = [page_id,l1,l2,l3,l4]
        end #<L1>
        ### pp  @arr_tags

        # explode into 4 levels
        @tagl1   = @arr_tags.select{|_, v| v[1]}.keys
        @tagl2   = @arr_tags.select{|_, v| v[2]}.keys
        @tagl3   = @arr_tags.select{|_, v| v[3]}.keys
        @tagl4   = @arr_tags.select{|_, v| v[4]}.keys
        #   exit 9
    end #<def>

    def loadTypes()
    #++++++++++++
    #   INP:    ?
    #   OUT:    ?
    #
        # Settings
        myheaders = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION_OLD,
            'Content-Type'      => 'application/json'
        }
        query = {
        #    filter: {},
            sorts: [{ property: 'Nom', direction: 'ascending' }]
        }
        all_pages       = []
        has_more        = true
        start_cursor    = nil

        # Read all pages
        while has_more  #<L1>
            query[:start_cursor] = start_cursor if start_cursor

            response = HTTParty.post(
                "#{BASE_URL}/databases/#{ID_TYPE_DB}/query",
                headers: myheaders,
                body: query.to_json
            )

            unless response.success?    #<IF2>
                puts "=> #{__method__} : Erreur query: #{response['message']}"
                pp  response
                break
            end #<IF2>

            all_pages.concat(response['results'])
            has_more        = response['has_more']
            start_cursor    = response['next_cursor']
        end #<L1>

        # Dispatch about type
        @arr_types = {}
        all_pages.each do |page|    #<L1>
            page_id         = page['id']
            properties      = page['properties']
            ### pp page['properties']
            value           = properties['Nom']
            nom             = value["title"].map { _1["plain_text"] }.join
           @arr_types[nom]  = [page_id]
        end #<L1>
    end #<def>


    def checkTag()
    #+++++++++++
    #   Check if tag exists
    #   INP:    ?
    #   OUT:    ?
    #
    end #<def>

    def checkFileType(file_select)
    #++++++++++++++++
    #   types available only
    #   INP:    file_select
    #   OUT:    arr_fileinfos   => {code=> ?, filename=> ?, size=> ?, type=> ?, data=> ?, content=> ?}
    #
        # extract file infos
        #-1- set directory
        @arr_fileinfos['directory'] = File.dirname(file_select)
        @arr_fileinfos['directory'] = Dir.pwd() if @arr_parameters['file'] == 'F'
        Dir.chdir(@arr_fileinfos['directory'])

        #-2- set infos
        file_path   = file_select
        @arr_fileinfos['path']      = file_path
        file_name   = File.basename(file_path)                      #get file name
        @arr_fileinfos['filename']  = file_name
        @arr_fileinfos['size']      = File.size(file_path)          #get file size
        file_type                   = File.extname(file_name).delete('.') #get file type without dot
        @arr_fileinfos['type']      = file_type
        @arr_fileinfos['data']      = File.read(file_path)          #read file data
        file_data                   = @arr_fileinfos['data']
    #    @arr_fileinfos['fullpath']  = "#{@arr_fileinfos['directory']}/#{@arr_fileinfos['filename']}"
        @arr_fileinfos['fullpath']  = "#{file_path}"

        # check type & Get content
        type_include    = ['txt', 'pdf', 'json', 'csv']
        if @type_include.none?{ |ex| file_type.include?(ex) }
            @arr_fileinfos['content']   = file_data[0,100]
            @arr_fileinfos['code']      = true
        else
            @arr_fileinfos['content']   = 'Type not processed'
            @arr_fileinfos['code']      = false
        end

        # Get tags
        file_tags               = "upload,#{file_type}"             #default tags
        @arr_fileinfos['tags']  = file_tags.split(',').map(&:strip) #split tags by comma and remove spaces

        # return
        return  true
    end #<def>

    def ask_db()
    #+++++++++
    #   get dossier id & fields
    #   INP:    ?
    #   OUT:    @dossier_id
    #           @arr_fields_req
    #
        # all choices
        # Display Tags
        b   = "\e[1m"
        r   = "\e[0m"

        # Get Level1/Area/DB from Tags
        while   true
            puts    "\n#{b}AREA::#{r} #{@tagl1}"
            print   "For the DB.Doc -#{b}Upcase#{r} [#{@old_level1}] => "
            level1  = ask(default: "#{@old_level1}", form: 'up')
            return  false   unless level1 != 'Q'
            ### next    unless level1.size != 3
            @old_level1 = level1
            break   if @tagl1.include?(level1)
        end 

        # Get Level2/Dossier from Dossiers
        while   true
            puts    "\n#{b}DOSIER::#{r} #{@arr_dossiers.keys.join(', ')}"
            print   "Enter the Object -#{b}Capilaize#{r} [#{@old_level2}] => "
            level2  = ask(default: "#{@old_level2}", form: 'cap')
            return  false   unless level2 != 'Q'
            @old_level2 = level2
            break   if @arr_dossiers.key?(level2)
        end

        # Get Level3/Tags from Tags
        while   true
            puts    "\n#{b}TAGS::#{r} #{@tagl3}"
            print   "Enter the Tags -#{b}Capilaize#{r} [#{@old_level3}] => "
            level3  = ask(default: "#{@old_level3}", form: 'nil')
            return  false   unless level3 != 'Q'
            @old_level3 = level3
            break   if @tagl3.include?(level3)
        end

        # Get Level4/Type from Types
        while   true
            puts    "\n#{b}TYPE::#{r} #{@arr_types.keys.join(', ')}"
            print   "Enter the Type -#{b}Capilaize#{r} [#{@old_level4}] => "
            level4  = ask(default: "#{@old_level4}", form: 'cap')
            return  false   unless level4 != 'Q'
            @old_level4 = level4
            break   if @arr_types.key?(level4)
        end

        # Get Emetteur from Tags
        while   true
            puts    "\n#{b}Sender::#{r} #{@tagl4}"
            print   "Enter the #{b}Sender#{r}-#{b}NoForm#{r} [#{@old_sender}] => "
            sender  = ask(default: "#{@old_sender}", form: 'nil')
            return  false   unless sender != 'Q'
            @old_sender = sender
            break   if @arr_tags.has_key?(sender)
            @old_sender = "Unknown"
            break
        end

        # Get Note
        print   "Enter the Note (if any) => "
        @note   = $stdin.gets.chomp.to_s

        return  true
    end #<def>


    def ask(default: nil, form: nil)
        print   "Your choice [#{default}]: "
        v = STDIN.gets&.strip
        v = default if v.nil? || v.empty?
        case form
        when 'low'
            v = v.downcase
        when 'up'
            v = v.upcase
        when 'cap'
            v = v.capitalize
        else
            v
        end
    end

    def getFileObject()
    #++++++++++++++++
    #   1st part => get 'File-Object' from API
    #   INP:    @arr_fileinfos
    #   OUT:    status
    
        url = URI("https://api.notion.com/v1/file_uploads")

        http            = Net::HTTP.new(url.host, url.port)
        http.use_ssl    = true

        request                     = Net::HTTP::Post.new(url)
        request['Authorization']    = "Bearer #{NOTION_TOKEN}"
        request['Notion-Version']   = NOTION_API_VERSION
        request["accept"]           = 'application/json'
        request["content-type"]     = 'application/json'
        request.body                = "{\"mode\":\"single_part\"}"

        response    = http.request(request)
        body        = response.read_body
        body        = JSON.parse(body)
        puts    "=> ID: #{body['id']}"
        puts    "=> Status: #{body['status']}"

        @arr_fileinfos['id']    = body['id']

        # Return
        body['status']
    end #<def>

    def uploadFile()
    #+++++++++++++
    #   upload multi-part file
    #   INP:    @arr_fileinfos
    #   OUT:    status
    #
        @arr_fileinfos['part']  = (@arr_fileinfos['size']/@max_size).ceil
        
        rc  = sendFileUpload()

        # return
        rc
    end #<def>

    def sendFileUpload()
    #+++++++++++++++++++
    #   2nd part => send file
    #   INP:    ?
    #   OUT:    status
    #
        file_name       = @arr_fileinfos['filename']
        file_path       = @arr_fileinfos['fullpath']
        file_upload_id  = @arr_fileinfos['id']

        url = "https://api.notion.com/v1/file_uploads/#{file_upload_id}/send"

        # Prepare the file
        file = File.new(file_path, 'rb')
        file_content_type = MIME::Types.type_for(file_name).first.content_type

        # Prepare headers
        headers = {
            'Authorization'   => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'  => NOTION_API_VERSION_OLD
        }

        # Prepare multipart data
        payload = {
        #    file: RestClient::Payload::File.new(file, filename: file_name, content_type: file_content_type),
            file: File.new(file, filename: file_name, content_type: file_content_type),
            part_number: '1'
        }

        # Send the request
        response = RestClient.post(url, payload, headers)

        # Print the response
        body    = response.body
        body    = JSON.parse(body)
        puts    "=> #{__method__} : Status: #{body['status']}"

        # return
        body['status']
    end #<def>

    def completeUpload()
    #+++++++++++++++++
    #   3thd part => finalize upload
    #   INP:    ?
    #   OUT:    status

        file_upload_id  = @arr_fileinfos['id']
        url = URI("https://api.notion.com/v1/file_uploads/#{file_upload_id}/complete")

        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(url)
        request['Authorization']    = "Bearer #{NOTION_TOKEN}"
        request['Notion-Version']   = NOTION_API_VERSION
        request["accept"]           = 'application/json'

        response = http.request(request)

        # print the response
        body    = response.body
        body    = JSON.parse(body)
        puts    "Message: #{body['message']}"

        # return
        body['status']
    end #<def>

    def attachFile()
    #+++++++++++++
    #   attach the file to a new page in DB
    #   INP:    ?
    #   OUT:    ?
    #
        # build properties
        props = {}
        props['Reference'] = { 'title' => [{ 'text' => { 'content' => @arr_fileinfos['filename'] }} ] }
        props['Type'] = { 'select' => { 'name' => @arr_fileinfos['type'] } }
        props['Statut'] = { 'status' => { 'name' => "Enregistré" } }
        props['Tags'] = { 'multi_select' => [{ 'name' => "Upload" }] }
        props['FileName'] = { 'rich_text' => [{ 'text' => { 'content' => @arr_fileinfos['fullpath'] } }] }
        props['FileID'] = { 'rich_text' => [{ 'text' => { 'content' => @arr_fileinfos['id'] } }] }
        props['FileContent'] = { 'files' => [{ 'file_upload' => { 'id' => @arr_fileinfos['id'] }}] }
        props['FileSize'] = { 'number' => @arr_fileinfos['size']}

        payload = {
            'parent'      => { 'database_id' => ID_FILE_DB },
            'properties'  => props
        }

        # request
        response = HTTParty.post(
            "#{BASE_URL}/pages",
            headers: @headers,
            body: payload.to_json
        )

        # response
        if response.success?
            puts "=> #{__method__}  ✓ File attached"
            return  true
        else
            puts "=> #{__method__}  ✗ Error new page: #{response['message']}"
            return  false
        end
    end #<def>

    def addnewPage()
    #+++++++++++++
    #   create new page on <Dossier> with file
    #   INP:    @arr_fileinfos
    #           @arr_fields_req
    #   OUT:    ?
    #
        # get dossier & properties
        while   true
            break   ask_db                              #get properties values
        end

        # build properties
        props = {}
        props['Référence']      = { 'title' => [{ 'text' => { 'content' => @arr_fileinfos['filename'] }} ] }
    #    props['Niveau 1']       = { 'relation' => [{ 'id' => @arr_tags[@old_level1][0]} ] }
    #    props['Dossier']        = { 'relation' => [{ 'id' => @arr_tags[@old_level2][0]} ] }
        props['Tags']           = { 'relation' => [{ 'id' => @arr_tags[@old_level3][0]} ] }
    #    props['Type']           = { 'relation' => [{ 'id' => @arr_tags[@old_level4][0]} ] }
        props['Emetteur']       = { 'relation' => [{ 'id' => @arr_tags[@old_sender][0]} ] }
        props['Description']    = { 'rich_text' => [{ 'text' => { 'content' => @note } }] }
        props['Fichier']        = { 'files' => [{ 'file_upload' => { 'id' => @arr_fileinfos['id'] }}] }

        ### pp  props
    
        # make payload
        id_docs_db  = ID_DOCS_BVL   if @old_level1.include?('BVL')
        id_docs_db  = ID_DOCS_FIN   if @old_level1.include?('FIN')
        id_docs_db  = ID_DOCS_INF   if @old_level1.include?('INF')
        id_docs_db  = ID_DOCS_OFF   if @old_level1.include?('OFF')
        id_docs_db  = ID_DOCS_SAN   if @old_level1.include?('SAN')
        id_docs_db  = ID_DOCS_DOC   if @old_level1.include?('DOC')

        payload = {
            'parent'      => { 'data_source_id' => id_docs_db },
            'properties'  => props
        }

        # request
        response = HTTParty.post(
            "#{BASE_URL}/pages",
            headers: @headers,
            body: payload.to_json
        )

        # response
        if response.success?
            puts "=> #{__method__}  ✓ File attached & page added into <Dossier>"
            return  true
        else
            puts "=> #{__method__}  ✗ Error new page: #{response['message']}"
            return  false
        end
    end #<def>

    def add_new_action()
    #+++++++++++++++++
    #
        # build properties
        props = {}
        props['Titre'] = { 'title' => [{ 'text' => { 'content' => "New doc added to #{@old_area}-#{@old_object}" } } ] }
        props['Type'] = { 'select' => { 'name' => "Dossier" } }
        props['Statut'] = { 'status' => { 'name' => "A clarifier" } }
        props['Priorité'] = { 'select' => { 'name' => "Basse" } }
        props['Notes'] = { 'rich_text' => [{ 'text' => { 'content' => @arr_fileinfos['filename'] } }] }
            
        # make payload
        payload = {
            'parent'      => { 'database_id' => ID_ACTION_DB },
            'properties'  => props
        }
        # headers old version
        myheaders = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION_OLD,
            'Content-Type'      => 'application/json'
        }

        # request
        response = HTTParty.post(
            "#{BASE_URL}/pages",
            headers: myheaders,
            body: payload.to_json
        )

        # response
        if response.success?
            return  true
        else
            puts "=> #{__method__}  ✗ Error new page: #{response['message']}"
            return  false
        end
    end #<def>
    #
    #           Main function
    #           *************
    def run()
    #++++++
    #   sequence
    #   INP:    ?
    #   OUT:    ?
    #
        puts    "\n=== Get Parameters ==="
        getParameters()

        puts    "\n=== Get Common values ==="
        rc  = loadDossiers()
        rc  = loadTags()
        rec = loadTypes()

        puts    "\n=== Loop all files ==="
        loop        = 0
        initial_dir = '.'
        while   @arr_parameters['P2'] == 'L'
            puts    "\n=== Select file to upload ==="
            if loop == 0
                # create instance
                tkroot = TkRoot.new { title "Sélection d'un répertoire et ensuite le fichier" }

                # search directory
                puts "Initial directory: #{initial_dir} for loop: #{loop}"
                dir = Tk::chooseDirectory(initialdir: initial_dir)
            else
                dir = initial_dir
            end
            if dir && !dir.empty?   #<IF1>
                puts "Vous avez sélectionné le répertoire : #{dir}"
                initial_dir = dir

                # select file within the directory
                files = Dir.glob(File.join(dir, "*")).select { |f| File.file?(f) }
                if files.empty? #<IF2>
                    puts "Aucun fichier trouvé dans le répertoire sélectionné."
                    seledt_file = nil
                else    #<IF2>
                    puts "Fichiers disponibles :"
                    files.each_with_index do |file, index|  #<D3
                        puts "#{index + 1}. #{File.basename(file)}"
                    end #<D3>

                    print "Entrez le numéro du fichier à sélectionner : "
                    selection = STDIN.gets.to_i
                    if selection.between?(1, files.size)    #<IF3> 
                        selected_file = files[selection - 1]
                        puts "Vous avez sélectionné : #{selected_file}"
                    else    #
                        puts "Numéro invalide, sortie."
                        selected_file = nil
                    end #<IF3>
                end            
            else
                puts "Aucun répertoire sélectionné."
            end

            puts    "\n=== File selected ==="
            break   unless selected_file

            puts    "\n=== Check file type ==="
            exit    3   if checkFileType(selected_file) == false
            @tk_initdir = @arr_fileinfos['directory']
            puts ">>>DBG: Init_Dir: #{@tk_initdir}"

            puts    "\n=== Get File-Object ==="
            rc  = getFileObject()
            exit 5      if rc != 'pending'

            puts    "\n=== Send file upload ==="
            rc  = uploadFile()
            exit 7      if rc != 'uploaded'

            puts    "\n=== Complete upload ==="
            rc  = completeUpload()

            puts    "\n=== Attach to my DB-upload ==="
            rc  = attachFile()

            puts    "\n=== Create page on <Dossiers> with fileID ==="
            rc  = addnewPage()

            puts    "\n=== Create page on <Actions> ==="
            rc  = add_new_action()

            print   "=> Sequence done with status: #{rc}\n"
            loop    += 1
        end
        puts    "=> Loop done"
    end #<def>
#
end #<class>

#               Main Code
#               *********
#
if __FILE__ == $0
    puts    "\n*** PrvUpload_Dos starting... ***"

    puts    "\n=== Create new instance ==="
    inst    = UploadFileToNotion.new()
    inst.run

    puts    "\n*** PrvUpload_Dos done ***\n"
end