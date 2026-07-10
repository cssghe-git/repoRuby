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
    p0  = ARGV[0] || nil    # Titre
    p1  = ARGV[1] || nil    # Date & heure début
    p2  = ARGV[2] || nil    # Date & heure fin
    p3  = ARGV[3] || nil    # Lieu
#-----------------------------
# Options
#-----------------------------
    OPTIONS = {
        mode:   "loop",
        debug:  "oui",
        dryrun: "oui",
        prop_nom: "Nom",
        prop_date:  "Date",
        prop_lieu:  "Lieu",
        props:  "none"
    }
    DRYRUN  = OPTIONS[:dryrun == "oui"] ? true : false

#-----------------------------
# Constantes
#-----------------------------
CONFIG              = JSON.parse(File.read(File.join(__dir__, "Data_Sources_ID2.json")))

#-----------------------------
# Variables
#-----------------------------
    PRMS    = {
        mode:               "loop",
        evnom:              "",
        evdebut:            "",
        evfin:              "",
        evlieu:             "Maison",
        evformat:           "En personne",
        evbusycal:          true,
        eop:                "EOP"
    }
#-----------------------------
# Initialisations
#-----------------------------
    LOG.info("Initialisations")
    stdnew      = Standards.new()              #nouvelle instance de ClStandards
    db_id       = CONFIG.find{ |k| k.key?("Evénements")}&.fetch("Evénements") #Evénements

#-----------------------------
# On boucle ou une fois seulement
#--------------------------------
    while   PRMS[:mode] == "loop"

#-----------------------------
# Acquisition des valeurs
#-----------------------------
        LOG.info("Acquisitions")
        if ARGV.size == 0
            print   "Nouvel événement ? (o/n) "
            rep = $stdin.gets.chomp
            break   unless rep == "o"

            LOG.info("--suivant les paramètres reçus")
            print   "Le titre de l'événement : "
            PRMS[:evnom]    = $stdin.gets.chomp

            print   "La date/heure de début : "
            PRMS[:evdebut]  = $stdin.gets.chomp

            print   "La date/heure de fin (fac) : "
            PRMS[:evfin]    = $stdin.gets.chomp

            print   "Le lieu : "
            PRMS[:evlieu]   = $stdin.gets.chomp
        else
            PRMS[:mode]     = "param"
            LOG.info("Suivant les questions")
            PRMS[:evnom]    = p0 unless p0.nil? || p0.empty?
            PRMS[:evdebut]  = p1 unless p1.nil? || p1.empty?
            PRMS[:evfin]    = p2 unless p2.nil? || p2.empty?
            PRMS[:evlieu]   = p3 unless p3.nil? || p3.empty?
        end
#-----------------------------
# Formation des propriétés de la page
#-----------------------------
        LOG.info("Formattage des proriétés")
        # nom

        # date & heure début
        exit 4 unless PRMS[:evdebut] && !PRMS[:evdebut].empty?
        case PRMS[:evdebut].size
        when 5  #HH:MM
            PRMS[:evdebut] = DateTime.now.strftime("%Y-%m-%d ") + PRMS[:evdebut]
        when 8  #DD@HH:MM
            PRMS[:evdebut] = DateTime.now.strftime("%Y-%m-") + PRMS[:evdebut].gsub("@", " ")
        when 11 #MM-DD@HH:MM
            PRMS[:evdebut] = DateTime.now.strftime("%Y-") + PRMS[:evdebut].gsub("@", " ")
        end

        # date & heure fin
        if PRMS[:evfin] && !PRMS[:evfin].empty?
            case PRMS[:evfin].size
            when 5  #HH:MM
                PRMS[:evfin] = DateTime.now.strftime("%Y-%m-%d ") + PRMS[:evfin]
            when 8  #DD@HH:MM
                PRMS[:evfin] = DateTime.now.strftime("%Y-%m-") + PRMS[:evfin].gsub("@", " ")
            when 11 #MM-DD@HH:MM
                PRMS[:evfin] = DateTime.now.strftime("%Y-") + PRMS[:evfin].gsub("@", " ")
            end
        end

        # lieu
        PRMS[:evlieu] = "Maison"    if PRMS[:evlieu].nil? || PRMS[:evlieu].empty?

        LOG.info("--Bloc Notion")
        props               = {}
        props["Nom"]        = stdnew.title(PRMS[:evnom])
        props["Date"]       = stdnew.date_iso(PRMS[:evdebut])                      if PRMS[:evfin].nil? || PRMS[:evfin].empty?
        props["Date"]       = stdnew.date_stop_iso(PRMS[:evdebut], PRMS[:evfin])   unless PRMS[:evfin].nil? || PRMS[:evfin].empty?
        props["Lieu"]       = stdnew.select(PRMS[:evlieu])
        props["Format"]     = stdnew.select(PRMS[:evformat])
        props["BusyCal"]    = stdnew.chkb(PRMS[:evbusycal])
#-----------------------------
# Envoi de la requête
#-----------------------------
#       pp PRMS
        pp props
        LOG.info("Envoi de la requète")
        response = stdnew.page_create(db_id, props)
        LOG.info("--Réponse Notion")
#       pp response
#-----------------------------
# envoi à BusyCal
#-----------------------------
        LOG.info("Envoi à BusyCal")
        response = system("osascript",
            "/Users/Gilbert/Applications/AddEventBusyCalNotion2.scpt",
            PRMS[:evnom].to_s,
            PRMS[:evdebut].to_s,
            PRMS[:evfin].to_s,
            PRMS[:evlieu]
            )
        LOG.info("--Réponse BusyCal")
        pp response

    end #<while loop>
#<EOS>