--midi = require "include/core/midi"

local Push = {}

Push.Colors  = require "include/controllers/PushColors"
Push.Buttons = require "include/controllers/PushButtons" 
Push.Display = require "include/controllers/PushDisplay"

---Semi general copy function but kept in this namespace
--to avoid being blindly used
--Note ! : ffi stuff is not handled !
function Push.deepcopy(o, seen)
    seen = seen or {}
    if o == nil then return nil end
    if seen[o] then return seen[o] end

    local no
    if type(o) == 'table' then
        no = {}
        seen[o] = no

        for k, v in next, o, nil do
            no[Push.deepcopy(k, seen)] = Push.deepcopy(v, seen)
        end
        setmetatable(no, Push.deepcopy(getmetatable(o), seen))
    else -- number, string, boolean, etc
        no = o
    end
    return no
end

function Push.newPushState()
    --- PushState: table representing the state that the controller is currently into ( what lights are on, what buttons are pressed ... )
    --
    local PushState = {}

    ---Pads
    local Pads    = {}
    Pads.color    = {}
    Pads.pressed  = {}
    PushState.Pads = Pads

    for i=1,64 do
        Pads.color[#Pads.color+1]     = Push.Colors.PadColors.Black
        Pads.pressed[#Pads.pressed+1] = 0
    end

    function Pads:getColor(i,j)
        return self.color[(j-1)*8 + i]
    end

    function Pads:setColor(i,j,x)
        self.color[(j-1)*8 + i] = x
    end

    function Pads:getPressed(i,j)
        return self.pressed[(j-1)*8 + i]
    end

    --- Changes to send to controller to go from current state to nextPads state
    --  or pass nil to flush ( ie send full state to controller )
    function Pads:delta(nextPads) 
        local delta = {}
        delta.list  = {}
        for i=1,8 do
            for j=1,8 do
                if nextPads then
                    local nv = nextPads:getColor(i,j)
                    if nv ~= self:getColor(i,j) then
                        delta.list[#(delta.list)+1] = {i, j, nv}
                    end
                else --Flush the state
                    delta.list[#(delta.list)+1] = {i, j, self:getColor(i,j)}
                end
            end
        end

        function delta.changeToEvent(change)
            return midi.Event.noteOn(1, 35 + change[1] + (change[2]-1)*8, change[2])
        end

        return delta
    end

    function Pads:update(change)
        self:setColor(change[1], change[2], change[3])
    end

    --------------------------------
    ---Top row ( "selection control" row)
    local TopRow   = {}
    TopRow.color   = {}
    TopRow.pressed = {}
    PushState.TopRow = TopRow

    for i=1,8 do
        TopRow.color[#TopRow.color+1]   = Push.Colors.TopRowColors.Black
        TopRow.pressed[#TopRow.pressed+1] = 0
    end

    --- Changes to send to controller to go from current state to nextTopRow state
    --  or pass nil to flush ( ie send full state to controller )
    function TopRow:delta(nextTopRow)
        local delta = {}
        delta.list  = {}
        for i=1,8 do
            if nextTopRow then
                local nv = nextTopRow.color[i]
                if nv ~= self.color[i] then
                    delta.list[#delta.list+1] = {i, nv}
                end
            else -- Flush the state
                delta.list[#delta.list+1] = {i, self.color[i]}
            end
        end

        function delta.changeToEvent(change)
            return midi.Event.control(19+change[1], change[2], 1)
        end

        return delta
    end

    function TopRow:update(change)
        self.color[change[1]] = change[2]
    end

    ---Bottom row ( "State Control" row )
    PushState.BottomRow = Push.deepcopy(PushState.TopRow) --Cheap shot but effective

    function PushState.BottomRow:delta(nextBottomRow) --But we still have to redefine this function because of delta.changeToEvent. This could be improved
        local delta = {}
        delta.list  = {}
        for i=1,8 do
            if nextBottomRow then
                local nv = nextBottomRow.color[i]
                if nv ~= self.color[i] then
                    delta.list[#delta.list+1] = {i, nv}
                end
            else -- Flush the state
                delta.list[#delta.list+1] = {i, self.color[i]}
            end
        end

        function delta.changeToEvent(change)
            return midi.Event.control(101+change[1], change[2], 1)
        end

        return delta
    end
    

    --------------------------------
    -- Scene buttons
    local SceneButtons     = {}
    PushState.SceneButtons = SceneButtons
    SceneButtons.color     = {}
    SceneButtons.pushed    = {}
    SceneButtons.midiNum   = {36, 37, 38, 39, 40, 41, 42, 43}

    for i=1,8 do
        SceneButtons.color[#SceneButtons.color+1]     = Push.Colors.SceneColors.Red
        SceneButtons.pushed[#SceneButtons.pushed+1] = 0
    end

    --- Changes to send to controller to go from current state to nextSceneButtons state
    --  or pass nil to flush ( ie send full state to controller )
    function SceneButtons:delta(nextSceneButtons)
        local delta = {}
        delta.list  = {}
        for i=1,8 do
            if nextSceneButtons then
                local nv = nextSceneButtons.color[i]
                if nv ~= self.color[i] then
                    delta.list[#delta.list+1] = {i, nv}
                end
            else -- Flush the state
                delta.list[#delta.list+1] = {i, self.color[i]}
            end
        end

        function delta.changeToEvent(change)
            return midi.Event.control(SceneButtons.midiNum[change[1]], change[2], 1)
        end

        return delta
    end

    function SceneButtons:update(change)
        self.color[change[1]] = change[2]
    end

    --------------------------------
    -- All other buttons
    local Buttons     = {}
    PushState.Buttons = Buttons
    Buttons.color     = {}
    Buttons.pushed    = {}

    for _,k  in ipairs(Push.Buttons.All) do
        Buttons.color[k]  = Push.Buttons.States.Off
        Buttons.pushed[k] = 0
    end

    function Buttons:delta(nextButtons)
        local delta = {}
        delta.list  = {}
        for _,k in ipairs(Push.Buttons.All) do
            if nextButtons then
                local nv = nextSceneButtons.color[k]
                if nv ~= self.color[k] then
                    delta.list[#delta.list+1] = {k, nv}
                end
            else -- Flush the state
                delta.list[#delta.list+1] = {k, self.color[k]}
            end
        end

        function delta.changeToEvent(change)
            return midi.Event.control(change[1], change[2], 1)
        end

        return delta
    end

    function Buttons:update(change)
        self.color[change[1]] = change[2]
    end

    --------------------------------
    -- Display
    -- NOTE: Looks like the sysex data might have to be sent to the Push's live port rather than 
    -- user port like the rest
    --
    local Display = {}
    PushState.Display = Display
    Display.lines = {"Welcome to Protoplug", "", "", ""}

    function Display:delta(nextDisplayState)
        local delta = {}
        delta.list  = {}
        for i,l in ipairs(Display.lines) do
            if nextDisplayState then
                local nv = nextDisplayState.lines[i]
                if nv ~= l then
                    delta.list[#delta.list+1] = {i, nv}
                end
            else -- Flush the state
                delta.list[#delta.list+1] = {i, l}
            end
        end

        function delta.changeToEvent(change)
            return PushDisplay.printLine(change[1], change[2])
        end

        return delta
    end

    function Display:update(change)
        self.lines[change[1]] = change[2]
    end
    
    -------------------------------
    -- Ribbon
    -- TODO
    
    function PushState:clone()
        return Push.deepcopy(self)
    end

    --Return a table of changes to be applied in order to get from current state
    --to next state
    function PushState:delta(nextState)
        local delta = {}
        print("State delta")
        print("nextState: " .. tostring(nextState))

        for k, v in next, self, nil do
            print("delta key: " ..k)
            print("delta val: " ..tostring(v))
            if type(v) == 'table' then
                local ns = nextState and nextState[k] or nil
                delta[k] = self[k]:delta(ns)
            end
        end
    end

    return PushState
end

function Push.sendUpdateToController(deviceHandle, updateTable)
    print("Send update to controller")

    if not updateTable then
        return
    end
    local outBuffer        = deviceHandle.output:getMidiBuffer()
    local displayOutBuffer = deviceHandle.displayOutput:getMidiBuffer()

    for changeType, changes in pairs(updateTable) do
        local buffer = (changeType == 'Display') and displayOutBuffer or outBuffer

        print(changeType)
        for k, v in pairs(changes) do
            print("--- " .. k)
            print("--- " .. v)
        end
        print(changes)

        for _, change in ipairs(changes.list) do
            buffer:addEvent(changes.changeToEvent(change))
        end
    end
end

function Push.setupController()

    local inputDevices   = midi.MidiInput.getDevices()
    local outputDevices  = midi.MidiOutput.getDevices()
    local iIndexController, oIndexController
    local oIndexDisplay

    local deviceHandle = {}

    for i,v in ipairs(inputDevices) do
        if v:find("User Port") then
            iIndexController = i
        end
    end

    for i,v in ipairs(outputDevices) do
        if v:find("User Port") then
            oIndexController = i
        elseif v:find("Live Port") then
            oIndexDisplay = i
        end
    end

    if not iIndexController then error("Could not find Push User input port, check Push is properly connected") end
    if not oIndexController then error("Could not find Push User output port, check Push is properly connected") end
    if not oIndexDisplay    then error("Could not find Push Live output port, check Push is properly connected") end

    deviceHandle.input          = midi.MidiInput.openDevice(iIndexController-1) 
    deviceHandle.output         = midi.MidiOutput.openDevice(oIndexController-1) 
    deviceHandle.displayOutput  = midi.MidiOutput.openDevice(oIndexDisplay-1) 
    deviceHandle.state          = Push.newPushState() 
    deviceHandle.pendingChanges = {}

    function deviceHandle:flushState(state)
        local allChanges = state:delta(nil)
        Push.sendUpdateToController(self, allChanges)
        self.pendingChanges = {}
    end

    function deviceHandle:registerInputHandler(inputEvent, callBack)
        --TODO !
    end
    function deviceHandle:processInput(smax)
        local inputMidiBuffer = self.input:collectNextBlockOfMessages(smax) 
        for ev in inputMidiBuffer:eachEvent() do
            --TODO !
        end
    end

    function deviceHandle:changePadColor(i, j, newColor)
        local padChanges = self.pendingChanges.Pads or {}
        padChanges[#padChanges+1] = {i, j, newColor}
        self.pendingChanges.Pads = padChanges
    end

    --TODO other changes ( buttons... )

    function deviceHandle:processOutput()
        --Send to controller
        Push.sendUpdateToController(self, self.pendingChanges)
        --Update state
        for changeType, changes in pairs(self.pendingChanges) do
            for i, c in ipairs(changes) do
                self.state[changeType]:update(c)
            end
        end
        --Clear pending changes
        self.pendingChanges = {}
    end

    deviceHandle:flushState(deviceHandle.state)

    return deviceHandle
end

return Push

