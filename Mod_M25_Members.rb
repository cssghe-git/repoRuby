# frozen_string_literal: true
#
=begin
        Class:      M25_Members
        Inherit:    Standards
        Goals:      MBR common commands
        Functions:  Initialize()
                    load_tables(filter & sort for MBR)  => CDC, ACT, MBR, COT
                                                        => @mbr_pages, @hash_mbr
                                                        => @cdc_pages, @hash_cdc
                                                        => @act_pages, @hash_act
                                                        => @cot_pages, @hash_cot
                    select_pages(all pages after GET)   => yield bloc
                    process_pages(all pages after SEL)  => yield bloc
                    create_mbr_hash(pages required)     => @hash_mbr
=end

# Requires
begin
  require "dotenv"; Dotenv.load
rescue LoadError
end
require 'logger'
require_relative 'ClStandards.rb'

module M25_Members
#*****************
    # require_relative 'Mod_M25_Members.rb'
    # include M25_Members
    #
    #************************
    class Members < Standards
    #************************
    #
    
    #
    # Class variables
    #================
        @@Members_instances = 0
        # Logger
        @@log_mbr   ="MBR:#{__method__}::"

    # Instance variables
    #==================
    # Getter & Setter
    #++++++++++++++++
        attr_accessor   :cdc_pages, :act_pages, :mbr_pages, :cot_pages
        attr_accessor   :cdc_ids, :act_ids
        attr_accessor   :mbr_properties, :mbr_selpages
        attr_accessor   :mbr_values, :hash_mbr, :hash_cdc, :hash_act, :hash_cot

    # Instance methods
    #=================

    # Initialize instance
    def initialize(options=[], old='New', debug=false)
    #++++++++++++++
    #   1.initialize parent
    #   2.create instances variables
    #
        puts    debug_vars      if @debug
        @debug  = debug
        super(options, 'New', debug)  #call parent initialize
        @@log.info @@log_mbr + "MBR->New instance settings - style: #{old}"   if @debug

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

        @@Members_instances += 1
    end #<def>

    # Load tables : CDC, ACT, MBR all pages & COT all pages
    def load_tables(filter: nil, sort: nil)
    #++++++++++++++
    #   1.CDC
    #   2.ACT
    #   3.MBR
    #   4.COT
    #
        @@log.info @@log_mbr + "Load tables: CDC - ACT - MBR"   if @debug
        #1A-Load CDC
        @cdc_pages  = db_fetch(@cdc_id)
        #1B-save ids of CDC pages in @cdc_ids => { 'Référence' => id }
        @cdc_ids    = {}
        @cdc_pages.each do |page|
            page_props                          = get_properties(page)
            @cdc_ids[page_props['Référence']]   = page['id']
            @hash_cdc[page_props['Référence']]  = page
        end
        @@log.info @@log_mbr + "CDC: #{@cdc_pages.size}"    if @debug

        #2A-load ACT 
        @act_pages  = db_fetch(@act_id)
        #2B-save ids of ACT pages in @act_ids => { 'Référence' => id }
        @act_ids    = {}
        @act_pages.each do |page|
            page_props                          = get_properties(page)
            @act_ids[page_props['Référence']]   = page['id']
            @hash_act[page_props['Référence']]  = page
        end
        @@log.info @@log_mbr + "ACT: #{@act_pages.size}"    if @debug

        #3-load MBR pages with filter & sort
        @mbr_pages  = db_fetch(@mbr_id, filter: filter, sort: sort)
        @@log.info @@log_mbr + "MBR: #{@mbr_pages.size}"    if @debug
        @mbr_pages.each do |page|
            page_props                          = get_properties(page)
            @hash_mbr[page_props['Référence']]  = page
        end
        @mbr_selpages   = @mbr_pages

        #4-Load COT
        @cot_pages  = db_fetch(@cot_id)
        @@log.info @@log_mbr + "COT: #{@cot_pages.size}"    if @debug
        @cot_pages.each do |page|
            page_props                          = get_properties(page)
            @hash_cot[page_props['Référence']]  = page
        end
    end #<def>

    # Select pages
    def select_pages()
    #+++++++++++++++++
    #   funct:  select on all pages read
    #   call:   members.select_pages do |page, properties|
    #               select page by yield if return true
    #           end
        @mbr_selpages   = []
        @mbr_selpages   = @mbr_pages.select do |page|       # select
            yield(page, get_properties(page)) ? true : false
        end
        @@log.info @@log_mbr + "SEL: #{mbr_selpages.size}"     if @debug
    end #<def>

    # Process all pages
    def process_pages()
    #++++++++++++++++
    #   funct:  process on all pages selected
    #   call:   members.process_pages do |page, properties, values|
    #               # process page, properties and values by yield
    #           end
    #   properties: hash of page properties with their types and values
    #   values:     hash of values with their raw values (e.g. id, )
    #
        @@log.info @@log_mbr + "Process MBR pages"   if @debug
        @mbr_selpages.each do |page|
                @mbr_values         = {}    #{id: , ?}
                # Process page
                @mbr_properties     = {}
                @mbr_properties     = get_properties(page)
                @mbr_values['id']   = page['id']
                yield(page, @mbr_properties, @mbr_values)   if block_given?
        end
    end #<def>

    # Create hash members
    def create_mbr_hash(pages=[])
    #++++++++++++++++++
    #   create a hash for members requested => {ref: page}
    #
        @@log.info @@log_mbr + "Create MBR hash"    if @debug
        @mbr_hash   = {}
        pages.each do |page|
            @mbr_properties = get_properties(page)
            @mbr_hash[@mbr_properties['Référence']]  = page
        end
    end

    # format new properties
    def new_properties(funct: nil)
    #+++++++++++++++++
    # 1-Automations
    @mbr_properties['Actprc'] = @act_ids[@mbr_properties['Actprc']]
    # 2-Direct
    props = {}
    props['Référence']  = title(@mbr_properties['Référence'])
    # ... other properties
    props['ActSecs']    = relation(@mbr_values['actsecsids'])

    # 3-Add or Update
    page_create(@dbid, properties: props)               if funct == 'create'
    page_update(@mbr_values[:id], properties: props)    if funct == 'update'
    end #<def>

    end #<class>
end #<Module>
#