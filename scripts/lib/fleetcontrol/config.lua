--[[

FLEETCONTROL MOD
author: w00zla

file: lib/fleetcontrol/config.lua
desc: configuration util for fleetcontrol mod

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"


-- available defaults
local defaults = {
	debugoutput = false
}


local configprefix = "fleetcontrol_"
local debugoutput = nil
local Config = {}


function Config.saveValue(config, val)

	local storagekey = configprefix .. config
	Server():setValue(storagekey, val)

end


function Config.loadValue(config)

	local storagekey = configprefix .. config
	local val = Server():getValue(storagekey)
	
	if not val and defaults[config] then
		val = defaults[config]
	end
	return val

end


function Config.getCurrent()

	local cfg = {
		-- galaxypath = Config.loadValue("galaxypath"),
	}
	
	return cfg
end


function Config.debugoutput()

	if debugoutput == nil then
		debugoutput = Config.loadValue("debugoutput")
	end	
	return debugoutput

end


return Config
