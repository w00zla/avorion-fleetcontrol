--[[

FLEETCONTROL MOD
author: w00zla

file: commands/fleetcontrolconfig.lua
desc:  auto-included script to implement custom command /fleetcontrolconfig

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

require "fleetcontrol.common"


local modinfo


function execute(sender, commandName, ...)
	local args = {...}	
	local player = Player(sender)	
    modinfo = getModInfo()
	
	if #args > 0 and args[1] ~= "" then	
		-- parse command args
		local configkey = string.lower(args[1])
		local configval = table.concat(args, " ", 2)	
		
		-- validate and save config option
		updateConfig(player, configkey, configval)

	else
		player:sendChatMessage(modinfo.name, 0, "Missing parameters! Use '/help fleetcontrolconfig' for information.")	
	end

    return 0, "", ""
end


function updateConfig(player, configkey, configval)

	local valid = false
	local paramtype = ""
    local sconfig = getConfig("server", sconfigdefaults)
	enableDebugOutput(sconfig.debugoutput) 
	
	if configkey == "updatedelay" then
		paramtype = "pnum"
		configval = validateParameter(configval, paramtype)
		if configval then valid = true end
	elseif configkey == "enablehud" then
		paramtype = "bool"
		configval = validateParameter(configval, paramtype)
		if configval ~= nil then valid = true end
	elseif configkey == "debugoutput" then
		paramtype = "bool"
		configval = validateParameter(configval, paramtype)
		if configval ~= nil then valid = true end
	else
		-- unknown config
		scriptLog(player, "unknown server configuration (key: %s | val: %s)", configkey, configval)
		player:sendChatMessage(modinfo.name, 0, "Error: Unknown server configuration '%s'!", configkey)
		return
    end

	if valid then
		-- valid update -> save config
		sconfig[configkey] = configval		
		scriptLog(player, "server configuration updated -> key: %s | val: %s", configkey, configval)
		player:sendChatMessage(modinfo.name, 0, "Server configuration updated successfully")
		-- trigger server config update for all relevant players
		local playerIndices = {}
		local onlinePlayers = Galaxy():getOnlinePlayerNames()
		if type(onlinePlayers) == "string" then -- and onlinePlayers == player.name then
			-- only one player, assume singleplayer game
			table.insert(playerIndices, player.index)
		else
			for index, name in pairs(onlinePlayers) do
				if Player(index):hasScript(fc_script_manager) then
					table.insert(playerIndices, index)
				end
			end
		end
		if sconfig.debugoutput then
			debugLog("update config -> found online players with manager script attached:")
			printTable(playerIndices)
		end
		for _, idx in pairs(playerIndices) do
			debugLog("update config -> triggering server config update in scripts for player %i", idx)
			Player(idx):invokeFunction(fc_script_manager, "updateServerConfig") 
		end
	else
		-- invalid value	
		local paramtypelabel = getParamTypeLabel(paramtype)
		scriptLog(player, "invalid server configuration value (key: %s | val: %s | paramtype: %s)", configkey, configval, paramtype)
		player:sendChatMessage(modinfo.name, 0, "Error: %s parameter required for config '%s'!", paramtypelabel, configkey)
	end

end


function getDescription()
    return "Configuration helper for the FleetControl mod."
end


-- called by /help command
function getHelp()
    return [[
Configuration helper for the FleetControl mod.
Usage:
/fleetcontrolconfig updatedelay <NUMBER>
/fleetcontrolconfig enablehud <BOOLEAN>
Parameter:
<NUMBER> = any positive number or 0
<BOOLEAN> = 'true' or 'false'
]]
end