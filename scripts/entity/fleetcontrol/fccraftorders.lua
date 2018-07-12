
package.path = package.path .. ";data/scripts/lib/?.lua"

require ("stringutility")
require ("faction")
local AIAction =
{
    Escort = 1,
    Attack = 2,
    FlyThroughWormhole = 3,
    FlyToPosition = 4,
    Guard = 5,
    Patrol = 6,
    Aggressive = 7,
    Mine = 8,
    Salvage = 9
}

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace FleetControlCraftOrders
FleetControlCraftOrders = {}

FleetControlCraftOrders.currentPlayerIndex = 0

function FleetControlCraftOrders.setCurrentPlayerIndex(index)
    FleetControlCraftOrders.currentPlayerIndex = index
end


function FleetControlCraftOrders.setAIActionForUI(action, index, position)
    if onServer() then
        invokeClientFunction(Player(FleetControlCraftOrders.currentPlayerIndex), "setAIActionForUI", action, index, position)
    end

    FleetControlCraftOrders.updateCurrentOrderIcon(action)
end

function FleetControlCraftOrders.updateCurrentOrderIcon(action)
    if action == AIAction.Escort then
        Entity():setValue("currentOrderIcon", "data/textures/icons/pixel/escort.png")
    elseif action == AIAction.Attack then
        Entity():setValue("currentOrderIcon", "data/textures/icons/pixel/attack.png")
    elseif action == AIAction.FlyThroughWormhole then
        Entity():setValue("currentOrderIcon", "data/textures/icons/pixel/gate.png")
    elseif action == AIAction.FlyToPosition then
        Entity():setValue("currentOrderIcon", "data/textures/icons/pixel/flytoposition.png")
    elseif action == AIAction.Guard then
        Entity():setValue("currentOrderIcon", "data/textures/icons/pixel/guard.png")
    elseif action == AIAction.Patrol then
        Entity():setValue("currentOrderIcon", "data/textures/icons/pixel/escort.png")
    elseif action == AIAction.Aggressive then
        Entity():setValue("currentOrderIcon", "data/textures/icons/pixel/attack.png")
    elseif action == AIAction.Mine then
        Entity():setValue("currentOrderIcon", "data/textures/icons/pixel/mine.png")
    elseif action == AIAction.Salvage then
        Entity():setValue("currentOrderIcon", "data/textures/icons/pixel/scrapyard_thin.png")
    else
        Entity():setValue("currentOrderIcon", "")
    end
end

function FleetControlCraftOrders.interactionPossible(playerIndex, option)
    return false
end


local function checkShipCommandable()

    local entity = Entity()
    if entity.allianceOwned then
        local ally = Alliance(entity.factionIndex)
        local auth = ally:hasPrivilege(FleetControlCraftOrders.currentPlayerIndex, AlliancePrivilege.FlyCrafts)
        if not auth then          
            debugLog("player #%s has no 'FlyCrafts' privilege for alliance '%s'", FleetControlCraftOrders.currentPlayerIndex, ally.name)
            return false
        end  
    end

    local captains = entity:getCrewMembers(CrewProfessionType.Captain)
    if captains and captains > 0 then
        return true
    end

    return false
end

local function removeSpecialOrders()

    local entity = Entity()

    for index, name in pairs(entity:getScripts()) do
        if string.match(name, "data/scripts/entity/ai/") then
            entity:removeScript(index)
        end
    end
end

function FleetControlCraftOrders.onIdleButtonPressed()
    if checkShipCommandable() then	
        removeSpecialOrders()

        local ai = ShipAI()
        ai:setIdle()
        FleetControlCraftOrders.setAIActionForUI()
    end
end

function FleetControlCraftOrders.stopFlying()
    if checkShipCommandable() then
        removeSpecialOrders()

        ShipAI():setPassive()
        FleetControlCraftOrders.setAIActionForUI()
    end
end

function FleetControlCraftOrders.onGuardButtonPressed()
    if checkShipCommandable() then
        removeSpecialOrders()

        local pos = Entity().translationf
        ShipAI():setGuard(pos)
        FleetControlCraftOrders.setAIActionForUI(AIAction.Guard, nil, pos)
    end
end

function FleetControlCraftOrders.escortEntity(index)
    if checkShipCommandable() then
        removeSpecialOrders()

        ShipAI():setEscort(Entity(index))
        FleetControlCraftOrders.setAIActionForUI(AIAction.Escort, index)
    end
end

function FleetControlCraftOrders.attackEntity(index)
    if checkShipCommandable() then
        removeSpecialOrders()

        local ai = ShipAI()
        ai:setAttack(Entity(index))
        FleetControlCraftOrders.setAIActionForUI(AIAction.Attack, index)
    end
end

function FleetControlCraftOrders.flyToPosition(pos)
    if checkShipCommandable() then
        removeSpecialOrders()

        local ai = ShipAI()
        ai:setFly(pos, 0)
        FleetControlCraftOrders.setAIActionForUI(AIAction.FlyToPosition, nil, pos)
    end
end

function FleetControlCraftOrders.flyThroughWormhole(index)
    if checkShipCommandable() then
        removeSpecialOrders()

        local ship = Entity()
        local target = Entity(index)

        if target:hasComponent(ComponentType.Plan) then
            -- gate
            local entryPos
            local flyThroughPos
            local waypoints = {}

            -- determine best direction for entering the gate
            if dot(target.look, ship.translationf - target.translationf) > 0 then
                entryPos = target.translationf + target.look * ship:getBoundingSphere().radius * 10
                flyThroughPos = target.translationf - target.look * ship:getBoundingSphere().radius * 5
            else
                entryPos = target.translationf - target.look * ship:getBoundingSphere().radius * 10
                flyThroughPos = target.translationf + target.look * ship:getBoundingSphere().radius * 5
            end
            table.insert(waypoints, entryPos)
            table.insert(waypoints, flyThroughPos)

            Entity():addScript("ai/flythroughwormhole.lua", unpack(waypoints))
        else
            -- wormhole
            ShipAI():setFly(target.translationf, 0)
        end

        FleetControlCraftOrders.setAIActionForUI(AIAction.FlyThroughWormhole, index)
    end
end

function FleetControlCraftOrders.onAttackEnemiesButtonPressed()
    if checkShipCommandable() then
        removeSpecialOrders()

        ShipAI():setAggressive()
        FleetControlCraftOrders.setAIActionForUI(AIAction.Aggressive)
    end
end

function FleetControlCraftOrders.onPatrolButtonPressed()
    if checkShipCommandable() then
        removeSpecialOrders()

        Entity():addScript("ai/patrol.lua")
        FleetControlCraftOrders.setAIActionForUI(AIAction.Patrol)
    end
end

function FleetControlCraftOrders.onMineButtonPressed()
    if checkShipCommandable() then
        removeSpecialOrders()

        Entity():addScript("ai/mine.lua")
        FleetControlCraftOrders.setAIActionForUI(AIAction.Mine)
    end
end

function FleetControlCraftOrders.onSalvageButtonPressed()
    if checkShipCommandable() then
        removeSpecialOrders()

        Entity():addScript("ai/salvage.lua")
        FleetControlCraftOrders.setAIActionForUI(AIAction.Salvage)
    end
end


-- this function will be executed every frame both on the server and the client
--function update(timeStep)
--
--end
--
---- this function gets called every time the window is shown on the client, ie. when a player presses F
--function onShowWindow()
--
--end
--
---- this function gets called every time the window is shown on the client, ie. when a player presses F
--function onCloseWindow()
--
--end
