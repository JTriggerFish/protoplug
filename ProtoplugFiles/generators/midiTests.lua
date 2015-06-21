require "include/protoplug"

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

--init
local outBuffer = pushOutput:getMidiBuffer()
for cc=0,127 do
	for val=20, 40 do
		outBuffer:addEvent(midi.Event.control(1, cc, 1))
	end
end
for note=0,127 do
    outBuffer:addEvent(midi.Event.noteOn(1, note, 0))
end
pushOutput:sendMessagesFromBuffer(44100)   

function plugin.processBlock(samples, smax, midiBuf)
	local pushInputBuf  = pushInput:collectNextBlockOfMessages(smax) 
    local pushOutputBuf = pushOutput:getMidiBuffer()

    for ev in pushInputBuf:eachEvent() do
        pushOutputBuf:addEvent(ev)
    end
    pushOutput:sendMessagesFromBuffer(plugin.getSampleRate())   
end


