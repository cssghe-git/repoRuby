# frozen_string_literal: true
#
=begin
        Goals:      compute or check
        Class:      Method_Luhn
        Calls:      k = Class_Luhn.new()
                    Get the code => code = k.compute(integer)
                    Check the code => rc = k.check(key, code) => true or false
        Functions:  initialize()
                    compute()
                    check()
=end

#Requires

module  Method_Luhn
#******************

class   Class_Luhn
#******************

# Class variables
#================

# Instance variables
#===================

# Code
#=====

    # Create new instance & initialize variables
    def initialize()
    #+++++++++++++
    #
    end #<def>

    # Compute value
    def compute(number: 0)
    #++++++++++
    #   input:  integer
    #   out:    code
    #
        return  0       if number.size==0
        number  = number * 10
        arr_num = add_private(input: number.to_s.chars)
        return  give_result(array: arr_num)       #give me the code
    end #<def>

    # Check value
    def check(number: 0, code: 0)
    #++++++++
    #   input:  integer
    #   code:   expected
    #   out:    true or false
    #
        return  false       if number.size==0
        array   = add_private(input: number.to_s.chars)
        return  give_result(array: array) == code #give result
    end #<def>

    private

    # add private key
    def add_private(input: [])
    #++++++++++++++
    #
        prv_key = 441205
        prv_key.to_s.chars.reverse_each do |c|
            input.unshift(c)
        end
        return  input
    end

    # give the code
    def give_result(array: [])
    #++++++++++++++
    #   array:  array of chars
    #   out:    code
    #
        sum     = 0                                     #init
        sum2    = 0
        skip    = true                                  #skip last char
        #
        array.reverse_each do |n|                       #loop all chars
            if skip                                      #skip 1 on 2
                skip    = false
                next
            end
            n2  = n.to_i * 2                            #cipher * 2
            n2  = n2 - 10 + 1   if n2 > 9               #if > 9
            sum += n2                                   #add to sum
            skip    = true                              #to skip next
        end
        sum.to_s.chars.map {|n| sum2 += n.to_i}
        return  sum2 % 10
    end #<def>

end #<class>
end #<module>
