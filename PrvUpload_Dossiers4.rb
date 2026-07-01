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

begin
  require "dotenv"; Dotenv.load
rescue LoadError
end

begin
  require "cli/ui"
  CLI::UI::StdoutRouter.enable
  CLI::UI::Frame.divider('═')
rescue LoadError
end

NOTION_TOKEN            = ENV.fetch("NOT_APITOKEN")
NOTION_API_VERSION      = ENV.fetch("NOT_APIVER")
NOTION_API_VERSION_OLD  = ENV.fetch("NOT_APIVER_OLD")
NOTION_BASE_URL         = ENV.fetch("NOT_HTTPBASE")

CONFIG                  = JSON.parse(File.read(File.join(__dir__, "Data_Sources_ID2.json")))

ID_FILE_DB              = CONFIG.find{ |k| k.key?("FilesUpload")}&.fetch("FilesUpload") #FilesUpload
ID_DOSS_DB              = CONFIG.find{ |k| k.key?("Dossiers")}&.fetch("Dossiers") #
ID_TAGS_DB              = CONFIG.find{ |k| k.key?("Tags")}&.fetch("Tags") #
ID_TYPE_DB              = CONFIG.find{ |k| k.key?("Types")}&.fetch("Types") #
ID_EMETTEUR_DB          = CONFIG.find{ |k| k.key?("Senders")}&.fetch("Senders") #

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
        @domain, @dossier, @tag, @type, @emetteur  = 'None'
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

    def ui_step(title)
      if defined?(CLI::UI)
        CLI::UI::Frame.open(title) { yield }
      else
        puts "==== #{title} ===="
        yield
      end
    end

    def ui_info(message)
      if defined?(CLI::UI)
        CLI::UI::fmt("{{info}}#{message}{{/info}}")
      else
        message
      end
    end

    def ui_ok(message)
      if defined?(CLI::UI)
        CLI::UI::fmt("{{green:✓}} #{message}")
      else
        message
      end
    end

    def ui_spin(title)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = nil
      if defined?(CLI::UI)
        CLI::UI::Spinner.spin(title) do
          result = yield
        end
      else
        puts "#{title}..."
        result = yield
      end
      elapsed_sec = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(2)
      puts ui_ok("#{title} terminé en #{elapsed_sec}s")
      result
    end

    def loadDomaines()
    #+++++++++++++++
    ui_step("Load <Domaines> values") do
        puts ui_info("Load start")
        @arr_domaines = {
            'BVL'   => 'BVL',
            'FIN'   => 'FIN',
            'INF'   => 'INF',
            'OFF'   => 'OFF',
            'SAN'   => 'SAN',
            'DOC'   => 'DOC',
            'RES'   => 'RES',
            'TBD'   => 'TBD'
        }
        rc = ui_ok("Load done"){puts "Domaines=>#{@arr_domaines.size}"}
    end
    end #<def>

    def loadDossiers()
    #+++++++++++++++
    #   INP:    ?
    #   OUT:    ?
    #
    ui_step("Load <Dossiers> values") do
        puts ui_info("Settings")
        # Settings
        myheaders = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION,
            'Content-Type'      => 'application/json'
        }
        query = {
        #    filter: {},
            sorts: [{ property: 'Référence', direction: 'ascending' }]
        }
        all_pages       = []
        has_more        = true
        start_cursor    = nil

        puts ui_info("Load start")
        # Read all pages
        while has_more  #<L1>
            query[:start_cursor] = start_cursor if start_cursor

            response = HTTParty.post(
                "#{NOTION_BASE_URL}/data_sources/#{ID_DOSS_DB}/query",
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
            value               = properties['Référence']
            nom                 = value["title"].map { _1["plain_text"] }.join
           @arr_dossiers[nom]   = page_id
        end #<L1>
        rc = ui_ok("Load done"){puts "Dossiers=>#{@arr_dossiers.size}"}
    end
    end #<def>

    def loadTags()
    #+++++++++++
    #   INP:    ?
    #   OUT:    ?
    #
    ui_step("Load <Tags> values") do
        puts ui_info("Settings")
        # Settings
        myheaders = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION,
            'Content-Type'      => 'application/json'
        }
        query = {
        #    filter: {},
            sorts: [{ property: 'Référence', direction: 'ascending' }]
        }
        all_pages       = []
        has_more        = true
        start_cursor    = nil

        puts ui_info("Load start")
        # Read all pages
        while has_more  #<L1>
            query[:start_cursor] = start_cursor if start_cursor

            response = HTTParty.post(
                "#{NOTION_BASE_URL}/data_sources/#{ID_TAGS_DB}/query",
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
        all_pages.each do |page|    #<L1>
            page_id     = page['id']
            properties  = page['properties']
            value       = properties['Référence']
            nom         = value["title"].map { _1["plain_text"] }.join
            @arr_tags[nom]  = page_id
        end #<L1>
        rc = ui_ok("Load done"){puts "Tags=>#{@arr_tags.size}"}
    end
    end #<def>

    def loadTypes()
    #++++++++++++
    #   INP:    ?
    #   OUT:    ?
    #
    ui_step("Load <Types> values") do
        puts ui_info("Settings")
        # Settings
        myheaders = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION,
            'Content-Type'      => 'application/json'
        }
        query = {
        #    filter: {},
            sorts: [{ property: 'Référence', direction: 'ascending' }]
        }
        all_pages       = []
        has_more        = true
        start_cursor    = nil

        puts ui_info("Load start")
        # Read all pages
        while has_more  #<L1>
            query[:start_cursor] = start_cursor if start_cursor

            response = HTTParty.post(
                "#{NOTION_BASE_URL}/data_sources/#{ID_TYPE_DB}/query",
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
            value           = properties['Référence']
            nom             = value["title"].map { _1["plain_text"] }.join
           @arr_types[nom]  = page_id
        end #<L1>
        rc = ui_ok("Load done"){puts "Types=>#{@arr_types.size}"}
    end
    end #<def>

    def loadEmetteurs()
    #++++++++++++++++
    #   INP:    ?
    #   OUT:    ?
    #
    ui_step("Load <Emetteurs> values") do
        puts ui_info("Settings")
        # Settings
        myheaders = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION,
            'Content-Type'      => 'application/json'
        }
        query = {
        #    filter: {},
            sorts: [{ property: 'Référence', direction: 'ascending' }]
        }
        all_pages       = []
        has_more        = true
        start_cursor    = nil

        puts ui_info("Load start")
        # Read all pages
        while has_more  #<L1>
            query[:start_cursor] = start_cursor if start_cursor

            response = HTTParty.post(
                "#{NOTION_BASE_URL}/data_sources/#{ID_EMETTEUR_DB}/query",
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
        @arr_emetteurs = {}
        all_pages.each do |page|    #<L1>
            page_id             = page['id']
            properties          = page['properties']
            value               = properties['Référence']
            nom                 = value["title"].map { _1["plain_text"] }.join
            @arr_emetteurs[nom] = page_id
        end #<L1>
        rc = ui_ok("Load done"){puts "Emetteurs=>#{@arr_emetteurs.size}"}
    end
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
    ui_step("Check File") do
        puts ui_info("Settings")
        # extract file infos
        #-1- set directory
        @arr_fileinfos['directory'] = File.dirname(file_select)
        @arr_fileinfos['directory'] = Dir.pwd() if @arr_parameters['file'] == 'F'
        Dir.chdir(@arr_fileinfos['directory'])

        puts ui_info("Define")
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

        puts ui_info("Checks")
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
        file_tags               = "upload, #{file_type}"             #default tags
        @arr_fileinfos['tags']  = file_tags.split(',').map(&:strip) #split tags by comma and remove spaces

        # return
        return  true
        puts ui_ok("Check done")
    end
    end #<def>

    def ask_db()
    #+++++++++
    #   get dossier id & fields
    #   INP:    ?
    #   OUT:    @dossier_id
    #           @arr_fields_req
    #
    ui_step("Load <Get D D T T E") do
        puts ui_info("Settings")
        # all choices
        # Display Tags
        b   = "\e[1m"
        r   = "\e[0m"

        puts ui_info("Domaine")
        # Get Level1/Domaine
        while   true
            puts    "\n#{b}DOMAINE::#{r} #{@arr_domaines.keys}"
            print   "For the DB.Doc - #{b}Capitalize#{r} [#{@domaine}]=> "
            domaine  = ask(default: "#{@domaine}", form: 'up')
            return  false   unless domaine != 'Q'
            @domaine = domaine
            @arr_domaines.include?(domaine) ? break : @domaine = "TBD"
        end 

        puts ui_info("Dossier")
        # Get Level2/Dossier from Dossiers
        while   true
            puts    "\n#{b}DOSSIER::#{r} #{@arr_dossiers.keys}"
            print   "Enter the Object -#{b}Capitaize#{r} [#{@dossier}] => "
            dossier = ask(default: "#{@dossier}", form: 'cap')
            return  false   unless dossier != 'Q'
            @dossier = dossier
            @arr_dossiers.key?(dossier) ? break : @dossier = "Tbd"
        end

        puts ui_info("Tag")
        # Get Level3/Tags from Tags
        while   true
            puts    "\n#{b}TAG::#{r} #{@arr_tags.keys}"
            print   "Enter the Tag -#{b}Capitalize#{r} [#{@tag}] => "
            tag  = ask(default: "#{@tag}", form: 'nil')
            return  false   unless tag != 'Q'
            @tag = tag
            @arr_tags.include?(tag) ? break : @tag = "Tbd"
        end

        puts ui_info("Type")
        # Get Level4/Type from Types
        while   true
            puts    "\n#{b}TYPE::#{r} #{@arr_types.keys}"
            print   "Enter the Type -#{b}Capitalize#{r} [#{@Types}] => "
            type    = ask(default: "#{@types}", form: 'cap')
            return  false   unless type != 'Q'
            @types = type
            @arr_types.key?(type) ? break : @types = "Tbd"
        end

        puts ui_info("Emetteur")
        # Get Emetteurs
        while   true
            puts    "\n#{b}EMETTEUR::#{r} #{@arr_emetteurs.keys}"
            print   "Enter the #{b}Sender#{r}-#{b}NoForm#{r} [#{@emetteur}] => "
            sender  = ask(default: "#{@emetteur}", form: 'nil')
            return  false   unless sender != 'Q'
            @emetteur = sender
            @arr_emetteurs.has_key?(sender) ? break : @emetteur = "Tbd"
        end

        puts ui_info("Note")
        # Get Note
        print   "Enter the Note (if any) => "
        @note   = $stdin.gets.chomp.to_s

        puts ui_ok("Load done")
        return  true
    end
    end #<def>


    def ask(default: nil, form: nil)
        print   "Enter your choice [#{default}] with Format #{form} : "
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
    
    ui_step("Load File-Step 1") do
        puts ui_info("Settings")
        url = URI("https://api.notion.com/v1/file_uploads")

        http            = Net::HTTP.new(url.host, url.port)
        http.use_ssl    = true

        request                     = Net::HTTP::Post.new(url)
        request['Authorization']    = "Bearer #{NOTION_TOKEN}"
        request['Notion-Version']   = NOTION_API_VERSION
        request["accept"]           = 'application/json'
        request["content-type"]     = 'application/json'
        request.body                = "{\"mode\":\"single_part\"}"

        puts ui_info("Send request")
        response    = http.request(request)
        body        = response.read_body
        body        = JSON.parse(body)
        puts    "=> ID: #{body['id']}"
        puts    "=> Status: #{body['status']}"

        @arr_fileinfos['id']    = body['id']

        # Return
        rc = ui_ok("Step done") {puts "#{body['status']}"}
        body['status']
    end
    end #<def>

    def uploadFile()
    #+++++++++++++
    #   upload multi-part file
    #   INP:    @arr_fileinfos
    #   OUT:    status
    #
    ui_step("Load File-Step 2") do
        puts ui_info("Settings")
        @arr_fileinfos['part']  = (@arr_fileinfos['size']/@max_size).ceil
        
        puts ui_info("Send request")
        rc  = sendFileUpload()
        exit 7      if rc != 'uploaded'

        puts ui_info("Send request")
        rc  = completeUpload()

        puts ui_ok("Load done")
        return
    end
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
    #   attach the file to a new page in DB-Upload
    #   INP:    ?
    #   OUT:    ?
    #
    ui_step("Attach file to new page") do
        puts ui_info("Settings")
        # get dossier & properties
        while   true
            break   ask_db                              #get properties values
        end

        # build properties
        props = {}
        props['Référence']      = { 'title' => [{ 'text' => { 'content' => @arr_fileinfos['filename'] }} ] }
        props['Type1']          = { 'select' => { 'name' => @arr_fileinfos['type'] } }
        props['Statut']         = { 'status' => { 'name' => "Enregistré" } }
        props['Tags1']          = { 'multi_select' => [{ 'name' => "Upload" }] }
        props['FileName']       = { 'rich_text' => [{ 'text' => { 'content' => @arr_fileinfos['fullpath'] } }] }
        props['FileID']         = { 'rich_text' => [{ 'text' => { 'content' => @arr_fileinfos['id'] } }] }
        props['FileContent']    = { 'files' => [{ 'file_upload' => { 'id' => @arr_fileinfos['id'] }}] }
        props['FileSize']       = { 'number' => @arr_fileinfos['size']}
        props['Domaine']        = { 'select' => { 'name' => @arr_domaines[@domaine] } }
        props['Dossier']        = { 'relation' => [{ 'id' => @arr_dossiers[@dossier] } ] }
        props['Tags']           = { 'relation' => [{ 'id' => @arr_tags[@tag] } ] }
        props['Type']           = { 'relation' => [{ 'id' => @arr_types[@types] } ] }
        props['Emetteur']       = { 'relation' => [{ 'id' => @arr_emetteurs[@emetteur] } ] }
        props['Notes']          = { 'rich_text' => [{'text' => { 'content' => @note }}]}

        myheaders = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION_OLD,
            'Content-Type'      => 'application/json'
        }

        payload = {
            'parent'      => { 'database_id' => ID_FILE_DB },
            'properties'  => props
        }

        puts ui_info("Request")
        # request
        response = HTTParty.post(
            "#{NOTION_BASE_URL}/pages",
            headers: myheaders,
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
        puts ui_ok("Attach done")
    end
    end #<def>

    def addnewPage()
    #+++++++++++++
    #   create new page on <FilesUpload> with file
    #   INP:    @arr_fileinfos
    #           @arr_fields_req
    #   OUT:    ?
    #
    #
        return
    #
    end #<def>

    def add_new_action()
    #+++++++++++++++++
    #
        return

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
    ui_step("=== Run script ===") do
        puts ui_info("Settings")
        ui_spin("=== Get Parameters ==="){getParameters()}

        puts ui_info("=== Get Fields ===")
        ui_spin("=Get Domaines="){loadDomaines()}
        ui_spin("=Get Dossiers="){loadDossiers()}
        ui_spin("=Get Tags="){loadTags()}
        ui_spin("=Get Types="){loadTypes()}
        ui_spin("=Get Emetteurs="){loadEmetteurs()}

        puts    "\n=== Loop all files ==="
        loop        = 0
        initial_dir = '.'
        while   @arr_parameters['P2'] == 'L'
            loop    += 1
            puts ui_info("=Loop:#{loop}=Select file to upload==")
            if loop == 1
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

            puts    "\n=== Get File-Object ==="
            rc  = getFileObject()
            exit 5      if rc != 'pending'

            puts    "\n=== Send file upload ==="
            ui_spin("Send file upload"){uploadFile()}

            puts    "\n=== Attach to my DB-upload ==="
            ui_spin("Attach file to table"){attachFile()}

            print   "=> Sequence done with status: #{rc}\n"
        end
        puts ui_ok("Run done")
    end
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