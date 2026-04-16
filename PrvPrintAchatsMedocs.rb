# frozen_string_literal: true
#
=begin
    DOC     Function:   ?
    DOC     Call:       ruby ? --?
    DOC     Build:      260206-1000
    DOC     Version:    1.1.1
        Bugs:       ?

=end

require 'rubygems'
require "json"
require "httparty"
require "optparse"
require "logger"
require 'timeout'
require 'date'
require 'pp'
require 'csv'
require "unf"
require "pdfkit"
#
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end
#
require_relative    'ClStandards.rb'

# ==============================
# CLI options
# ==============================
# Options
    OPTS    = {                                         #specific options
        DEBUG:      false,
        DRYRUN:     false,
        LOGLEVEL:   'INFO',
        OUTPUT:     'PDF'
    }                         

    OptionParser.new do |o|
        o.banner = "Usage: ruby PrvPrintAchatsMedocs.rb [options] [apply]"
        o.on('--debug=DEBUG', 'Mode : Debug or not') { |v| OPTS[:DEBUG] = v }
        o.on('--level=INFO', 'Logger level') { |v| OPTS[:LOGLEVEL] = v }
        o.on('--output=PDF', 'Output type') { |v| OPTS[:OUTPUT] = v }
    end
    DRYRUN = (ARGV.last != "simul")

# Logger
    log                 = Logger.new(STDOUT)
    log.level           = OPTS[:LOGLEVEL].to_sym
    log.datetime_format = '%H:%M:%S'

    log.info "PRMS::LOG:#{OPTS[:LOGLEVEL]} - OUTPUT:#{OPTS[:OUTPUT]}"

# Variables
    arr_achats  = []
    ach_id      = '27472117-082a-80ac-92b8-000b3dd6b297'    # Data-Source Achats
    pat_id      = '27472117-082a-802e-a980-000bd75da62d'    # Data-Spource Patients
#
# Helpers
#********
#

#
# Main code
#**********
#
# Initialize
#***********

    stds = Standards.new([],'New')
#
# Run
#****
    log.info "Start of process."
    log.info "Reading file..."
    filtre  = { "property"=>"Etat","status"=>{"equals"=>"En achat"} }
    sorts   = [{ property: 'Patient', direction: 'ascending' }]
    achats  = stds.db_fetch(ach_id, filter: filtre, sort: sorts)

    ### pp achats

    log.info "Extract values"
    patient_old     = 'None'
    patient_name    = 'None'
    achats.each do |ach|
        props           = stds.get_properties(ach)
        patient_id      = props['Patient'][0]
        if patient_id != nil
            if patient_id != patient_old
                patient_page    = stds.page_get(patient_id)
                patient_props   = stds.get_properties(patient_page)
                patient         = patient_props['Référence']
                patient_old     = patient_id
                patient_name    = patient
            else
                patient = patient_name
            end
        else
            patient = 'None'
        end
        reference       = props['Référence']
        arr_achats.push([patient_name, reference])
    end

    ### pp arr_achats
#
# Save to .pdf
#*************
    if OPTS[:OUTPUT] == 'PDF'
        log.info "Make pdf"
        # Header
        html    = '<html><head></head><body><h1>Achat de médicaments</h1>'
        html    += '<table><caption>tableau</caption<thead><tr><th scop="col">Patient</th><th scope="col">Médicament</th></tr></thead><tbody>'
        # Body 
        result  = 0
        arr_achats.each do |ach|
            patient     = ach[0].to_s
            medicament  = ach[1].to_s
            html    += "<tr><td>#{patient}</td><td>#{medicament}</td></tr>"
            result  += 1
        end
        # Trailer
        html    += '</tbody><tfoot>'
        html    += '<tr><th scope = "row">Nombre</th><td>'
        html    +=  "#{result}"
        html    += '</td></tfoot></table>'
        html    += '</body></head>'

        log.info "Write pdf on disk"
        pdf = PDFKit.new(html, page_size:"A4", print_media_type: true)
        pdf.to_file("/users/Gilbert/Public/Private/ToSend/Achats_de_Medicaments.pdf")
    end

# Display
    if OPTS[:OUTPUT] == 'DIS'
        log.info "Display results"
        puts "\nAchat de médicaments :"
        arr_achats.each do |ach|
            puts "Patient: #{ach[0]}, Médicament: #{ach[1]}"
        end
        puts "Nombre total d'achats : #{arr_achats.size}\n"
    end


# Exit
    log.info "End of process."
    exit 0