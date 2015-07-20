local midi = require "core/midi"
local PushDisplay = {}

---Return a midi.Event containing the sysex message required to print the message on 
--display.
--Line has to be be between 1 and 4
--text must be a string of 68 characters or less
--Note that ASCII values between 0 and 31 can be used to print
--special characters, example usage string.char(0,1,2,3) ....
--Note that passing "" will print a blank line since strings are right padded automatically
PushDisplay.printLine = function(lineNum, _text, padLeft)

    lineNum = math.max(1, math.min(lineNum, 4))
    local pad       = {}
    local padLeftString = ""
    if padLeft and padLeft > 0 then
        for i=1, padLeft do
            pad[#pad+1] = " "
        end
        padLeftString = table.concat(pad, "")
    end
    pad = {}
    for i=1, 68 do
        pad[#pad+1] = " "
    end
    local padRightString = table.concat(pad, "")
    local text = string.sub(padLeftString.._text..padRightString,1,68) --truncate at 68 characters

    --SysEx message for screen: preamble{lineNumber}separator{ASCII char1}{ASCII char2}...{ASCII char68}termination
    local event       = midi.Event(0, 77)
    local preamble    = {0xf0, 0x47, 0x7f, 0x15} 
    local separator   = {0x0, 0x45, 0x0}
    local termination = {0xf7}

    local i = 0
    local addToMsg = function(p)
        for _,v in ipairs(p) do
            event.data[i] = bit.band(v, 127)
            i = i + 1
        end
    end

    addToMsg(preamble)
    addToMsg({bit.band(lineNum+23,127)})
    addToMsg(separator)

    for j=1, 68 do
        event.data[i] = bit.band(string.byte(text,j), 127)
        i = i + 1
    end

    --TODO check channel ?
    addToMsg(termination)

    return event
end

return PushDisplay
