--local midi = require "../core/midi"
--
--
local Push = {}

Push.Colors = require "PushColors"

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
    local Pads = {}
    PushState.Pads = Pads

    for i=1,64 do
        Pads[#Pads+1] = Push.Colors.PadsColors.Black
    end

    function Pads:get(i,j)
        return self[(j-1)*8 + i]
    end

    function Pads:set(i,j,x)
        self[(j-1)*8 + i] = x
    end

    function Pads:delta(nextPads)
        local delta = {}
        for i=1,8 do
            for j=1,8 do
                local nv = nextPads.get(i,j)
                if nv != self.get(i,j) then
                    delta[#delta+1] = {i, j, nv}
                end
            end
        end
        return delta
    end
    
    --------------------------------
    ---Top row ( "selection control" row)
    local TopRow = {}
    PushState.TopRow = TopRow

    for i=1,8 do
        TopRow[#TopRow+1] = Push.Colors.TopRowColors.Black
    end

    function TopRow:delta(nextTopRow)
        local delta = {}
        for i=1,8 do
            local nv = nextTopRow[i]
            if nv != self[i] then
                delta[#delta+1] = {i, nv}
            end
        end
        return delta
    end

    ---Bottom row ( "State Control" row )
    PushState.BottomRow = Push.deepCopy(PushState.TopRow) --Cheap shot but effective

    --------------------------------
    
    function PushState:clone()
        return Push.deepcopy(self)
    end

    --Return a table of changes to be applied in order to get from current state
    --to next state
    function PushState:delta(nextState)
        local delta = {}

        for k, v in next, self, nil do
            if type(v) == 'table' then
                delta[k] = self[k]:delta(nextState[k])
            end
        end
    end

    return PushState
end

