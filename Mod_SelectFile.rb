#!/usr/bin/env ruby
# encoding: UTF-8
=begin
DOC     Function:   select a file within a selected directory
DOC     require_relative 'Mod_SelectFile'
DOC     usage:      file    = self.select_pages()
DOC                 exit    unless file.nil?
DOC     build:  <260112-1400>
=end
#
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end
require 'open3'
require 'tk'

    module  SelectFile
#   ******************
    def self.show_pages(files, page, page_size, old_dir="")
    #++++++++++++++++++++++++
    #   Display a range of files
    #
        start_idx = page * page_size
        end_idx   = [start_idx + page_size - 1, files.size - 1].min

    #    system("clear") # sur macOS, efface l'écran du Terminal
        puts "Fichiers #{start_idx + 1} à #{end_idx + 1} sur #{files.size} (page #{page + 1}/#{(files.size.to_f / page_size).ceil})"
        puts "-" * 60

        (start_idx..end_idx).each_with_index do |idx, offset|
            array = files[idx].split("/")
            new_dir = array[0..-2].join("/")
            if new_dir != old_dir
                puts "\n"+"-"*20+"==> #{new_dir} <=="+"-"*20
                puts "-"*24+"="*new_dir.length+"-"*24
                old_dir = new_dir
            end
            puts "#{idx + 1}. #{files[idx]}"
        end

        puts "-" * 60
        puts "Commandes : [n] suivant  [p] précédent  [s] sélectionner numéro  [q] quitter"
    end #<def>

    def self.select_pages(initial_dir=nil, loop=0)
    #++++++++++++++++++++++++++
    #   Select a file within the displayed range
    #
        @root = initial_dir
        puts ">>>DBG: Root: #{initial_die}"

        # Select start directory
        loop do #<L1>
            puts    '>'
            print   "Choix pour (F)ichiers ou (R)épertoire ou (S)can ou (Q)uit [Q] ? "
            reply   = STDIN.gets.chomp.downcase
            reply   = 'q'   if reply.empty?

            current_pwd = Dir.pwd
            choice  = reply.strip.downcase
            case choice #S2>
            when    'f'
            when    'r'
                sf  = self.TK_Use()
                return  sf
            when    'q'
                exit
            when    's'
                prms    = {
                    :mode      =>  'Auto',
                    :out_dir   =>  "/users/Gilbert/Library/Mobile Documents/com~apple~CloudDocs/Downloads/From Scan",
                    :out_name  =>  "ToDispatch.pdf",
                    :title     =>  "From Scan to Notion-DOSS",
                    :subject   =>  "Unknown",
                    :keywords  =>  "byScript"
                }
                scan_pages(prms)
                Dir.chdir(prms[:out_dir])
                @root    = Dir.pwd
                puts ">>>DBG: Root: #{@root}"
            else
                puts    "Choix invalide"
                next
            end #S2>
            break
        end #<L1>

        # First list
        page_size = 40
        puts ">>>DBG: Root: #{@root}"

        files = Dir.glob(File.join(@root, "**", "*")).select { |f| File.file?(f) }

        # Set params
        current_page = 0
        total_pages  = (files.size.to_f / page_size).ceil
        old_dir      = ""

        # Main loop
        loop do #<L1>
            self.show_pages(files, current_page, page_size, old_dir)

            print "> "
            input = STDIN.gets
            break unless input
            cmd = input.strip.downcase

            case cmd    #<S2>
            when "n"
                current_page += 1 if current_page < total_pages - 1
            when "p"
                current_page -= 1 if current_page > 0
            when "q"
                puts "Abandon."
                break
            when "s"
                print "Numéro du fichier à sélectionner : "
                num = STDIN.gets.to_i
                index = num - 1
                if index.between?(0, files.size - 1)    #<IF3
                    puts "Vous avez choisi : #{files[index]}"
                    # ici vous pouvez traiter le fichier choisi
                    return  files[index]
                else    #<IF3>
                    puts "Numéro invalide, appuyez sur Entrée pour continuer."
                    STDIN.gets
                    return  nil
                end #<IF3>
            else    #<S2>
                # touche inconnue : on ignore, boucle suivante
            end #S2>
        end #<L1>
    end #<def>

    def self.select_scan(initial_dir: nil, loop: 0)
    #++++++++++++++++++++++++++
    #   Select a file within the displayed range
    #
        while  true  #<L0>
            @root = "."
            prms    = {
                :mode      =>  'Auto',
                :out_dir   =>  "/users/Gilbert/Library/Mobile Documents/com~apple~CloudDocs/Downloads/From Scan",
                :out_name  =>  "ToDispatch.pdf",
                :title     =>  "From Scan to Notion-DOSS",
                :subject   =>  "Unknown",
                :keywords  =>  "byScript"
            }
            scan_pages(prms)
            Dir.chdir(prms[:out_dir])
            @root    = Dir.pwd
            puts ">>>DBG: Root: #{@root}"

            # First list
            page_size = 40

            files = Dir.glob(File.join(@root, "**", "*")).select { |f| File.file?(f) }

            # Set params
            current_page = 0
            total_pages  = (files.size.to_f / page_size).ceil
            old_dir      = ""
            cmd          = ""

            # Main loop
            loop do #<L1>
                self.show_pages(files, current_page, page_size, old_dir)

                print "> "
                input = STDIN.gets
                break unless input
                cmd = input.strip.downcase

                case cmd    #<S2>
                when "n"
                    puts "Next scan iteration"
                    break
                when "p"
                    puts "No yet in use"
                when "q"
                    puts "Abandon."
                    break
                when "s"
                    print "Numéro du fichier à sélectionner : "
                    num = STDIN.gets.to_i
                    index = num - 1
                    if index.between?(0, files.size - 1)    #<IF3
                        puts "Vous avez choisi : #{files[index]}"
                        # ici vous pouvez traiter le fichier choisi
                        return  files[index]
                    else    #<IF3>
                        puts "Numéro invalide, appuyez sur Entrée pour continuer."
                        STDIN.gets
                        return  nil
                    end #<IF3>
                else    #<S2>
                    # touche inconnue : on ignore, boucle suivante
                end #S2>
            end #<L1>
            break   if cmd == "q"
        end #<L0>
    end #<def>

    def self.scan_pages(prms={})
    #++++++++++++++++++++++++
    #   Scan pages & save on temp folder
    #   INP:    prms {mode: out_dir: out_name: title: author: subject: keywords:}
    #
        mode            = prms[:mode] || 'Auto'
        scan_dir        = prms[:out_dir] || "/users/Gilbert/Temp"
        scan_name       = prms[:out_name] || "ToKeep.pdf"
        pdf_title       = " --pdftitle #{prms[:title]}"
        pdf_author      = " --pdfauthor #{prms[:author]}"
        pdf_subject     = " --pdfsubject #{prms[:subject]}"
        pdf_keywords    = " --pdfkeywords #{prms[:keywords]}"
        case    mode
        when    'Auto'
            scan_prog       = "/Applications/NAPS2.app/Contents/MacOS/NAPS2 console -v -a "
            cmdopen3        = "#{scan_prog}#{pdf_title}#{pdf_author}#{pdf_subject}#{pdf_keywords} "
        when    'Output'
            end

        stdin, stdout, stderr, wait_thr = Open3.popen3(cmdopen3)
        output = stdout.read
        error = stderr.read
        exit_status = wait_thr.value.exitstatus

        puts    "Log of scan => "
        puts    "- Output: #{output}"
        puts    "- Error: #{error}"
        puts    "- Exit status: #{exit_status}"
        puts    "End of scan log"
    end #<def>

    def self.TK_Use(initial_dir: "/users/Gilbert", loop: 0)
    #+++++++++++++++++++++
    #
        # create instance
        tkroot = TkRoot.new { title "Sélection d'un répertoire et ensuite le fichier" }

        # search directory
        puts "Initial directory: #{initial_dir} for loop: #{loop}"
        if loop == 0
            dir = Tk::chooseDirectory(initialdir: initial_dir)
        else
            dir = initial_dir
        end
        if dir && !dir.empty?   #<IF1>
            puts "Vous avez sélectionné le répertoire : #{dir}"

            # select file within the directory
            files = Dir.glob(File.join(dir, "*")).select { |f| File.file?(f) }
            if files.empty? #<IF2>
                puts "Aucun fichier trouvé dans le répertoire sélectionné."
                return nil
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
                    return selected_file
                else    #
                    puts "Numéro invalide, sortie."
                    return nil
                end #<IF3>
            end

        else
            puts "Aucun répertoire sélectionné."
        end
    end #<def>

end #<mod>