#
=begin

=end

require_relative    'ClStandards.rb'


#
module  M25t_Membres
#*******************
#
    def self.infos()
    #+++++++++++++++++++++
    #   OUT:    prms {}
    #
        prms    = {
            table:  'm25t.Membres',
            fields: {
                'Référence'=>   'title',
                'Seagma'=>      'rich_text'
            },
            csv:    {
                'Seagma' =>     0,
                'Nom' =>        1,
                'Prénom' =>     2
            }
        }
        return  prms
    end #<def>

    def self.load(field: nil)
    #++++++++++++++++++++
    #   OUT:    membres {ref=>data} or {ref=>field.value}
    #
        membres = {}
        stds    = Standards.new()
        dbid    = stds.getDbId('m25t.Membres')
        filter  = {
            "property" => "En/Hors service", "checkbox" => { "equals" => true }
        }
        sorts   = [
            { "property" => 'Référence', "direction" => 'ascending' }
        ]
        data    = stds.db_fetch(dbid, filter: filter, sort: sorts)
        data.each do |mbr|  #<L1>
            p   = mbr.dig("properties", 'Référence')
            key = p["title"].map { _1["plain_text"] }.join
            if field.nil?   #<IF2>
                membres[key]    = mbr
            else    #<IF2>
                membres[key]    = stds.get_prop_value(mbr, field)
            end #<IF2>
        end #<L1>
        return  membres
    end #<def>

end #<Mod>