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

local Config = {}
local debugoutput = {
    server = nil,
    sector = nil,
    player = nil,
    entity = nil
}


function Config.saveValue(scope, config, val)

    local storagekey = configprefix .. config

    local target = getTargetByScope(scope)
    target:setValue(storagekey, val)
    
end


function Config.loadValue(scope, config)

    local storagekey = configprefix .. config

    local target = getTargetByScope(scope)
    local val = target:getValue(storagekey)
    
    if not val and defaults[config] then
        val = defaults[config]
    end
    return val

end


function getTargetByScope(scope)

    if scope == "entity" then
        return Entity()
    elseif scope == "player" then
        return Player()
    elseif scope == "sector" then
        return Sector()
    elseif scope == "server" then
        return Server()
    end

end


function Config.getCurrent()

    local cfg = {
        -- galaxypath = Config.loadValue("galaxypath"),
    }
    
    return cfg
end


function Config.debugoutput(scope)

    if debugoutput[scope] == nil then
        debugoutput[scope] = Config.loadValue(scope, "debugoutput")
    end	
    return debugoutput[scope]

end


return Config
