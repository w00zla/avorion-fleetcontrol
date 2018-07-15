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

-- namespace FleetControlCommon
FleetControlCommon = {}

local Me = FleetControlCommon


-- MODINFO
local modInfo = {  
    name = "FleetControl",
    author = "w00zla",
    version = { 0, 5, 1 },
    clientminversion = { 0, 5, 1 }
}

-- config
local debugoutput = false
local configprefix = "fleetcontrol_"

local sconfigdefaults = {
    updatedelay = 750,
    enablehud = true,
    debugoutput = false
}
local pconfigdefaults = {
    groups = {
            {
                name="Group 1",
                showhud=true,
                hudcolor={a=0.5,r=1,g=1,b=1}
            },
            {
                name="Group 2",
                showhud=true,
                hudcolor={a=0.5,r=0.75,g=0.75,b=0.75}
            },
            {
                name="Group 3",
                showhud=true,
                hudcolor={a=0.5,r=0.5,g=0.5,b=0.5}
            },
            {
                name="Group 4",
                showhud=true,
                hudcolor={a=0.5,r=0.25,g=0.25,b=0.25}
            }    
        },
    hud = {
            showhud = true,
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
            enableordersounds = true,
            ordersoundfile = "fc-affirmative,fc-copy,fc-roger",
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
FleetControlCommon.fc_script_manager = "data/scripts/player/fleetcontrol/manager.lua"
FleetControlCommon.fc_script_controlui = "data/scripts/entity/fleetcontrol/controlui.lua"
FleetControlCommon.fc_script_craftorders = "data/scripts/entity/fleetcontrol/fccraftorders.lua"

-- other stuff

local ordersInfo = {
    { order="Idle", text="Idle"%_t, script=Me.fc_script_craftorders, func="onIdleButtonPressed" },
    { order="Passive", text="Passive"%_t, script=Me.fc_script_craftorders, func="stopFlying" },
    { order="Guard", text="Guard Position"%_t, script=Me.fc_script_craftorders, func="onGuardButtonPressed" },
    { order="Patrol", text="Patrol Sector"%_t, script=Me.fc_script_craftorders, func="onPatrolButtonPressed" },
    { order="Escort", text="Escort Me"%_t, script=Me.fc_script_craftorders, func="escortEntity", param="playercraftindex" },
    --{ order="Follow", text="Follow Me"%_t, script=Me.av_script_craftorders, func="followEntity", param="playercraftindex" },
    { order="EscortShip", text="Escort Ship"%_t, script=Me.fc_script_controlui, func="onEscortShipButtonPressed", param="selectedcraftindex", invokecurrent=true, nongrouporder=true },
    { order="Attack", text="Attack Enemies"%_t, script=Me.fc_script_craftorders, func="onAttackEnemiesButtonPressed" },
    { order="Mine", text="Mine"%_t, script=Me.fc_script_craftorders, func="onMineButtonPressed" },
    { order="", text="Salvage"%_t, script=Me.fc_script_craftorders, func="onSalvageButtonPressed" },
}

local aiStates = {
    "Aggressive", "Attack", "Escort", "Fly", "Follow", 
    "Guard", "Idle", "Jump", "None", "Passive", "Patrol"
}

local paramtypelabels = { pnum="Number", bool="Boolean" }


function FleetControlCommon.enableDebugOutput(enable)
    debugoutput = enable or false
end


function FleetControlCommon.getConfig(scope, defaults)
    local config = CachedConfig(configprefix, defaults, scope)
    if defaults then
        for k, v in pairs(defaults) do
            local cval = config[k]
            Me.debugLog("%s config value loaded -> k: %s v: %s", scope, k, cval)
        end
    end
    return config
end


function FleetControlCommon.copyConfig(source)
    local copy = CachedConfig(configprefix, source._defaults, source._scope, source._index)
    copy._cache = source._cache
    return copy
end


function FleetControlCommon.saveConfig(config)
    if config then
        --Me.debugLog("persisting %s configuration...", config._scope)
        CachedConfig_CommitSave(config)
    end
end


function FleetControlCommon.clearConfigStorage(config)
	if config then
		--Me.debugLog("clearing %s configuration...", config._scope)
        CachedConfig_ClearSavedValues(config)
	end
end


function FleetControlCommon.getServerConfigDefaults()
    return sconfigdefaults
end

function FleetControlCommon.getPlayerConfigDefaults()
    return pconfigdefaults
end


function FleetControlCommon.getOrdersInfo()
    return ordersInfo
end

function FleetControlCommon.getAiStates()
    return aiStates
end


function FleetControlCommon.getModInfo()
    return modInfo
end

function FleetControlCommon.getVersionString(version)
    if version then
		if #version == 3 then
			return string.format("v%i.%i.%i", version[1],  version[2], version[3])
		else
				return string.format("v%i.%i", version[1],  version[2])
		end
    end
end

function FleetControlCommon.getModInfoLine()
    return string.format("%s [%s] by %s", modInfo.name, Me.getVersionString(modInfo.version), modInfo.author)
end


function FleetControlCommon.shortenText(text, maxlen)

    if text then
        if string.len(text) > maxlen then
            text = string.sub(text, 1, maxlen - 2) .. "..."
        end
    end
    return text

end


function FleetControlCommon.formatPosition(pos)
    return string.format("X=%i Y=%i", pos.x, pos.y)
end


-- validate parameter value based on type
function FleetControlCommon.validateParameter(paramval, paramtype)

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
function FleetControlCommon.getParamTypeLabel(paramtype)

	local paramtypelabel = paramtype
	if paramtypelabels[paramtype] then
		paramtypelabel = paramtypelabels[paramtype]
	end
	return paramtypelabel
	
end


-- attaches script to entity if not already existing
function FleetControlCommon.ensureEntityScript(entity, entityscript, ...)
    
    if tonumber(entity) then
        entity = Entity(entity)
    end
    
    if entity and not entity:hasScript(entityscript) then
        entity:addScriptOnce(entityscript, ...)
        Me.debugLog("script was added to entity (index: %s, script: %s)", entity.index, entityscript)
    end

end


function FleetControlCommon.removeEntityScript(entity, entityscript)

    if tonumber(entity) then
        entity = Entity(entity)
    end

    if entity and entity:hasScript(entityscript) then
        entity:removeScript(entityscript)
        Me.debugLog("script was removed from entity (index: %s, script: %s)", entity.index, entityscript)
    end	

end


function FleetControlCommon.scriptLog(player, msg, ...)

    if msg and msg ~= "" then 
        local pinfo = ""
        if player then pinfo = " p#" .. tostring(player.index) end
        local prefix = string.format("SCRIPT %s [%s]%s => ", modInfo.name, Me.getVersionString(modInfo.version), pinfo)
        Me.printsf(prefix .. msg, ...)
    end
    
end


function FleetControlCommon.debugLog(msg, ...)

    if debugoutput and msg and msg ~= "" then
        local pinfo = ""
        if onServer() then
            local player = Player()
            if player then pinfo = " p#" .. tostring(player.index) end
        end
        local prefix = string.format("SCRIPT %s [%s]%s DEBUG => ", modInfo.name, Me.getVersionString(modInfo.version), pinfo)
        Me.printsf(prefix .. msg, ...)
    end
    
end


function FleetControlCommon.printsf(message, ...)

    message = string.format(message, ...)
    print(message)
    
end


function FleetControlCommon.table_contains(table, value)

    for _, v in pairs(table) do
        if v == value then return true end
    end
    return false

end

function FleetControlCommon.table_childByKeyVal(table, key, value)

    for i, t in pairs(table) do
        if type(t) == "table" and t[key] == value then
            return t, i
        end
    end

end


-- source: http://notebook.kulchenko.com/algorithms/alphanumeric-natural-sorting-for-humans-in-lua
function FleetControlCommon.alphanumsort(o)

  local function padnum(d) return ("%03d%s"):format(#d, d) end
  table.sort(o, function(a,b)
    return tostring(a):gsub("%d+",padnum) < tostring(b):gsub("%d+",padnum) end)
  return o

end
function FleetControlCommon.sortShipsArray(o)

  local function padnum(d) return ("%03d%s"):format(#d, d) end
  table.sort(o, function(a,b)
    return a.name:gsub("%d+",padnum) < b.name:gsub("%d+",padnum) end)
  return o

end


function FleetControlCommon.checkShipCaptain(entity)

    if entity.isShip then
        local captains = entity:getCrewMembers(CrewProfessionType.Captain)
        return (captains and captains > 0)
    end
    
end


function FleetControlCommon.checkShipAllianceFlyCraftPrivileges(entity, playeridx)

    if entity.allianceOwned then
        local ally = Alliance(entity.factionIndex)
        local auth = ally:hasPrivilege(playeridx, AlliancePrivilege.FlyCrafts)
        if not auth then          
            debugLog("player #%s has no 'FlyCrafts' privilege for alliance '%s'", playeridx, ally.name)
            return false
        end  
    end

    return true
end


function FleetControlCommon.getPlayerCrafts()

    local ships = {}
    local player = Player()

    -- player owned ships
    local playerentities = {Sector():getEntitiesByFaction(player.index)}
    for _, e in pairs(playerentities) do
        if e.isShip then
            table.insert(ships, { name=e.name, index=e.index })
        end
    end

    -- manageable alliance ships
    if player.alliance then
        local allyentities = {Sector():getEntitiesByFaction(player.allianceIndex)}
        for _, e in pairs(allyentities) do
            if e.isShip and Co.checkShipAllianceFlyCraftPrivileges(e, player.index) then
                table.insert(ships, { name=e.name, index=e.index })
            end
        end
    end

    return ships

end


function FleetControlCommon.getAIStateString(state)

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


function FleetControlCommon.getShipAIOrderState(entity, playershipidx)

    local aistate, order

    local ai = ShipAI(entity.index)
    if ai then
        aistate = Me.getAIStateString(ai.state)
    end

    -- if entity:hasScript(Me.fc_script_craftorders) then
    --     local success, target = entity:invokeFunction(Me.fc_script_craftorders, "getCurrentTagetData")
    --     if not success then
    --         Me.scriptLog("Could not invoke script '%s' sucessfully -> unable to retrieve ship order", Me.fc_script_craftorders)
    --     end
    --     if not target.action then
    --         order = aistate 
    --     elseif target.action == 1 then -- Escort
    --         if target.index == playershipidx then
    --             order = "Escort"
    --         else
    --             order = "EscortShip"
    --         end
    --     elseif target.action == 2 or target.action == 7 then -- Attack or Aggressive
    --         order = "Attack"
    --     -- elseif target.action == 3 then -- FlyThroughWormhole
    --     --     order = "FlyThroughWormhole"
    --     -- elseif target.action == 4 then -- FlyToPosition
    --     --     order = "FlyToPosition"
    --     elseif target.action == 5 then -- Guard
    --         order = "Guard"
    --     elseif target.action == 6 then -- Patrol
    --         order = "Patrol"
    --     elseif target.action == 8 then -- Mine
    --         order = "Mine"
    --     elseif target.action == 9 then -- Salvage
    --         order = "Salvage"
    --     end
    -- else

        -- get current ship order by looking at the AI state and attached scripts like "ai/mine.lua"

        if ai.state == AIState.Idle or 
           ai.state == AIState.Passive or 
           ai.state == AIState.Guard then
            order = aistate
        elseif ai.state == AIState.Aggressive then
            order = "Attack"
        elseif ai.state == AIState.Escort then
            order = "EscortShip"
        elseif ai.state == AIState.Follow then
            order = "Follow"
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
    -- end

    return aistate, order

end


-- gets all existing files in given directory
function FleetControlCommon.scandir(directory, pattern)

    local i, t, popen = 0, {}, io.popen
    --local BinaryFormat = package.cpath:match("%p[\\|/]?%p(%a+)")
	local BinaryFormat = string.sub(package.cpath,-3)
	local cmd = ""
	if not string.ends(directory, "/") then
		directory = directory .. "/"				
	end
	local path = directory	
	if pattern then 	
		path = path .. pattern
	end
    if BinaryFormat == "dll" then
		path = string.gsub(path, "/", "\\")
		cmd =   'dir "'..path..'" /b /a-d'
    else
		path = string.gsub(path, "\\", "/")
		cmd = "ls " .. path
    end
	
	Me.debugLog("scandir() -> cmd: %s", cmd)
    local pfile = popen(cmd)
    for filename in pfile:lines() do
		i = i + 1
		if string.starts(filename, directory) then
			t[i] = string.sub(filename, string.len(directory) + 1)
		else
			t[i] = filename
		end		
    end
    pfile:close()
    return t
	
end


function FleetControlCommon.getInterfaceSounds()

    local soundfiles = Me.scandir("data/sfx/interface/", "*.wav")

    Me.debugLog("getInterfaceSounds() -> soundfiles:")
    printTable(soundfiles)

    local sounds = {}
    for i, sf in pairs(soundfiles) do
        sounds[i] = sf:match("(.+)%..+")
    end

    Me.debugLog("getInterfaceSounds() -> sounds:")
    printTable(sounds)

    return sounds

end
