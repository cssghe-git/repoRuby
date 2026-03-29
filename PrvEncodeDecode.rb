=begin
    Script:     PrvEncodeDecode
    Function:   encode or decode plain text
    Call:       ruby PrvEncode.Decode.rb
    Build:      1.1.0   <251212-1500>
=end

require 'clipboard'
require 'base64'
require 'openssl'
require 'httparty'
require 'json'

# Contants
#*********
NOTION_TOKEN            = 'secret_FIhPnoyaCFBlTWzD1Y4BBRbzEx7chTck1HkAm14uBd3'
NOTION_API_VERSION      = '2025-09-03'
BASE_URL                = 'https://api.notion.com/v1'

ID_FILE_DB              = '2c172117-082a-807a-a442-000be661990c'

# Functions
#**********
    def getCredentials(pageref='')
    #+++++++++++++++++
    #   INP:    Reference to get
    #   OUT:    all pages after query
    #
        @headers = {
            'Authorization'     => "Bearer #{NOTION_TOKEN}",
            'Notion-Version'    => NOTION_API_VERSION,
            'Content-Type'      => 'application/json'
        }
        query = {
            filter: {
                "property"=>"Référence", "title"=>{ "equals"=> pageref }
            },
            sorts: [{ property: 'Référence', direction: 'ascending' }]
        }
        all_pages       = []
        has_more        = true
        start_cursor    = nil
        
        while has_more
            query[:start_cursor] = start_cursor if start_cursor

            response = HTTParty.post(
            "#{BASE_URL}/data_sources/#{ID_FILE_DB}/query",
            headers: @headers,
            body: query.to_json
            )

            unless response.success?
                puts "Erreur query: #{response['message']}"
                break
            end

            all_pages.concat(response['results'])
            has_more = response['has_more']
            start_cursor = response['next_cursor']
        end

        return  all_pages
    end #<def>

# Main
#*****
    puts    "Functions =>"
    puts    "-- c: encode from clipboard"
    puts    "-- d: decode from clipboard"
    puts    "-- e: encode from input"
    puts    "-- o: crypto from clipboard"
    puts    "-- s: decrypto from clipboard"
    print   "What do you do ? "
    reply   = $stdin.gets.chomp.to_s.downcase
    case    reply
    when    'c'     #encode from clipboard
        # Get text to secure from clipboard
        value   = Clipboard.paste
        # Transform into Base64
        encode  = Base64.encode64(value)
        # Save on clipboard
        Clipboard.copy(encode)
        puts    "Script done"

    when    'd'     #décode from clipboard
        value   = Clipboard.paste
        decode  = Base64.decode64(value)
        # Save on clipboard
        Clipboard.copy(decode)
        puts    "Result: #{value} => #{decode}"

    when    'e'     #encode from input
        print   '\nEnter the value : '
        value   = $stdin.gets.chomp.strip
        exit    9   if value.empty?
        # Save on clipboard
        encode  = Base64.encode64(value)
        Clipboard.copy(encode)
        puts    "Script done"

    when    'o'     #crypto from clipboard
        # Get keys fron Security
        page    =    getCredentials("OpenSSL_Key")
        key64       = page.dig(0, 'properties', 'Description', 'rich_text', 0, 'text', 'content')
        key         = Base64.decode64(key64)

        page    =    getCredentials("OpenSSL_IV")
        iv64        = page.dig(0, 'properties', 'Description', 'rich_text', 0, 'text', 'content')
        iv          = Base64.decode64(iv64)

        # Get text to Crypto from clipboard
        plaintext = Clipboard.paste

        # Crypto
        cipher = OpenSSL::Cipher.new('AES-256-CBC')
        cipher.encrypt
        cipher.key = key
        cipher.iv = iv
        encrypted = cipher.update(plaintext) + cipher.final
o
        # Transfrm into Base64
        encrypted_base64 = Base64.encode64(encrypted)

        # Save on clipboard
        Clipboard.copy(encrypted_base64)
        puts    "Script done"

    when    's'     #decrypto from clipboard
        # Get keys from Security
        page    =    getCredentials("OpenSSL_Key")
        key64       = page.dig(0, 'properties', 'Description', 'rich_text', 0, 'text', 'content')
        key         = Base64.decode64(key64)

        page    =    getCredentials("OpenSSL_IV")
        iv64        = page.dig(0, 'properties', 'Description', 'rich_text', 0, 'text', 'content')
        iv          = Base64.decode64(iv64)

        # Get text to decrypto from Clipboard
        encrypted_base64    = Clipboard.paste

        # DeCrypto
        decoded         = Base64.decode64(encrypted_base64)
        decipher        = OpenSSL::Cipher.new('AES-256-CBC')
        decipher.decrypt
        decipher.key    = key
        decipher.iv     = iv
        decrypted       = decipher.update(decoded) + decipher.final

        # Save on clipboard
        Clipboard.copy(decrypted)
        puts "Result : #{decrypted}"
    else
        puts    "I am away"
    end