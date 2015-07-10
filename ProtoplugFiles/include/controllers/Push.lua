--local midi = require "../core/midi"
--
--
local Push = {}

Push.Colors  = require "PushColors"
Push.Buttons = require "PushButtons" 
Push.Display = require "PushDisplay"

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
        Pads.color[#Pads.color+1]     = Push.Colors.PadsColors.Black
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
        for i=1,8 do
            for j=1,8 do
                if nextPads then
                    local nv = nextPads.getColor(i,j)
                    if nv != self.getColor(i,j) then
                        delta[#delta+1] = {i, j, nv}
                    end
                else --Flush the state
                    delta[#delta+1] = {i, j, self.getColor(i,j)}
                end
            end
        end
        return delta
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
        for i=1,8 do
            if nextTopRow then
                local nv = nextTopRow.color[i]
                if nv != self.color[i] then
                    delta[#delta+1] = {i, nv}
                end
            else -- Flush the state
                delta[#delta+1] = {i, self.color[i]}
            end
        end
        return delta
    end

    ---Bottom row ( "State Control" row )
    PushState.BottomRow = Push.deepCopy(PushState.TopRow) --Cheap shot but effective

    --------------------------------
    -- Scene buttons
    local SceneButtons     = {}
    PushState.SceneButtons = SceneButtons
    SceneButtons.color     = {}
    SceneButtons.pushed    = {}
    SceneButtons.midiNum   = {36, 37, 38, 39, 40, 41, 42, 43}

    for i=1,8 do
        SceneButtons.color[#SceneButtons.color+1]     = Push.Colors.SceneColors.Red
        SceneButtons.pressed[#SceneButtons.pressed+1] = 0
    end

    --- Changes to send to controller to go from current state to nextSceneButtons state
    --  or pass nil to flush ( ie send full state to controller )
    function SceneButtons:delta(nextSceneButtons)
        local delta = {}
        for i=1,8 do
            if nextSceneButtons then
                local nv = nextSceneButtons.color[i]
                if nv != self.color[i] then
                    delta[#delta+1] = {i, nv}
                end
            else -- Flush the state
                delta[#delta+1] = {i, self.color[i]}
            end
        end
        return delta
    end

    --------------------------------
    -- All other buttons
    local Buttons     = {}
    PushState.Buttons = Buttons
    Buttons.colors    = {}
    Buttons.pushed    = {}

    for _,k  in ipairs(Push.Buttons.All) do
        Buttons.colors[k] = Push.Buttons.States.Off
        Buttons.pushed[k] = 0
    end

    function Buttons:delta(nextButtons)
        local delta = {}
        for _,k in ipairs(Push.Buttons.All) do
            if nextButtons then
                local nv = nextSceneButtons.color[k]
                if nv != self.color[k] then
                    delta[#delta+1] = {k, nv}
                end
            else -- Flush the state
                delta[#delta+1] = {k, self.color[k]}
            end
        end
        return delta
    end

    --------------------------------
    -- Display
    -- NOTE: Looks like the sysex data might have to be sent to the Push's live port rather than 
    -- user port like the rest
    --
    local Display = {}
    PushState.Display = Display
    Display.lines = {}  = {"Welcome to our awesome drum seq", "", "", ""}

    function Display:delta(nextDisplayState)
        local delta = {}
        for i,l in ipairs(Display.lines) do
            if nextDisplayState then
                local nv = nextDisplayState.lines[i]
                if nv != l then
                    delta[#delta+1] = {i, nv}
                end
            else -- Flush the state
                delta[#delta+1] = {i, l}
            end
        end
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

        for k, v in next, self, nil do
            if type(v) == 'table' then
                ns = nextState and nextState[k] or nil
                delta[k] = self[k]:delta(ns)
            end
        end
    end

    return PushState
end

