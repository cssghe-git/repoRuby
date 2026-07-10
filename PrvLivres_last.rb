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

#-----------------------------
# Variables
#-----------------------------
    PRMS    = {
        clstd_new:      "",
        clstdold:       "",
        cllecture:      "",
        clecriture:     "",
        lecture_pages:  0,
        ecriture_pages: 0,
        notion_passions_id: "8055cff596214c31a5d91848a9dbf109",
        notion_livres_id:   "",
        notion_auteurs_id:  "35872117082a80338d15e164a703ef05",
        eop:            "EOP"
    }
#-----------------------------
# Code
#-----------------------------
    LOG.info("Initialisations")
    stdold  = ClStandards.new([], "Old")
    stdnew  = ClStandards.new([], "New")
    #
    LOG.info("Step 1 - Lecture des livres (ancienne version)")
    arr_livres_old = stdold.db_fetch(PRMS[:notion_passions_id])
    arr_livres_old.each do |livre|
        props = stdold.get_properties(livre)
        reference   = props['Reference']
        auteur      = props['Auteur']
        livres_old[reference] = {
            'Auteur' => auteur,
            'id' => livre['id']
        }
    end
    LOG.info("--#{livres_old.size} pages lues dans l'ancienne version")
    #
    LOG.info("Step 2 - Lecture des Auteurs (nouvelle version)")

    LOG.info("Step 3 - Lecture des livres (nouvelle version)")
    arr_livres_new = stdnew.db_fetch(PRMS[:notion_livres_id])
    arr_livres_new.each do |livre|
        props = stdnew.get_properties(livre)
        reference   = props['Reference']
        auteur      = props['Auteur']
        livres_new[reference] = {
            'id' => livre['id']
        }
    end