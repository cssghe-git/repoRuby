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
        relation_dossier:   "35972117-082a-80e2-bc2c-000b528b61be",
        relation_tags:      "35972117-082a-80a0-b8bd-000b8185135c",
        relation_types:     "35972117-082a-80d1-b7b7-000b74157f86",
        relation_emetteurs: "37472117-082a-8001-be4d-000ba509339e",
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

        return  pages_initiales     #{page, ...}
    end #<def>

    def lesDossiers()
    #**************
        stdnew          = PRMS[:clstdnew]
        pages_dossiers  = {}
        rel_dossiers    = {}
        LOG.info("----Dossiers")
        pages_dossiers  = stdnew.db_fetch(PRMS[:relation_dossier])
        pages_dossiers.each do |page|
            props   = stdnew.get_properties(page)
            key     = props['Référence']
            rel_dossiers[key] = page["id"]
        end
        return  rel_dossiers     #{key => relation, ...}
    end

    def lesTags()
    #**************
        stdnew          = PRMS[:clstdnew]
        pages_tags      = {}
        rel_tags        = {}
        LOG.info("----Tags")
        pages_tags      = stdnew.db_fetch(PRMS[:relation_tags])
        pages_tags.each do |page|
            props       = stdnew.get_properties(page)
            key         = props['Référence']
            rel_tags[key]   = page["id"]
        end
        return  rel_tags     #{key => relation, ...}
    end
    
    def lesEmetteurs()
    #***************
        stdnew          = PRMS[:clstdnew]
        pages_emetteurs = {}
        rel_emetteurs   = {}
        LOG.info("----Emetteurs")
        pages_emetteurs = stdnew.db_fetch(PRMS[:relation_emetteurs])
        pages_emetteurs.each do |page|
            props       = stdnew.get_properties(page)
            key         = props['Référence']
            rel_emetteurs[key] = page["id"]
        end
        return  rel_emetteurs     #{key => relation, ...}
    end
    
    def lesTypes()
    #***************
        stdnew          = PRMS[:clstdnew]
        pages_types     = {}
        rel_types       = {}
        LOG.info("----Types")
        pages_types     = stdnew.db_fetch(PRMS[:relation_types])
        pages_types.each do |page|
            props       = stdnew.get_properties(page)
            key         = props['Référence']
            rel_types[key] = page["id"]
        end
        return  rel_types     #{key => relation, ...}
    end
    
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
        LOG.info("----#{pages_documents.size} pages -> #{pages_ref.size} index")
        #
        LOG.info("----DOC")
        PRMS[:notion_fichier]   = 'DOC'
        pages_documents = stdnew.db_fetch(PRMS[:notion_doc])
        pages_ref   = {}
        pages_documents.each do |page|
            props   = stdnew.get_properties(page)
            pages_ref[props['Référence']] = PRMS[:notion_fichier]
        end
        LOG.info("----#{pages_documents.size} pages -> #{pages_ref.size} index")
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
        LOG.info("----#{pages_documents.size} pages -> #{pages_ref.size} index")
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
        LOG.info("----#{pages_documents.size} pages -> #{pages_ref.size} index")
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
        LOG.info("----#{pages_documents.size} pages -> #{pages_ref.size} index")
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
        LOG.info("----#{pages_documents.size} pages -> #{pages_ref.size} index")
        #

        return  pages_index.sort     #{reference => domaine}
    end #<def>

    def trt_domaine(arr_properties={}, pages_index={})
    #**************
        reference   = arr_properties['Référence']
        domaine     = pages_index.fetch(reference, 'TBD')

        return  domaine
    end #<def>

    def trt_dossier(arr_properties={}, rel_dossiers={})
    #**************
        reference   = arr_properties['Référence']
        dossier     = ''
       dossier_cnv = arr_properties['Dossier_cnv'][0]  unless arr_properties['Dossier_cnv'].nil?
        unless dossier_cnv.nil?
            stdold      = PRMS[:clstdold]
            page        = stdold.page_get(dossier_cnv)
            props       = stdold.get_properties(page)
            dossier     = props['Nom']
            relation    = rel_dossiers.fetch(dossier, nil)
            puts "DBG>trtDossier>Relation:#{relation}"
        end

        return  relation
    end #<def>

    def trt_tag(arr_properties={}, rel_tags={})
    #**************
        reference   = arr_properties['Référence']
        tag         = ''
        tag_cnv     = arr_properties['Tags_cnv'][0]  unless arr_properties['Tags_cnv'].nil?
        unless tag_cnv.nil?
            stdold      = PRMS[:clstdold]
            page        = stdold.page_get(tag_cnv)
            props       = stdold.get_properties(page)
            tag         = props['Nom']
            relation    = rel_tags.fetch(tag, nil)
            puts "DBG>trtTag>Relation:#{relation}"
        end

        return  relation
    end #<def>

    def trt_type(arr_properties={}, rel_types={})
    #**************
        reference   = arr_properties['Référence']
        type         = ''

        type_cnv     = arr_properties['Type_cnv'][0]  unless arr_properties['Type_cnv'].nil?
        unless type_cnv.nil?
            stdold      = PRMS[:clstdold]
            page        = stdold.page_get(type_cnv)
            props       = stdold.get_properties(page)
            type         = props['Nom']
            relation    = rel_types.fetch(type, nil)
            puts "DBG>trtType>Relation:#{relation}"
        end

        return  relation
    end #<def>

    def trt_emetteur(arr_properties={}, rel_emetteurs={})
    #**************
        reference   = arr_properties['Référence']
        emetteur         = ''
    #    puts    "DBG>trtEmetteur>#{arr_properties['Emetteur_cnv']}"
        emetteur_cnv     = arr_properties['Emetteur_cnv'][0]  unless arr_properties['Emetteur_cnv'].nil?
        unless emetteur_cnv.nil?
            stdold      = PRMS[:clstdold]
            page        = stdold.page_get(emetteur_cnv)
    #        puts "DBG>trtEmetteur>Page:#{page}"
            props       = stdold.get_properties(page)
    #        puts "DBG>trtEmetteur>Props:#{props}"
            emetteur         = props['Nom']
            relation    = rel_emetteurs.fetch(emetteur, nil)
            puts "DBG>trtEmetteur>Relation:#{relation}"
        end

        return  relation
    end #<def>

    def run()
    #******
        LOG.info("Module : #{__method__}")
        pages_initiales = {}
        rel_dossiers    = {}
        rel_tags        = {}
        rel_emetteurs   = {}
        rel_types       = {}
        pages_index     = {}
        arr_pages       = {}
        arr_properties  = {}
        ecr_properties  = {}
        #
        LOG.info("--Les Index")
        pages_initiales = lesIndex()
        LOG.info("----#{pages_initiales.size} index")
        #
        LOG.info("--Les Relations")
        rel_dossiers    = lesDossiers()
        LOG.info("----#{rel_dossiers.size} relations")
        rel_tags        = lesTags()
        LOG.info("----#{rel_tags.size} relations")
        rel_emetteurs   = lesEmetteurs()
        LOG.info("----#{rel_emetteurs.size} relations")
        rel_types       = lesTypes()
        LOG.info("----#{rel_types.size} relations")
        
        #
        LOG.info("--Les Documents")
        pages_index = lesDocuments()
        LOG.info("----#{pages_index.size} index")

        #
        LOG.info("--Traitement")
        stdold  = PRMS[:clstdold]
        count   = 0
        nbr_ecrits = 0
        pages_initiales.each do |page|
            puts    "Nombre: #{count}"  if count%100 == 0
            flag_maj        = false
            arr_properties  = {}
            ecr_properties  = {}
            page_id         = page["id"]
            arr_properties  = stdold.get_properties(page)
            puts    "Référence: #{arr_properties['Référence']} -Dossier: #{arr_properties['Dossier']} : #{arr_properties['Dossier_cnv']}"
            # Domaine
        #    if arr_properties['Domaine'].nil? or arr_properties['Domaine'] == 'TBD'
        #        ecr_properties['Domaine']   = stdold.select(trt_domaine(arr_properties, pages_index))
        #        flag_maj                    = true
        #    end
            # Dossier
            puts    "DBG>Dossier>#{arr_properties['Dossier'].size} - #{arr_properties['Dossier_cnv'].size}"
            if arr_properties['Dossier'].size==0 and arr_properties['Dossier_cnv'].size>0
                relation   = trt_dossier(arr_properties, rel_dossiers)
                puts    "Dossier: #{arr_properties['Référence']} -Dossier: #{arr_properties['Dossier']} -ID: #{relation}"
                unless relation.nil?
                    ecr_properties['Dossier']   = stdold.relation1(relation)
                    flag_maj                    = true
                end
            end

            # Tags
            puts    "DBG>Tags>#{arr_properties['Tags'].size} - #{arr_properties['Tags_cnv'].size}"
            if arr_properties['Tags'].size==0 and arr_properties['Tags_cnv'].size>0
                relation   = trt_tag(arr_properties, rel_tags)
                puts    "Tags: #{arr_properties['Référence']} -Tags: #{arr_properties['Tags']} -ID: #{relation}"
                unless relation.nil?
                    ecr_properties['Tags']      = stdold.relation1(relation)
                    flag_maj                    = true
                end
            end

            # Emmetteurs
            puts    "DBG>Emetteurs>#{arr_properties['Emetteur'].size} - #{arr_properties['Emetteur_cnv'].size}"
            if arr_properties['Emetteur'].size==0 and arr_properties['Emetteur_cnv'].size>0
                relation   = trt_emetteur(arr_properties, rel_emetteurs)
                puts    "Emetteur: #{arr_properties['Référence']} -Emetteur: #{arr_properties['Emetteurs']} : #{relation}"
                unless relation.nil?
                    ecr_properties['Emetteur'] = stdold.relation1(relation)
                    flag_maj                    = true
                end
            end

            # Types
            puts    "DBG>Types>#{arr_properties['Type'].size} - #{arr_properties['Type_cnv'].size}"
            if arr_properties['Type'].size==0 and arr_properties['Type_cnv'].size>0
                relation   = trt_type(arr_properties, rel_types)
                puts    "Type: #{arr_properties['Référence']} -Types: #{arr_properties['Type']} -ID: #{relation}"
                unless relation.nil?
                    ecr_properties['Type'] = stdold.relation1(relation)
                    flag_maj                    = true
                end
            end

            #
            if flag_maj
                puts    "Référence: #{arr_properties['Référence']} -valeurs: #{ecr_properties}"
                response    = stdold.page_update(page_id, ecr_properties)
                nbr_ecrits += 1
            #    exit 9
            end
            count += 1
        end
        LOG.info("Nombre de pages traitées : #{count}")
        LOG.info("Nombre de pages écrites : #{nbr_ecrits}")
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
