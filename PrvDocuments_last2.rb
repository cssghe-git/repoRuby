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
        notion_version: "",
        notion_docid:   "20172117082a809784efeb6f051f8e0c",
        lecture_pages:  0,
        ecriture_pages: 0,
        eop:            "EOP"
    }
#-----------------------------
# Classes
#-----------------------------

# flow :
#   source
#   lecture
#   conversion format
#   écriture Notion

class   Source
#*************
    def initialize()
    #+++++++++++++
        LOG.info("Source::Module : #{__method__}")
    end #<def>

    def choixSource()
    #++++++++++++++
        LOG.info("Source::Module : #{__method__}")
        # Fichier ?
        if OPTIONS[:fichier] != 'none'
            if File.exist?(OPTIONS[:fichier])
                PRMS[:source_type]      = 'fichier'
                PRMS[:source_valeur]    = OPTIONS[:fichier]
                return  true
            else
                LOG.warn("Le fichier : #{OPTIONS[:fichier]} n'existe pas")
                return false
            end
        end

        # Dossier ?
        if OPTIONS[:dossier] != 'none'
            if Dir.exist?(OPTIONS[:dossier])
                PRMS[:source_type]      = 'dossier'
                PRMS[:source_valeur]    = OPTIONS[:fichier]
                return  true
            else
                LOG.warn("Le dossier : #{OPTIONS[:dossier]} n'existe pas")
                return  false
            end
        end

        # Scan ?

        # Conversion
        arr_documents   = {
            "Mes Documents" => "32e72117082a804c81c1ee636a1a42e3",
            "BVL.Documents" => "2c372117-082a-8033-b77a-000b4e5b6fb6",
            "DOC.Documents" => "33172117-082a-802c-b4aa-000b97e72313",
            "FIN.Documents" => "2c272117-082a-80ea-a31a-000b9f58c855",
            "INF.Documents" => "2c172117-082a-808d-8936-000b3ad03c19",
            "OFF.Documents" => "2c372117-082a-805a-9cca-000b6c71d553",
            "RES.Documents" => "8b7efb46fde248d19d7219b201b257b3",
            "SAN.Documents" => "2c372117-082a-8020-bd2a-000b4ec7a18b"
        }
        index   = 0
        LOG.info("Liste des dossiers-Documents à convertir")
        arr_documents.each_pair do |key, value|
            LOG.info("(#{index+1}) => #{key}")
            index   += 1
        end
        LOG.info("Choisissez votre dossier par son N°")
        print "? "
        selection = $stdin.gets.chomp.to_i
        return  false   unless selection > 0 and selection < arr_documents.size+1
        index   = 1
        fichier = ""
        dbid    = ""
        arr_documents.each_pair do |key, value|
            fichier = key
            dbid    = value
            break   unless index < selection
            index   += 1
        end
        PRMS[:source_type]      = 'conversion'
        PRMS[:notion_fichier]   = fichier
        PRMS[:notion_id]        = dbid
        PRMS[:notion_version]   = 'old'
        PRMS[:notion_version]   = 'new' if PRMS[:notion_id].include?('-')
        puts    "Source: conversion - Fichier: #{fichier}"
        return  true
    end

end #<classe source>

class   Lecture
#**************
    def initialize()
        LOG.info("Lecture::Module : #{__method__}")
    end #<def>

    def chargeFichier()
    +++++++++++++++++
        LOG.info("Lecture::Module : #{__method__}")
    end #<def>

    def chargeDossier()
    #++++++++++++++++
        LOG.info("Lecture::Module : #{__method__}")
        std = PRMS[:clstdnew]     if PRMS[:notion_version] == 'new'
        std = PRMS[:clstdold]     if PRMS[:notion_version] == 'old'
        arr_pages   = std.db_fetch(PRMS[:notion_id])
    end #<def>

    def chargeConversion()
    #+++++++++++++++++++
        LOG.info("Lecture::Module : #{__method__}")
        std = PRMS[:clstdnew]     if PRMS[:notion_version] == 'new'
        std = PRMS[:clstdold]     if PRMS[:notion_version] == 'old'
        arr_pages   = std.db_fetch(PRMS[:notion_id])
    end #<def>

end #<classe lecture>

class   Conversion
#*****************
    def initialize()
        LOG.info("Conversion::Module : #{__method__}")
    end #<def>

    def conversionMes(page)
    #++++++++++++++++
        LOG.info("Conversion::Module : #{__method__}")
        std = PRMS[:clstdnew]     if PRMS[:notion_version] == 'new'
        std = PRMS[:clstdold]     if PRMS[:notion_version] == 'old'
        ecr_properties  = {}
        arr_properties  = std.get_properties(page)
        puts    "Référence::Lecture:#{arr_properties['Référence']} - #{arr_properties['Statut']}"
        ecr_properties['Référence']     = std.title(arr_properties['Référence'])
        ecr_properties['Domaine']       = std.select("TBD")
        ecr_properties['Dossier_cnv']       = std.relation1(arr_properties['Dossier'][0])   unless arr_properties['Dossier'][0].nil?
        ecr_properties['Tags_cnv']          = std.relation1(arr_properties['Tags'][0])      unless arr_properties['Tags'][0].nil?
        ecr_properties['Type_cnv']          = std.relation1(arr_properties['Types'][0])     unless arr_properties['Types'][0].nil?
        ecr_properties['Emetteur_cnv']      = std.relation1(arr_properties['Emetteur'][0])  unless arr_properties['Emetteur'][0].nil?
        ecr_properties['Statut']        = std.status(arr_properties['Statut'])
        ecr_properties['FileContent']   = std.file_int(arr_properties['Fichier'][0], arr_properties['Référence'])   unless arr_properties['Fichier'][0].nil?

        return  ecr_properties
    end

    def conversionDoc(page, index=[])
    #++++++++++++++++
        std = PRMS[:clstdnew]     if PRMS[:notion_version] == 'new'
        std = PRMS[:clstdold]     if PRMS[:notion_version] == 'old'

        arr_properties  = std.get_properties(page)
        reference       = arr_properties['Référence']
        puts    "Référence::Lecture:#{reference} - #{arr_properties['Statut']}"

        unless  index.include?(reference)
            index.push(reference)
            ecr_properties  = {}
            ecr_properties['Référence']     = std.title(reference)
            ecr_properties['Domaine']       = std.select("TBD")
            ecr_properties['Dossier_cnv']       = std.relation1(arr_properties['Dossier'][0])   unless arr_properties['Dossier'][0].nil?
            ecr_properties['Tags_cnv']          = std.relation1(arr_properties['Tags'][0])      unless arr_properties['Tags'][0].nil?
            ecr_properties['Type_cnv']          = std.relation1(arr_properties['Type'][0])      unless arr_properties['Type'][0].nil?
            ecr_properties['Emetteur_cnv']      = std.relation1(arr_properties['Emetteur'][0])  unless arr_properties['Emetteur'][0].nil?
            ecr_properties['Statut']        = std.status(arr_properties['Statut'])
            ecr_properties['FileContent']   = std.file_int(arr_properties['Fichier'][0], arr_properties['Référence'])   unless arr_properties['Fichier'][0].nil?
        end
    #    puts    "Props_entrée::#{arr_properties}"
    #    puts    "Props_sortie::#{ecr_properties}"
        return  ecr_properties
    end

    def formatChamps(arr_pages)
    #+++++++++++++++
        LOG.info("Conversion::Module : #{__method__}")
    end #<def>

end #<classe conversion>

class   Ecriture
#***************
    def initialize()
        LOG.info("Ecriture::Module : #{__method__}")
    end #<def>

    def ajoutDossier(ecr_properties={})
    #+++++++++++++++
        std = PRMS[:clstdold]
        response    = std.page_create(PRMS[:notion_docid], ecr_properties)
        PRMS[:ecriture_pages]   += 1
    end #<def>

end #<classe ecriture
#
#   fin des classes
#------------------

#-----------------------------
# Fonctions
#-----------------------------
    def lesIndex()
    #***********
        std = PRMS[:clstdold]
        arr_index   = []
        pages_initiales = std.db_fetch(PRMS[:notion_docid]) do |page|
            page_props  = std.get_properties(page)
            arr_index.push(page_props['Référence'])
            true
        end

        return  arr_index
    end #<def>

    def run()
    #******
        LOG.info("Module : #{__method__}")
        arr_index       = []
        arr_pages       = {}
        ecr_properties  = {}
        #
        #UI
            LOG.info("--Les Index")
            arr_index = lesIndex()
            LOG.info("----#{arr_index.size} index")
        #
            LOG.info("--Choix de la source")
            source          = Source.new()
            PRMS[:clsource] = source
            PRMS[:source] = source.choixSource()
        #
            LOG.info("--Lecture des pages")
            lecture             = Lecture.new()
            PRMS[:cllecture]    = lecture
            case    PRMS[:source_type]
            when    'fichier'
                arr_pages = lecture.chargeFichier()   if PRMS[:source_type] == 'fichier'
            when    'dossier'
                arr_pages = lecture.chargeDossier()   if PRMS[:source_type] == 'dossier'
            when    'conversion'
                arr_pages = lecture.chargeConversion()   if PRMS[:source_type] == 'conversion'
            end
            PRMS[:lecture_pages]    = arr_pages.size
            LOG.info("----#{arr_pages.size} pages")
        #
            LOG.info("--Conversion des formats et Ajout")
            conversion          = Conversion.new
            PRMS[:clconversion] = conversion
            ecriture            = Ecriture.new()
            PRMS[:clecriture]   = ecriture
            case    PRMS[:source_type]
            when    'fichier'
            when    'dossier'
            when    'conversion'
                #UI
                    arr_pages.each do |page|
                        if PRMS[:notion_fichier] == "Mes Documents"
                            ecr_properties = conversion.conversionMes(page)
                        else
                            ecr_properties = conversion.conversionDoc(page, arr_index)
                        end
                        ecriture.ajoutDossier(ecr_properties) unless ecr_properties.nil?
                    end
                #UIend
            end
            LOG.info("----#{PRMS[:ecriture_pages]} pages")
        #UIend
    end #<run>

    # Utilisation
    #++++++++++++
    if __FILE__ == $0   #IF0>
        #UI
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
        #UIend #<UI>
    end #<IF0>

