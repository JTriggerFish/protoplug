local ffi = require("ffi")
local filter = {}

ffi.cdef[[
typedef struct _FirstOrderAllPass
{
  // H(z) = Y/X(z) = (a + z^-1 ) / (1 + a*z^-1)
  double a;
  double s1;
}FirstOrderAllPass;
typedef struct _SecondOrderAllPass
{
  // H(z) = Y/X(z) = (a + z^-2 ) / (1 + a*z^-2)
  double a;
  double s1;
  double s2;
}SecondOrderAllPass;
typedef struct _OneSampleDelay
{
  double s;
}OneSampleDelay;
]]
ffi.cdef[[
typedef struct _SecondOrderIIR
{
  // H(z) = Y/X(z) = ( b0 + b1 * z^-1 + b2 * x z^-2 ) / ( a0 + a1 * z^-1 + a2 * x z^-2 )
  double a[3];
  double b[3];
  double s1;
  double s2;
}SecondOrderIIR;
typedef struct _Integrator
{
  double s; //state
} Integrator;
]]

filter.static = {}

function filter.OneSampleDelay()
  local data = ffi.new("OneSampleDelay")  -- note the scruct will be zero filled by ffi.new
  return function(x)
    local y = data.s
    data.s  = x
    return y
  end
end

function filter.LinearIntegratorZDF()
  local data = ffi.new("Integrator")  -- note the scruct will be zero filled by ffi.new
  return function(x, g --[[cutoff - expected to have been computed as tan(pi/2 * freq/sampleRate)--]])
    local v = (x - data.s) * g / (1+g)
    local y = v + data.s
    data.s  = y + v
    return y
  end
end

function filter.NonLinearIntegratorZDF()
  --[[Like LinearIntegratorZDF but with a tanh on the input and on the feedback loop.
  -- Note that the zero delay on the feedback loop involves solving a non linear equation
  -- with no closed form by using Newton Raphson
  --]]
  local data = ffi.new("Integrator")  -- note the scruct will be zero filled by ffi.new
  return function(x, g --[[cutoff - expected to have been computed as tan(pi/2 * freq/sampleRate)--]])
    local tanh = math.tanh
    local xs = tanh(x)
    local v = g * xs + data.s
    
    --Solving y + g*tanh(y) - v = 0
    --by 4 iterations of Newton Raphson method, using the initial guess
    --from the linear case, and the known derivative  1 + g*(1-tanh^2(y))
    local y = 1/(1+g) * v --initial guess
    
    for i = 1, 4 do
      local f  = y + g*tanh(y) - v
      local df = 1 + g*(1 - (tanh(y))^2)
      y        = y - f / df
    end
    
    data.s  = g*( xs - tanh(y)) + y
    return y
  end
end
function filter.FirstOrderAllPassTDF2(coeff)
  local data = ffi.new("FirstOrderAllPass") -- note the scruct will be zero filled by ffi.new
  data.a = coeff
  return function(x)
      local s = x - data.a * data.s1
      local y = data.a * s + data.s1
      data.s1 = s
      return y
    end
end

function filter.SecondOrderAllPassTDF2(coeff)
  local data = ffi.new("SecondOrderAllPass") -- note the scruct will be zero filled by ffi.new
  data.a = coeff
  return function(x)
      local s = x - data.a * data.s2 
      local y = data.a * s + data.s2
      data.s2 = data.s1
      data.s1 = s
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
  --Note fc is a normalised frequency between 0 and 1, 1 being the Nyquist limit
  local c = 1 / math.tan(math.pi * fc/2)
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
