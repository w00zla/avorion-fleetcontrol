--[[

FLEETCONTROL MOD
author: w00zla

file: lib/fleetcontrol/cachedconfig.lua
desc: configuration util for fleetcontrol mod (with cached values)

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"


local CachedConfig = {
    _scope = "server",
    _prefix = "",
    _defaults = {}
}


local function new(prefix, defaults, scope)

    -- create new "object instance"
    return setmetatable({ _prefix = prefix, _defaults = defaults, _scope = scope }, CachedConfig)
    
end


local function getTargetByScope(scope)

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


local function loadValue(config, scope, prefix, defaults)

    local storagekey = prefix .. config

    -- get config target
    local target = getTargetByScope(scope)
    if not target then
        print(string.format("CachedConfig => invalid config target (scope: %s)", scope))
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


local function saveValue(scope, prefix, config, value)

    local storagekey = prefix .. config

    -- save value to target storage via server-side call (required!)
    CachedConfig_CommitSave(scope, storagekey, value)
    
end


function CachedConfig_CommitSave(scope, config, val)

    -- force this function to run server-side only
    if onClient() then
        invokeServerFunction("CachedConfig_CommitSave", scope, config, val)
        return
    end

    -- get config target
    local target = getTargetByScope(scope)

    if target then
        -- persist value in targets storage
        target:setValue(config, val)
    else
        print(string.format("CachedConfig => invalid config target (scope: %s)", scope))
    end

end


-- wrap the lookup of existing properties
CachedConfig.__index = function(t, k) 
    local value = rawget(t, k)
    if value == nil then 
        -- load value from storage and cache result in table 
        value = loadValue(k, rawget(t, "_scope"), rawget(t, "_prefix"), rawget(t, "_defaults"))
        rawset(t, k, value)
    end
    return value
end


-- wrap the assignment of property values
CachedConfig.__newindex = function(t, k, v)  
    local value = rawget(t, k)
    if (v ~= value) then
        -- save value to storage and update cached result in table 
        saveValue(rawget(t, "_scope"), rawget(t, "_prefix"), k, v)
        rawset(t, k, v) 
    end
end


-- returns table which acts as a factory for new object instances
return setmetatable({new = new}, {__call = function(_, ...) return new(...) end})