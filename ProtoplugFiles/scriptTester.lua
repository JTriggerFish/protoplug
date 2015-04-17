
protoplug_path = "C:\\Lua\\protoplug\\Bin\\win32\\Lua Protoplug Gen.dll"
protoplug_dir  = "."
require "generators/poissonHarmonics"


local smax = 64
for i=0, 2*44100 / smax do
  midiBuf = {}
  samples = {}
  for i =1, smax do
    samples[i] = 0
  end
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