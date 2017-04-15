--[[

FLEETCONTROL MOD
author: w00zla

file: lib/fleetcontrol/cachedconfig.lua
desc: configuration util for fleetcontrol mod (with cached values)

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

json = require("fleetcontrol.json")


local CachedConfig = {
    _scope = "server",
    _index = nil,
    _prefix = nil,
    _defaults = {}
}


local function new(prefix, defaults, scope, index)

    -- prefix is required
    if not prefix or prefix == "" then
        error("CachedConfig: prefix must not be nil or empty!")
    end 
  
    local obj = {
        _prefix = prefix
    }

    -- assign fields if defined
    if scope then
        obj._scope = scope
    end
    if defaults then
        obj._defaults = defaults
    end
    if index then
        obj._index = index
    end

    -- create and return new "object instance"
    return setmetatable(obj, CachedConfig)
    
end


local function getTargetByScope(scope, index)

    if scope == "entity" then
        return Entity(index)
    elseif scope == "player" then
        return Player(index)
    elseif scope == "sector" then
        return Sector()
    elseif scope == "server" then
        return Server()
    end

end


local function loadValue(config, scope, index, prefix, defaults)

    local storagekey = prefix .. config

    -- get config target
    local target = getTargetByScope(scope, index)
    if not target then
        print(string.format("CachedConfig => invalid config target (scope: %s | index: %s)", scope, index))
        return
    end

    -- load value from target's storage 
    local val = target:getValue(storagekey)
       
    if val then      
        -- parse JSON string for LUA variables
        val = json.parse(val)
    elseif defaults then
        -- use existing default value if present
        val = defaults[config]
    end
    return val

end


local function saveValue(scope, index, prefix, config, value)

    local storagekey = prefix .. config

    local vt = type(value)
    if vt == "function" or vt == "userdata" or vt == "thread" then 
        error(string.format("Type '%s' is not supported", vt))
    end

    if value then 
        value = json.stringify(value)
    end

    -- save value to target storage via server-side call (required!)
    CachedConfig_CommitSave(scope, index, storagekey, value)
    
end


function CachedConfig_CommitSave(scope, index, config, val)

    -- force this function to run server-side only
    if onClient() then
        invokeServerFunction("CachedConfig_CommitSave", scope, index, config, val)
        return
    end

    -- get config target
    local target = getTargetByScope(scope, index)

    if target then
        -- persist value in targets storage
        target:setValue(config, val)
    else
        print(string.format("CachedConfig => invalid config target (scope: %s | index: %s)", scope, index))
    end

end


-- wrap the lookup of existing properties
CachedConfig.__index = function(t, k) 
    local value = rawget(t, "_c_"..k)
    if value == nil then 
        -- load value from storage and cache result in table 
        value = loadValue(k, rawget(t, "_scope"), rawget(t, "_index"), rawget(t, "_prefix"), rawget(t, "_defaults"))
        rawset(t, "_c_"..k, value)
    end
    return value
end


-- wrap the assignment of property values
CachedConfig.__newindex = function(t, k, v)  
    local value = rawget(t, "_c_"..k)
    -- save value to storage and update cached result in table 
    saveValue(rawget(t, "_scope"), rawget(t, "_index"), rawget(t, "_prefix"), k, v)
    rawset(t, "_c_"..k, v) 
end


-- return factory function for creating new object instances
return new