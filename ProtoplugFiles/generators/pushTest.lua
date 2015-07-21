require "include/protoplug"


local pushControllerHandle = Push.setupController()

function createTimer(_timeInterval)
    local counter = 0
    local timeInterval = _timeInterval

    local function nextEventSample(sampleRate, smax)
        local nextSample = ( timeInterval * sampleRate ) - counter
        counter = ( counter + smax ) % ( timeInterval * sampleRate )
        return nextSample
    end

    return nextEventSample
end

local timer = createTimer(0.5)

local blinkRow   = 1
local blinkCol   = 1
local direction  = 1

local blinkColorOn  = PushColors.PadColors.Lime
local blinkColorOff = PushColors.PadColors.Black

pushControllerHandle:changePadColor(blinkRow, blinkCol, blinkColorOn)

function plugin.processBlock(samples, smax, midiBuf)
    pushControllerHandle:processInput(smax)

    local nextEventSample = timer.nextEventSample(plugin.getSampleRate(), smax)

    if nextEventSample < smax then
        pushControllerHandle:changePadColor(blinkRow, blinkCol, blinkColorOff)
        
        blinkCol = blinkCol + direction

        if blinkCol > 8 then
            blinkCol  = 7
            direction = -1
        elseif blinkCol < 1 then
            blinkCol  = 1
            direction = 1
        end

        pushControllerHandle:changePadColor(blinkRow, blinkCol, blinkColorOn)
    end

    pushControllerHandle:processOutput()

end


