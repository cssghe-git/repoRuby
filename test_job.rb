#


require_relative 'Mod_M25_Members.rb'
require_relative 'Mod_M25_Cotis.rb'


include M25_Members
include M25_Cotis

# Logger
    log                   = Logger.new(STDOUT)
    log.level             = Logger::INFO
    log.datetime_format   = '%H:%M:%S'
    log_proc              ="PROC:#{__method__}::"

puts    "DBG>>>#{$0} started @ " + "#{created_at}"
debug   = ARGV[0].to_s.downcase || false
debug   = debug == 'debug' ? true : false
puts    "DBG>>>Params::Debug: #{debug}"

imbr    = Members.new([], 'new', debug)
icot    = Cotis.new([], "new", debug)

log.info log_proc + "DBG>>>Load tables @ #{updated_at}"
imbr.load_tables()

puts    "*"
log.info log_proc + "DBG>>>Step 1 @ #{updated_at}"
log.info log_proc + "DBG>>>CDC: #{imbr.cdc_pages.size}"
log.info log_proc + "DBG>>>ACT: #{imbr.act_pages.size}"
log.info log_proc + "DBG>>>MBR: #{imbr.mbr_pages.size}"
log.info log_proc + "DBG>>>COT: #{imbr.cot_pages.size}"
log.debug log_proc + "DBG>>>CDC_IDs: #{imbr.cdc_ids}"       if debug
log.debug log_proc + "DBG>>>ACT_IDs: #{imbr.act_ids}"       if debug

puts    "*"
log.info log_proc + "DBG>>>Step 2 @ #{updated_at} => select members: <En/Hors service>"
imbr.select_pages() do |page, properties|        # bloc yield => select members "en service"
    properties['En/Hors service']
end
log.info log_proc + "DBG>>>Selected <En service>: #{imbr.mbr_selpages.size}"

puts    "*"
log.info log_proc + "DBG>>>Step 3 @ #{updated_at} => get members selected & process"
count_x = imbr.mbr_selpages.size
count_y = 0
count_z = 0
imbr.process_pages do |page, properties, values|     # bloc yield => process each member selected
    count_y += 1

    # check if MBR -> COT
    mbr = properties['Référence']
    cot = imbr.hash_cot[mbr]
    count_z += 1    unless cot.nil?
    log.info log_proc + "MBR->COT for GHE: OK"  if mbr == "Heintje-Gilbert"

    # Print infos for GHE
    if properties['Référence'] == "Heintje-Gilbert"
        log.info log_proc + "DBG>>#{count_y}/#{count_x}>REF: #{properties['Référence']} ID:#{values['id']}" 
        properties.each do |key, value|
            log.debug log_proc + "DBG>>>#{key} => #{value}"      if debug
        end
        log.debug log_proc + "DBG>>>Values:"     if debug
        values.each do |key, value|
            log.debug log_proc + "DBG>>>#{key} => #{value}"      if debug
        end
    end
end
log.info log_proc + "DBG>>>MBR -> COT : #{count_z}"

puts    "*"
log.info log_proc + "DBG>>>Step 4 @ #{updated_at} => create new mbr hash"
imbr.create_mbr_hash(imbr.mbr_selpages)
log.info log_proc + "DBG>>Items: #{imbr.hash_mbr.size}"
# check Hash for GHE
mbr_membre  = imbr.hash_mbr['Heintje-Gilbert']
#log.info log_proc + "DBG>>>Item: #{mbr_membre}"
log.info log_proc + "DBG>>>Hash GHE: #{mbr_membre==nil ? false : true}"

puts    "*"
log.info log_proc + "Check COT"
icot.select_pages() do |page, properties|        # bloc yield => select members "en service"
    puts    properties['Status']
    properties['Status'] == "Child"
end
log.info log_proc + "DBG>>>Selected <Child>: #{icot.cot_selpages.size}"


puts    "*"
log.info log_proc + "DBG>>>#{$0} ended @ " + "#{ended_at}"