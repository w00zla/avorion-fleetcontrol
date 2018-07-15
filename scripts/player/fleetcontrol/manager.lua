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

local Me = FleetControlManager
local Co = FleetControlCommon

local lastCraft


function FleetControlManager.initialize()

    if onClient() then return end -- only init server-side

    local sconfig = Co.getConfig("server", Co.getServerConfigDefaults())
    Co.enableDebugOutput(sconfig.debugoutput) 

    -- deferred server<->client version check
    -- (calling invokeClient/invokeServer from initialize just keeps calling the function in current context!)
    deferredCallback(1, "requestClientVersion")
 
end


function FleetControlManager.onRemove()
    Me.removeAllScripts()
end


function FleetControlManager.requestClientVersion()

    if onServer() then
        invokeClientFunction(Player(), "requestClientVersion")
        return
    end
    
    local cmodinfo = Co.getModInfo()

    Co.scriptLog(nil, "client mod version requested by server -> %s", Co.getVersionString(cmodinfo.version))

    -- send result back to server
    Me.validateClientVersion(cmodinfo.version)

end


function FleetControlManager.validateClientVersion(cversion)

    if onClient() then
        invokeServerFunction("validateClientVersion", cversion)
        return
    end

    local player = Player(callingPlayer)
    local smodinfo = Co.getModInfo()

    local cminversion = smodinfo.clientminversion
    local versionvalid = false
    if #cversion == 3 and cversion[1] >= cminversion[1] and cversion[2] >= cminversion[2] and cversion[3] >= cminversion[3] then
        versionvalid = true
    elseif cversion[1] >= cminversion[1] and cversion[2] >= cminversion[2] then
        versionvalid = true
    end
    
    if versionvalid then 
        -- client version is valid for server version
        Co.debugLog("successfully validated mod versions (server: %s | clientminversion: %s | client: %s)", 
                Co.getVersionString(smodinfo.version), Co.getVersionString(cminversion), Co.getVersionString(cversion))

        Me.upgradeConfigs()
        -- continue script loading etc.
        Me.initShipUIHandling(player)
    else
        -- invalid/outdated client version
        Co.scriptLog(player, "invalid client mod versions, aborted loading of scripts (server: %s | clientminversion: %s | client: %s)", 
                Co.getVersionString(smodinfo.version), Co.getVersionString(cminversion), Co.getVersionString(cversion))
        player:sendChatMessage(smodinfo.name, ChatMessageType.ServerInfo, "Could not load UI due to client-server version mismatch!")
        player:sendChatMessage(smodinfo.name, ChatMessageType.ServerInfo, string.format("Your version is %s, minimum required version is %s", 
                Co.getVersionString(cversion), Co.getVersionString(cminversion)))
        player:sendChatMessage(smodinfo.name, ChatMessageType.ServerInfo, "Please update the mod files on your client and restart the game!")
    end

end


function FleetControlManager.upgradeConfigs()

    local pconfig = Co.getConfig("player", Co.getPlayerConfigDefaults())
    if pconfig.knownships then
        for _, ship in pairs(pconfig.knownships) do           
            if not ship.index then
                pconfig.knownships = {}
                pconfig.shipgroups = {}
                Co.saveConfig(pconfig)
                break
            end
        end
    end

end


function FleetControlManager.initShipUIHandling(player)

    -- subscribe to event callbacks
    player:registerCallback("onShipChanged", "onShipChanged")	
    player:registerCallback("onSectorEntered", "onSectorEntered")
    Sector():registerCallback("onDestroyed", "onDestroyed")
    Server():registerCallback("onPlayerLogOff", "onPlayerLogOff")

    -- add UI script
    Me.addShipUIScript(player.craftIndex) 

end


function FleetControlManager.onPlayerLogOff(playerIndex)

    Co.debugLog("onPlayerLogOff() -> playerIndex: %s", playerIndex)

    local player = Player(playerIndex)
    if lastCraft then 
        -- ensure UI scripts are deattached
        Me.removeShipUIScript(lastCraft)	
    end

end


function FleetControlManager.onShipChanged(playerIndex, craftIndex)

    Co.debugLog("onShipChanged() -> playerIndex: %s | craftIndex: %s", playerIndex, craftIndex)

    local player = Player(playerIndex)
    local shipidx = player.craftIndex

    --add and remove UI script for ship entities
    if lastCraft then
        Me.removeShipUIScript(lastCraft)	
    end
    Me.addShipUIScript(craftIndex)	

end


function FleetControlManager.onDestroyed(index, lastDamageInflictor) 

    Co.debugLog("onDestroyed()")
    Me.removePlayerShip(index)

end


function FleetControlManager.onSectorEntered(playerIndex, x, y) 

    Sector():registerCallback("onDestroyed", "onDestroyed")
    Me.updateSectorPlayerShips()

end


function FleetControlManager.addShipUIScript(shipidx)

    -- add script to ship entity
    if shipidx and lastCraft ~= shipidx then
        local entity = Entity(shipidx)
        if entity and valid(entity) then
            Co.ensureEntityScript(entity, Co.fc_script_controlui)
            lastCraft = entity.index
        end
    end

end


function FleetControlManager.removeShipUIScript(shipidx)

    -- remove scripts(s) from player ship
    if shipidx then
        local entity = Entity(shipidx)
        if entity and valid(entity) then
            Co.removeEntityScript(entity, Co.fc_script_controlui)
            if shipidx == lastCraft then
                lastCraft = nil
            end
        end
    end
    
end


function FleetControlManager.removeAllScripts()

    local player = Player()
    local shipidx = player.craftIndex

    -- remove UI script for current ship
    Me.removeShipUIScript(shipidx)
    if lastCraft and lastCraft ~= shipidx then
        Me.removeShipUIScript(lastCraft)	
    end

    -- remove all entity scripts for all known ships
    for _, s in pairs(knownships) do
        local entity = Entity(s.index)
        if entity and valid(entity) then
            Co.removeEntityScript(entity, Co.fc_script_craftorders)
        end
    end

    -- remove myself
    terminate()
end


function FleetControlManager.removePlayerShip(index)

    local entity = Entity(index)
    if entity and valid(entity) then
        -- get config values to update
        local pconfig = Co.getConfig("player", Co.getPlayerConfigDefaults())
        local knownships = pconfig.knownships
        local shipgroups = pconfig.shipgroups
        
        local ship, idx = Co.table_childByKeyVal(knownships, "index", entity.index.string)
        if ship then
            -- remove ship(s) from knownships
            table.remove(knownships, idx)
            -- remove ship from assigned group
            for g, grp in pairs(shipgroups) do 
                for s, shpidx in pairs(grp) do
                    if shpidx == entity.index.string then
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

            Co.scriptLog(Player(), "player ship '%s' was destroyed -> known and group ships were updated", entity.name)       
        end
    end

end


function FleetControlManager.updateSectorPlayerShips()

    local pconfig = Co.getConfig("player", Co.getPlayerConfigDefaults())
    local knownships = pconfig.knownships
    local shipgroups = pconfig.shipgroups

    -- get all exisiting ships of player in current sector
    local sectorships = Co.getPlayerCrafts()

    local cx, cy = Sector():getCoordinates()
    local coords = {x=cx, y=cy}

    -- remove known ship if not encountered in last saved location/sector
    -- (this is a workaround until ships can report back their location properly)
    local delidx = {}
    for i, s in pairs(knownships) do
        if s.location.x == coords.x and s.location.y == coords.y then
            local ship = Co.table_childByKeyVal(sectorships, "name", s.name)
            if not ship then
                table.insert(delidx, i)    
                -- remove ship from assigned group
                for gi, grp in pairs(shipgroups) do 
                    for si, shpidx in pairs(grp) do
                        if shpidx == s.index then
                            table.remove(shipgroups[gi], si)
                            break
                        end
                    end
                end
            end
        end      
    end
    pconfig.shipgroups = shipgroups

    if #delidx > 0 then
        -- remove ship(s) from knownships
        for _, idx in pairs(delidx) do
            local ship = knownships[idx]
            table.remove(knownships, idx)        
            Co.scriptLog(Player(), "player ship '%s' was expected but not found in sector!", ship.name)
        end
        -- update player config
        pconfig.knownships = knownships
        Co.scriptLog(Player(), "player known and group ships were updated")
    end

end


function FleetControlManager.updateServerConfig()

    local player = Player()
    if player.craftIndex then
        local entity = Entity(player.craftIndex)
        if entity and valid(entity) then
            -- push server config values to client UI script
            local sconfig = Co.getConfig("server", Co.getServerConfigDefaults())            
            entity:invokeFunction(Co.fc_script_controlui, "syncServerConfig", sconfig, player.index)
        end
    end

end
