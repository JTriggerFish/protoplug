local ffi = require("ffi")
local filter = {}

ffi.cdef[[
typedef struct _SecondOrderAllPassSection
{
  double coeff;
  double x_z[2]; //Input delay elements z^-1 and z^-2
  double y_z[2]; //Output delay elements z^-1 and z^-2
}SecondOrderAllPassSection;
]]
ffi.cdef[[
typedef struct _SecondOrderIIR
{
  //a0 * y[n] = b0 * x[n] + b1 * x[n-1] + b2 * x[n-2] - a1* y[n-1] - a2 * y[n-2]
  double a[3];
  double b[3];
  double s1;
  double s2;
}SecondOrderIIR;
]]

filter.static = {}

function filter.SecondOrderAllPassSection(coeff)
  local data = ffi.new("SecondOrderAllPassSection") -- note it wil be zero filled by ffi.new
  data.coeff = coeff
  return function(x)
      local y = data.x_z[1] + data.coeff * ( x - data.y_z[1] )
      data.x_z[1] = data.x_z[0]
      data.y_z[1] = data.y_z[0]
      data.x_z[0] = x
      data.y_z[0] = y
      return y
    end
end

function filter.BiquadTDF2(a, b)
   local data = ffi.new("SecondOrderIIR") -- note it wil be zero filled by ffi.new 
   data.a[0] = a[1]
   data.a[1] = a[2] / a[1]
   data.a[2] = a[3] / a[1]
   data.b[0] = b[1] / a[1]
   data.b[1] = b[2] / a[1]
   data.b[2] = b[3] / a[1]
   
   return function(x)
     local y =                   data.b[0] * x + data.s1
     data.s1 = - data.a[1] * y + data.b[1] * x + data.s2
     data.s2 = - data.a[2] * y + data.b[2] * x
     return y
   end
   
end

function filter.SecondOrderButterworthLP(fc)
  --Note fc is a normalised frequency between 0 and 0.5 !
  local c = 1 / math.tan(math.pi * fc)
  local b = { 1, 2, 1 }
  local a = { 1 + math.sqrt(2)*c + c^2, 2 - 2*c^2, 1 - math.sqrt(2)*c + c^2}
  
  return filter.BiquadTDF2(a,b)
  
end

--[[local filterTest = filter.SecondOrderAllPassSection(0.7)
local dataTest   = { 0.1, 0.2, 0.3, 0.4, 0.5 }
for i=1, #dataTest do
  print(filterTest(dataTest[i]))
end
]]--

    --TODO : dither input to avoid denormals. Need a decent RNG..


return filter
