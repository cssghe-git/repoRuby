#
=begin

=end

    module  HelpApplic
#   ******************
#
# Variables
#**********        

# Functions
#**********
    def self.displayApplic(prv_dir: nil, mbr_dir: nil)
    #+++++++++++++++++++++++++++
    #   Display applications
    #
        bold = "\e[1m"
        reset = "\e[0m"
        @arrfunctions    = {                                #all programs to run
            #key=>[Display, Directory, Name, Prms, Temp]
        #    '010' => ["*","**","***","****","*****"],
            '01'  => ["#---------#{bold}=>Private<= ▼#{reset}---------#","*","*","*","*"],
            '10'  => ["#{bold}PRV=>#{reset}PrvCvrtCsvFile_Iso-Utf8",    "#{prv_dir}", "PrvCvrtCsvFile_Iso-Utf8","N"],
            '11'  => ["#{bold}PRV=>#{reset}PrvCvrtCsvFileComma",        "#{prv_dir}", "/PrvCvrtCsvFileComma","N"],
            '12'  => ["#{bold}PRV=>#{reset}PrvBudget_Calculs",          "#{prv_dir}", "/PrvBudget_Calculs",""],
        #    '020' => ["*","**","***","****","*****"],
            '02'  => ["#---------#{bold}=>Private files<= ▼#{reset}---------#","**","***","****","*****"],
            '20'  => ["#{bold}FIL=>#{reset}PrvUpload-File into Notion-Dossiers",    "#{prv_dir}", "PrvUpload_Dossiers2","N L N F"],
        #    '030'  => ["*","**","***","****","*****"],
            '03'  => ["#---------#{bold}==>Budget<== 🔻#{reset}---------#","**","***","****","*****"],
            '30'  => ["#{bold}ACC=>#{reset}Budget hebdo",   "#{prv_dir}", "PrvBudget_Calculs","--", %w[debug simul],],
        #    '040'  => ["*","**","***","****","*****"],
        #    '050' => ["*","**","***","****","*****"],
            '05'  => ["#---------#{bold}=>Members<= ▼#{reset}---------#","**","***","****","*****"],
            '50'  => ["#{bold}UPD=>#{reset}Check records (.xlsx) before Merge to UPD",  "#{mbr_dir}", "/EneoBwCom_ChkXlsToUpd25", "",],
            '51'  => ["#{bold}UPD=>#{reset}Check records (.csv) before Merge to UPD",   "#{mbr_dir}", "/EneoBwCom_ChkCsvToUpd25", "",],
            '52'  => ["#{bold}UPD=>#{reset}Process records from UPD to MBR with IA",    "#{mbr_dir}", "/EneoBwCom_UpdMbrIA", "--", %w[act_mode cdc act only limit since],],
            '53'  => ["#{bold}UPD=>#{reset}Load to UPD from XL file",                   "#{mbr_dir}", "/EneoBwCom_AddXlsToUpd05", "",],
            '54'  => ["#{bold}COT=>#{reset}Checks records COT",                         "#{mbr_dir}", "/EneoBwSpc_ChkCot", "",],
            '55'  => ["#{bold}COT=>#{reset}Process records COT",                        "#{mbr_dir}", "/EneoBwSpc_MgtCot", "",],
            '56'  => ["#{bold}COT=>#{reset}Checks records COT details",                 "#{mbr_dir}", "/EneoBwSpc_ChkCotFull", "",],
        #    '060' => ["*","**","***","****","*****"],
            '06'  => ["#---------#{bold}=>Checks<= ▼#{reset}---------#","**","***","****","*****"],
            '60'  => ["#{bold}CHK=>#{reset}Check specific fields on all tables",        "#{mbr_dir}", "/EneoBwSpc_ChkFields", "--", %w[json examples missing],],
            '61'  => ["#{bold}CHK=>#{reset}Check duplicates members",                   "#{mbr_dir}", "/EneoBwSpc_ChkDupl_2", "N",],
            '62'  => ["#{bold}CHK=>#{reset}Log all updates on MBR UPD MAJ COT PRJ",     "#{mbr_dir}", "/EneoBwSpc_LogModifs", "--", %w[since state buffer dry_run],"Help: Since:ISO8601 date->YYYY-MM-DDT00:00:00+01:00 or nul | Dry:Simulation"],
        #    '070' => ["*","**","***","****","*****"],
            '07'  => ["#---------#{bold}=>Mgt Activities<= ▼#{reset}---------#","**","***","****","*****"],
            '70'  => ["#{bold}MBR=>#{reset}Extract members for Activity",               "#{mbr_dir}", "/EneoBwCom_ExtrMbr05", "N",],
            '71'  => ["#{bold}MBR=>#{reset}Extract members for Activity with Error",    "#{mbr_dir}", "/EneoBwCom_ChkMbr05", "N",],
            '72'  => ["#{bold}MBR=>#{reset}Extract Member Hist",                        "#{mbr_dir}", "/EneoBwSpc_DisplMember", "- -",],
            '73'  => ["#{bold}MAIL=>#{reset}Send mails with members file.xlsx",          "#{mbr_dir}", "/EneoBwSpc_SndMailAllActs", "--", %w[exec debug],],
            '74'  => ["#{bold}MAIL=>#{reset}Send mails with attachment",                 "#{mbr_dir}", "/EneoBwSpc_SndMail2_AllActs", "--", %w[exec debug],],
        #    '080' => ["*","**","***","****","*****"],
            '08'  => ["#---------#{bold}=>Mgt M25 for Office<= ▼#{reset}---------#","**","***","****","*****"],
            '80'  => ["#{bold}MBR=>#{reset}Extract records for Office",                 "#{mbr_dir}", "/EneoBwCom_ExtrOffice05", "--", %w[debug list lstdate],],
            '81'  => ["#{bold}MBR=>#{reset}Extract records for Office - EXT",           "#{mbr_dir}", "/EneoBwCom_ExtrOfficeExt", "--", %w[debug list lstdate],],
        #    '090' => ["*","**","***","****","*****"],
            '09'  => ["#---------#{bold}=>System<= ▼#{reset}---------#","**","***","****","*****"],
            '90'  => ["#{bold}SYS=>#{reset}Encode / Decode",                            "#{prv_dir}", "/PrvEncodeDecode","N",],
            '91'  => ["#{bold}SYS=>#{reset}Search Data-Sources IDs ",                   "#{mbr_dir}", "/Search_DBs_ID", "N",]
        }

        @arrfunctions.each do |key,function|    #<L1>
            puts    "*  (#{key})  => #{function[0]}"    unless function[0].include?("*")
            puts    "*"                                 if function[0].include?('*')
        end #<L1>
        puts    "*****"
        return  @arrfunctions
    end #<def

    def self.show_pages(apl_num: nil, log: nil)
    #++++++++++++++++++++++++
    #   Display help coments
    #
        bold    = "\e[1m"
        reset   = "\e[0m"
        key     = apl_num.to_s
        applic  = @arrfunctions[key][0]

        puts    "***** Help comments *****"
        puts    ">>>Application: #{apl_num} -> #{applic}"
        puts    ">>>Comments: ▼"
        case    apl_num #<L1>
        when    10
            puts    "#{bold}Conversion de format pour un fichier .csv#{reset}"
            puts    "#{bold}Répertoire d'entrée#{reset}: MBR/Works ou Prv/Works"
            puts    "#{bold}Répertoire de sortie#{reset}: le même"
            puts    "#{bold}Nom du fichier en entrée#{reset}: aaaaaa.csv"
            puts    "#{bold}Nom du fichier en sortie#{reset}: Cvrt-<input>-<output>"
            puts    "<input>:  I pour CP1252 - U pour UTF-8"
            puts    "<output>: I pour CP1252 - U pour UTF-8"
            puts    "#{bold}Séparateur entrée et sortie#{reset}: <,> ou <;>"
            puts    "Les dates sont converties: -> YYYY-MM-DD"
            puts    "Les nombres sont convertis: <,> -> <.>"
        when    20
        when    30
        when    40
        when    50
        when    51
        when    52
        when    53
        when    54
        when    55
        when    56
        when    60
        when    61
        when    62
        when    70
        when    71
        when    72
        when    73
        when    74
        when    80
        when    81
        when    90
        when    91
        end #<L1>
        puts    "***** Help comments *****"
        puts    ">>>Application: #{apl_num} -> #{applic}"
    end #<def>
    #
end #<Mod>