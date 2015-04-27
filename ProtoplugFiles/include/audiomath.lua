-- Support math and low level function to help with plugin development

--[[ 
    Functions added to math
    ------------------------------------------------------------------------------------
--]]
-- Initialise the random number generator
math.randomseed(os.time())
math.random(); math.random(); math.random()


math.boxMuller = function()
	local U1 = math.random()
	local U2 = math.random()
	return math.sqrt(-2*math.log(U1))*math.cos(2*math.pi*U2),
			math.sqrt(-2*math.log(U1))*math.sin(2*math.pi*U2)
end

math.gaussianRandom = function(mean, stdDev)
	return math.boxMuller() * stdDev + mean
end
----------------------------------------------------------------------------------------
--[[ 
    Actual audioMath library
    ------------------------------------------------------------------------------------
--]]

local audioMath = {}

--Take a nunmber between 0 and 1 and map it exponentionally between low and high
function audioMath.expRange(x, low, high)
	return (low-1) + math.pow(1+high-low, x)
end

function audioMath.midiToFreq(midiNote)
	return 440.0 * math.pow(2.0, (midiNote - 69)/12)
end

function audioMath.freqToMidi(freq)
	return math.floor(math.log(freq/440.0)/math.log(2) * 12 + 69)
end

--[[ 
    Utility to add timed midi events, for sequencers etc
    ------------------------------------------------------------------------------------
--]]

audioMath.MidiEventsQueue = { maxBlock = 2^14, currentBlock = 0, events = {}}

function audioMath.MidiEventsQueue:registerEvent(event, sampleOffsetToCurrentBlock, blockSize)
  local blockOffset  = math.floor(sampleOffsetToCurrentBlock / blockSize)
  local sampleOffset = sampleOffsetToCurrentBlock - blockOffset * blockSize
  event.time = sampleOffset
  local idx = (self.currentBlock + blockOffset) % self.maxBlock
  self.events[idx] = self.events[idx] or {}
  self.events[idx].list = self.events[idx].list or {}
  table.insert(self.events[idx].list, event)
  self.events[idx].lastEventTime = self.events[idx].lastEventTime or 0
  if sampleOffset >= self.events[idx].lastEventTime then
    self.events[idx].lastEventTime = sampleOffset
    self.events[idx].lastEvent     = event
  end
end

--This function has to be called in each processBlock !
function audioMath.MidiEventsQueue:playEvents(midiBuf)
  local blockEvents = self.events[self.currentBlock]
  if blockEvents then
    for i, event in ipairs(blockEvents.list) do
      midiBuf:addEvent(event)
      --print(event)
    end
  end
  self.events[self.currentBlock] = nil
  self.currentBlock = (self.currentBlock + 1) % self.maxBlock
end

function audioMath.MidiEventsQueue:lastTimeEventInCurrentBlock()
 local blockEvents = self.events[self.currentBlock]
  if blockEvents then
    return blockEvents.lastEventTime
  end
  return 0
end

filters = require("include/filters")
ffi     = require("ffi")


function audioMath.X2Upsampler()
  --local A0 = filters.SecondOrderAllPassSection(0.1380)
  --local A1 = filters.SecondOrderAllPassSection(0.5847)
  local LPS = {}
  local nbLP = 3
  for i=1, nbLP do
    LPS[i] = filters.SecondOrderButterworthLP(0.25)
  end
  
  --Note inSamples should be floats but
  -- doubles are supposedly more efficient in LuaJIT so we output that instead
  local bufferSize = 2048
  local outSamples = ffi.new("double[?]", bufferSize)
  
  return function(inSamples, blockSize)
    if bufferSize < blockSize * 2 then
      bufferSize = blockSize * 2
      outSamples = ffi.new("double[?]", bufferSize) 
    end
    
    --[[Polyphase IIR interpolation filter as per http://www.ensilica.com/wp-content/uploads/High_performance_IIR_filters_for_interpolation_and_decimation.pdf--]]
    for i=0, blockSize-1 do
      --outSamples[2*i]   = A0(inSamples[i])
      --outSamples[2*i+1] = A1(inSamples[i])
      
      --Dumb way for now
      outSamples[2*i]   = inSamples[i]
      outSamples[2*i+1] = 0
    end
    
    --Dumb way for now
    for i=0, 2*blockSize-1 do
      for lp=1, nbLP do
        outSamples[i] = LPS[lp](outSamples[i])
      end
    end

    return outSamples
  end
end

function audioMath.X2Downsampler()
  -- TODO ! check values are correct and cutoff still in the right place !?
  local A0 = filters.SecondOrderAllPassSection(0.1380)
  local A1 = filters.SecondOrderAllPassSection(0.5847)
  
  return function(inSamples, outSamples, blockSize)

    --[[Polyphase IIR interpolation filter as per   http://www.ensilica.com/wp-content/uploads/High_performance_IIR_filters_for_interpolation_and_decimation.pdf--]]
    for i=0, blockSize-1 do
      outSamples[i] = 0.5 * (A0(inSamples[2*i]) + A1(inSamples[2*i+1]))
    end

    return outSamples
  end
end

return audioMath