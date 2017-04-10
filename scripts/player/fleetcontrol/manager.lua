--[[

FLEETCONTROL MOD
author: w00zla

file: player/fleetcontrol/manager.lua
desc:  player script for managing fleet data and entity UI scripts

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

require "utility"
require "stringutility"

require "fleetcontrol.common"


local lastCraft
local storage = "notyet"


function initialize()

    -- subscribe to event callbacks
    Player():registerCallback("onShipChanged", "onShipChanged")	
    
    addShipScript(fc_controlui) 
    
end


-- called by server on galaxy/sector saving
-- given return values are persisted into galaxy database
function secure()

    scriptLog("manager.lua -> secure() called")

    if storage then
        return storage
    end
    
end


-- called by server on galaxy/sector loading
-- given arguments are persisted return values of secure() function 
function restore(data)

    scriptLog("manager.lua -> restore() called")

    storage = data
    
end


function onShipChanged(playerIndex, craftIndex)

    -- remove and add script to ship entities
    removeEntityScript(lastCraft, fc_controlui)	
    addShipScript(fc_controlui)	

end


function addShipScript(script) 

    -- add script to current ship entity
    if Player().craftIndex and Player().craftIndex > 0 then
        local entity = Entity(Player().craftIndex)
        if entity then
            ensureEntityScript(entity, script)
            lastCraft = entity.index	
        end
    end

end


function removeScripts()

    -- remove scripts from all ship entities
    local currentCraft = Player().craftIndex
    removeEntityScript(currentCraft, fc_controlui)
    
    if lastCraft ~= currentCraft then
        removeEntityScript(lastCraft, fc_controlui)
    end

    -- unsubscribe from event callbacks
    Player():unregisterCallback("onShipChanged", "onShipChanged")

    -- kill and remove script from entity
    terminate()
    
end

