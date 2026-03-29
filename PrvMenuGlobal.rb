#
=begin
DOC     *
DOC:    Program:   PrvMenuGlobal
DOC:    Function:  Execute all applications from 'Private'
DOC:                                        from 'Members'
DOC:    Call:      ruby PrvMenus.rb --exec --debug --loop N --sleep N --fct N apply
DOC:    Build:     5-2-1   <260327-1130>
DOC:    Parameters::
DOC:        ENV:
DOC:            EXEC:   B or P
DOC:            DEBUG:  true or false
DOC:        Flags:
DOC:        --Json:     json file with DB IDs
DOC         --exec:     P or B or H
DOC         --debug     false or true
DOC:        --loop:     how many loops today, 0 = no limits
DOC:        --sleep:    how secs to sleep between 2 programs (Sleep * 5)
DOC:        --fct:      first program to run @ startup
DOC:        apply:      from ENV or (as last flag) => Simulate all actions if present
DOC     *
        Bugs:   <001>   <yymmdd>    <text>
                <002>   <260327>    <New prog>
                <5.3.1>  <260329>   <New directory>
=end
#
#Require
#*******
require 'rubygems'
require 'timeout'
require 'json'
require 'pp'
require 'optparse'

require_relative    'Mod_HelpApplic.rb'
begin
  require "dotenv"; Dotenv.load('.env')
rescue LoadError
end

#
# Arguments
#**********
    options = {
        json_file: "Data_Sources_ID.json",
        exec:   ENV.fetch("EXEX","P"),
        debug:  ENV.fetch("DEBUG","INFO"),
        loop:   0,
        sleep:  1,
        fct:    0
    }
    # from command line
    OptionParser.new do |opts|
        opts.on("--json FILE", "Fichier data_sources.json") { |v| options[:json_file] = v }
        opts.on("--exec P",String,"Processing mode") do |v| options[:exec] = v end
        opts.on("--debug INFO",String,"Debug mode"){|v| options[:debug] = v }

        opts.on("--loop 0",Integer,"Loops count") { |v| options[:loop] = v }
        opts.on("--sleep 0",Integer,"Sleep timeout") { |v| options[:sleep] = v }
        opts.on("--fct 0",Integer,"Function @ startup") { |v| options[:fct] = v }
    end.parse!  #<OptionParser>
    #
DRY_RUN = ENV.fetch("DRY_RUN",true)
dry_run_mode    = 'Production'  if DRY_RUN
dry_run_mode    = 'Simulation'  unless DRY_RUN
#
# Display DOC
    file        = __FILE__
    lines       = File.readlines(file)
    doc_flag    = false
    doc_lines   = []
    lines.each do |line|
        if !doc_flag
            if line =~ /^\s*=begin(?:\s+.*)?\s*$/
                doc_flag    = true
                next
            end
        end
        break   if line =~ /^\s*=end(?:\s+.*)?\s*$/
        doc_lines << line   if line.include?('DOC')
    end

#
#***** Exec environment *****
# Start of block
# Logger
require 'logger'
    log                 = Logger.new(STDOUT)
    log.level           = Logger::INFO
    log.datetime_format = '%H:%M:%S'
    log.info("🔧 Mode: #{DRY_RUN} => #{dry_run_mode}}")
    log.info("🌹 Doc: ▼")
    log.info("🌹 #{doc_lines.join()}") unless doc_lines.empty?

    exit    0   if options[:exec] == 'H'

# Data_Sources
    if File.exist?(options[:json_file])
        data_sources = JSON.parse(File.read(options[:json_file]))
    else
        log.warn "Data sources file not found: #{options[:json_file]}. Proceeding with empty data sources."
        data_sources = {}
    end

# Directories
    arrdirs     = {                                     #directories used to run programs
        prv_progs:  ENV.fetch("PRG_INUSE_DIR", nil),
        mbr_progs:  ENV.fetch("PRG_INUSE_DIR", nil),
    }


# End of block
#***** Exec environment *****

#
#Variables
#*********
    vrp         = "5.3.1"
    repfct      = options[:fct]
    timeout     = options[:sleep]
    timemin     = timeout/60
    timestart   = "06:45"
    timestop    = "19:00"
    timeloop    = timeout * 1
    flagloop    = true
    flagwait    = true

    bold = "\e[1m"
    reset = "\e[0m"

    RUBY_PROGS_DIR   = "/users/Gilbert/Public/Progs/InUse/repoRuby"

    arrfunctions    = {                                 #all programs to run
        #key=>[Display, Directory, Name, Prms, Temp]
    #    '010' => ["*","**","***","****","*****"],
        '01'  => ["#---------#{bold}=>Private<= ▼#{reset}---------#","*","*","*","*"],
        '10'  => ["#{bold}PRV=>#{reset}PrvCvrtCsvFile_Iso-Utf8",    "#{RUBY_PROGS_DIR}", "PrvCvrtCsvFile_Iso-Utf8","N"],
        '11'  => ["#{bold}PRV=>#{reset}PrvCvrtCsvFileComma",        "#{RUBY_PROGS_DIR}", "/PrvCvrtCsvFileComma","N"],
    #    '020' => ["*","**","***","****","*****"],
        '02'  => ["#---------#{bold}=>Private files<= ▼#{reset}---------#","**","***","****","*****"],
        '20'  => ["#{bold}FIL=>#{reset}New PrvUpload-File into Notion-Dossiers",    "#{RUBY_PROGS_DIR}", "PrvUpload_Dossiers2","N L N F"],
    #    '030'  => ["*","**","***","****","*****"],
        '03'  => ["#---------#{bold}==>Budget<== 🔻#{reset}---------#","**","***","****","*****"],
        '30'  => ["#{bold}ACC=>#{reset}Budget hebdo",   "#{RUBY_PROGS_DIR}", "PrvBudget_Calculs","--", %w[debug simul],],
    #    '040'  => ["*","**","***","****","*****"],
    #    '050' => ["*","**","***","****","*****"],
        '05'  => ["#---------#{bold}=>Members<= ▼#{reset}---------#","**","***","****","*****"],
        '50'  => ["#{bold}UPD=>#{reset}Check records (.xlsx) before Merge to UPD",  "#{RUBY_PROGS_DIR}", "/EneoBwCom_ChkXlsToUpd25", "",],
        '51'  => ["#{bold}UPD=>#{reset}Check records (.csv) before Merge to UPD",   "#{RUBY_PROGS_DIR}", "/EneoBwCom_ChkCsvToUpd25", "",],
        '52'  => ["#{bold}UPD=>#{reset}Process records from UPD to MBR with IA",    "#{RUBY_PROGS_DIR}", "/EneoBwCom_UpdMbrIA", "--", %w[act_mode cdc act only limit since],],
        '53'  => ["#{bold}UPD=>#{reset}Load to UPD from XL file",                   "#{RUBY_PROGS_DIR}", "/EneoBwCom_AddXlsToUpd05", "",],
        '54'  => ["#{bold}COT=>#{reset}Checks records COT",                         "#{RUBY_PROGS_DIR}", "/EneoBwSpc_ChkCot", "",],
        '55'  => ["#{bold}COT=>#{reset}Process records COT",                        "#{RUBY_PROGS_DIR}", "/EneoBwSpc_MgtCot", "",],
        '56'  => ["#{bold}COT=>#{reset}Checks records COT details",                 "#mRUBY_PROGS_DIR}", "/EneoBwSpc_ChkCotFull", "",],
    #    '060' => ["*","**","***","****","*****"],
        '06'  => ["#---------#{bold}=>Checks<= ▼#{reset}---------#","**","***","****","*****"],
        '60'  => ["#{bold}CHK=>#{reset}Check specific fields on all tables",        "#{RUBY_PROGS_DIR}", "/EneoBwSpc_ChkFields", "--", %w[json examples missing],],
        '61'  => ["#{bold}CHK=>#{reset}Check duplicates members",                   "#{RUBY_PROGS_DIR}", "/EneoBwSpc_ChkDupl_2", "N",],
        '62'  => ["#{bold}CHK=>#{reset}Log all updates on MBR UPD MAJ COT PRJ",     "#{RUBY_PROGS_DIR}", "/EneoBwSpc_LogModifs", "--", %w[since state buffer dry_run],"Help: Since:ISO8601 date->YYYY-MM-DDT00:00:00+01:00 or nul | Dry:Simulation"],
    #    '070' => ["*","**","***","****","*****"],
        '07'  => ["#---------#{bold}=>Mgt Activities<= ▼#{reset}---------#","**","***","****","*****"],
        '70'  => ["#{bold}MBR=>#{reset}Extract members for Activity",               "#{RUBY_PROGS_DIR}", "/EneoBwCom_ExtrMbr05", "N",],
        '71'  => ["#{bold}MBR=>#{reset}Extract members for Activity with Error",    "#{RUBY_PROGS_DIR}", "/EneoBwCom_ChkMbr05", "N",],
        '72'  => ["#{bold}MBR=>#{reset}Extract Member Hist",                        "#{RUBY_PROGS_DIR}", "/EneoBwSpc_DisplMember", "- -",],
        '73'  => ["#{bold}MAIL=>#{reset}Send mails with members file.xlsx",          "#{RUBY_PROGS_DIR}", "/EneoBwSpc_SndMailAllActs", "--", %w[exec debug],],
        '74'  => ["#{bold}MAIL=>#{reset}Send mails with attachment",                 "#{RUBY_PROGS_DIR}", "/EneoBwSpc_SndMail2_AllActs", "--", %w[exec debug],],
    #    '080' => ["*","**","***","****","*****"],
        '08'  => ["#---------#{bold}=>Mgt M25 for Office<= ▼#{reset}---------#","**","***","****","*****"],
        '80'  => ["#{bold}MBR=>#{reset}Extract records for Office",                 "#{RUBY_PROGS_DIR}", "/EneoBwCom_ExtrOffice05", "--", %w[debug list lstdate],],
        '81'  => ["#{bold}MBR=>#{reset}Extract records for Office - EXT",           "#{RUBY_PROGS_DIR}", "/EneoBwCom_ExtrOfficeExt", "--", %w[debug list lstdate],],
    #    '090' => ["*","**","***","****","*****"],
        '09'  => ["#---------#{bold}=>System<= ▼#{reset}---------#","**","***","****","*****"],
        '90'  => ["#{bold}SYS=>#{reset}Encode / Decode",                            "#{RUBY_PROGS_DIR}", "/PrvEncodeDecode","N",],
        '91'  => ["#{bold}SYS=>#{reset}Search Data-Sources IDs ",                   "#{RUBY_PROGS_DIR}", "/Search_DBs_ID", "N",]
    }

#
# Internal functions
#*******************
    def execProg(prog,log)
    #+++++++++++
    #   INP:    prog => full program path
    #           log  => logger instance
    #
        time_start  = Time.now
        log.info("Run #{$0} : #{__method__} => #{prog} @ #{time_start}")
        rc  = system("#{prog}")
        time_end    = Time.now
        log.info("Done #{$0} : #{__method__} => #{prog} @ #{time_end} time: #{time_end - time_start} secs")
    end #<def>

    def wait(p_timeout=60,p_reply=false,log)
    #++++++++
        #INP::  time to wait
        #       accept reply or not
        #       log => logger instance
        #OUT::  reply Go, n, q [def: Go]
        #
        answer  = 'Go'
        if p_reply  #<IF1>
            begin
                log.info("#{__method__} => TimeOut for #{p_timeout} secs, break if q or n typed")
                answer  = 'x'
                status = Timeout::timeout(p_timeout) { answer = $stdin.gets.chomp.downcase until answer == 'q' or answer == 'n' }
            rescue Timeout::Error
                answer  = 'Go'
            end
        else    #<IF1>
            log.info("#{__method__} => TimeOut for #{p_timeout} secs, no break")
            sleep   p_timeout
        end #<IF1>
        return  answer
    end #<def>

    def getChoice(log)
        print   ">Menu>>Enter your choice (0=>exit): "
        repfct  = $stdin.gets.chomp                 #get choice
        repfct  = repfct.to_i
        repfct  = repfct * 10   if repfct < 10

        return  repfct
    end #<def>

    def enterRet(log)
        log.info("<>")
        print   "Menu<>Press return to continue"
        z   = $stdin.gets.chomp
        log.info("<>")
    end

    def helpApplic(log)
        log.info("***** Help *****")
        reply   = getChoice(log)
        HelpApplic.show_pages(apl_num: reply, log: log)
    end #<def>

#
# Main code
#**********
    # Initialize
    #+++++++++++
    puts    "\033]0;***Menu Global***\007"
    current_mode    = options[:exec]
    log.info("#{$0} => With parameters: EXEC:#{current_mode} | TMO:#{timeout} | FCT:#{repfct}}")
    log.info("DBG>>>Directories: ☛")
    log.info("#{RUBY_PROGS_DIR}")
    log.info("#{$0} => List of programs to execute")

    # Loop
    #+++++
    flagloop    = true
    while flagloop  #<L1>
        t           = Time.now                          #get time
        currtime    = t.strftime("%k:%M").strip         #extract HH:MM
        currsize    = currtime.size
        currtime    = "0#{currtime}"    if currsize < 5
        puts    "\033]0;>Menu Global>@#{currtime}\007"

        # get request
        #++++++++++++
        log.info("*************************")
        log.info("*****Common  Menu***#{vrp}** @ #{currtime}")
        log.info("*************************")

        if repfct == 0  #<IF2>
            log.info("1B:: Choice program to execute on #{current_mode}")
            #Display infos
            puts    "*****"
            puts    "Programs :"
            puts    "*"

            arrfunctions    = HelpApplic.displayApplic(prv_dir: RUBY_PROGS_DIR, mbr_dir: RUBY_PROGS_DIR)

            #get choice
            repfct  = getChoice(log)
        else    #<IF2>
            repfct  = options[:fct]
        end #<IF2>
        #

        if repfct > 100 #<IF2>
            enterRet(log)
        #
        elsif repfct == 0  #<IF2>
            log.warn("#{$0} => Exit requested by operator")
            exit 0
        #
        elsif   repfct == 99
            helpApplic(log)
            enterRet(log)
        #
        elsif   repfct < 99    #<IF2>
            # Execute it
            #+++++++++++
            prog_key    = repfct.to_s
            prog_displ  = arrfunctions[prog_key][0]
            prog_dir    = arrfunctions[prog_key][1]
            prog_name   = arrfunctions[prog_key][2]
            prog_prms   = arrfunctions[prog_key][3]
            if prog_prms == '--'
                puts    "#{arrfunctions[prog_key][4]}"
                puts    "#{arrfunctions[prog_key][5]}"
                prms    = ""
                keys    = arrfunctions[prog_key][4]
                keys.each do |key|
                    print   "Menu>Value for #{key} ? "
                    value   = $stdin.gets.chomp
                    next    if value.nil? or value.size==0
                    prms.concat("--#{key} #{value} ")
                end
                prog_prms   = prms
                puts    "Prms: #{prog_prms}"
            end
            log.info("1C:: Program: #{prog_displ} in progress...")

            prog    = "ruby #{prog_dir}/#{prog_name}.rb #{prog_prms}"
            log.info("1D:: Run : #{prog}")

            execProg(prog, log)
            
            enterRet(log)
        end #<IF2>

        flagwait    = true
        while   flagwait    #<L2>
            # Next
            #+++++
            log.info("3::Next program => wait #{timeloop}secs/#{timeloop/60}mins or enter your request [q, n] ")
            answer  = wait(timeloop,true,log)
            if answer == 'q'
                log.warn(">>>Forced exit")
                flagloop    = false
                flagwait    = false
                repfct      = 0
            else
                log.warn('>>>Forced loop')
                flagwait    = false
                repfct      = options[:fct]
            end
        end #<L2>
    end #<L1>

#Exit
#****
    log.info("#{$0} => Bye bye, see you soon")
    exit 0
#<EOS>
