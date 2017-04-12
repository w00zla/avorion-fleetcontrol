--[[

FLEETCONTROL MOD
author: w00zla

file: lib/fleetcontrol/cachedconfig.lua
desc: configuration util for fleetcontrol mod (with cached values)

]]--


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
    
    -- use existing default value if present
    if not val and defaults then
        val = defaults[config]
    end
    return val

end


local function saveValue(scope, index, prefix, config, value)

    local storagekey = prefix .. config

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
    if (v ~= value) then
        -- save value to storage and update cached result in table 
        saveValue(rawget(t, "_scope"), rawget(t, "_index"), rawget(t, "_prefix"), k, v)
        rawset(t, "_c_"..k, v) 
    end
end


-- return factory function for creating new object instances
return new