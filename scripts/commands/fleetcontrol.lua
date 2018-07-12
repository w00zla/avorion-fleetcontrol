--[[

FLEETCONTROL MOD
author: w00zla

file: commands/fleetcontrol.lua
desc:  auto-included script to implement custom command /fleetcontrol

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

require "fleetcontrol.common"

-- namespace FleetControlCommand
FleetControlCommand = {}

local Me = FleetControlCommand
local Co = FleetControlCommon


function FleetControlCommand.execute(sender, commandName, ...)
	local args = {...}	
	local player = Player(sender)	
    local modinfo = Co.getModInfo()

	if #args == 0 or args[1] == "enable" then	
	
		-- make sure entity scripts are present
		Co.ensureEntityScript(player, Co.fc_script_manager)
		Co.scriptLog(player, "UI was enabled  -> manager script attached to player")
		player:sendChatMessage(modinfo.name, ChatMessageType.ServerInfo, "'Fleet Control' UI was enabled")
		
	elseif args[1] == "disable" then
		
		if player:hasScript(Co.fc_script_manager) then
			player:invokeFunction(Co.fc_script_manager, "removeAllScripts")		
			Co.scriptLog(player, "all scripts have been removed")
		end			
		player:sendChatMessage(modinfo.name, ChatMessageType.ServerInfo, "'Fleet Control' UI was disabled")
		
	else
		player:sendChatMessage(modinfo.name, ChatMessageType.ServerInfo, "Missing parameters! Use '/help fleetcontrol' for information.")
	end

    return 0, "", ""
end


function FleetControlCommand.getDescription()
    return "Enables/disables the UI (menu item & window) for FleetControl mod."
end


-- called by /help command
function FleetControlCommand.getHelp()
    return [[
Enables/disables the UI (menu item & window) for FleetControl mod.
Usage:
/fleetcontrol
/fleetcontrol enable
/fleetcontrol disable
]]
end