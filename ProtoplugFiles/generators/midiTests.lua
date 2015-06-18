require "include/protoplug"
local J = require "include/protojuce"

--Welcome to Lua Protoplug generator (version 1.3.0)

local inputDevices = J.MidiInput.getDevices()

for _, v in ipairs(inputDevices) do
	print("Input "..v)
end

local outputDevices = J.MidiOutput.getDevices()

for _, v in ipairs(outputDevices) do
	print("Output "..v)
end
 