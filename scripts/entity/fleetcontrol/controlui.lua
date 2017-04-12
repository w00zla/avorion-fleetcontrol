--[[

FLEETCONTROL MOD
author: w00zla

file: entity/fleetcontrol/controlui.lua
desc:  entity script providing GUI window for fleetcontrol

]]--

package.path = package.path .. ";data/scripts/lib/?.lua"

require "utility"
require "stringutility"

require "fleetcontrol.common"
json = require("fleetcontrol.json")


-- client / UI vars

local mywindow
local tabs = {
    window = nil,
    orders = nil,
    groups = nil,
    config = nil
}

local c_ord = {
    btnPrevPage = nil,
    btnNextPage = nil,
    lblGroupName = nil,
    cmdGroupOrder = nil,
    ships = {
        frame = {},
        lblName = {},
        lblState = {},
        lblLoc = {},
        btnLook = {},
        cmdOrder = {},
        lblOrder = {}
    }
}

local c_grp = {
    lstPool = nil,
    groups = {
        lblName = {},
        lstShips = {},
        btnAssign = {},
        btnUnassign = {}
    }
}

local c_conf = {
    lstCategories = nil,
    cntCatGroups = nil,
    cntCatHUD = nil,
    groups = {
        lblName = {},
        btnRename = {},
        chkShowHud = {}
    }
}

local groupconfig
local shipgroups
local shipinfos
local allships

local config
local ordersInfo

local groupshiplimit = 12
local shipPoolLastIndex
local configCatsLastIndex
local groupListsLastIndices = {}
local currentShipGroup = 1

local selectedtabidx
local uivisible = false
local doupdatestates = false
local laststateupdate = 0
local ordersbusy = false


function initialize()

    if onServer() then
        return
    end

    -- TODO: load some configs from server (i.e. updatedelay)

    config = getConfig("player")
    ordersInfo = getOrdersInfo()

    groupconfig = config.groupconfig
    if groupconfig then
        groupconfig = json.parse(groupconfig)
    else
        groupconfig = {
            {
                name="Group 1",
                showhud=false,
                hudcolor={a=0.5,r=1,g=1,b=1}
            },
            {
                name="Group 2",
                showhud=false,
                hudcolor={a=0.5,r=0.75,g=0.75,b=0.75}
            },
            {
                name="Group 3",
                showhud=false,
                hudcolor={a=0.5,r=0.5,g=0.5,b=0.5}
            },
            {
                name="Group 4",
                showhud=false,
                hudcolor={a=0.5,r=0.25,g=0.25,b=0.25}
            }    
        }
    end

    shipgroups = config.shipgroups
    if shipgroups then
        shipgroups = json.parse(shipgroups)
    else
        shipgroups = { {},{},{},{} }
        -- shipgroups = {
        --     { "Craft", "Craft 1", "Craft 2" },
        --     { "Craft 3" },
        --     {},
        --     {}
        -- }
    end

end


function secure()

    return shipinfos

end


function restore(data)

    shipinfos = data

end


function getIcon(seed, rarity)
    return "data/textures/icons/fleetcontrol/commander.png"
end


function interactionPossible(player)
    return true, ""
end


function onShowWindow()

    tabs.window:selectTab(tabs.orders)

    -- show current groupnames in related widgets
    refreshGroupNames()

    -- trigger updates of UI widgets
    uivisible = true   
    -- trigger update of ship states and orders
    doupdatestates = true

end


function onCloseWindow()

    uivisible = false
    doupdatestates = false

end


function initUI()

    local size = vec2(800, 650)
    local res = getResolution()

    -- create window
    local menu = ScriptUI()
    mywindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(mywindow, "Fleet Control")

    mywindow.caption = "Fleet Control"
    mywindow.showCloseButton = 1
    mywindow.moveable = 1
    
    tabs.window = mywindow:createTabbedWindow(Rect(vec2(10, 10), size - 10))
    tabs.window.onSelectedFunction = "onTabSelected"

    tabs.orders = tabs.window:createTab("Orders", "data/textures/icons/back-forth.png", "Fleet Orders")
    buildOrdersUI(tabs.orders)

    tabs.groups = tabs.window:createTab("Groups", "data/textures/icons/backup.png", "Fleet Groups")
    buildGroupsUI(tabs.groups)

    tabs.config = tabs.window:createTab("Config", "data/textures/icons/gears.png", "Configuration")
    buildConfigUI(tabs.config)

    scriptLog(nil, "client UI initialized successfully")
    
end


function buildOrdersUI(parent)

    local size = parent.size

    -- footer
    c_ord.btnPrevPage = parent:createButton(Rect(10, size.y - 40, 60, size.y - 10), "<", "onPrevPagePressed")	
    c_ord.btnPrevPage.active = false
    c_ord.btnNextPage = parent:createButton(Rect(size.x - 60, size.y - 40, size.x - 10, size.y - 10), ">", "onNextPagePressed")	
    
    local split_grp = UIVerticalSplitter(Rect(10, 10, size.x - 10, 40), 10, 0, 0.5)
    split_grp.rightSize = 250

    local xl = split_grp.left.lower.x
    local xu = split_grp.left.upper.x

    -- group widgets
    local groupname = parent:createLabel(vec2(xl, 10), "", 17)
    local cbox = parent:createComboBox(split_grp.right, "onGroupOrderSelected")
    cbox:addEntry("-")
    for _, btninfo in pairs(ordersInfo) do
        cbox:addEntry(btninfo.text)
    end    

    --cbox:hide()
    c_ord.lblGroupName = groupname
    c_ord.cmdGroupOrder = cbox
    
    -- create ship list widgets 
    local nameLabelX = 10
    local stateLabelX = -200
    local locLabelX = -85

    local y_shp = 65
    for s = 1, groupshiplimit do 

        local yText = y_shp + 16
        
        local split1 = UIVerticalSplitter(Rect(10, y_shp, size.x - 10, y_shp +  50), 10, 10, 0.5)
        split1.rightSize = 210

        local frame = parent:createFrame(split1.left)        
        
        local xl = split1.left.lower.x
        local xu = split1.left.upper.x    

        -- captions
        if s == 01 then
            local cap1 = parent:createLabel(vec2(xl + nameLabelX, 50), "Ship", 15)
            local cap2 = parent:createLabel(vec2(xu + stateLabelX, 50), "State", 15)
            local cap3 = parent:createLabel(vec2(xu + locLabelX, 50), "Sector", 15)
            cap1.color = ColorRGB(0.2, 0.2, 0.2)
            cap2.color = ColorRGB(0.2, 0.2, 0.2)
            cap3.color = ColorRGB(0.2, 0.2, 0.2)
        end     
        
        -- ship labels
        local nameLabel = parent:createLabel(vec2(xl + nameLabelX, yText), "", 15)
        local stateLabel = parent:createLabel(vec2(xu + stateLabelX, yText), "", 15)
        local locLabel = parent:createLabel(vec2(xu + locLabelX, yText), "", 15)
        
        nameLabel.font = "Arial"
        stateLabel.font = "Arial"
        locLabel.font = "Arial"
        
        -- ship controls
        local split2 = UIVerticalSplitter(split1.right, 25, 0, 0.5)
        split2.leftSize = 30

        local lookat = parent:createButton(split2.left, "", "onLookAtPressed")
        lookat.icon = "data/textures/icons/look-at.png"

        if s == 01 then
            local cap4 = parent:createLabel(vec2(split2.right.lower.x, 50), "Order", 15)
            cap4.color = ColorRGB(0.2, 0.2, 0.2)
        end     

        local cbox = parent:createComboBox(split2.right, "onShipOrderSelected")
        cbox:addEntry("-")
        for _, btninfo in pairs(ordersInfo) do
            cbox:addEntry(btninfo.text)
        end

        local orderLabel = parent:createLabel(vec2(split2.right.lower.x, split2.right.lower.y + 6), "", 15)

        -- hide controls initially and add to reference table
        frame:hide()
        nameLabel:hide()
        stateLabel:hide()
        locLabel:hide()
        lookat:hide()
        cbox:hide()
        orderLabel:hide()

        table.insert(c_ord.ships.frame, frame)
        table.insert(c_ord.ships.lblName, nameLabel)
        table.insert(c_ord.ships.lblState, stateLabel)
        table.insert(c_ord.ships.lblLoc, locLabel)
        table.insert(c_ord.ships.btnLook, lookat)
        table.insert(c_ord.ships.cmdOrder, cbox)
        table.insert(c_ord.ships.lblOrder, orderLabel)
            
        y_shp = y_shp + 35	   
    end

end


function buildGroupsUI(parent)

    local size = parent.size

    local split1 = UIVerticalSplitter(Rect(10, 10, size.x - 10, size.y - 10), 30, 0, 0.5)
    split1.rightSize = 530

    -- ships pool list
    local split_sp = UIHorizontalSplitter(split1.left, 10, 0, 0.5)
    split_sp.topSize = 30

    parent:createLabel(vec2(split_sp.top.lower.x, split_sp.top.lower.y), "Unassigend captained\nships in sector:", 12)
    c_grp.lstPool = parent:createListBox(split_sp.bottom)

    parent:createLine(vec2(split1.left.upper.x + 15, split1.left.lower.y), vec2(split1.left.upper.x + 15, split1.left.upper.y))

    -- ship groups sections
    local x, y = split1.right.lower.x, split1.right.lower.y
    local r_size = split1.right.size

    -- quarter splitters
    parent:createLine(vec2(x + (r_size.x / 2), y), vec2(x + (r_size.x / 2), split1.right.upper.y))
    parent:createLine(vec2(x, y + (r_size.y / 2)), vec2(split1.right.upper.x, y + (r_size.y / 2)))

    for i = 1, 4 do

        local r_quarter     
        if i == 1 then
            r_quarter = Rect(x, y, x + (r_size.x / 2) - 15, y + (r_size.y / 2) - 15)
        elseif i == 2 then
            r_quarter = Rect(x + (r_size.x / 2) + 15, y, x + r_size.x, y + (r_size.y / 2) - 15)
        elseif i == 3 then
            r_quarter = Rect(x, y + (r_size.y / 2) + 15, x + (r_size.x / 2) - 15, y + r_size.y)
        elseif i == 4 then
            r_quarter = Rect(x + (r_size.x / 2) + 15, y + (r_size.y / 2) + 15, x + r_size.x, y + r_size.y)
        end

        local split_grp1 = UIHorizontalSplitter(r_quarter, 10, 0, 0.5)
        split_grp1.topSize = 30

        -- group labels
        local split_grp2 = UIVerticalSplitter(split_grp1.top, 10, 0, 0.5)
        split_grp2.leftSize = 20

        local nrlbl = parent:createLabel(vec2(split_grp2.left.lower.x, split_grp2.left.lower.y + 8), string.format("#%i", i), 14)
        c_grp.groups.lblName[i] = parent:createLabel(vec2(split_grp2.right.lower.x, split_grp2.right.lower.y + 6), string.format("Group#%i", i), 16)

        -- group ship list
        local split_grp3 = UIVerticalSplitter(split_grp1.bottom, 5, 0, 0.5)
        split_grp3.rightSize = 30

        c_grp.groups.lstShips[i] = parent:createListBox(split_grp3.left)

        local xl, yl = split_grp3.right.lower.x, split_grp3.right.lower.y
        local xu, yu = split_grp3.right.upper.x, split_grp3.right.upper.y

        local shipassign = parent:createButton(Rect(xl, yl, xl + 30, yl + 30), "+", "onAssignShipGroupPressed")           
        local shipunassign = parent:createButton(Rect(xl, yl + 35, xl + 30, yl + 65), "-", "onUnassignShipGroupPressed")     

        nrlbl.color = ColorARGB(0.5, 0.2, 0.2, 0.2)
        shipassign.textSize = 18  
        shipunassign.textSize = 18  
        shipassign.active = false
        shipunassign.active = false

        c_grp.groups.btnAssign[i] = shipassign
        c_grp.groups.btnUnassign[i] = shipunassign
        
    end  

end


function buildConfigUI(parent)

    local size = parent.size

    local split1 = UIVerticalSplitter(Rect(10, 10, size.x - 10, size.y - 10), 30, 0, 0.5)
    split1.rightSize = 580

    local split2 = UIHorizontalSplitter(split1.left, 10, 0, 0.5)
    split2.topSize = 20

    parent:createLabel(vec2(split2.top.lower.x, split2.top.lower.y), "Categories:", 12)
    -- option categories list
    c_conf.lstCategories = parent:createListBox(split2.bottom)

    -- GROUPS options

    c_conf.lstCategories:addEntry("Groups")
    c_conf.cntCatGroups = parent:createContainer(split1.right)

    local rs = c_conf.cntCatGroups.size

    c_conf.cntCatGroups:createLabel(vec2(0, 0), "Groups Options", 16)
    c_conf.cntCatGroups:createLine(vec2(0, 30), vec2(rs.x, 30))

    local sgrp1 = UIHorizontalMultiSplitter(Rect(0, 40, rs.x, rs.y), 20, 10, 3)
    for p = 0, 3 do
        local g = p + 1
        local r = sgrp1:partition(p)  

        local frm = c_conf.cntCatGroups:createFrame(r)
        frm.backgroundColor = ColorARGB(0.2, 0, 0, 0)

        local sgrp2 = UIHorizontalSplitter(r, 10, 10, 0.5)

        local xl, yl = sgrp2.top.lower.x, sgrp2.top.lower.y
        local xu, yu = sgrp2.top.upper.x, sgrp2.top.upper.y
        
        local nrlbl = c_conf.cntCatGroups:createLabel(vec2(xl, yl + 3), string.format("#%i", g), 14)
        local namelbl = c_conf.cntCatGroups:createLabel(vec2(xl + 30, yl), string.format("Group#%i", g), 16)
        local renbtn = c_conf.cntCatGroups:createButton(Rect(xu - 90, yl, xu, yl + 30), "Rename", "onRenameGroupPressed")

        local xl, yl = sgrp2.bottom.lower.x, sgrp2.bottom.lower.y
        local xu, yu = sgrp2.bottom.upper.x, sgrp2.bottom.upper.y

        local hudchk = c_conf.cntCatGroups:createCheckBox(Rect(xl, yl, xl + 150, yl + 20), "Show on HUD", "onGroupHudChecked") 
        local hudcolorlbl = c_conf.cntCatGroups:createLabel(vec2(xl + 160, yl + 26), "HUD Color:", 13)

        --local hudcolorpic = c_conf.cntCatGroups:createPicture(Rect(xl + 250, ))

        nrlbl.color = ColorRGB(0.2, 0.2, 0.2)
        hudcolorlbl.italic = true
        hudchk.italic = true
        hudchk.fontSize = 13

        c_conf.groups.lblName[g] = namelbl
        c_conf.groups.btnRename[g] = renbtn
        c_conf.groups.chkShowHud[g] = hudchk
    end

    -- HUD options

    c_conf.lstCategories:addEntry("HUD")
    c_conf.cntCatHUD = parent:createContainer(split1.right)

    local shud1 = UIHorizontalSplitter(split1.right, 10, 0, 0.5)
    shud1.topSize = 30
    local rs = shud1.top.size

    c_conf.cntCatHUD:createLabel(vec2(0, 0), "HUD Options", 16)
    c_conf.cntCatHUD:createLine(vec2(0, 30), vec2(rs.x, 30))
    
    
    c_conf.lstCategories:select(0)
    c_conf.cntCatHUD:hide()

end


function onTabSelected()

    selectedtabidx = tabs.window:getActiveTab().index

    if tabs.groups and tabs.groups.index == selectedtabidx then
        -- update groups tab widgets
        refreshGroupsUI()
    end

end


function onPrevPagePressed()
    
    currentShipGroup = currentShipGroup - 1
    laststateupdate = 0

    c_ord.lblGroupName.caption = groupconfig[currentShipGroup].name

    if currentShipGroup == 1 then
        c_ord.btnPrevPage.active = false
    end
    c_ord.btnNextPage.active = true

end


function onNextPagePressed()

    currentShipGroup = currentShipGroup + 1
    laststateupdate = 0

    c_ord.lblGroupName.caption = groupconfig[currentShipGroup].name

    if currentShipGroup == 4 then
        c_ord.btnNextPage.active = false
    end
    c_ord.btnPrevPage.active = true

end


function onLookAtPressed(sender)

    for i, btn in pairs(c_ord.ships.btnLook) do
		if btn.index == sender.index then
            if shipinfos[currentShipGroup][i].index then
                local entity = Entity(shipinfos[currentShipGroup][i].index)
			    if entity then
				    Player().selectedObject = entity
                end
			elseif shipinfos[currentShipGroup][i].location then
                local coords = shipinfos[currentShipGroup][i].location
				GalaxyMap():setSelectedCoordinates(coords.x, coords.y)
				GalaxyMap():show(coords.x, coords.y)
			end
			
		end
	end

end


function onGroupOrderSelected(sender)

    if c_ord.cmdGroupOrder.selectedIndex < 1 then return end

    if ordersbusy then return end
    ordersbusy = true

    local indices = {}
    local pshipIndex = Player().craftIndex

    for i, info in pairs(shipinfos[currentShipGroup]) do
        if info.index ~= pshipIndex then
            indices[i] = info.index
        end
	end
    invokeOrdersScript(indices, ordersInfo[c_ord.cmdGroupOrder.selectedIndex])

end


function onShipOrderSelected(sender)

    if ordersbusy then return end
    ordersbusy = true

    for i, cmd in pairs(c_ord.ships.cmdOrder) do
		if cmd.index == sender.index then
            if cmd.selectedIndex < 1 then return end

			local indices = {shipinfos[currentShipGroup][i].index}	
            invokeOrdersScript(indices, ordersInfo[cmd.selectedIndex])
            break
		end
	end

end


function onAssignShipGroupPressed(sender)

    local shipname = c_grp.lstPool:getEntry(c_grp.lstPool.selected)

    for i, btn in pairs(c_grp.groups.btnAssign) do
		if btn.index == sender.index then
            -- update config data
            table.insert(shipgroups[i], shipname)
            local strval = json.stringify(shipgroups)
            config.shipgroups = strval

            -- update list widgets
            c_grp.groups.lstShips[i]:addEntry(shipname)
            c_grp.lstPool:removeEntry(c_grp.lstPool.selected)
            break
		end
	end

end


function onUnassignShipGroupPressed(sender)

    for i, btn in pairs(c_grp.groups.btnUnassign) do
		if btn.index == sender.index then
            -- update config data
            table.remove(shipgroups[i], c_grp.groups.lstShips[i].selected + 1)
            config.shipgroups = json.stringify(shipgroups)

            -- update list widgets
            local shipname = c_grp.groups.lstShips[i]:getEntry(c_grp.groups.lstShips[i].selected)       
            c_grp.lstPool:addEntry(shipname)
            c_grp.groups.lstShips[i]:removeEntry(c_grp.groups.lstShips[i].selected)
            break
		end
	end

end


function onRenameGroupPressed(sender)

end


function onGroupHudChecked(sender)

end


function displayShipState(idx, ship, currloc)

    -- display basic ship states
    c_ord.ships.lblName[idx].caption = ship.name
    c_ord.ships.lblName[idx]:show()

    if ship.isplayer then
        c_ord.ships.lblState[idx].caption = "Player"
    else
        c_ord.ships.lblState[idx].caption = ship.aistate or "-"
    end
    c_ord.ships.lblState[idx].bold = ship.isplayer or false
    c_ord.ships.lblState[idx]:show()

    -- location/sector of ship
    if ship.location then 
        local loc = vec2(ship.location.x, ship.location.y)
        if  loc.x == currloc.x and loc.y == currloc.y then
            c_ord.ships.lblLoc[idx].caption = "current"
            c_ord.ships.lblLoc[idx].italic = true
        else
            c_ord.ships.lblLoc[idx].caption = tostring(loc) 
            c_ord.ships.lblLoc[idx].italic = false
        end
        c_ord.ships.lblLoc[idx]:show()
        c_ord.ships.btnLook[idx]:show() 
    end
   
    if ship.order then
        if ship.elsewhere or ship.isplayer then
            -- disable orders combobox if ship is controlled by player or elsewhere
            c_ord.ships.lblOrder[idx].caption = "-"
            for i, oi in pairs(ordersInfo) do 
                if oi.order == ship.order then
                    c_ord.ships.lblOrder[idx].caption = oi.text
                    break
                end
            end
            c_ord.ships.lblOrder[idx]:show()
        else
            -- set selected order to ship's current order
            c_ord.ships.cmdOrder[idx]:setSelectedIndexNoCallback(1)    
            for i, oi in pairs(ordersInfo) do 
                if oi.order == ship.order then
                    c_ord.ships.cmdOrder[idx]:setSelectedIndexNoCallback(i)
                    break
                end
            end
            c_ord.ships.cmdOrder[idx]:show()
        end
    elseif not ship.isplayer then
        c_ord.ships.cmdOrder[idx]:setSelectedIndexNoCallback(1)
        c_ord.ships.cmdOrder[idx]:show()
    end

    -- make rest of ship related widgets visible
    c_ord.ships.frame[idx]:show() 

end


function refreshShipsUI()

    -- hide all ship list widgets at first
    for s = 1, groupshiplimit do
        c_ord.ships.frame[s]:hide()
        c_ord.ships.lblName[s]:hide()
        c_ord.ships.lblState[s]:hide()
        c_ord.ships.lblLoc[s]:hide()
        c_ord.ships.btnLook[s]:hide()
        c_ord.ships.cmdOrder[s]:hide()
        c_ord.ships.lblOrder[s]:hide()
    end

    if not shipinfos then return end

    local ordersequal = true
    local lastorder 
    local currentcoords = vec2(Sector():getCoordinates())

    for i, shipinfo in pairs(shipinfos[currentShipGroup]) do 
        -- check if all ships have same order/state
        if lastorder and lastorder ~= shipinfo.order then
            ordersequal = false
        end
        lastorder = shipinfo.order

        displayShipState(i, shipinfo, currentcoords)       
    end

    -- pre-select group order
    if ordersequal then
        for i, oi in pairs(ordersInfo) do 
            if oi.order == lastorder then
                c_ord.cmdGroupOrder:setSelectedIndexNoCallback(i)
                break
            end
        end
    else
        c_ord.cmdGroupOrder:setSelectedIndexNoCallback(0)
    end

end


function refreshGroupNames()

    -- update group name related labels on all tabs
    for g = 1, 4 do 
        if currentShipGroup == g then
            c_ord.lblGroupName.caption = groupconfig[g].name
        end
        c_grp.groups.lblName[g].caption = groupconfig[g].name
        c_conf.groups.lblName[g].caption = groupconfig[g].name
    end
    
end


function refreshGroupsUI()

    c_grp.lstPool:clear()
    for i = 1, #shipgroups do
        c_grp.groups.lstShips[i]:clear()
    end

    for _, ship in pairs(allships) do 
        local assigned = false
        for i, shipgrp in pairs(shipgroups) do 
            if tablecontains(shipgrp, ship.name) then
                c_grp.groups.lstShips[i]:addEntry(ship.name)
                assigned = true
                break
            end      
        end
        if not assigned then
            c_grp.lstPool:addEntry(ship.name)
        end
    end

end


function updateUI()

    if selectedtabidx == tabs.groups.index then

        -- GROUPS
        -- en/disable ship assignment buttons according to list selections
        if c_grp.lstPool.selected ~= shipPoolLastIndex then
            shipPoolLastIndex = c_grp.lstPool.selected
            for i = 1, 4 do
                c_grp.groups.btnAssign[i].active = (shipPoolLastIndex >= 0)
            end     
        end
        for i = 1, 4 do 
            if c_grp.groups.lstShips[i].selected ~= groupListsLastIndices[i] then
                groupListsLastIndices[i] = c_grp.groups.lstShips[i].selected
                c_grp.groups.btnUnassign[i].active = (groupListsLastIndices[i] >= 0)
            end
        end

    elseif selectedtabidx == tabs.config.index then

        -- CONFIG
        -- show selected options category widgets
        if c_conf.lstCategories.selected ~= configCatsLastIndex then  
            configCatsLastIndex = c_conf.lstCategories.selected
            if configCatsLastIndex == 0 then
                c_conf.cntCatHUD:hide()
                c_conf.cntCatGroups:show()
            elseif configCatsLastIndex == 1 then
                c_conf.cntCatGroups:hide()
                c_conf.cntCatHUD:show()
            end        
        end

    end

end


function updateClient(timeStep)

    if doupdatestates then

        local current = systemTimeMs()
        -- only do update if configured delay has passed
        if (current - laststateupdate) >= config.updatedelay then

            -- get all exisiting ships (with captains) of player in current sector
            allships = getPlayerCaptainedCrafts()

            -- TODO: sort allships alphabetically

            -- update ship states and refresh ships UI widgets
            updateShipStates(shipgroups, allships)

            laststateupdate = current
            ordersbusy = false
        end

    end

end


function syncShipInfos(data)

    if onServer() then
        invokeClientFunction(Player(callingPlayer), "syncShipInfos", data)
        return
    end

    shipinfos = data

    -- update infos in UI
    if uivisible then
        refreshShipsUI()
    end

end


-- SERVER-SIDE FUNCTIONS

function updateShipStates(groups, allships)

    if onClient() then
        invokeServerFunction("updateShipStates", groups, allships)
        return
    end

    local statedata = {}
    local cx, cy = Sector():getCoordinates()
    local coords = {x=cx, y=cy}

    -- create flat array of ship names to update
    local updateships = {}
    for _, grp in pairs(groups) do
        for _, shp in pairs(grp) do
            table.insert(updateships, shp)
        end
    end

    local pshipIndex = Player(callingPlayer).craftIndex

    -- compare existing ships in sector and get their states 
    for _, ship in pairs(allships) do 
        if tablecontains(updateships, ship.name) then
            local entity = Entity(ship.index)
            if entity and entity.isShip and entity.name == ship.name then
                -- TODO: check also if ship is controlled by another player
                if entity.index == pshipIndex then
                    table.insert(statedata, {
                        name = entity.name,
                        index = entity.index,
                        isplayer = true
                    })
                else
                    local aistate, order = getShipAIOrderState(entity)
                    table.insert(statedata, {
                        name = entity.name,
                        index = entity.index,
                        aistate = aistate,
                        order = order,
                        location = coords
                    })
                end
            end
        end
    end

    -- merge new and old states and group the infos
    local newstates = {}
    for gi, gships in pairs(groups) do
        newstates[gi] = {}
        for _, shipname in pairs(gships) do
            local info
            for _, data in pairs(statedata) do
                if data.name == shipname then
                    -- ship in current sector -> update info
                    info = data
                    break
                end
            end
            if not info and shipinfos then
                -- ship elsewhere -> reuse old info and mark it
                for _, data in pairs(shipinfos[gi]) do
                    if data.name == shipname then
                        info = {
                            name = data.name,
                            order = data.order,
                            location = data.location,
                            elsewhere = true
                        }
                        break
                    end
                end
            end
            table.insert(newstates[gi], info)
        end
    end

    -- set server-side data and return to client
    shipinfos = newstates
    invokeClientFunction(Player(callingPlayer), "syncShipInfos", shipinfos)

end


function invokeOrdersScript(shipindices, orderinfo)

    -- make this function run server-side only
    if onClient() then
        invokeServerFunction("invokeOrdersScript", shipindices, orderinfo)
        return
    end

    for _, idx in pairs(shipindices) do

        local ship = Entity(idx)
        if ship and ship.isShip then
            if not ship:hasScript(orderinfo.script) then
                debugLog("invokeOrdersScript() --> ship: %s (%s) is missing script '%s'!", idx, orderinfo.script)
                return
            end
            debugLog("invokeOrdersScript() --> ship: %s (%s) | order: %s | script: %s | func: %s | param: %s", ship.name, ship.index, orderinfo.order, orderinfo.script, orderinfo.func, orderinfo.param)
            
            if orderinfo.param then
                if orderinfo.param == "playercraftindex" then
                    ship:invokeFunction(orderinfo.script, orderinfo.func, Player(callingPlayer).craftIndex) 
                else
                    debugLog("invokeOrdersScript() --> unknown order function parameter!", idx)
                end
            else
                ship:invokeFunction(orderinfo.script, orderinfo.func) 
            end
        else
            debugLog("invokeOrdersScript() --> no ship/entity with index %s found!", idx)
        end

    end

end


function requestShipInfoSync()

    if onClient() then
        invokeServerFunction("requestShipInfoSync")
        return
    end

    debugLog("shipinfo sync requested")
    invokeClientFunction(Player(callingPlayer), "syncShipInfos", shipinfos)

end