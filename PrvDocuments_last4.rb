#!/usr/bin/env ruby
# encoding: UTF-8
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
#
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end
#
#
require_relative    'ClStandards.rb'
#
# Logger
    LOG                 = Logger.new(STDOUT)
    LOG.level           = :DEBUG
    LOG.datetime_format = '%H:%M:%S'

#-----------------------------
# Parmamètres
#-----------------------------
    p0  = ARGV[0] || nil    # mode : test, prod
    p1  = ARGV[1] || nil    # debug : oui, non
    p2  = ARGV[2] || nil    # dryrun : oui, non
    p3  = ARGV[3] || nil    # dossier : xyz, vide
    P4  = ARGV[4] || nil    # fichier : xyz, vide
#-----------------------------
# Options
#-----------------------------
    OPTIONS = {
        mode: "test",
        debug: "oui",
        dryrun: "oui",
        dossier: "none",
        fichier: "none"
    }
    OptionParser.new do |o|
        o.banner = "Usage: ruby PrvDocuments_Last.rb <options>"
        o.on("--mode=MODE", %w[test prod], "Mode") { |v| OPTIONS[:mode] = v }
        o.on("--debug=DEBUG", %w[oui non], "DEBUG") { |v| OPTIONS[:debug] = v }
        o.on("--dryrun=DRYRUN", %w[oui non], "DRYRUN") { |v| OPTIONS[:dryrun] = v }
        o.on("--dossier=DOSSIER","--répertoire","DOSSIER") { |v| OPTIONS[:dossier] = v }
        o.on("--fichier=FICHIER","--file","FICHIER") { |v| OPTIONS[:fichier] = v}
    end.parse!(ARGV)
    DRYRUN  = OPTIONS[:dryrun == "oui"] ? true : false

#-----------------------------
# Constantes
#-----------------------------
CONFIG              = JSON.parse(File.read(File.join(__dir__, "Data_Sources_ID2.json")))

#-----------------------------
# Variables
#-----------------------------
    PRMS    = {
        clstd_new:      "",
        clstdold:       "",
        cllecture:      "",
        clconversion:   "",
        clecriture:     "",
        clsource:       "",
        source_type:    "none",
        source_valeur:  "",
        notion_fichier: "",
        notion_id:      "",
        notion_bvl:     "2c372117-082a-8033-b77a-000b4e5b6fb6",
        notion_doc:     "33172117-082a-802c-b4aa-000b97e72313",
        notion_fin:     "2c272117-082a-80ea-a31a-000b9f58c855",
        notion_inf:     "2c172117-082a-808d-8936-000b3ad03c19",
        notion_off:     "2c372117-082a-805a-9cca-000b6c71d553",
        notion_san:     "2c372117-082a-8020-bd2a-000b4ec7a18b",
        notion_version: "",
        notion_docid:   "20172117082a809784efeb6f051f8e0c",
        lecture_pages:  0,
        ecriture_pages: 0,
        eop:            "EOP"
    }
#-----------------------------
# Classes
#-----------------------------
#
#   fin des classes
#------------------

#-----------------------------
# Fonctions
#-----------------------------
    def lesIndex()
    #***********
        stdold          = PRMS[:clstdold]
        pages_initiales = stdold.db_fetch(PRMS[:notion_docid])

        return  pages_initiales
    end #<def>

    def lesDocuments()
    #***************
        stdnew  = PRMS[:clstdnew]
        pages_index     = {}
        #
        LOG.info("----BVL")
        PRMS[:notion_fichier]   = 'BVL'
        pages_ref   = {}
        pages_documents = stdnew.db_fetch(PRMS[:notion_bvl])
        pages_documents.each do |page|
            props   = stdnew.get_properties(page)
            pages_ref[props['Référence']] = PRMS[:notion_fichier]
        end
        LOG.info("#{pages_documents.size} pages -> #{pages_ref.size} index")
        #
        LOG.info("----DOC")
        PRMS[:notion_fichier]   = 'DOC'
        pages_documents = stdnew.db_fetch(PRMS[:notion_doc])
        pages_ref   = {}
        pages_documents.each do |page|
            props   = stdnew.get_properties(page)
            pages_ref[props['Référence']] = PRMS[:notion_fichier]
        end
        pages_index = pages_index.merge(pages_ref)
        LOG.info("#{pages_documents.size} pages -> #{pages_ref.size} index")
        #
        LOG.info("----FIN")
        PRMS[:notion_fichier]   = 'FIN'
        pages_documents = stdnew.db_fetch(PRMS[:notion_fin])
        pages_ref   = {}
        pages_documents.each do |page|
            props   = stdnew.get_properties(page)
            pages_ref[props['Référence']] = PRMS[:notion_fichier]
        end
        pages_index = pages_index.merge(pages_ref)
        LOG.info("#{pages_documents.size} pages -> #{pages_ref.size} index")
        #
        LOG.info("----INF")
        PRMS[:notion_fichier]   = 'INF'
        pages_documents = stdnew.db_fetch(PRMS[:notion_inf])
         pages_ref   = {}
        pages_documents.each do |page|
            props   = stdnew.get_properties(page)
            pages_ref[props['Référence']] = PRMS[:notion_fichier]
        end
        pages_index = pages_index.merge(pages_ref)
        LOG.info("#{pages_documents.size} pages -> #{pages_ref.size} index")
        #
        LOG.info("----OFF")
        PRMS[:notion_fichier]   = 'OFF'
        pages_documents = stdnew.db_fetch(PRMS[:notion_off])
        pages_ref   = {}
        pages_documents.each do |page|
            props   = stdnew.get_properties(page)
            pages_ref[props['Référence']] = PRMS[:notion_fichier]
        end
        pages_index = pages_index.merge(pages_ref)
        LOG.info("#{pages_documents.size} pages -> #{pages_ref.size} index")
        #
        LOG.info("----SAN")
        PRMS[:notion_fichier]   = 'SAN'
        pages_documents = stdnew.db_fetch(PRMS[:notion_san])
        pages_ref   = {}
        pages_documents.each do |page|
            props   = stdnew.get_properties(page)
            pages_ref[props['Référence']] = PRMS[:notion_fichier]
        end
        pages_index = pages_index.merge(pages_ref)
        LOG.info("#{pages_documents.size} pages -> #{pages_ref.size} index")
        #

        return  pages_index     #{reference => domaine}
    end #<def>

    def domaine(arr_properties={}, pages_index={})
    #**********
        reference   = arr_properties['Référence']
        domaine = pages_index.fetch(reference, 'TBD')

        return  domaine
    end #<def>

    def dossier(arr_properties={})
    #**********
        reference   = arr_properties['Référence']
        dossier     = ''
        dossier_cnv = arr_properties['Dossier_cnv']
        unless dossier_cnv.nil?
            page    = stdold.page_get(dossier_cnv)
        end
    end #<def>

    def run()
    #******
        LOG.info("Module : #{__method__}")
        pages_initiales = {}
        pages_index     = {}
        arr_pages       = {}
        arr_properties  = {}
        ecr_properties  = {}
        #
        LOG.info("--Les Index")
        pages_initiales = lesIndex()
        LOG.info("----#{pages_initiales.size} index")
        #
        LOG.info("--Les Documents")
        pages_index = lesDocuments().sort
        LOG.info("----#{pages_index.size} index")
        #
        LOG.info("--Traitement")
        stdold  = PRMS[:clstdold]
        count   = 0
        pages_initiales.each do |page|
            puts    "Nombre: #{count}"  if count%100 == 0
            flag_maj        = false
            ecr_properties  = {}
            page_id         = page["id"]
            arr_properties  = stdold.get_properties(page)
        #    puts    "Référence: #{arr_properties['Référence']} -Domaine: #{arr_properties['Domaine']}"

            if arr_properties['Domaine'].nil? or arr_properties['Domaine'] == 'TBD'
                ecr_properties['Domaine']   = stdold.select(domaine(arr_properties, pages_index))
                flag_maj                    = true
            end

        #    if arr_properties['Dossier'].nil?
        #        ecr_properties['Dossier']   = dossier(arr_properties)
        #        flag_maj                    = true
        #    end

            if flag_maj
                puts    "Référence: #{arr_properties['Référence']} -Domaine: #{ecr_properties['Domaine']}"
                response    = stdold.page_update(page_id, ecr_properties)
            end
        end
    end #<def>

    # Utilisation
    #++++++++++++
    if __FILE__ == $0   #IF0>
        # initialisations
        LOG.info("Step 1 : Initialisations")
        stdold  = Standards.new([],'Old', false)
        PRMS[:clstdold] = stdold
        stdnew  = Standards.new([],'New', false)
        PRMS[:clstdnew] = stdnew
        #
        LOG.info("Step 2 : exécution")
        run()
        #
        LOG.info("Step 3 : fin")
    end #<IF0>
