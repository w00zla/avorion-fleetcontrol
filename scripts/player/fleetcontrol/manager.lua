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

    if onClient() then return end -- only init server-side

    local sconfig = getConfig("server", sconfigdefaults)
    enableDebugOutput(sconfig.debugoutput) 

    -- deferred server<->client version check
    -- (calling invokeClient/invokeServer from initialize just keeps calling the function in current context!)
    deferredCallback(1, "requestClientVersion")
 
end


function requestClientVersion()

    if onServer() then
        invokeClientFunction(Player(), "requestClientVersion")
        return
    end
    
    local cmodinfo = getModInfo()
    scriptLog(nil, "client mod version requested by server -> %s", getVersionString(cmodinfo.version))

    -- send result back to server
    validateClientVersion(cmodinfo.version)

end


function validateClientVersion(cversion)

    if onClient() then
        invokeServerFunction("validateClientVersion", cversion)
        return
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
        scriptLog(player, "invalid client mod versions, aborted loading of scripts (server: %s | clientminversion: %s | client: %s)", getVersionString(smodinfo.version), getVersionString(cminversion), getVersionString(cversion))
        player:sendChatMessage(smodinfo.name, 0, "Could not load UI due to client-server version mismatch!")
        player:sendChatMessage(smodinfo.name, 0, string.format("Your version is %s, minimum required version is %s", getVersionString(cversion), getVersionString(cminversion)))
        player:sendChatMessage(smodinfo.name, 0, "Please update the mod files on your client and restart the game!")
    end

end


function initShipUIHandling(player)

    -- subscribe to event callbacks
    player:registerCallback("onShipChanged", "onShipChanged")	
    Server():registerCallback("onPlayerLogOff", "onPlayerLogOff")

    -- add UI script
    addShipUIScript(player.craftIndex) 

end


function onPlayerLogOff(playerIndex)

    debugLog("onPlayerLogOff() -> playerIndex: %s", playerIndex)

    local player = Player(playerIndex)
    if lastCraft then 
        -- ensure UI scripts are deattached
        removeShipUIScript(lastCraft)	
    end

end


function onShipChanged(playerIndex, craftIndex)

    debugLog("onShipChanged() -> playerIndex: %s | craftIndex: %s", playerIndex, craftIndex)

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

    -- remove scripts(s) from player ship
    if shipidx and shipidx > 0 then
        local entity = Entity(shipidx)
        if entity then
            removeEntityScript(entity, fc_script_controlui)
            if shipidx == lastCraft then
                lastCraft = nil
            end
        end
    end
    
end


function removeAllScripts()

    local player = Player()
    local shipidx = player.craftIndex

    --add and remove UI script for ship entities
    removeShipUIScript(shipidx)
    if lastCraft and lastCraft ~= shipidx then
        removeShipUIScript(lastCraft)	
    end

    -- TODO: remove all scripts from every entity

    -- remove myself
    terminate()
end
