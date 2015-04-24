
protoplug_path = "C:\\Lua\\protoplug\\Bin\\win32\\Lua Protoplug Gen.dll"
protoplug_dir  = "."
require "generators/poissonHarmonics"
local ffi = require("ffi")
--local gp = require('gnuplot')
--fftlib = script.ffiLoad("libfftw3.so.3", "libfftw3-3")


--[[local g = gp{
    -- all optional, with sane defaults
    width  = 640,
    height = 480,
    xlabel = "X axis",
    ylabel = "Y axis",
    key    = "top left",
    consts = {
        gamma = 2.5
    },
    
    data = {
        gp.array {  -- plot from an 'array-like' thing in memory. Could be a
                    -- numlua matrix, for example.
            {
                {0,1,2,3,4,5,6,7,8,9},  -- x
                {3,4,5,6,7,8,9,8,7,6}   -- y
            },
            
            title = "Title 2",          -- optional
            using = {1,2},              -- optional
            with  = 'linespoints'       -- optional
        }
    }    
}:plot('output.png') --]]

local smax = 64
for i=0, 2*44100 / smax do
  midiBuf = {}
  samples = ffi.new("float[2][64]") -- Note FFI zero fills arrays by default
 
  
  function midiBuf:addEvent(event)
    table.insert(self, event)
  end
  function midiBuf:eachEvent()
    return function ()
      return nil
    end
  end
  function midiBuf:clear()
end

  plugin.processBlock(samples, smax, midiBuf)
end