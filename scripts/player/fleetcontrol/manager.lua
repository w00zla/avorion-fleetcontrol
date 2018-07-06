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

-- namespace FleetControlManager
FleetControlManager = {}


local lastCraft


function FleetControlManager.initialize()

    if onClient() then return end -- only init server-side

    local sconfig = getConfig("server", sconfigdefaults)
    enableDebugOutput(sconfig.debugoutput) 

    -- deferred server<->client version check
    -- (calling invokeClient/invokeServer from initialize just keeps calling the function in current context!)
    deferredCallback(1, "requestClientVersion")
 
end


function FleetControlManager.requestClientVersion()

    if onServer() then
        invokeClientFunction(Player(), "requestClientVersion")
        return
    end
    
    local cmodinfo = getModInfo()

    scriptLog(nil, "client mod version requested by server -> %s", getVersionString(cmodinfo.version))

    -- send result back to server
    FleetControlManager.validateClientVersion(cmodinfo.version)

end


function FleetControlManager.validateClientVersion(cversion)

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
        deferredCallback(1, "initShipUIHandling", player)
        --FleetControlManager.initShipUIHandling(player)
    else
        -- invalid/outdated client version
        scriptLog(player, "invalid client mod versions, aborted loading of scripts (server: %s | clientminversion: %s | client: %s)", getVersionString(smodinfo.version), getVersionString(cminversion), getVersionString(cversion))
        player:sendChatMessage(smodinfo.name, 0, "Could not load UI due to client-server version mismatch!")
        player:sendChatMessage(smodinfo.name, 0, string.format("Your version is %s, minimum required version is %s", getVersionString(cversion), getVersionString(cminversion)))
        player:sendChatMessage(smodinfo.name, 0, "Please update the mod files on your client and restart the game!")
    end

end


function FleetControlManager.initShipUIHandling(player)

    -- subscribe to event callbacks
    player:registerCallback("onShipChanged", "onShipChanged")	
    player:registerCallback("onSectorEntered", "onSectorEntered")
    Sector():registerCallback("onDestroyed", "onDestroyed")
    Server():registerCallback("onPlayerLogOff", "onPlayerLogOff")

    -- add UI script
    FleetControlManager.addShipUIScript(player.craftIndex) 

end


function FleetControlManager.onPlayerLogOff(playerIndex)

    debugLog("onPlayerLogOff() -> playerIndex: %s", playerIndex)

    local player = Player(playerIndex)
    if lastCraft then 
        -- ensure UI scripts are deattached
        FleetControlManager.removeShipUIScript(lastCraft)	
    end

end


function FleetControlManager.onShipChanged(playerIndex, craftIndex)

    debugLog("onShipChanged() -> playerIndex: %s | craftIndex: %s", playerIndex, craftIndex)

    local player = Player(playerIndex)
    local shipidx = player.craftIndex

    --add and remove UI script for ship entities
    if lastCraft then
        FleetControlManager.removeShipUIScript(lastCraft)	
    end
    FleetControlManager.addShipUIScript(craftIndex)	

end


function FleetControlManager.onDestroyed(index, lastDamageInflictor) 

    debugLog("onDestroyed()")
    FleetControlManager.removePlayerShip(index)

end


function FleetControlManager.onSectorEntered(playerIndex, x, y) 

    Sector():registerCallback("onDestroyed", "onDestroyed")
    FleetControlManager.updateSectorPlayerShips()

end


function FleetControlManager.addShipUIScript(shipidx)

    -- add script to ship entity
    if shipidx and lastCraft ~= shipidx then
        local entity = Entity(shipidx)
        if entity and valid(entity) then
            ensureEntityScript(entity, fc_script_controlui)
            lastCraft = entity.index
        end
    end

end


function FleetControlManager.removeShipUIScript(shipidx)

    -- remove scripts(s) from player ship
    if shipidx then
        local entity = Entity(shipidx)
        if entity and valid(entity) then
            removeEntityScript(entity, fc_script_controlui)
            if shipidx == lastCraft then
                lastCraft = nil
            end
        end
    end
    
end


function FleetControlManager.removeAllScripts()

    local player = Player()
    local shipidx = player.craftIndex

    --add and remove UI script for ship entities
    FleetControlManager.removeShipUIScript(shipidx)
    if lastCraft and lastCraft ~= shipidx then
        FleetControlManager.removeShipUIScript(lastCraft)	
    end

    -- TODO: remove all scripts from every entity when non-UI entity scripts are added

    -- remove myself
    FleetControlManager.terminate()
end


function FleetControlManager.removePlayerShip(index)

    local entity = Entity(index)
    if entity and valid(entity) then
        -- get config values to update
        local pconfig = getConfig("player", getPlayerConfigDefaults())
        local knownships = pconfig.knownships
        local shipgroups = pconfig.shipgroups
        
        local ship, idx = table.childByKeyVal(knownships, "name", entity.name)
        if ship then
            -- remove ship(s) from knownships
            table.remove(knownships, idx)
            -- remove ship from assigned group
            for g, grp in pairs(shipgroups) do 
                for s, shp in pairs(grp) do
                    if shp == entity.name then
                        table.remove(shipgroups[g], s)
                        break
                    end
                end
            end
            -- update configs
            pconfig.knownships = knownships
            -- debugLog("onDestroyed() -> knownships:")
            -- debugLog(printTable(knownships))
            pconfig.shipgroups = shipgroups
            -- debugLog("onDestroyed() -> shipgroups:")
            -- debugLog(printTable(shipgroups))

            scriptLog(Player(), "player ship '%s' was destroyed -> known and group ships were updated", entity.name)       
        end
    end

end


function FleetControlManager.updateSectorPlayerShips()

    local pconfig = getConfig("player", getPlayerConfigDefaults())
    local knownships = pconfig.knownships

    -- get all exisiting ships of player in current sector
    local sectorships = getPlayerCrafts()

    local cx, cy = Sector():getCoordinates()
    local coords = {x=cx, y=cy}

    -- remove known ship if not encountered in last saved location/sector
    -- (this is a workaround until ships can report back their location properly)
    local delidx = {}
    for i, s in pairs(knownships) do
        if s.location.x == coords.x and s.location.y == coords.y then
            local ship = table.childByKeyVal(sectorships, "name", s.name)
            if not ship then
                table.insert(delidx, i)    
                -- remove ship from assigned group
                for gi, grp in pairs(shipgroups) do 
                    for si, shp in pairs(grp) do
                        if shp == s.name then
                            table.remove(shipgroups[gi], si)
                            break
                        end
                    end
                end
            end
        end      
    end
    if #delidx > 0 then
        -- remove ship(s) from knownships
        for _, idx in pairs(delidx) do
            local ship = knownships[idx]
            table.remove(knownships, idx)        
            scriptLog(Player(), "player ship '%s' was expected but not found in sector!", ship.name)
        end
        -- update player config
        pconfig.knownships = knownships
        scriptLog(Player(), "player known and group ships were updated")
    end

end


function FleetControlManager.updateServerConfig()

    local player = Player()
    if player.craftIndex and player.craftIndex > 0 then
        local entity = Entity(player.craftIndex)
        if entity and valid(entity) then
            -- push server config values to client UI script
            FleetControlManager.pushShipUIServerConfig(entity)
        end
    end

end