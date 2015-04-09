--[[
name: poisson Harmonics
description: MIDI generator VST/AU. Generate notes in the harmonics series
            of the last pressed key, with arrival times determined by a poisson
            process of which the intensity can be changed.
author: JT Marin
--]]

require "include/protoplug"
prng = require "sci.prng"

-- Initialise the random number generator
math.randomseed(os.time())
math.random(); math.random(); math.random()

--scilua random number generator:
local sciRng = prng.std()

-- Default base note : A 440hz at half velocity
local baseNote = { note = 69, velocity = 69 }


--Poisson event based random time midi note generator
local DustGenerator = {lambda = 1.0, sampleRate = 44100,
					   channel = 1,
					   nextEventTime = 1.0, --[[in seconds--]]
					   blockCount = 0
					   }
					

function DustGenerator:generateEvent(noteGen, velocityGen, smax, midiBuf)

	function nextPoissonEventTime(lambda) 
		local U = math.random()
		return -math.log(U) / lambda
	end
	
	self.blockCount = self.blockCount + 1
	
	local div = self.nextEventTime / self.sampleRate
	local blockNum = math.floor(div)
	local timeOffset = (div - blockNum)
	
	if blockNum == blockCount then
		::eventInBlock::
		
		event = midi.Event.noteOn (self.channel, noteGen(), velolicityGen(),
		 						timeOffset*self.sampleRate)
		midiBuf:addEvent(event)
		self.nextEventTime = nextPoissonEventTime(self.lambda) + timeOffset
		
		blockNum = math.floor(self.nextEventTime / sampleRate)
		if blockNum == 0 then
		 	timeOffset = self.nextEventTime / sampleRate - blockNum
		 	goto eventInBlock
		end
		
		blockCount = 0
	end
	
end

--Take a nunmber between 0 and 1 and map it exponentionally between low and high
function expRange(x, low, high)
	return (low-1) + math.pow(1+high-low, x)
end

function midiToFreq(midiNote)
	return 440.0 * math.pow(2.0, (baseMidiNote - 69)/12)
end

function freqToMidi(freq)
	return math.floor(math.log(freq/440.0)/math.log(2) * 12 + 69)
end


function harmonicNoteGen(baseMidiNote)
	local baseFreq = midiToFreq(baseMidiNote)
	local maxFreq  = midiToFreq(128)
	local harmonicNotes = {}
	for i = 0, 10 do
		local freq = baseFreq * ( 2 ^ i )
		if freq > maxFreq then break end
		harmonicNotes[i] = freqToMidi(freq) 
	end
	return function()
		end
end

function gaussianVelGen(baseVel)


function plugin.processBlock(samples, smax, midiBuf)
	DustGenerator.sampleRate = plugin.getSampleRate()
	local inputNotes = {}
	local i = 1
	
	--[[ analyse midi buffer and keep last note on
	]]--
	for ev in midiBuf:eachEvent() do
		if ev:isNoteOn() then
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
	if #blockEvents>0 then
		for _,e in ipairs(blockEvents) do
			midiBuf:addEvent(e)
		end
	end
end

function chordOn(root)
	for _, offset in ipairs(chordStructure) do
		local newEv = midi.Event.noteOn(
			root:getChannel(), 
			root:getNote()+offset, 
			root:getVel())
		table.insert(blockEvents, newEv)
	end
end

function chordOff(root)
	for _, offset in ipairs(chordStructure) do
		local newEv = midi.Event.noteOff(
			root:getChannel(), 
			root:getNote()+offset)
		table.insert(blockEvents, newEv)
	end
end
