require "include/protoplug"
Push = require "include/controllers/Push"

local pushControllerHandle = Push.setupController()

local function createTimer(_timeInterval)
    local counter = 0
    local timeInterval = _timeInterval

    local function nextEventSample(sampleRate, smax, timeIntervalChange)
        if timeIntervalChange then
            timeInterval = timeInterval
        end
        local nextSample = ( timeInterval * sampleRate ) - counter
        counter = ( counter + smax ) % ( timeInterval * sampleRate )
        return nextSample
    end

    return nextEventSample
end


local function ClockedFunction(timeInterval, f)
    local timer = createTimer(timeInterval)

    local function clock(sampleRate, smax, timeIntervalChange)
        local nextEventSample = timer(sampleRate,smax, timeIntervalChange)
        if nextEventSample <= smax then
            f(sampleRate, smax)
        end
    end
    return clock

end

local function createBlinkingCol(col, color, timeInterval)
    local br = {}
    br.row       = 1
    br.col       = col
    br.color     = color
    br.direction = 1
    br.run       = 1

    --turn on first pad
    pushControllerHandle:changePadColor(br.row, br.col, br.color)

    function br.blink(sampleRate, smax)
        if not br.run then 
            return
        end
        pushControllerHandle:changePadColor(br.row, br.col, Push.Colors.PadColors.Black)
        
        br.row = br.row + br.direction
    
        if br.row > 8 then
            br.row  = 7
            br.direction = -1
        elseif br.row < 1 then
            br.row  = 2
            br.direction = 1
        end

        pushControllerHandle:changePadColor(br.row, br.col, br.color)
    end

    br.clock = ClockedFunction(timeInterval, br.blink)
    
    return br
end

local blinkingCols = {}
for i = 1, 8 do
    blinkingCols[i] = createBlinkingCol(i, Push.Colors.PadColors.Lime, 0.5)
end

local function CreateLinesBuffer()
    local lines = {"","","",""}
    local writeTo   = 3
    local printFrom = 0

    local function pushLine(text)
        writeTo   = 1 + (writeTo % 4)
        printFrom = 1 + (printFrom % 4)
        lines[writeTo] = text
        local r = printFrom
        for i=0, 3 do
            pushControllerHandle:changeDisplayLine(i+1, lines[r])
            r = 1 + ((printFrom+i)%4)
        end
    end
    return pushLine
end

local pushLineToDisplay = CreateLinesBuffer()

local function printMidiEventToDisplay(event, state)
    local text
    if event:isNoteOn() then
        text = "Note On    : " .. tostring(event:getNote()) .. ", velocity = " .. tostring(event:getVel())
    end
    if event:isNoteOff() then
        text = "Note Off   : " .. tostring(event:getNote()) .. ", velocity = " .. tostring(event:getVel())
    end
    if event:isControl() then
        text = "Control    : " .. tostring(event:getControlNumber()) .. ", value = " .. tostring(event:getControlValue())
    end
    if event:isAftertouch() then
        text = "Aftertouch : " .. tostring(event:getNote()) .. ", value = " .. tostring(event:getAftertouch())
    end
    if not text then return end

    pushLineToDisplay(text)
end

pushControllerHandle:registerInputHandler(printMidiEventToDisplay)

function plugin.processBlock(samples, smax, midiBuf)
    pushControllerHandle:processInput(smax)
    local sr = plugin.getSampleRate()

    for i = 1, 8 do
        blinkingCols[i].clock(sr, smax)
    end

    pushControllerHandle:processOutput(sr)

end

