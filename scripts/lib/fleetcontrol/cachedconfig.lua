--[[

FLEETCONTROL MOD
author: w00zla

file: lib/fleetcontrol/cachedconfig.lua
desc: configuration util for fleetcontrol mod (with cached values)

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/lib/fleetcontrol/?.lua"

json = require("json")

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
        _cache = {},
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


function CachedConfig_GetTargetByScope(scope, index)

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


function CachedConfig_LoadValue(config, scope, index, prefix, defaults)

    local storagekey = prefix .. config

    -- get config target
    local target = CachedConfig_GetTargetByScope(scope, index)
    if not target then
        print(string.format("CachedConfig => invalid config target (scope: %s | index: %s)", scope, index))
        return
    end

    -- load value from target's storage 
    local val = target:getValue(storagekey)
       
    if val ~= nil then    
        if type(val) == "string" then
            -- parse JSON string for LUA variables
            val = json.parse(val)
        end
        -- make sure every property defined in defaults is available for tables
        if type(val) == "table" and defaults and defaults[config] and type(defaults[config]) == "table" then
            for k, v in pairs(defaults[config]) do
                if val[k] == nil then
                    val[k] = v
                end
            end
        end
    elseif defaults then
        -- use existing default value if present
        val = defaults[config]
    end
    return val

end


function CachedConfig_StringifyValue(value)

    local vt = type(value)
    if vt == "function" or vt == "userdata" or vt == "thread" then 
        error(string.format("Type '%s' is not supported", vt))
    end

    if value then 
        local numval = tonumber(value)
        if numval then
            value = numval
        else
            value = json.stringify(value)
        end
    end

    return value

end


function CachedConfig_CommitSave(config)

    -- this function is required to run server-side only!!

    -- get config target
    local target = CachedConfig_GetTargetByScope(config._scope, config._index)

    if target then
        -- persist values in target's storage
        for k, v in pairs(config._cache) do  
            local storagekey = config._prefix .. k
            local storageval = CachedConfig_StringifyValue(v)
            target:setValue(storagekey, storageval)
        end     
    else
        print(string.format("CachedConfig => invalid config target (scope: %s | index: %s)", config._scope, config._index))
    end

end


function CachedConfig_ClearSavedValues(config)

	-- this function is required to run server-side only!!

	-- get config target
    local target = CachedConfig_GetTargetByScope(config._scope, config._index)
	
	if target then
        -- remove values from target's storage
        for k, v in pairs(config._cache) do  
            local storagekey = config._prefix .. k
            target:setValue(storagekey, nil)
        end     
    else
        print(string.format("CachedConfig => invalid config target (scope: %s | index: %s)", config._scope, config._index))
    end

end


local function getParams(t)

    return rawget(t, "_scope"), rawget(t, "_index"), rawget(t, "_prefix"), rawget(t, "_defaults")

end 


-- wrap the lookup of existing properties
CachedConfig.__index = function(t, k) 
    local cache = rawget(t, "_cache")
    if cache[k] == nil then 
        -- load value from storage and cache result in table 
        local s, i, p, d = getParams(t)
        value = CachedConfig_LoadValue(k, s, i, p, d)
        cache[k] = value
    end
    return cache[k]
end


-- wrap the assignment of property values
CachedConfig.__newindex = function(t, k, v)  
    local cache = rawget(t, "_cache")
    cache[k] = v
end


-- return factory function for creating new object instances
return new
