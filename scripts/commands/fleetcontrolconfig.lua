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
	
	if configkey == "updatedelay" then
		paramtype = "pnum"
		configval = validateParameter(configval, paramtype)
		if configval then valid = true end
	if configkey == "enablehud" then
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