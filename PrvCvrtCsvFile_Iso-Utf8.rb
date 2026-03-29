#!/usr/bin/env ruby
# encoding: utf-8
# csv_to_notion.rb - Conversion CSV → format Notion
#                       INP: CP1252 & ';'
#                       OUT: UTF-8 & ',' (for Notion)

require 'rubygems'
require 'timeout'
require 'date'
require 'pp'
require 'CSV'
require 'logger'
require_relative    'ClStandards.rb'
require_relative    'Mod_SelectFile.rb'

#****************
class CsvToNotion
#****************
#
  def initialize(input_file, output_file = nil)
    @input_file = input_file
    @output_file = output_file || input_file.sub(/\.csv$/, '_notion.csv')
  end

  def convert(type='',inp_prms='',out_prms='')
    inp_encod   = inp_prms.split('/')[0]
    inp_separ   = inp_prms.split('/')[1]
    rows = CSV.read(@input_file, headers: true, encoding: inp_encod, col_sep: inp_separ)
    @count_inp  = rows.size
    #GHE#   pp  rows
    
    # Colonnes à convertir (ajustez selon votre CSV)
    #+++++++++++++++++++++
    date_columns_sta    = ['Date', 'Date valeur']
    date_columns_div    = ['Date Naissance', 'Date Entrée', 'Date Paiement', 'Date Sortie', 'Date Deces']
    number_columns_sta  = ['Montant', 'Crédit', 'Débit', 'Solde']
    number_columns_div  = ['Cotisation']
    if type == 'P' or type == 'W'
        date_columns    = date_columns_sta
        number_columns  = number_columns_sta
    elsif type == 'M'
        date_columns    = date_columns_div
        number_columns  = number_columns_div
    end
    puts    "=> Columns to convert:: Dates: #{date_columns} Int: #{number_columns}"
    print   " => Press <Return> to continue"
    
    # Processing
    #+++++++++++
    rows.each do |row|
      # Conversion des dates DD/MM/YYYY → YYYY-MM-DD
      date_columns.each do |col|
        #GHE#   puts    "Date:: #{col} => #{row[col]}"
        next unless row[col] && !row[col].empty?
        row[col] = convert_date(row[col])
        #GHE#   puts    "Date:: #{col} => #{row[col]}"
      end
      
      # Conversion des nombres : virgule → point
      number_columns.each do |col|
        next unless row[col] && !row[col].empty?
        row[col] = convert_number(row[col])
      end
    end
    
    # Sauvegarde
    #+++++++++++
    ### puts    "Save file: #{@output_file}"
    out_encod   = out_prms.split('/')[0]
    out_separ   = out_prms.split('/')[1]
    CSV.open(@output_file, 'w', encoding: out_encod, col_sep: out_separ) do |csv|
        csv << rows.headers
    #    rows.each { |row| csv << row }
        rows.each do |row|
            puts    row
            csv << row
        end
    end
    @count_out  = rows.size
    arr_result      = []
    arr_result[0]   = @input_file
    arr_result[1]   = @output_file
    arr_result[2]   = @count_inp
    arr_result[3]   = @count_out

    return    arr_result
  end

  private

  def convert_date(date_str)
    # Gère DD/MM/YYYY → YYYY-MM-DD
    return date_str if date_str =~ /^\d{4}-\d{2}-\d{2}$/ # Déjà au bon format

    if date_str =~ %r{^(\d{2})/(\d{2})/(\d{4})$}
        return  "#{$3}-#{$2}-#{$1}"
    elsif   date_str =~ %r{^(\d{2})/(\d{2})/(\d{2})$}
        return  "20#{$3}-#{$2}-#{$1}"
    else
        return  date_str # Retourne tel quel si format non reconnu
    end
    #GHE#   date_out    = "#{date_str[6,4]}-#{date_str[3,2]}-#{date_str[0,2]}"
    return  
  end

  def convert_number(number_str)
    # Gère la virgule → point décimal
    # Enlève les espaces (séparateurs de milliers)
    number_str.gsub(' ', '').gsub(',', '.')
  end
end #<class>

#***************
# Initialisation
#***************
    @log                    = Logger.new(STDOUT)
    @log.level              = Logger::INFO
    @log.datetime_format    = '%H:%M:%S'

    # Check ARGV
    _type   = ARGV[0]   unless ARGV.empty?

    @log.info "🚀 Démarrage Conversion .csv\n"
    @log.info "Usage: ruby csv_to_notion.rb #{_type} <fichier_entrée.csv> => [CVRT_fichier_sortie.csv]\n"

#*****************
# Check parameters
#*****************
# Start of block
    _debug  = true      if _debug == 'Y'
    _debug  = false     if _debug == 'N'

    print   "What is the type of file : (P(rivate), M(embers), W(orks) ? "
    _type   = $stdin.gets.chomp.to_s.upcase
    exit    3       if _type.nil? or _type.empty?
    type_text   = "Private"     if _type == 'P'
    type_text   = "Members"     if _type == 'M'
    type_text   = "Works"       if _type == 'W'
    @log.info   "🚀 Démarrage en tant que #{type_text}\n"

    print   "For the input : format & separator : (W(in),/; or U(tf-8),/;) [W/;] x/x ? "
    inp_reply   = $stdin.gets.chomp.to_s.upcase
    encod_inp   = inp_reply.empty? ? "W" : inp_reply[0]
    separ_inp   = inp_reply.empty? ? ";" : inp_reply[2]
    encod_inp_text  = "CP1252"      if encod_inp == 'W'
    encod_inp_text  = "UTF-8"       if encod_inp == 'U'
    separ_inp_text  = separ_inp
    inp_prms    = "#{encod_inp_text}/#{separ_inp_text}"
    @log.info   "🚀 Lecture en tant que <#{inp_prms}>\n"

    print   "For the output : format & separator : (W(in),/; or U(tf-8),/;) [U/,] x/x ? "
    out_reply   = $stdin.gets.chomp.to_s.upcase
    encod_out   = out_reply.empty? ? "U" : out_reply[0]
    separ_out   = out_reply.empty? ? "," : out_reply[2]
    encod_out_text  = "CP1252"          if encod_out == 'W'
    encod_out_text  = "UTF-8"           if encod_out == 'U'
    separ_out_text  = separ_out
    out_prms    = "#{encod_out_text}/#{separ_out_text}"
    @log.info   "🚀 Ecriture en tant que <#{out_prms}>\n"

# End of block

#
#***** Exec environment *****
# Start of block
    @count_inp  = 0
    @count_out  = 0
# End of block
#***** Exec environment *****
#
#
# Get file to convert
#********************
#    current_dir = "/users/Gilbert/Public/MemberLists/Works"     if _type == 'M'
#    current_dir = "/users/Gilbert/Public/Private/Works"         if _type == 'P' or _type == 'W'
#    @log.info   "🚀 File must be read on #{current_dir}\n"
#    print   "Press <Return> to continue"
#    rep     = $stdin.gets.chomp

#    Dir.chdir(current_dir)
#    allfiles    = Dir.glob("*.csv")
#    @log.info  "#{allfiles.count} files are ready to process\n"
#    allfiles.each_with_index do |file,index|    #<L1>
#        puts    "#{index+1}.#{file}"
#    end #<L1>
#    print   "Please select file to process by N° => "
#    fileindex   = $stdin.gets.chomp.to_i
#    exit    9   if fileindex == 0
#    fileselect  = allfiles[fileindex-1]
    initial_dir = "/users/Gilbert/Public"
    initial_dir = "/users/Gilbert/Public/Private"       if _type == 'P'
    initial_dir = "/users/Gilbert/Public/MemberLists"   if _type == 'M'
    initial_dir = "/users/Gilbert/Public/Private"       if _type == 'W'
    fileselect  = SelectFile.TK_Use(initial_dir: initial_dir)
    @log.info "File selected: #{fileselect}\n"
    file_dirname    = File.dirname(fileselect)
    file_name       = File.basename(fileselect)
    Dir.chdir(file_dirname)

    # Make filenames
    file_inp    = fileselect
    prefixe     = "None-"
    prefixe     = "Cvrt-I-U-"   if encod_inp == 'W' and encod_out == 'U'
    prefixe     = "Cvrt-U-I-"   if encod_inp == 'U' and encod_out == 'W'
    prefixe     = "Cvrt-I-I-"   if encod_inp == 'W' and encod_out == 'W'
    prefixe     = "Cvrt-U-U-"   if encod_inp == 'U' and encod_out == 'U'
    file_out    = "#{file_dirname}/#{prefixe}#{file_name}"

#
#   Execution
#************
    converter   = CsvToNotion.new(file_inp, file_out)   #new instance
#    stds        = Standards.new([],'old')               #new instance
    
    @log.info   " Prêt à convertir de #{inp_prms} vers #{out_prms}"
    arr_result  = converter.convert(_type, inp_prms, out_prms)              #process it

    
    # End of convert
    #+++++++++++++++
    @log.info "\n" + "=" * 50
    @log.info   "  Read file: #{arr_result[0]}\n"
    @log.info   "✓ Conversion terminée => #{arr_result[1]}\n"
    @log.info   " Input: #{arr_result[2]} - Output: #{arr_result[3]}"
    @log.info "\n" + "=" * 50
#
#<EOP>