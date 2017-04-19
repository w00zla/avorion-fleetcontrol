--[[

FLEETCONTROL MOD
author: w00zla

file: player/fleetcontrol/manager.lua
desc:  player script for managing fleet data and entity UI scripts

]]--

if onServer() then -- make this script run server-side only


package.path = package.path .. ";data/scripts/lib/?.lua"

require "utility"
require "stringutility"

require "fleetcontrol.common"


local lastCraft


function initialize()

    local sconfig = getConfig("server", sconfigdefaults)
    enableDebugOutput(sconfig.debugoutput) 

    local player = Player()

    -- subscribe to event callbacks
    player:registerCallback("onShipChanged", "onShipChanged")	
    -- add UI script
    addShipUIScript(player.craftIndex) 
    
end


-- called by server on galaxy/sector saving
-- given return values are persisted into galaxy database
function secure()

    return lastCraft

end


-- called by server on galaxy/sector loading
-- given arguments are persisted return values of secure() function 
function restore(data)

    lastCraft = data
    
end


function onShipChanged(playerIndex, craftIndex)

    local player = Player(playerIndex)
    local shipidx = player.craftIndex

    --add and remove UI script for ship entities
    removeShipUIScript(shipidx)	
    addShipUIScript(shipidx)	

end


function addShipUIScript(shipidx)

    -- add script to ship entity
    if shipidx and shipidx > 0 then
        local entity = Entity(shipidx)
        if entity then
            ensureEntityScript(entity, fc_script_controlui)
            lastCraft = entity.index	
        end
    end

end


function removeShipUIScript(shipidx)

    if shipidx and shipidx > 0 then
        -- remove scripts(s) from player ship
        removeEntityScript(shipidx, fc_script_controlui)
        -- try remove scripts(s) from last known ship for sakes (i.e. after server crashes)
        if lastCraft ~= shipidx then
            removeEntityScript(lastCraft, fc_script_controlui)
        end
    end
    
end

-- TODO: implement uninstall function (remove all scripts from every entity)

end