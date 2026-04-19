#
#   Program:    PrcUploadToNotion
#   Parameters: P1 => debug => Y or N
#               P2 => nil
#               P3 => nil
#               P4 => file from finder or F to select
#
#   Function:   upload 1 file to Notion.DB
#   Build:      0.0.1   <251026-0907>
#
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

class   UploadFileToNotion
#*************************
#
NOTION_TOKEN            = 'secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3'
CONTAINER_DATABASE_ID   = ''
NOTION_API_VERSION      = '2025-09-03'
BASE_URL                = 'https://api.notion.com/v1'

ID_FILE_DB              = '20172117082a809784efeb6f051f8e0c'    #https://www.notion.so/cssghe/20172117082a809784efeb6f051f8e0c?v=20472117082a806eb8b2000c628584ea&source=copy_link

    def initialize()
    #+++++++++++++
    #   create new instance
    #   INP:    ?
    #   OU:     instance
    #
        @token              = NOTION_TOKEN
        @container_db_id    = CONTAINER_DATABASE_ID
        @file_db_id         = ID_FILE_DB

        @headers = {
            'Authorization'     => "Bearer #{@token}",
            'Notion-Version'    => NOTION_API_VERSION,
            'Content-Type'      => 'application/json'
        }
        # internal values
        @max_size       = 10000
        @type_include   = ['txt', 'pdf', 'json', 'csv']
    end #<def>

    def getParameters()
    #++++++++++++++++
    #   get parameters
    #   INP:    ARGV
    #   OUT:    @arr_parameters => {debug=> ?, P2=> ?, P3=> ?, file=> ?}
    #
        @arr_parameters = {}
        @arr_parameters['debug']    = ARGV[0]
        @arr_parameters['P2']       = ARGV[1]
        @arr_parameters['P3']       = ARGV[2]
        @arr_parameters['file']     = ARGV[3]

        @arr_parameters
    end #<def>

    def selectFile()
    #+++++++++++++
    #   select 1 file from list
    #   INP:    ?
    #   OUT:    ?
    #
        file_select = @arr_parameters['file']
        return  file_select     if file_select != 'F'

        allfiles    = Dir.glob("*.*")
        allfiles.each_with_index do |file,index|    #<L1>
            puts    "#{index+1}.#{file}"
        end #<L1>
        print   "Please select file to process by N° => "
        fileindex       = $stdin.gets.chomp.to_i
        exit    9       if fileindex == 0
        file_select     = allfiles[fileindex-1]
        puts    "File selected: #{file_select}"

        file_select
    end #<def>

    def checkFileType(file_select)
    #++++++++++++++++
    #   types available only
    #   INP:    file_select
    #   OUT:    arr_fileinfos   => {code=> ?, filename=> ?, size=> ?, type=> ?, data=> ?, content=> ?}
    #
        @arr_fileinfos  = {}
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
        @arr_fileinfos['fullpath']  = "#{@arr_fileinfos['directory']}/#{@arr_fileinfos['filename']}"

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
        puts    "ID: #{body['id']}"
        puts    "Status: #{body['status']}"

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
        file = File.new(file_name, 'rb')
        file_content_type = MIME::Types.type_for(file_name).first.content_type

        # Prepare headers
        headers = {
            'Authorization'   => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'  => '2022-06-28'
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
        puts    "Status: #{body['status']}"

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
            puts "  ✓ File attached"
            return  true
        else
            puts "  ✗ Error new page: #{response['message']}"
            return  false
        end
    end #<def>
    #
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

        puts    "\n=== Select file to upload ==="
        file_select = selectFile()

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

        puts    "\n=== Attach to my DB ==="
        rc  = attachFile()

        print   "Sequence done with status: #{rc}"
    end #<def>
#
end #<class>

if __FILE__ == $0
    puts    "\n*** PrvUploadToNotion starting... ***"
    puts    "\n=== Create new instance ==="
    inst    = UploadFileToNotion.new()
    inst.run
end