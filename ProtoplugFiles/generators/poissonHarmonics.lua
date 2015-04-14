--[[
name: poisson Harmonics
description: MIDI generator VST/AU. Generate note triggers in the harmonics series
            of the last pressed key, with arrival times determined by a poisson
            process of which the intensity can be changed.
            The velocity is also random following a gaussian distribution
author: JT Marin
--]]

require "include/protoplug"
am = require "include/audioMath"
--dist = require "sci.dist"
--math = require "sci.math"


-- Default base note : A 440hz at half velocity
local baseNote = { note = 69, velocity = 69 }


--Poisson event based random time midi note generator
local DustGenerator = {lambda = 1 / 0.3, sampleRate = 44100,
					   channel = 1,
					   blocksTillEvents = 0
             gateLength = 0.001 --1ms - only send a short impulse
					   }
					
-- Wait until the next block of events then creates new events to fill another block at least
function DustGenerator:generateEvents(noteGen, velocityGen, smax, midiBuf)
	function nextPoissonEventSample(lambda) 
		local U = math.random()
		return math.floor((-math.log(U) / lambda) * self.sampleRate)
	end
  
  --Events in this block, we need to generate the next set
  if self.blocksTillEvents == 0 then
    local offset    = am.MidiEventsQueue:lastTimeEventInCurrentBlock()
    while offset < smax do
      local nextEventTime = nextPoissonEventSample() + offset
      local noteOffTime    = nextEventTime + math.floor(self.gateLength * self.sampleRate)
      local eventOn = midi.Event.noteOn (self.channel, noteGen(), velocityGen())
      local eventOff = midi.Event.noteOff(self.channel, eventOn:getNote(), 0)
      am.MidiEventsQueue:registerEvent(eventOn, nextEventTime, smax)
      am.MidiEventsQueue:registerEvent(eventOff, noteOffTime, smax)
      offset = nextEventTime
    end
    
    self.blockTillEvents = math.floor(offset / smax)
  end
    self.blockTillEvents = self.blockTillEvents - 1
  
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
  
	DustGenerator:generateEvent(harmonicNoteGen(baseNote.note), 
					gaussianVelGen(baseNote.velocity, 30), smax, midiBuf)

	-- fill midi buffer with prepared notes
	midiBuf:clear()
  audioMath.MidiEventsQueue:playEvents(midiBuf)

	
end


