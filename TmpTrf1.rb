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

require_relative 'ClStandards'
#
FROM_ID     = '8b7efb46fde248d19d7219b201b257b3'    #https://www.notion.so/cssghe/8b7efb46fde248d19d7219b201b257b3?v=ad7b94f2177e465c80e93a5fc7dec103&source=copy_link
TO_ID       = '33172117-082a-802c-b4aa-000b97e72313'
TAGS_ID     = '32a72117082a80ea8dabf4523ddbe769'    #https://www.notion.so/cssghe/32a72117082a80ea8dabf4523ddbe769?v=32a72117082a815c9da8000cad0dadff&source=copy_link
#
NOTION_TOKEN            = 'secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3'
NOTION_API_VERSION      = '2025-09-03'
NOTION_API_VERSION_OLD  = '2022-06-28'
BASE_URL                = 'https://api.notion.com/v1'
#
    std_inp = Standards.new([],'Old')
    std_out = Standards.new([],'New')
    #
    #
    # Load tags
    puts    "Load tags"
    all_tags    = std_inp.db_fetch(TAGS_ID)
    arr_tags       = {}
    all_tags.each do |page|    #<L1>
        page_id     = page['id']
        properties  = page['properties']
        value       = properties['Référence']
        nom         = value["title"].map { _1["plain_text"] }.join
        arr_tags[nom]  = page_id
    end #<L1>

    # Load all input data
    puts    "load input"
    sorts   = [{ property: 'Titre', direction: 'ascending' }]
    pages_inp   = std_inp.db_fetch(FROM_ID, sort: sorts)
    puts    "INP:: #{pages_inp.size} pages"
    
    # Loop input data
    puts    "Loop input"
    count   = 0
    pages_inp.each do |page|
        ### puts    "\nPAGE::"
        ### pp page
        # Load properties
        properties  = std_inp.get_properties(page)
        ### puts    "PROPERTIES::"
        ### pp properties
        # Do new fields
        reference       = properties['Titre']
        fichier1        = properties['Files']
        fichier2        = properties['Fichier(s)']
        description     = properties['Texte'].to_s + "#" +
                          "K:#{properties['Clé'].to_s}" + "#" +
                          "E:#{properties['Email'].to_s}" + "#" +
                          "I:#{properties['Ident'].to_s}" + "#" +
                          "I:#{properties['Identifiant'].to_s}" + "#" +
                          "P:#{properties['Mot_de_Passe'].to_s}" + "#" +
                          "U:#{properties['URL'].to_s}" + "#" +
                          "F:#{fichier1} \ #{fichier2}"
        puts    "REF:: #{reference} -> #{fichier1} \ #{fichier2}"

        # create new page
        props   = {}
        props['Référence']      = std_out.title(reference)
        props['Description']    = std_out.text(description)
    ###    props['Fichier']        = std_out.file_int(fichier)     unless fichier.size == 0

        response    = std_out.page_create(TO_ID, props)
        ### puts   "\nRESPONSE::" 
        ### pp response
        count   += 1
        exit 9  unless count < 999
    end
    puts    "End"