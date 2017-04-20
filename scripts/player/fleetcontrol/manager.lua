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


function initialize()

    if onClient() then return end -- only initialize server-side

    local sconfig = getConfig("server", sconfigdefaults)
    enableDebugOutput(sconfig.debugoutput) 

    -- server<->client version check
    requestClientVersion()
    
end


function requestClientVersion()

    if onServer() then
        invokeClientFunction(Player(), "requestClientVersion")
    end

    local cmodinfo = getModInfo()
    -- send result back to server
    validateClientVersion(cmodinfo.version)

end


function validateClientVersion(cversion)

    if onClient() then
        invokeServerFunction("validateClientVersion", cversion)
    end

    local player = Player(callingPlayer)
    local smodinfo = getModInfo()

    local cminversion = smodinfo.clientminversion
    if cversion[1] >= cminversion[1] and cversion[2] >= cminversion[2] then 
        -- client version is valid for server version
        debugLog("successfully validated mod versions (server: %s | clientminversion: %s | client: %s)", getVersionString(smodinfo.version), getVersionString(cminversion), getVersionString(cversion))
        -- continue script loading etc.
        initShipUIHandling(player)
    else
        -- invalid/outdated client version
        scriptLog(player, "Invalid client mod versions, aborted loading of scripts (server: %s | clientminversion: %s | client: %s)", getVersionString(smodinfo.version), getVersionString(cminversion), getVersionString(cversion))
        local msg = "Could not load UI due to client-server version mismatch!\nYour version is %s, minimum required version is %s\nPlease update the mod files and restart the game!"
        player:sendChatMessage(smodinfo.name, 0, string.format(msg, getVersionString(cversion), getVersionString(cminversion)))
    end

end


function initShipUIHandling(player)

    -- subscribe to event callbacks
    player:registerCallback("onShipChanged", "onShipChanged")	
    Server():registerCallback("onPlayerLogOff", "onPlayerLogOff")

    -- add UI script
    addShipUIScript(player.craftIndex) 

end


-- called by server on galaxy/sector saving
-- given return values are persisted into galaxy database
function secure()

    -- return lastCraft

end


-- called by server on galaxy/sector loading
-- given arguments are persisted return values of secure() function 
function restore(data)

    -- lastCraft = data
    
end


function onPlayerLogOff(playerIndex)

    debugLog("onPlayerLogOff() -> playerIndex: %s", playerIndex)

    local player = Player(playerIndex)
    local shipidx = player.craftIndex

    removeShipUIScript(shipidx)	
    if lastCraft and lastCraft ~= shipidx then
        -- ensure all UI scripts are deattached
        removeShipUIScript(lastCraft)	
    end

end


function onShipChanged(playerIndex, craftIndex)

    debugLog("onShipChanged() -> playerIndex: %s |craftIndex: %s", playerIndex, craftIndex)

    local player = Player(playerIndex)
    local shipidx = player.craftIndex

    --add and remove UI script for ship entities
    if lastCraft then
        removeShipUIScript(lastCraft)	
    end
    addShipUIScript(craftIndex)	

end


function addShipUIScript(shipidx)

    -- add script to ship entity
    if shipidx and shipidx > 0 and lastCraft ~= shipidx then
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
    end
    
end

-- TODO: implement uninstall function (remove all scripts from every entity)
