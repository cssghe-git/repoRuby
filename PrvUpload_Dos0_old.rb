=begin
#   Program:    PrvUploadToNotion Dossiers
#   Parameters: P1 => debug => Y or N
#               P2 => Loop => L or null
#               P3 => nil
#               P4 => file from finder or F to select
#
#   Function:   upload 1 file to Notion.DB & attach to 'Dossier'
#   Build:      0.0.2   <251026-0907>
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
                        # secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3
CONTAINER_DATABASE_ID   = ''
NOTION_API_VERSION      = '2025-09-03'
NOTION_API_VERSION_OLD  = '2022-06-28'
BASE_URL                = 'https://api.notion.com/v1'

ID_FILE_DB              = '20172117082a809784efeb6f051f8e0c'    #upload
ID_ACTION_DB            = '32972117082a80308f29fdce26746200'    #Action utilisateurs 

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
        @container_db_id    = CONTAINER_DATABASE_ID
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

    def getTypeTag()
    #+++++++++++++
    #   INP:    ?
    #   OUT:    ?
    #
        # Settings
        myheaders = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION_OLD,
            'Content-Type'      => 'application/json'
        }
        id_aidt_common  = '2cd72117082a8017a72bfb196354b23a'    #https://www.notion.so/cssghe/2cd72117082a8017a72bfb196354b23a?v=2cd72117082a8051b85a000c64b9bea8&source=copy_link
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
                "#{BASE_URL}/databases/#{id_aidt_common}/query",
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
        @arr_emetteurs  = {}
        @arr_tags       = {}
        @arr_types      = {}
        all_pages.each do |page|    #<L1>
            page_id = page['id']
            page['properties'].each do |key, value| #<L2>
                case value['type']  #<L3>
                when    'title'
                    nom         = value['title']&.first&.dig('text', 'content')
                end #<L3>
                @arr_tags[nom]  = page_id
            end #<L2>
        end #<L1>
    end #<def>

    def getTagType(id)
    #+++++++++++++
    #   INP:    ?
    #   OUT:    ?
    #
        myheaders = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION_OLD,
            'Content-Type'      => 'application/json'
        }
        response = HTTParty.get(
            "#{BASE_URL}/pages/#{id}",
            headers: myheaders
        )
        unless response.success?    #<IF1>
            puts "=> #{__method__} : Erreur query: #{response['message']}"
            pp  response
            exit 7
        end #<IF1>

        results = response['results']
        props   = results['properties']
        type    = props['Type'].dig('select', 'name')
        return  type
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
        return
    end #<def>

    def ask_db()
    #+++++++++
    #   get dossier id & fields
    #   INP:    ?
    #   OUT:    @dossier_id
    #           @arr_fields_req
    #
        # all choices
        @obj_choices    = {
            'BVL'=> {
                'TEXT'=>    ['CCCA', 'ENBW', 'ENIV', 'LST', 'CYB', 'DOC'],
                'CCCA'=>    {'ID'=> '2c172117-082a-806e-928b-000b0e5068f9',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'ENBW'=>    {'ID'=> '2c172117-082a-80a1-a4ca-000baa9795f0',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'ENIV'=>    {'ID'=> '2c172117-082a-80e0-b99a-000b6e36f6c2',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'LST'=>     {'ID'=> '2c172117-082a-80e0-b99a-000b6e36f6c2',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'CYB'=>     {'ID'=> '2c172117-082a-80f4-ab46-000b74090847',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)}},
                'DOC'=>     {'ID'=>  '2c372117-082a-8033-b77a-000b4e5b6fb6',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'select'=> %w(Type Emetteur),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            }
            },
            'SAN'=> {
                'TEXT'=>    ['COL','GIL','DOC'],
                'COL'=>     {'ID'=> '2c172117-082a-80ee-af9d-000b81773e80',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'select'=> %w(Type Emetteur),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'GIL'=>     {'ID'=> '2c172117-082a-80de-8861-000b0bf22f81',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'select'=> %w(Type Emetteur),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'DOC'=>     {'ID'=> '2c372117-082a-8020-bd2a-000b4ec7a18b',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'select'=> %w(Type Emetteur),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            }
            },
            'INF'=> {
                'TEXT'=>    ['SEC','DOC'],
                'SEC'=>     {'ID'=> '2c172117-082a-807a-a442-000be661990c',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'DOC'=>     {'ID'=> '2c172117-082a-808d-8936-000b3ad03c19',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'select'=> %w(Type Emetteur),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            }
            },
            'OFF'=> {
                'TEXT'=>    ['ONP','SPF','DOC'],
                'ONP'=>     {'ID'=> '2c172117-082a-800b-981b-000b687b592d',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'SPF'=>     {'ID'=> '2c172117-082a-80b9-9f21-000bbcc8804d',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'DOC'=>     {'ID'=>  '2c372117-082a-805a-9cca-000b6c71d553',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'select'=> %w(Type Emetteur),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            }
            },
            'FIN'=> {
                'TEXT'=>    ['CBC','KEY','SAN','DOC'],
                'CBC'=>     {'ID'=> '2c172117-082a-802b-b70e-000b7e80a023',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'KEY'=>     {'ID'=> '2c172117-082a-80fe-a624-000bb41cfbe4',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'SAN'=>     {'ID'=> '2c172117-082a-80a0-aca9-000bcee0ce32',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                    #    'multi_select'=> %w(Tags),
                                        'fichier'=> %w(Fichier)
                                    }
                            },
                'DOC'=>     {'ID'=> '2c272117-082a-80ea-a31a-000b9f58c855',
                            'FLD'=> {'title'=> %w(Référence),
                                        'text'=> %w(Description),
                                        'relation'=> %w(Type Emetteur),
                                        'fichier'=> %w(Fichier)
                                    }
                            }
            }
        }
        # Get Area
        print   "Enter the Area [#{@old_area}] => "
        @obj_choices.each do |key, val|
            print   key
            print   '/'
        end
            print   "\n"
        area        = ask("Your choice : ","#{@old_area}").upcase
        @old_area   = area

        # Get Object
        print   "Enter the object for #{area} [#{@old_object}] => "
        array   = @obj_choices[area]['TEXT']
        array.each do |key, val|
            print   key
            print   '/'
        end
        print   "\n"

        # set values
        object          = ask("Your choice : ","#{@old_object}").upcase
        @old_object     = object
        @dossier_id     = @obj_choices[area][object]['ID']
        @arr_fields_req = @obj_choices[area][object]['FLD']
        puts    "=> For Object: #{object}"
        puts    "=> DOSID: #{@dossier_id}"
        puts    "=> FIELDS: #{@arr_fields_req}"
    end #<def>


    def ask(prompt, default = nil)
        print default ? "#{prompt} [#{default}]: " : "#{prompt}: "
        v = STDIN.gets&.strip
        (v.nil? || v.empty?) ? default : v
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
        rc  = ask_db()                              #request DB & Object & fields

        # build properties
        props = {}
        keys    = @arr_tags.keys
        puts    "\n=> Tags=> #{keys}"
        @arr_fields_req.each do |type, names|
            names.each do |name|
                next    unless name != 'Tags'
                
                val = ask("Type: #{type} & Name: #{name} => Value ? ","Upload")
                # force if default
                if val == 'Upload' and name == 'Référence'
                    val = @arr_fileinfos['filename']
                end
                # format for API
                case    type
                when    'title'
                    props[name] = { 'title' => [{ 'text' => { 'content' => @arr_fileinfos['filename'] }} ] }
                when    'text'
                    props[name] = { 'rich_text' => [{ 'text' => { 'content' => val } }] }
                when    'multi_select'
                    props[name] = { 'multi_select' => [ {'name' => val } ] }
                when    'fichier'
                    props[name] = { 'files' => [{ 'file_upload' => { 'id' => @arr_fileinfos['id'] }}] }
                when    'select'
                    props[name] = { 'select' => { 'name' => val } }
                when    'relation'
                    props[name] = { 'relation' => [{ 'id' => @arr_tags[val]}]}
                end
            end
        end

        ### pp  props
    
        # make payload
        payload = {
            'parent'      => { 'data_source_id' => @dossier_id },
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
    #
    def run()
    #++++++
    #   sequence
    #   INP:    ?
    #   OUT:    ?
    #
        puts    "\n=== Get Parameters ==="
        getParameters()

        puts    "\n=== Get Common values ==="
        rc  = getTypeTag()

        puts    "\n=== Loop all files ==="
        while   @arr_parameters['P2'] == 'L'
            puts    "\n=== Select file to upload ==="
            file_select = SelectFile.TK_Use(initial_dir: @tk_init_dir)
            puts    "\n=== File selected ==="
            break   unless file_select
            puts    "#{file_select}"
            @tk_initdir = @arr_fileinfos['directory']

            puts    "\n=== Check file type ==="
            exit    3   if checkFileType(file_select) == false

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
        end
        puts    "=> Loop done"
    end #<def>
#
end #<class>

if __FILE__ == $0
    puts    "\n*** PrvUpload_Dos starting... ***"

    puts    "\n=== Create new instance ==="
    inst    = UploadFileToNotion.new()
    inst.run

    puts    "\n*** PrvUpload_Dos done ***\n"
end