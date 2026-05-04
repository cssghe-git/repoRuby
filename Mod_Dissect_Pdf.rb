# frozen_string_literal: true

#
#         Class:      M25_Members
#         Inherit:    Standards
#         Goals:      MBR common commands
#         Functions:  Initialize()

# Requires
begin
    require 'dotenv'
    Dotenv.load
rescue LoadError
end
require 'logger'
require 'hexapdf'

module Dissect_Pdf
    # *****************
    # require_relative 'Mod_Dissect_Pdf.rb'
    # include Dissect_Pdf
    #
    # ************************
    class Dissect
        # ************************
        #
        #
        # Class variables
        #================
        @@dissect_instances = 0
        # Logger
        @@log_mod = "DIS:#{__method__}::"

        @@categories = {
            invoice: ['facture', 'tva', 'montant', 'numero facture', 'societe', 'vat'],
            contract: ['contrat', 'clauses', 'force majeure', 'acceptation'],
            report: %w[rapport bilan analyse synthese],
            cv: %w[cv curriculum compétences experience]
        }

        # Instance variables
        #==================
        # Getter & Setter
        #++++++++++++++++
        attr_accessor   :doc, :allpages, :allpages_count, :meta_data
        attr_accessor   :arr_pages

        # Instance methods
        #=================

        # Initialize instance
        def initialize(options: [], file: nil, debug: false)
            #++++++++++++++
            #   1.create instances variables
            #
            puts    debug_vars      if debug
            @file   = file
            @debug  = debug
            @@log.info @@log_mod + "DIS->New instance settings for: #{file}" if @debug
            raise       if file.nil?

            @meta_data  = {}
            @arr_pages  = []

            @doc            = HexaPDF::Document.open(file)
            @allpages       = @doc.pages
            @allpages_count = @doc.pages.count
            @allpages_count.times do |index|
                text = @allpages[index].extract_text
                @arr_pages.push(text) unless text.nil?
            end

            @@dissect_instances += 1
        end

        # Get metadata
        def get_metadata
            #+++++++++++++++
            #   extract some metadata
            #
            @meta_data['title']      = @doc.trailer[:Info][:Title]
            @meta_data['author']     = @doc.trailer[:Info][:Author]
            @meta_data['date']       = @doc.trailer[:Info][:CreationDate]
            @meta_data['producer']   = @doc.trailer[:Info][:Producer]

            @meta_data
        end

        # Compute Category
        def get_category(text: nil)
            #+++++++++++++++
            #   copute category according score of keywords
            #
            text = (text.nil? ? @alltext : text) || ''
            text_downcase = text.downcase
            candidates = {}
            @@categories.each do |cat, keywords|
                score = keywords.count { |kw| text_downcase.include?(kw) }
                candidates[cat] = score if score.positive?
            end
            candidates.max_by { |_, score| score }&.first
        end
    end
end
