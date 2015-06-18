--- MidiInput
-- wrap functionality from [JUCE MidiInput](https://www.juce.com/api/classMidiInput.html)
--- MidiOutput
-- wrap functionality from [JUCE MidiOutput](https://www.juce.com/api/classMidiOutput.html)
ffi.cdef [[
struct pStringList
{
	char** strings;
	int listSize;
};
pStringList getMidiInputDevices();
pStringList getMidiOutputDevices();
void StringList_delete(pStringList l)
]]

local MidiInput = {}
local MidiOutput = {}

function MidiInput.getDevices()
    local cList = ffi.gc(protolib.getMidiInputDevices(), protolib.StringList_delete)
    local sList = {}
    for i=0, cList.listSize-1 do
        sList[#sList+1] = ffi.string(cList.strings[i])
    end
    return sList
end
function MidiOutput.getDevices()
    local cList = ffi.gc(protolib.getMidiOutputDevices(), protolib.StringList_delete)
    local sList = {}
    for i=0, cList.listSize-1 do
        sList[#sList+1] = ffi.string(cList.strings[i])
    end
    return sList
end

return MidiInput, MidiOutput
