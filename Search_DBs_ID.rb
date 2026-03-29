#
#!/usr/bin/env ruby
require 'httparty'
require 'json'
require 'pp'
#

# Constants
NOTION_TOKEN            = 'secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3'
CONTAINER_DATABASE_ID   = ''
NOTION_API_VERSION      = '2025-09-03'
BASE_URL                = 'https://api.notion.com/v1'

# Variables
    @container_url       = ''
    @container_db_id     = ''
    @data_source_name    = ''
    @data_source_id      = ''   #
    @data_sources        = {}

# Function
    def Search_DBs_ID_get_DB_ID(p_container_url='', p_db_name='')
    #++++++++++++++++++++++++++
        # check parameters
        @container_url   = p_container_url
        return  @data_source_id  if @container_url.nil?
        @data_source_name    = p_db_name
        return  @data_source_id  if @data_source_name.nil?

        # make Container_ID
        if @container_url.size > 60
            @container_db_id = @container_url[29..60]
        else
            @container_db_id    = @container_url
        end

        # get all data-sources
        header = {
            'Authorization' => "Bearer #{NOTION_TOKEN}",
            'Notion-Version' => NOTION_API_VERSION,
            'accept' => 'application/json'
        }

        # Request
        response = HTTParty.get(
            "#{BASE_URL}/databases/#{@container_db_id}",
            headers: header
        )

        # Response
        ### pp  response
        if response.success?
            data_sources    = response['data_sources']
            ### pp  data_sources
            puts    ">>>Data-Sources list"
            data_sources.each do |source|
                puts    "   >>>DB:: Name: #{source['name']} - ID: #{source['id']}"
                if source['name'] == @data_source_name
                    @data_source_id  = source['id']
                end
            end
        else
            puts    "###Error:: #{response['status']} : #{response['code']} -> #{response['message']}"
        end

        return  @data_source_id
    end

    print   ">>>Please enter the Container URL => "
    @container_url   = $stdin.gets.chomp
    puts    ">>>Your container url is : #{@container_url}"

    print   ">>>Please enter the Data-Source name : "
    @data_source_name = $stdin.gets.chomp
    puts    ">>>Your Data-Source name is : #{@data_source_name}"

    @data_source_id  = Search_DBs_ID_get_DB_ID(@container_url, @data_source_name)
    puts    ">>>For #{@data_source_name} => Your Data-Source ID is : #{@data_source_id}"
