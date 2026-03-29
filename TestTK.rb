#
#require_relative 'ClTkPoo'
require 'tk'
#tkinst  = MyTk.new
#tkinst.run
        @root = TkRoot.new do
            title "Demo Ruby/Tk OO"
            geometry "400x200"
        end

        @label = TkLabel.new(@root) do
            text "Clique sur un bouton"
            pack pady: 20
        end
