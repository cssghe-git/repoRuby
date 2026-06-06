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

require 'huh' 

module  SelectDocs
*******************
    # Load <Domaines>
    def self.load_domaines()
    #++++++++++++++++++++
        arr_domaines = {
            'BVL' : 'Bénévolats'
        }

        return arr_domaines
    end #def>

    # Détermine <Domaines>
    def self.determine_domaine()
    #+++++++++++++++++++++++++
        arr_domaines = self.load_domaines() if arr_domaines.empty?
    end #def>

    # Load <Dossiers>
    def self.load_dossiers()
    #+++++++++++++++++++++
        arr_dossiers = self.api_function('Fetch', 'Dossiers')
    end #def>

    # Détermine <Dossiers>
    def self.determine_dossier()
    #+++++++++++++++++++++++++
        arr_dossiers = self.load_dossiers() if arr_dossiers.empty?
    end #def>
end #<Module>