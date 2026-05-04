#
require_relative 'Mod_Luhn.rb'
include Method_Luhn

x   = Class_Luhn.new

nombre  = 247029
y   = x.compute(number: nombre)
puts "PROC::Code: #{y}"

for z in 0..9
    nombre  = 247029
    arr_nombre  = nombre.to_s.chars
    arr_nombre.push(z.to_s)
    nombre  = arr_nombre.join.to_i
    y   = x.check(number: nombre, code: z)
    puts    "PROC::Z: #{z} -> NOMBRE: #{nombre} -> #{y}"  if y==true
end