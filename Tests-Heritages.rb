require 'pp'
require_relative    'ClStandards.rb'
#
class   TestsHeritages < Standards
    def initialize()
        super
        @test   = "In Use"
    end #<def>

    def tests()
        loadOpts()
        pp  @test
        pp  @opts
    end #<def>

    def run()
        tests()
    end #<def>
end #<class>

#
    puts    "Start"
    x = TestsHeritages.new()
    x.run()
    puts    "Done"