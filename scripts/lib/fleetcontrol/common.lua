--[[

FLEETCONTROL MOD
author: w00zla

file: lib/fleetcontrol/common.lua
desc:  general library script for fleetcontrol mod

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

require "utility"
require "stringutility"

CachedConfig = require("fleetcontrol.cachedconfig")

-- MODINFO
local modInfo = {  
    name = "fleetcontrol",
    version = "0.1",
    author = "w00zla"
}

-- config
local configdefaults = {
    updatedelay = 750,
    debugoutput = false
}
local configprefix = "fleetcontrol_"
local myconfig = CachedConfig(configprefix, configdefaults, "player")

-- globals
av_script_craftorders = "data/scripts/entity/craftorders.lua"
fc_script_controlui = "fleetcontrol/controlui.lua"

-- useful stuff
local ordersInfo = {
    { order="Idle", text="Idle", script=av_script_craftorders, func="onIdleButtonPressed"},
    { order="Passive", text="Passive", script=av_script_craftorders, func="onPassiveButtonPressed"},
    { order="Guard", text="Guard Position", script=av_script_craftorders, func="onGuardButtonPressed"},
    { order="Patrol", text="Patrol Sector", script=av_script_craftorders, func="onPatrolButtonPressed"},
    { order="Escort", text="Escort Me", script=av_script_craftorders, func="onEscortMeButtonPressed", param="playercraftindex"},
    { order="Attack", text="Attack Enemies", script=av_script_craftorders, func="onAttackEnemiesButtonPressed"},
    { order="Mine", text="Mine", script=av_script_craftorders, func="onMineButtonPressed"},
    { order="Salvage", text="Salvage", script=av_script_craftorders, func="onSalvageButtonPressed"}
}


function getConfig()
    return myconfig
end

function getOrdersInfo()
    return ordersInfo
end


-- attaches script to entity if not already existing
function ensureEntityScript(entity, entityscript, ...)
    
    if tonumber(entity) then
        entity = Entity(entity)
    end
    
    if entity and not entity:hasScript(entityscript) then
        entity:addScriptOnce(entityscript, ...)
        debugLog("script was added to entity (index: %s, script: %s)", entity.index, entityscript)
    end

end


function removeEntityScript(entity, entityscript)

    if tonumber(entity) then
        entity = Entity(entity)
    end

    if entity and entity:hasScript(entityscript) then
        entity:removeScript(entityscript)
        debugLog("script was removed from entity (index: %s, script: %s)", entity.index, entityscript)
    end	

end


function getModInfoLine()

    return string.format("%s [v%s] by %s", modInfo.name, modInfo.version, modInfo.author)

end

function scriptLog(player, msg, ...)

    if msg and msg ~= "" then 
        local pinfo = ""
        if player then pinfo = " p#" .. tostring(player.index) end
        local prefix = string.format("SCRIPT %s [v%s]%s => ", modInfo.name, modInfo.version, pinfo)
        printsf(prefix .. msg, ...)
    end
    
end


function debugLog(msg, ...)

    if myconfig.debugoutput and msg and msg ~= "" then
        local pinfo = ""
        if onServer() then
            local player = Player()
            if player then pinfo = " p#" .. tostring(player.index) end
        end
        local prefix = string.format("SCRIPT %s [v%s]%s DEBUG => ", modInfo.name, modInfo.version, pinfo)
        printsf(prefix .. msg, ...)
    end
    
end


function printsf(message, ...)

    message = string.format(message, ...)
    print(message)
    
end


function tablecontains(table, value)

    for _, v in pairs(table) do
        if v == value then return true end
    end
    return false

end


local function checkCaptain(entity)

    local captains = entity:getCrewMembers(CrewProfessionType.Captain)
    if captains and captains > 0 then
        return true
    end

end


function getPlayerCaptainedCrafts()

    local ships = {}
    local player = Player()

    local playerentities = {Sector():getEntitiesByFaction(player.index)}
    for _, e in pairs(playerentities) do
        if e.index ~= player.craftIndex and e.isShip and checkCaptain(e) then
            table.insert(ships, { name=e.name, index=e.index })
        end
    end

    return ships

end


function getAIStateString(state)

    local aistate = "-"

    if state == AIState.None then
        aistate = "None"
    elseif state == AIState.Idle then
        aistate = "Idle"
    elseif state == AIState.Patrol then
        aistate = "Patrol"
    elseif state == AIState.Escort then
        aistate = "Escort"
    elseif state == AIState.Aggressive then
        aistate = "Aggressive"
    elseif state == AIState.Passive then
        aistate = "Passive"
    elseif state == AIState.Guard then
        aistate = "Guard"
    elseif state == AIState.Jump then
        aistate = "Jump"
    elseif state == AIState.Fly then
        aistate = "Fly"
    elseif state == AIState.Attack then
        aistate = "Attack"
    elseif state == AIState.Follow then
        aistate = "Follow"
    end

    return aistate

end


function getShipAIOrderState(entity)

    local aistate, order

    local ai = ShipAI(entity.index)
    if ai then
        aistate = getAIStateString(ai.state)
        
        -- get current ship order by looking at the AI state and attached scripts like "ai/mine.lua"
        if ai.state == AIState.Idle or 
           ai.state == AIState.Passive or 
           ai.state == AIState.Guard or 
           ai.state == AIState.Escort then
            order = aistate
        elseif ai.state == AIState.Aggressive then
            order = "Attack"
        else
            -- get special orders
            if entity:hasScript("ai/patrol.lua") then
                order = "Patrol"
            elseif entity:hasScript("ai/mine.lua") then
                order = "Mine"
            elseif entity:hasScript("ai/salvage.lua") then
                order = "Salvage"
            end
        end
    end

    return aistate, order

end