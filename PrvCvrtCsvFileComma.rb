#!/usr/bin/env ruby
# encoding: utf-8
# csv_to_notion.rb - Conversion CSV bancaire belge (UTF-8/;) → format Notion (UTF-8/,)

require 'rubygems'
require 'timeout'
require 'date'
require 'pp'
require 'CSV'

class CsvToNotion
#****************
  def initialize(input_file, output_file = nil)
    @input_file = input_file
    @output_file = output_file || input_file.sub(/\.csv$/, '_notion.csv')
  end

  def convert(type='')
    rows = CSV.read(@input_file, headers: true, encoding: 'UTF-8', col_sep: (';'))
    #GHE#   pp  rows
    
    # Colonnes à convertir (ajustez selon votre CSV)
    #+++++++++++++++++++++
    date_columns_sta    = ['Date', 'Date valeur']
    date_columns_div    = ['Date Naissance', 'Date Entrée', 'Date Paiement', 'Date Sortie', 'Date Deces']
    number_columns_sta  = ['Montant', 'Crédit', 'Débit', 'Solde']
    number_columns_div  = ['Cotisation']
    if type == 'sta'
        date_columns    = date_columns_sta
        number_columns  = number_columns_sta
    elsif type == 'div'
        date_columns    = date_columns_div
        number_columns  = number_columns_div
    end
    
    # Processing
    #+++++++++++
    rows.each do |row|
        #GHE#   puts    row
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
    CSV.open(@output_file, 'w', encoding: 'UTF-8', col_sep: ",") do |csv|
        csv << rows.headers
        rows.each { |row| csv << row }
    end
    
    # End of convert
    #+++++++++++++++
    puts    "=>"
    puts    "✓ Conversion terminée : #{@output_file}"
    puts    "<="
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
end

#
# Initialisation
#***************
    # Check ARGV
    if ARGV.empty?  #<L1
      puts "Usage: ruby csv_to_notion.rb fichier.csv [fichier_sortie.csv]"
      exit 1
    else
        _type   = ARGV[0]
    end #<L1>

#
#***** Directories management *****
# Start of block
    exec_mode   = 'B'                                   #change B or P
    require_dir = Dir.pwd
    common_dir  = "/users/gilbert/public/progs/prod/common/"    if exec_mode == 'P'
    common_dir  = "/users/gilbert/public/progs/dvlps/common/"    if exec_mode == 'B'
require "#{common_dir}/ClDirectories.rb"
    _dir    = Directories.new(false)
    arrdirs = _dir.otherDirs(exec_mode)                 #=>{exec,private,membres,common,send,work}
# End of block
#***** Directories management *****
#

#
# Check parameters
#*****************
# Start of block
    _debug  = true      if _debug == 'Y'
    _debug  = false     if _debug == 'N'

    print   "What is the type ? (sta, div) []"
    _type   = $stdin.gets.chomp.to_s
    _type   = 'sta' if _type == 's'
    _type   = 'div' if _type == 'd'
# End of block

#
#***** Exec environment *****
# Start of block
    program     = 'PrvCvrtCsvFileComma'
    dbglevel    = 'DEBUG'

require "#{arrdirs['common']}/ClCommon_2.rb"
    _com    = Common_2.new(program,_debug,dbglevel)
require "#{arrdirs['common']}/ClNotion_04.rb"

    private_dir     = arrdirs['private']                #private directory
    member_dir      = arrdirs['membres']                #members directory
    common_dir      = arrdirs['common']                 #common directory
    work_dir        = arrdirs['work']
    send_dir        = arrdirs['send']
    process_dir     = arrdirs['process']
    pwork_dir       = arrdirs['pwork']

require "#{member_dir}/mdEneoBwCom.rb"
# End of block
#***** Exec environment *****
#

#
# Get file to convert
#********************
    puts    "🚀 File must be read on #{pwork_dir}\n"
    Dir.chdir(pwork_dir)
    allfiles    = Dir.glob("*.csv")
    allfiles.each_with_index do |file,index|    #<L1>
        puts    "#{index+1}.#{file}"
    end #<L1>
    print   "Please select file to process by N° => "
    fileindex   = $stdin.gets.chomp.to_i
    exit    9   if fileindex == 0
    fileselect  = allfiles[fileindex-1]
    puts    "File selected: #{fileselect}"

    # Make filenames
    file_inp    = fileselect
    file_out    = "Cvrt-" + fileselect

#
#   Execution
#************
    converter = CsvToNotion.new(file_inp, file_out)     #new instance
    converter.convert(_type)                            #process it
#
#<EOP>