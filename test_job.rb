require_relative 'Mod_M25_Members.rb'


include M25_Members

# Logger
    log                   = Logger.new(STDOUT)
    log.level             = Logger::INFO
    log.datetime_format   = '%H:%M:%S'
    log_proc              ="PROC:#{__method__}::"

puts    "DBG>>>#{$0} started @ " + "#{created_at}"
debug   = ARGV[0].to_s.downcase || false
debug   = debug == 'debug' ? true : false
puts    "DBG>>>Params::Debug: #{debug}"
tab = Members.new([], 'new', debug)

log.info log_proc + "DBG>>>Load tables @ #{updated_at}"
tab.load_tables()

puts    "*"
log.info log_proc + "DBG>>>Step 1 @ #{updated_at}"
log.info log_proc + "DBG>>>CDC: #{tab.cdc_pages.size}"
log.info log_proc + "DBG>>>ACT: #{tab.act_pages.size}"
log.info log_proc + "DBG>>>MBR: #{tab.mbr_pages.size}"
log.info log_proc + "DBG>>>COT: #{tab.cot_pages.size}"
log.debug log_proc + "DBG>>>CDC_IDs: #{tab.cdc_ids}"       if debug
log.debug log_proc + "DBG>>>ACT_IDs: #{tab.act_ids}"       if debug
puts    "Hash COT"
cot_hash    = {}
tab.cot_pages.each do |page|
    cot_properties  = tab.get_properties(page)
    cot_hash[cot_properties['Référence']] = page
end

puts    "*"
log.info log_proc + "DBG>>>Step 2 @ #{updated_at} => select members: <En/Hors service>"
tab.select_pages() do |page, properties|        # bloc yield => select members "en service"
    properties['En/Hors service']
end
log.info log_proc + "DBG>>>Selected <En service>: #{tab.mbr_pages.size}"

puts    "*"
log.info log_proc + "DBG>>>Step 3 @ #{updated_at} => get members selected & process"
count_x = tab.mbr_pages.size
count_y = 0
count_z = 0
tab.process_pages do |page, properties, values|     # bloc yield => process each member selected
    count_y += 1

    # check if MBR -> COT
    mbr = properties['Référence']
    cot = cot_hash[mbr]
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
log.info log_proc + "DBG>>>Step 4 @ #{updated_at} => create the mbr hash"
tab.create_mbr_hash(tab.process_pages)
log.info log_proc + "DBG>>Items: #{tab.mbr_hash.size}"
# check Hash for GHE
mbr_membre  = tab.mbr_hash['Heintje-Gilbert']
#log.info log_proc + "DBG>>>Item: #{mbr_membre}"
log.info log_proc + "DBG>>>Hash GHE: #{mbr_membre==nil ? false : true}"

puts    "*"
log.info log_proc + "Check COT errors"

puts    "*"
log.info log_proc + "DBG>>>#{$0} ended @ " + "#{ended_at}"