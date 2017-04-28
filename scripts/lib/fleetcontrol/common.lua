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
    name = "FleetControl",
    author = "w00zla",
    version = { 0, 4 },
    clientminversion = { 0, 4 }
}

-- config
local debugoutput = false
local configprefix = "fleetcontrol_"

local sconfigdefaults = {
    updatedelay = 750,
    enablehud = true
}
local pconfigdefaults = {
    groups = {
            {
                name="Group 1",
                showhud=false,
                hudcolor={a=0.5,r=1,g=1,b=1}
            },
            {
                name="Group 2",
                showhud=false,
                hudcolor={a=0.5,r=0.75,g=0.75,b=0.75}
            },
            {
                name="Group 3",
                showhud=false,
                hudcolor={a=0.5,r=0.5,g=0.5,b=0.5}
            },
            {
                name="Group 4",
                showhud=false,
                hudcolor={a=0.5,r=0.25,g=0.25,b=0.25}
            }    
        },
    hud = {
            showhud = false,
            hudanchor = {x=50,y=50},
            hudstyle = 0,
            showgroupnames = true,
            showshipstates = true,     
            showshiporders = true,
            showshiplocations = false,
            hideuncaptained = true,
            useuistatecolors = false,
        },
    ui = {
            preselectorderstab = true,
            preselectordersfirstpage = false,
            closewindowonlookat = true,
            statecolors = {
                Aggressive = {r=0.9,g=0.5,b=0.2},
                Attack = {r=0.9,g=0.7,b=0.4},
                Escort = {r=0.9,g=0.9,b=0},
                Fly = {r=0.6,g=0.3,b=0.4},
                Follow = {r=0.8,g=0.9,b=0.1},
                Guard = {r=0.2,g=0.4,b=0.8},
                Idle = {r=0.3,g=0.3,b=0.3},
                Jump = {r=0.5,g=0.4,b=0.7},
                None = {r=1,g=1,b=1},
                Passive = {r=0.5,g=0.5,b=0.5},
                Patrol = {r=0.6,g=0.7,b=0.9},
            }
        },
    knownships = {},
    shipgroups = { {},{},{},{} }
}

-- globals
fc_script_manager = "data/scripts/player/fleetcontrol/manager.lua"
fc_script_controlui = "data/scripts/entity/fleetcontrol/controlui.lua"
av_script_craftorders = "data/scripts/entity/craftorders.lua"

-- other stuff

local ordersInfo = {
    { order="Idle", text="Idle", script=av_script_craftorders, func="onIdleButtonPressed" },
    { order="Passive", text="Passive", script=av_script_craftorders, func="onPassiveButtonPressed" },
    { order="Guard", text="Guard Position", script=av_script_craftorders, func="onGuardButtonPressed" },
    { order="Patrol", text="Patrol Sector", script=av_script_craftorders, func="onPatrolButtonPressed" },
    { order="Escort", text="Escort Me", script=av_script_craftorders, func="onEscortMeButtonPressed", param="playercraftindex" },
    { order="EscortShip", text="Escort Ship", script=fc_script_controlui, func="onEscortShipButtonPressed", param="selectedcraftindex", invokecurrent=true, nongrouporder=true },
    { order="Attack", text="Attack Enemies", script=av_script_craftorders, func="onAttackEnemiesButtonPressed" },
    { order="Mine", text="Mine", script=av_script_craftorders, func="onMineButtonPressed" },
    { order="Salvage", text="Salvage", script=av_script_craftorders, func="onSalvageButtonPressed" }
}

local aiStates = {
    "Aggressive", "Attack", "Escort", "Fly", "Follow", 
    "Guard", "Idle", "Jump", "None", "Passive", "Patrol"
}

local paramtypelabels = { pnum="Number", bool="Boolean" }


function enableDebugOutput(enable)
    debugoutput = enable or false
end


function getConfig(scope, defaults)
    return CachedConfig(configprefix, defaults, scope)
end

function getServerConfigDefaults()
    return sconfigdefaults
end

function getPlayerConfigDefaults()
    return pconfigdefaults
end


function getOrdersInfo()
    return ordersInfo
end

function getAiStates()
    return aiStates
end


function getModInfo()
    return modInfo
end

function getVersionString(version)
    if version then
        return string.format("v%i.%i", version[1],  version[2])
    end
end

function getModInfoLine()
    return string.format("%s [%s] by %s", modInfo.name, getVersionString(modInfo.version), modInfo.author)
end


function shortenText(text, maxlen)

    if text then
        if string.len(text) > maxlen then
            text = string.sub(text, 1, maxlen - 2) .. "..."
        end
    end
    return text

end


function formatPosition(pos)
    return string.format("X=%i Y=%i", pos.x, pos.y)
end


-- validate parameter value based on type
function validateParameter(paramval, paramtype)

	-- paramvalidate config paramvalues by type
	if paramval and paramval ~= "" then
		if paramtype == "pnum" then
			-- positive number paramvalues
			local pnum = tonumber(configparamval)
			if pnum and pnum >= 0 then
				return pnum
			end
		elseif paramtype == "bool" then
			if paramval:lower() == "true" then
                paramval = true
            elseif paramval:lower() == "false" then
                paramval = false
            end
            return paramval
		end
		-- generic string param
		return paramval
	end
	
end


-- get nice titles for parameter-types
function getParamTypeLabel(paramtype)

	local paramtypelabel = paramtype
	if paramtypelabels[paramtype] then
		paramtypelabel = paramtypelabels[paramtype]
	end
	return paramtypelabel
	
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


function scriptLog(player, msg, ...)

    if msg and msg ~= "" then 
        local pinfo = ""
        if player then pinfo = " p#" .. tostring(player.index) end
        local prefix = string.format("SCRIPT %s [%s]%s => ", modInfo.name, getVersionString(modInfo.version), pinfo)
        printsf(prefix .. msg, ...)
    end
    
end


function debugLog(msg, ...)

    if debugoutput and msg and msg ~= "" then
        local pinfo = ""
        if onServer() then
            local player = Player()
            if player then pinfo = " p#" .. tostring(player.index) end
        end
        local prefix = string.format("SCRIPT %s [%s]%s DEBUG => ", modInfo.name, getVersionString(modInfo.version), pinfo)
        printsf(prefix .. msg, ...)
    end
    
end


function printsf(message, ...)

    message = string.format(message, ...)
    print(message)
    
end


function table.contains(table, value)

    for _, v in pairs(table) do
        if v == value then return true end
    end
    return false

end

function table.childByKeyVal(table, key, value)

    for i, t in pairs(table) do
        if type(t) == "table" and t[key] == value then
            return t, i
        end
    end

end


-- source: http://notebook.kulchenko.com/algorithms/alphanumeric-natural-sorting-for-humans-in-lua
function alphanumsort(o)

  local function padnum(d) return ("%03d%s"):format(#d, d) end
  table.sort(o, function(a,b)
    return tostring(a):gsub("%d+",padnum) < tostring(b):gsub("%d+",padnum) end)
  return o

end
function sortShipsArray(o)

  local function padnum(d) return ("%03d%s"):format(#d, d) end
  table.sort(o, function(a,b)
    return a.name:gsub("%d+",padnum) < b.name:gsub("%d+",padnum) end)
  return o

end


function checkShipCaptain(entity)

    if entity.isShip then
        local captains = entity:getCrewMembers(CrewProfessionType.Captain)
        return (captains and captains > 0)
    end
    
end


function getPlayerCrafts()

    local ships = {}
    local player = Player()

    local playerentities = {Sector():getEntitiesByFaction(player.index)}
    for _, e in pairs(playerentities) do
        if e.isShip then
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
           ai.state == AIState.Guard then
            order = aistate
        elseif ai.state == AIState.Aggressive then
            order = "Attack"
        elseif ai.state == AIState.Escort then
            order = "EscortShip"
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