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
  self.events[idx][event] = sampleOffset
  self.events[idx].lastEventTime = self.events[idx].lastEventTime or 0
  if sampleOffset >= self.events[idx].lastEventTime then
    self.events[idx].lastEventTime = sampleOffset
    self.events[idx].lastEvent     = event
  end
end

--This function has to be called in each processBlock !
function audioMath.MidiEventsQueue:playEvents(midiBuf)
  blockEvents = self.events[self.currentBlock]
  if blockEvents then
    for event in pairs(blockEvents) do
      midiBuf:addEvent(event)
      --print(event)
    end
  end
  self.events[self.currentBlock] = nil
  self.currentBlock = (self.currentBlock + 1) % self.maxBlock
end

function audioMath.MidiEventsQueue:lastTimeEventInCurrentBlock()
  blockEvents = self.events[self.currentBlock]
  if blockEvents then
    return blockEvents.lastEventTime
  end
  return 0
end

return audioMath