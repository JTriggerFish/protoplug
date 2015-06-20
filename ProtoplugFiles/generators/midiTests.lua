require "include/protoplug"
local J = require "include/protojuce"

--Welcome to Lua Protoplug generator (version 1.3.0)

local inputDevices = midi.MidiInput.getDevices()

for _, v in ipairs(inputDevices) do
	print("Input "..v)
end

local outputDevices = midi.MidiOutput.getDevices()

for _, v in ipairs(outputDevices) do
	print("Output "..v)
end

local pushInput  = midi.MidiInput.openDevice(#inputDevices-1)
local pushOutput = midi.MidiOutput.openDevice(#outputDevices-1)

for i=0,10000 do
	local midiBuf = pushInput:collectNextBlockOfMessages(64) 
	for ev in midiBuf:eachEvent() do
		print(ev)
	end
end

local outBuffer = pushOutput:getMidiBuffer()
for cc=0,127 do
	for val=20, 40 do
		outBuffer:addEvent(midi.Event.control(1, cc, 1))
	end
end
for color=0,127 do
	for note=0,127 do
			outBuffer:addEvent(midi.Event.noteOn(1, note, color))
	end
	pushOutput:sendMessagesFromBuffer(44100)   
end
