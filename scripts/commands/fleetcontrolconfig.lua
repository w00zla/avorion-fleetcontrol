--[[

FLEETCONTROL MOD
author: w00zla

file: commands/fleetcontrolconfig.lua
desc:  auto-included script to implement custom command /fleetcontrolconfig

]]--


require "fleetcontrol.common"


function execute(sender, commandName, ...)
	local args = {...}	
	local player = Player(sender)	
    local modinfo = getModInfo()
	
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

    local sconfig = getConfig("server", sconfigdefaults)

    local valid = false
	local paramtype = ""
	local config = configkey
	
	-- if configkey == "galaxy" then
	-- 	configval = validateParameter(configval, "Name")
	-- 	if configval then
	-- 		local datapath = getDefaultDataPath()
	-- 		if not datapath then
	-- 			scriptLog(player, "ERROR: unable to determine default datapath!")
	-- 			player:sendChatMessage("findstation", 0, "Error: unable to determine default datapath!")
	-- 		end
	-- 		configkey = "galaxypath"
	-- 		galaxyname = configval
	-- 		configval = datapath .. configval .. "/"
	-- 		if not checkFileExists(configval .. "server.ini") then
	-- 			player:sendChatMessage("findstation", 0, "Error: Unable to find directory for galaxy '%s'!", galaxyname)
	-- 			return
	-- 		end
	-- 		valid = true
	-- 	end
    -- end

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