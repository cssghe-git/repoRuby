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
require_relative 'ClStandards'

module M25_Cotis
    # *****************
    # require_relative 'Mod_M25_Cotis.rb'
    # include M25_Cotis
    #
    # ************************
    class Cotis < Standards
        # ************************
        #
        #
        # Class variables
        #================
        @@cotis_instances = 0
        # Logger
        @@log_cot = "COT:#{__method__}::"

        # Instance variables
        #==================
        # Getter & Setter
        #++++++++++++++++
        attr_accessor :cdc_pages, :act_pages, :mbr_pages, :cot_pages
        attr_accessor :cdc_ids, :act_ids, :mbr_ids, :mbr_properties, :mbr_selpages, :mbr_values, :cot_properties,
                      :cot_selpages, :cot_values, :mbr_hash, :cdc_hash, :act_hash, :cot_hash

        # Instance methods
        #=================

        # Initialize instance
        def initialize(options = [], old = 'New', debug = false)
            #++++++++++++++
            #   1.initialize parent
            #   2.create instances variables
            #
            puts    debug_vars if debug
            @debug  = debug
            super(options, 'New', debug) # call parent initialize
            @@log.info @@log_cot + "COT->New instance settings - style: #{old}" if @debug

            @cdc_id     = getDbId('m25t.CDC')
            @mbr_id     = getDbId('m25t.Membres')
            @act_id     = getDbId('m25t.Activités')
            @cot_id     = getDbId('m25t.Cotisations')
            @cdc_pages  = []
            @act_pages  = []
            @mbr_pages  = []
            @cot_pages  = []
            @hash_mbr   = {}
            @hash_cdc   = {}
            @hash_act   = {}
            @hash_cot   = {}

            @@cotis_instances += 1
        end

        # Load tables : CDC, ACT, MBR all pages & COT all pages
        def load_tables(filter: nil, sort: nil)
            #++++++++++++++
            #   1.CDC
            #   2.ACT
            #   3.MBR
            #   4.COT
            #
            @@log.info "#{@@log_mbr}Load tables: CDC - ACT - MBR - COT" if @debug
            # 1A-Load CDC
            @cdc_pages  = db_fetch(@cdc_id)
            # 1B-save ids of CDC pages in @cdc_ids => { 'Référence' => id }
            @cdc_ids    = {}
            @cdc_pages.each do |page|
                page_props                          = get_properties(page)
                @cdc_ids[page_props['Référence']]   = page['id']
                @hash_cdc[page_props['Référence']]  = page
            end
            @@log.info @@log_mbr + "CDC: #{@cdc_pages.size}" if @debug

            # 2A-load ACT
            @act_pages  = db_fetch(@act_id)
            # 2B-save ids of ACT pages in @act_ids => { 'Référence' => id }
            @act_ids    = {}
            @act_pages.each do |page|
                page_props                          = get_properties(page)
                @act_ids[page_props['Référence']]   = page['id']
                @hash_act[page_props['Référence']]  = page
            end
            @@log.info @@log_mbr + "ACT: #{@act_pages.size}" if @debug

            # 3-load MBR pages with filter & sort
            @mbr_pages = db_fetch(@mbr_id, filter: filter, sort: sort)
            @@log.info @@log_mbr + "MBR: #{@mbr_pages.size}" if @debug
            @mbr_pages.each do |page|
                page_props                          = get_properties(page)
                @hash_mbr[page_props['Référence']]  = page
            end
            @mbr_selpages = @mbr_pages

            # 4-Load COT
            @cot_pages = db_fetch(@cot_id)
            @@log.info @@log_mbr + "COT: #{@cot_pages.size}" if @debug
            @cot_pages.each do |page|
                page_props                          = get_properties(page)
                @hash_cot[page_props['Référence']]  = page
            end
        end

        # Select pages
        def select_pages
            #+++++++++++++++++
            #   funct:  select on all pages read
            #   call:   cotis.select_pages do |page, properties|
            #               select page by yield if return true
            #           end
            #
            @@log.info "#{@@log_cot}Select COT pages" if @debug
            @cot_selpages   = []
            @cot_selpages   = @cot_pages.select do |page| # select
                yield(page, get_properties(page)) ? true : false
            end
            @@log.info @@log_cot + "SEL: #{@cot_selpages.size}" if @debug
        end

        # Process all pages
        def process_pages
            #++++++++++++++++
            #   funct:  process on all pages selected
            #   call:   cotis.process_pages do |page, properties, values|
            #               # process page, properties and values by yield
            #           end
            #   properties: hash of page properties with their types and values
            #   values:     hash of values with their raw values (e.g. id, )
            #
            @@log.info "#{@@log_cot}Process COT pages" if @debug
            @cot_selpages.each do |page|
                @cot_values = {} # {id: , ?}
                # Process page
                @cot_properties     = {}
                @cot_properties     = get_properties(page)
                @cot_values['id']   = page['id']
                yield(page, @cot_properties, @cot_values) if block_given?
            end
        end

        # Create hash members
        def create_cot_hash(pages = [])
            #++++++++++++++++++
            #   create a hash for cotis requested => {ref: page}
            #
            @@log.info "#{@@log_cot}Create COT hash" if @debug
            @cot_hash = {}
            pages.each do |page|
                @cot_properties = get_properties(page)
                @cot_hash[@cot_properties['Référence']] = page
            end
        end

        # format new properties
        def new_properties(funct: nil)
            #+++++++++++++++++
            # 1-Automations

            # 2-Direct
            props = {}
            props['Référence'] = title(@cot_properties['Référence'])
            # ... other properties

            # 3-Add or Update
            page_create(@dbid, properties: props)               if funct == 'create'
            page_update(@cot_values[:id], properties: props)    if funct == 'update'
        end
    end
end
