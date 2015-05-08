-- Support math and low level function to help with plugin development

--[[ 
    Functions added to math
    ------------------------------------------------------------------------------------
--]]
-- Initialise the random number generator
--require('mobdebug').start()
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
  --[[Polyphase IIR decomposition of 5th order buttworth with normalised cutoff at 0.5 ( half Nyquist)
  used for interpolation: --]]
  --We apply the filter twice in series
  local A0_1 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local A0_2 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local A0_3 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local A1_1 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local A1_2 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local A1_3 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local z_1  = filters.OneSampleDelay()
  
  --Note inSamples should be floats but
  -- doubles are supposedly more efficient in LuaJIT so we output that instead
  local bufferSize = 2048
  local outSamples = ffi.new("double[?]", bufferSize)
  
  return function(inSamples, blockSize)
    if bufferSize < blockSize * 2 then
      bufferSize = blockSize * 2
      outSamples = ffi.new("double[?]", bufferSize) 
    end
    
    -- Apply the butterworth filter's decomposition twice in series.
    local d1
    for i=0, blockSize-1 do
      d1                = z_1(inSamples[i])
      outSamples[2*i]   = 0.5 * ( A0_2( A0_1(inSamples[i]))  + A1_2( A1_1(d1) ))
      outSamples[2*i+1] = A0_3 (A1_3(inSamples[i]))
    end

    return outSamples
  end
end

function audioMath.X4Upsampler()
  --This is essentially a 2X upsampling applied twice and unrolled for efficency
  --[[Polyphase IIR decomposition of 5th order buttworth with normalised cutoff at 0.5 ( half Nyquist)
  used for interpolation: --]]
  --We apply the filter twice in series
  local First_A0_1 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local First_A0_2 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local First_A0_3 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local First_A1_1 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local First_A1_2 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local First_A1_3 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local First_z_1  = filters.OneSampleDelay()
  
  --Same thing for second stage
  local Second_A0_1 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local Second_A0_2 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local Second_A0_3 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local Second_A1_1 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local Second_A1_2 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local Second_A1_3 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local Second_z_1  = filters.OneSampleDelay()
  
  
  --Note inSamples should be floats but
  -- doubles are supposedly more efficient in LuaJIT so we output that instead
  local bufferSize = 4096
  local outSamples = ffi.new("double[?]", bufferSize)
  
  return function(inSamples, blockSize)
    if bufferSize < blockSize * 4 then
      bufferSize = blockSize * 4
      outSamples = ffi.new("double[?]", bufferSize) 
    end
    
    local s1, s2, d1, d2, d3
    for i=0, blockSize-1 do
      d1                  = First_z_1(inSamples[i])
      s1                  = ( First_A0_2( First_A0_1(inSamples[i]))  + First_A1_2( First_A1_1(d1) ))
      s2                  = 2 * First_A0_3 (First_A1_3(inSamples[i]))
      d2                  = Second_z_1(s1)
      d3                  = Second_z_1(s2)
      outSamples[4*i + 0] = 0.5 * ( Second_A0_2( Second_A0_1(s1))  + Second_A1_2( Second_A1_1(d2) ))
      outSamples[4*i + 1] = Second_A0_3 (Second_A1_3(s1))
      outSamples[4*i + 2] = 0.5 * ( Second_A0_2( Second_A0_1(s2))  + Second_A1_2( Second_A1_1(d3) ))
      outSamples[4*i + 3] = Second_A0_3 (Second_A1_3(s2))
    end

    return outSamples
  end
end

function audioMath.X2Downsampler()
  --Polyphase IIR decomposition of 5th order buttworth with normalised cutoff at 0.5 ( half Nyquist)
  --used for decimation, and applied twice in series
  local bufferSize = 1024
  local outSamples = ffi.new("float[?]", bufferSize)
  
  --[[
  local A0 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local A1 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local z_1  = filters.OneSampleDelay() --]]
  local A0_1 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local A0_2 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local A0_3 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local A1_1 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local A1_2 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local A1_3 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local z_1_1  = filters.OneSampleDelay()
  local z_1_2  = filters.OneSampleDelay()
  
  --local test = filters.SecondOrderButterworthLP(0.5)

  
  return function(inSamples, blockSize)
    if bufferSize < blockSize / 2 then
      bufferSize = blockSize / 2
      outSamples = ffi.new("float[?]", bufferSize) 
    end
    
    
    local s1, s2, s3, s4
    for i=0, blockSize/2-1 do
      --[[Single filter application ( 5th orde ) version
      s1 = z_1(inSamples[2*i])
      s2 = z_1(inSamples[2*i+1])
      outSamples[i] = 0.5 * (A0_1(inSamples[2*i]) + A1_1(s1)) --]]
      --Double application of the decomposed IIR filter :
      --
      s1 = z_1_1(inSamples[2*i])
      s2 = z_1_1(inSamples[2*i+1])
      s3 = z_1_2(s1)
      s4 = z_1_2(s2)
      outSamples[i] = 0.25 * ( A0_2( A0_1(inSamples[2*i]))  + A1_2( A1_1(s3) )) + 0.5 * A0_3 (A1_3(s1)) 
    --]]
    end

    return outSamples
  end
end

function audioMath.X4Downsampler()
  --Essentially two X2Downsamplers applied in series, but unrolled into a single loop
  local bufferSize = 1024
  local outSamples = ffi.new("float[?]", bufferSize)
  
  --First stage of 2X downsampling
  --Polyphase IIR decomposition of 5th order buttworth with normalised cutoff at 0.5 ( half Nyquist)
  --used for decimation, and applied twice in series
  local First_A0_1 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local First_A0_2 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local First_A0_3 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local First_A1_1 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local First_A1_2 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local First_A1_3 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local First_z_1_1  = filters.OneSampleDelay()
  local First_z_1_2  = filters.OneSampleDelay()

  --Second stage of 2X downsampling
  local Second_A0_1 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local Second_A0_2 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local Second_A0_3 = filters.FirstOrderAllPassTDF2(2/(10 + 4*math.sqrt(5)))
  local Second_A1_1 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local Second_A1_2 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local Second_A1_3 = filters.FirstOrderAllPassTDF2((10 - 4*math.sqrt(5))/2)
  local Second_z_1_1  = filters.OneSampleDelay()
  local Second_z_1_2  = filters.OneSampleDelay()
  
  
  return function(inSamples, blockSize)
    if bufferSize < blockSize / 4 then
      bufferSize = blockSize / 4
      outSamples = ffi.new("float[?]", bufferSize) 
    end
    
    
    local fs1, fs2, fs3, fs4
    local ss1, ss2, ss3, ss4
    local twoXSample1, twoXSample2

    for i=0, blockSize/4 - 1 do
      fs1 = First_z_1_1(inSamples[4*i])
      fs2 = First_z_1_1(inSamples[4*i+1])
      fs3 = First_z_1_2(fs1)
      fs4 = First_z_1_2(fs2)
      twoXSample1 = 0.25 * ( First_A0_2( First_A0_1(inSamples[4*i]))  + First_A1_2( First_A1_1(fs3) )) + 0.5 * First_A0_3 (First_A1_3(fs1)) 

      fs1 = First_z_1_1(inSamples[4*i+2])
      fs2 = First_z_1_1(inSamples[4*i+3])
      fs3 = First_z_1_2(fs1)
      fs4 = First_z_1_2(fs2)
      twoXSample2 = 0.25 * ( First_A0_2( First_A0_1(inSamples[4*i+2]))  + First_A1_2( First_A1_1(fs3) )) + 0.5 * First_A0_3 (First_A1_3(fs1)) 

      ss1 = Second_z_1_1(twoXSample1)
      ss2 = Second_z_1_1(twoXSample2)
      ss3 = Second_z_1_2(ss1)
      ss4 = Second_z_1_2(ss2)
      outSamples[i] = 0.25 * ( Second_A0_2( Second_A0_1(twoXSample1))  + Second_A1_2( Second_A1_1(ss3) )) + 0.5 * Second_A0_3 (Second_A1_3(ss1)) 

    end

    return outSamples
  end
end

return audioMath
