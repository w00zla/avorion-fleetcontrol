--[[

FLEETCONTROL MOD
author: w00zla

file: lib/fleetcontrol/common.lua
desc:  general library script for fleetcontrol mod

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

require "utility"
require "stringutility"

Config = require("findstation.config")

-- globals
fc_controlui = "fleetcontrol/controlui.lua"


local modInfo = {  
	name = "fleetcontrol",
	version = "0.1",
	author = "w00zla"
}


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

	if Config.debugoutput() and msg and msg ~= "" then
		local pinfo = ""
		local player = Player()
		if player then pinfo = " p#" .. tostring(player.index) end
		local prefix = string.format("SCRIPT %s [v%s]%s DEBUG => ", modInfo.name, modInfo.version, pinfo)
		printsf(prefix .. msg, ...)
	end
	
end


function printsf(message, ...)

	message = string.format(message, ...)
	print(message)
	
end