--[[
name: poisson Harmonics
description: MIDI generator VST/AU. Generate note triggers in the harmonics series
            of the last pressed key, with arrival times determined by a poisson
            process of which the intensity can be changed.
            The velocity is also random following a gaussian distribution
author: JT Marin
--]]

require "include/protoplug"
--dist = require "sci.dist"
--math = require "sci.math"

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

-- Default base note : A 440hz at half velocity
local baseNote = { note = 69, velocity = 69 }


--Poisson event based random time midi note generator
local DustGenerator = {lambda = 1 / 0.3, sampleRate = 44100,
					   channel = 1,
					   nextEventSample = 1.0*44100,
					   blockCount = 0
					   }
					

function DustGenerator:generateEvent(noteGen, velocityGen, smax, midiBuf)
	function nextPoissonEventSample(lambda) 
		local U = math.random()
		return (-math.log(U) / lambda) * self.sampleRate
		--return 0.03 * self.sampleRate
	end
	
	self.blockCount = self.blockCount + 1
	
	local blockNum     = math.floor(self.nextEventSample  / smax)
	local sampleOffset = self.nextEventSample  - blockNum * smax
	
	if blockNum == self.blockCount then
		::eventInBlock::
		
		--Only send a short pulse
		local eventOn = midi.Event.noteOn (self.channel, noteGen(), velocityGen(), sampleOffset)
		midiBuf:addEvent(eventOn)
		local eventOff = midi.Event.noteOff(self.channel, eventOn:getNote(), 0, math.min(smax, sampleOffset+1))
		midiBuf:addEvent(eventOff)
		self.nextEventSample = nextPoissonEventSample(self.lambda) + sampleOffset
		
        blockNum     = math.floor(self.nextEventSample / smax)
		if blockNum == 0 then
            sampleOffset = self.nextEventSample - blockNum * smax
		 	goto eventInBlock
		end
		
		self.blockCount = 0
	end
end

--Take a nunmber between 0 and 1 and map it exponentionally between low and high
function expRange(x, low, high)
	return (low-1) + math.pow(1+high-low, x)
end

function midiToFreq(midiNote)
	return 440.0 * math.pow(2.0, (midiNote - 69)/12)
end

function freqToMidi(freq)
	return math.floor(math.log(freq/440.0)/math.log(2) * 12 + 69)
end


function harmonicNoteGen(baseMidiNote)
	local baseFreq = midiToFreq(baseMidiNote)
	local maxFreq  = midiToFreq(127)
	local harmonicNotes = {}
	for i = 1, 127 do
		local freq = baseFreq * i
		if freq > maxFreq then break end
		harmonicNotes[i] = freqToMidi(freq)
	end
	local len = #harmonicNotes
  --[[for _,n in ipairs(harmonicNotes) do
    io.write(string.format("%d : %.3f\n", n, midiToFreq(n))) 
  end]]--
  local lambda = 0.3 --Make this lower to get more higher harmonics
	return function()
		local idx = math.min(1 + math.floor(-math.log(math.random()) / lambda), len)
		return harmonicNotes[idx]
  end
  
end

function gaussianVelGen(center, dev)
	--print(rng:sample())
	
	return function()
		local s = math.gaussianRandom(center,dev)
		s = math.max(1, math.min(s, 127))
		--print(s)
		return s
	end
end


function plugin.processBlock(samples, smax, midiBuf)
	DustGenerator.sampleRate = plugin.isSampleRateKnown() and plugin.getSampleRate() or 44100
	--print(DustGenerator.sampleRate)
	local inputNotes = {}
	local i = 1
	
	--[[ analyse midi buffer and keep last note on
	]]--
	for ev in midiBuf:eachEvent() do
		if ev:isNoteOn() then
		    --print(ev:getNote())
			inputNotes[i] = ev
			i = i+1
		end
	end
	
	if inputNotes[i-1] then --new note in the current buffer
		baseNote.note     = inputNotes[i-1]:getNote()
		baseNote.velocity = inputNotes[i-1]:getVel()
	end

	-- fill midi buffer with prepared notes
	midiBuf:clear()
	DustGenerator:generateEvent(harmonicNoteGen(baseNote.note), 
					gaussianVelGen(baseNote.velocity, 30), smax, midiBuf)
	
end


