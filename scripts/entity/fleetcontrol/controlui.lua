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

-- Config

-- TODO: maybe optimize for use of ColorInt for color values
local configdefaults = {
    updatedelay = 750,
    debugoutput = false,
    groups = {
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
        },
    hud = {
            enablehud = false
        },
    knownships = {},
    shipgroups = { {},{},{},{} }
}

-- UI vars

local mywindow
local textdialog = {
    window = nil,
    param = nil,
    callback = nil,
    textbox = nil
}
local colordialog = {
    window = nil,
    param = nil,
    callback = nil,
    color = nil,
    colorpreview = nil,
    sliderA = nil,
    sliderR = nil,
    sliderG = nil,
    sliderB = nil
}
local tabs = {
    window = nil,
    orders = nil,
    groups = nil,
    config = nil
}

local c_ord = {
    btnPrevPage = nil,
    btnNextPage = nil,
    lblPageInfo = nil,
    lblGroupName = {},
    cmdGroupOrder = {},
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
        btnUnassign = {},
        btnMoveUp = {},
        btnMoveDown = {},
        lblGroupInfo = {}
    }
}

local c_conf = {
    lstCategories = nil,
    cntCatGroups = nil,
    cntCatHUD = nil,
    groups = {
        lblName = {},
        btnRename = {},
        chkShowHud = {},
        picHudColorPrev = {},
        btnHudColorPick = {}
    },
    hud = {
        chkEnableHud = nil
    }
}

-- limits
local ordergroupslimit = 2
local groupshiplimit = 6
local groupnamelimit = 18

-- configs
local config
local ordersInfo
local groupconfig
local hudconfig
local shipgroups

-- runtime data
local shipinfos -- server&client
local knownships

-- widget indices
local shipPoolLastIndex
local configCatsLastIndex
local groupListsLastIndices = {}
local currentPage = 1
local selectedtabidx

-- runtime flags and timestamps
local uivisible = false
local doupdatestates = false
local laststateupdate = 0
local ordersbusy = false
local hudsubscribed = false


function initialize()

    if onServer() then
        return
    end

    -- TODO: load some configs from server (i.e. updatedelay)

    -- load config and dynamic data
    config = getConfig("player", configdefaults)
    ordersInfo = getOrdersInfo()

    -- init runtime configs
    groupconfig = config.groups
    hudconfig = config.hud
    shipgroups = config.shipgroups
    knownships = config.knownships

    if hudconfig.enablehud then
        subscribeHudCallbacks()
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


function subscribeHudCallbacks()

    if not hudsubscribed then
        Sector():registerCallback("onPreRenderHud", "onPreRenderHud")
        hudsubscribed = true
    end
    debugLog("subscribeHudCallbacks()")

end

function unsubscribeHudCallbacks()

    Sector():unregisterCallback("onPreRenderHud", "onPreRenderHud")
    hudsubscribed = false
    debugLog("unsubscribeHudCallbacks()")

end


function onShowWindow()

    -- pre-select orders tab everytime window is opened
    tabs.window:selectTab(tabs.orders)

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

    local size = vec2(900, 700)
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

    -- build tabs

    tabs.orders = tabs.window:createTab("Orders", "data/textures/icons/fleetcontrol/commander.png", "Fleet Orders")
    buildOrdersUI(tabs.orders)

    tabs.groups = tabs.window:createTab("Groups", "data/textures/icons/fleetcontrol/shipgroups.png", "Fleet Groups")
    buildGroupsUI(tabs.groups)

    tabs.config = tabs.window:createTab("Config", "data/textures/icons/spanner.png", "Configuration")
    buildConfigUI(tabs.config)

    -- build dialogs

    buildTextDialog(menu, res)
    buildColorDialog(menu, res)

    scriptLog(nil, "client UI initialized successfully")
    
end


function buildOrdersUI(parent)

    local size = parent.size

    -- footer
    c_ord.btnPrevPage = parent:createButton(Rect(10, size.y - 40, 60, size.y - 10), "<", "onPrevPagePressed")	
    c_ord.btnPrevPage.active = false
    c_ord.btnNextPage = parent:createButton(Rect(size.x - 60, size.y - 40, size.x - 10, size.y - 10), ">", "onNextPagePressed")	

    c_ord.lblPageInfo = parent:createLabel(vec2((size.x/2) - 40, size.y - 30), "", 16)
    c_ord.lblPageInfo.color = ColorRGB(0.2, 0.2, 0.2)

    
    local y_grp = 0
    for g = 1, ordergroupslimit do

        local split_grp = UIVerticalSplitter(Rect(10, y_grp, size.x - 10, y_grp + 30), 10, 0, 0.5)
        split_grp.rightSize = 250

        local xl = split_grp.left.lower.x
        local xu = split_grp.left.upper.x

        -- group widgets
        local groupname = parent:createLabel(vec2(xl, y_grp + 4), "", 17)
        groupname.bold = true

        local cbox = parent:createComboBox(split_grp.right, "onGroupOrderSelected")
        cbox:addEntry("-")
        for _, btninfo in pairs(ordersInfo) do
            cbox:addEntry(btninfo.text)
        end    

        c_ord.lblGroupName[g] = groupname
        c_ord.cmdGroupOrder[g] = cbox
        
        -- create ship list widgets 
        local nameLabelX = 10
        local stateLabelX = -200
        local locLabelX = -85

        c_ord.ships.frame[g] = {}
        c_ord.ships.lblName[g] = {}
        c_ord.ships.lblState[g] = {}
        c_ord.ships.lblLoc[g] = {}
        c_ord.ships.btnLook[g] = {}
        c_ord.ships.cmdOrder[g] = {}
        c_ord.ships.lblOrder[g] = {}

        local y_shp = y_grp + 15
        for s = 1, groupshiplimit do 

            y_shp = y_shp + 35
            local yText = y_shp + 16
            
            local split1 = UIVerticalSplitter(Rect(10, y_shp, size.x - 10, y_shp +  50), 10, 10, 0.5)
            split1.rightSize = 210

            local frame = parent:createFrame(split1.left)        
            
            local xl = split1.left.lower.x
            local xu = split1.left.upper.x    

            -- captions
            if s == 1 then
                local cap1 = parent:createLabel(vec2(xl + nameLabelX, y_grp + 35), "Ship", 15)
                local cap2 = parent:createLabel(vec2(xu + stateLabelX, y_grp + 35), "State", 15)
                local cap3 = parent:createLabel(vec2(xu + locLabelX, y_grp + 35), "Sector", 15)
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
            lookat.tooltip = "Look at ship or map"

            if s == 01 then
                local cap4 = parent:createLabel(vec2(split2.right.lower.x, y_grp + 35), "Order", 15)
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

            c_ord.ships.frame[g][s] = frame
            c_ord.ships.lblName[g][s] = nameLabel
            c_ord.ships.lblState[g][s] = stateLabel
            c_ord.ships.lblLoc[g][s] = locLabel
            c_ord.ships.btnLook[g][s] = lookat
            c_ord.ships.cmdOrder[g][s] = cbox
            c_ord.ships.lblOrder[g][s] = orderLabel
	   
        end

        y_grp = y_shp + 65

    end

end


function buildGroupsUI(parent)

    local size = parent.size

    local split1 = UIVerticalSplitter(Rect(10, 10, size.x - 10, size.y - 10), 30, 0, 0.5)
    split1.leftSize = 200

    -- ships pool list
    local split_sp = UIHorizontalSplitter(split1.left, 10, 0, 0.5)
    split_sp.topSize = 20

    local cappool = parent:createLabel(vec2(split_sp.top.lower.x, split_sp.top.lower.y + 4), "Unassigned ships:", 13)
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

        -- parent:createFrame(split_grp1.top)

        -- group labels
        local split_grp2 = UIVerticalSplitter(split_grp1.top, 8, 0, 0.5)
        split_grp2.leftSize = 20

        local nrlbl = parent:createLabel(vec2(split_grp2.left.lower.x + 2, split_grp2.left.lower.y + 7), string.format("#%i", i), 12)
        local grplbl = parent:createLabel(vec2(split_grp2.right.lower.x, split_grp2.right.lower.y + 3), string.format("Group#%i", i), 17)

        -- group ship list
        local split_grp3 = UIVerticalSplitter(split_grp1.bottom, 5, 0, 0.5)
        split_grp3.rightSize = 30

        local xl, yl = split_grp3.right.lower.x, split_grp3.right.lower.y
        local xu, yu = split_grp3.right.upper.x, split_grp3.right.upper.y

        local shipassign = parent:createButton(Rect(xl, yl + 10, xl + 30, yl + 40), "+", "onAssignShipGroupPressed")   
        shipassign.tooltip = "Assign ship to group"        
        local shipunassign = parent:createButton(Rect(xl, yl + 50, xl + 30, yl + 80), "-", "onUnassignShipGroupPressed")   
        shipunassign.tooltip = "Unassign ship from group"

        local moveshipup = parent:createButton(Rect(xl, yu - 90, xl + 25, yu - 65), "", "onGroupShipUpPressed")
        moveshipup.icon = "data/textures/icons/flatarrowup.png"
        moveshipup.tooltip = "Move ship up in list"
        local moveshipdown = parent:createButton(Rect(xl, yu - 55, xl + 25, yu - 30), "", "onGroupShipDownPressed") 
        moveshipdown.icon = "data/textures/icons/flatarrowdown.png"
        moveshipdown.tooltip = "Move ship down in list"

        local split_grp4 = UIHorizontalSplitter(split_grp3.left, 0, 0, 0.5)
        split_grp4.bottomSize = 20

        local shiplist = parent:createListBox(split_grp4.top)
        local grpinfo = parent:createLabel(vec2(split_grp4.bottom.lower.x + (split_grp4.bottom.size.x/2) - 25, split_grp4.bottom.lower.y + 5), "", 12)

        grplbl.bold = true
        cappool.color = ColorARGB(0.5, 0, 0.3, 1)   
        nrlbl.color = ColorARGB(0.5, 0.2, 0.2, 0.2)     
        grpinfo.color = ColorARGB(0.5, 0.2, 0.2, 0.2)
        shipassign.textSize = 18  
        shipunassign.textSize = 18  
        shipassign.active = false
        shipunassign.active = false
        moveshipup.active = false
        moveshipdown.active = false

        c_grp.groups.lblName[i] = grplbl
        c_grp.groups.lstShips[i] = shiplist
        c_grp.groups.btnAssign[i] = shipassign
        c_grp.groups.btnUnassign[i] = shipunassign
        c_grp.groups.btnMoveUp[i] = moveshipup
        c_grp.groups.btnMoveDown[i] = moveshipdown
        c_grp.groups.lblGroupInfo[i] = grpinfo
        
    end  

end


function buildConfigUI(parent)

    -- IDEAS for configs
    --------------------
    -- "General" category:
    -- # close window on "look at" click if ship in sector
    --
    -- "HUD" category:
    -- # enable/disable certain info output and various styles (vert/horz listing etc)
    -- # alter location of hud with offset values from top, left, right, bottom
    --
    -- "Custom Orders" category for option related to "builtin" custom orders
    --
    -- "Integration" category for options regarding other mods


    local size = parent.size

    local split1 = UIVerticalSplitter(Rect(10, 10, size.x - 10, size.y - 10), 30, 0, 0.5)
    split1.leftSize = 150

    local split2 = UIHorizontalSplitter(split1.left, 10, 0, 0.5)
    split2.topSize = 20

    -- option categories list
    local catlbl = parent:createLabel(vec2(split2.top.lower.x, split2.top.lower.y + 4), "Categories:", 12)
    catlbl.color = ColorARGB(0.5, 0.8, 0.4, 0.2)  
    catlbl.italic = true
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

        local sgrp2 = UIHorizontalSplitter(r, 15, 10, 0.5)
        sgrp2.topSize = 40

        local frm = c_conf.cntCatGroups:createFrame(sgrp2.top)
        frm.backgroundColor = ColorARGB(0.35, 0, 0, 0)

        local xl, yl = sgrp2.top.lower.x, sgrp2.top.lower.y
        local xu, yu = sgrp2.top.upper.x, sgrp2.top.upper.y
        
        local nrlbl = c_conf.cntCatGroups:createLabel(vec2(xl + 2, yl + 8), string.format("#%i", g), 14)
        local namelbl = c_conf.cntCatGroups:createLabel(vec2(xl + 32, yl + 5), string.format("Group#%i", g), 16)
        local renbtn = c_conf.cntCatGroups:createButton(Rect(xu - 90, yl, xu, yl + 30), "Rename", "onRenameGroupPressed")

        local xl, yl = sgrp2.bottom.lower.x, sgrp2.bottom.lower.y
        local xu, yu = sgrp2.bottom.upper.x, sgrp2.bottom.upper.y

        local hudchk = c_conf.cntCatGroups:createCheckBox(Rect(xl + 10, yl + 8, xl + 150, yl + 20), "Show on HUD", "onGroupHudChecked") 
        
        local hudcolorlbl = c_conf.cntCatGroups:createLabel(vec2(xl + 200, yl + 7), "HUD Color:", 13)
        local hudcolorprev = c_conf.cntCatGroups:createPicture(Rect(xl + 300, yl, xl + 330, yl + 30), "data/textures/icons/fleetcontrol/white.png")
        local hudcolorpic = c_conf.cntCatGroups:createButton(Rect(xl + 335, yl, xl + 365, yl + 30), "", "onPickHudColorPressed")
        hudcolorpic.icon = "data/textures/icons/fleetcontrol/colorpicker.png"
        hudcolorpic.tooltip = "Choose HUD color"
       
        nrlbl.color = ColorRGB(0.2, 0.2, 0.2)
        hudcolorprev.color = ColorARGB(0.5, 1, 1, 1)

        c_conf.groups.lblName[g] = namelbl
        c_conf.groups.btnRename[g] = renbtn
        c_conf.groups.chkShowHud[g] = hudchk
        c_conf.groups.picHudColorPrev[g] = hudcolorprev
        c_conf.groups.btnHudColorPick[g] = hudcolorpic
    end

    -- HUD options

    c_conf.lstCategories:addEntry("HUD")
    c_conf.cntCatHUD = parent:createContainer(split1.right)

    local rs = c_conf.cntCatHUD.size

    c_conf.cntCatHUD:createLabel(vec2(0, 0), "HUD Options", 16)
    c_conf.cntCatHUD:createLine(vec2(0, 30), vec2(rs.x, 30))

    -- local sgrp1 = UIHorizontalMultiSplitter(Rect(0, 40, rs.x, rs.y), 20, 10, 3)

    c_conf.hud.chkEnableHud = c_conf.cntCatHUD:createCheckBox(Rect(10, 70, 200, 85), "Enable HUD Display", "onEnableHudChecked")
      
    c_conf.lstCategories:select(0)
    c_conf.cntCatHUD:hide()

end


function onTabSelected()

    selectedtabidx = tabs.window:getActiveTab().index

    if tabs.orders and tabs.orders.index == selectedtabidx then

        -- update groupnames and shown groups in related widgets
        refreshGroupNames()
        refreshPageInfo()
        
    elseif tabs.groups and tabs.groups.index == selectedtabidx then

        -- update groups tab widgets
        refreshGroupsUIShips()
        refreshGroupsInfo()

    elseif tabs.config and tabs.config.index == selectedtabidx then

        -- update config tab widgets
        refreshConfigUIGroups()
        refreshConfigUIHud()

    end

end


function onPrevPagePressed()
    
    currentPage = currentPage - 1
    laststateupdate = 0

    refreshGroupNames()
    refreshPageInfo()

    if currentPage == 1 then
        c_ord.btnPrevPage.active = false
    end
    c_ord.btnNextPage.active = true

end


function onNextPagePressed()

    currentPage = currentPage + 1
    laststateupdate = 0

    refreshGroupNames()
    refreshPageInfo()

    if currentPage == 2 then
        c_ord.btnNextPage.active = false
    end
    c_ord.btnPrevPage.active = true

end


function onLookAtPressed(sender)

    for i, g in orderGroupsIter() do
        for s, btn in pairs(c_ord.ships.btnLook[i]) do
            if btn.index == sender.index then
                if shipinfos[g][s].index then
                    local entity = Entity(shipinfos[g][s].index)
                    if entity then
                        Player().selectedObject = entity
                    end
                    return
                elseif shipinfos[g][s].location then
                    local coords = shipinfos[g][s].location
                    GalaxyMap():setSelectedCoordinates(coords.x, coords.y)
                    GalaxyMap():show(coords.x, coords.y)
                    return
                end               
            end
        end
    end

end


function onGroupOrderSelected(sender)

    -- TODO: prevent re-selection of current order

    local cbox, grp
    for i, g in orderGroupsIter() do
        if sender.index == c_ord.cmdGroupOrder[i].index then
            cbox = c_ord.cmdGroupOrder[i]
            grp = g
            break
        end
    end

    if cbox.selectedIndex < 1 then return end

    if ordersbusy then return end
    ordersbusy = true

    local indices = {}
    local pshipIndex = Player().craftIndex

    -- issue orders to all group ships excluding player driven ships
    for i, info in pairs(shipinfos[grp]) do
        if info.index ~= pshipIndex and info.hascaptain then
            indices[i] = info.index
        end
	end
    invokeOrdersScript(indices, ordersInfo[cbox.selectedIndex])

end


function onShipOrderSelected(sender)

    if ordersbusy then return end
    ordersbusy = true

    -- TODO: prevent re-selection of current order

    for i, g in orderGroupsIter() do
        for s, cmd in pairs(c_ord.ships.cmdOrder[i]) do
            if cmd.index == sender.index then
                if cmd.selectedIndex < 1 then return end
                local indices = {shipinfos[g][s].index}	
                invokeOrdersScript(indices, ordersInfo[cmd.selectedIndex])
                break
            end
        end
    end

end


function onAssignShipGroupPressed(sender)

    local shipname = c_grp.lstPool:getEntry(c_grp.lstPool.selected)

    for i, btn in pairs(c_grp.groups.btnAssign) do
		if btn.index == sender.index then
            -- update config data
            table.insert(shipgroups[i], shipname)
            config.shipgroups = shipgroups
            -- update list widgets
            c_grp.groups.lstShips[i]:addEntry(shipname)
            c_grp.lstPool:removeEntry(c_grp.lstPool.selected)
            break
		end
	end

    refreshGroupsUIButtons(true)
    refreshGroupsInfo()

end


function onUnassignShipGroupPressed(sender)

    for i, btn in pairs(c_grp.groups.btnUnassign) do
		if btn.index == sender.index then
            -- update config data
            table.remove(shipgroups[i], c_grp.groups.lstShips[i].selected + 1)
            config.shipgroups = shipgroups
            -- update list widgets
            local shipname = c_grp.groups.lstShips[i]:getEntry(c_grp.groups.lstShips[i].selected)       
            c_grp.lstPool:addEntry(shipname)
            c_grp.groups.lstShips[i]:removeEntry(c_grp.groups.lstShips[i].selected)
            break
		end
	end

    refreshGroupsUIButtons(true)
    refreshGroupsInfo()

end


function onGroupShipUpPressed(sender)

    for i, btn in pairs(c_grp.groups.btnMoveUp) do
		if btn.index == sender.index then
            local selidx = c_grp.groups.lstShips[i].selected + 1
            if selidx > 1 then
                -- swap table elements & update config data
                local s1, s2 = shipgroups[i][selidx], shipgroups[i][selidx-1]
                shipgroups[i][selidx-1] = s1
                shipgroups[i][selidx] = s2
                config.shipgroups = shipgroups
                -- update list widgets
                local _, bold, italic, color = c_grp.groups.lstShips[i]:getEntry(c_grp.groups.lstShips[i].selected-1)
                c_grp.groups.lstShips[i]:setEntry(c_grp.groups.lstShips[i].selected-1, s1, bold, italic, color)
                local _, bold, italic, color = c_grp.groups.lstShips[i]:getEntry(c_grp.groups.lstShips[i].selected)
                c_grp.groups.lstShips[i]:setEntry(c_grp.groups.lstShips[i].selected, s2, bold, italic, color) 
                -- select moved list entry 
                c_grp.groups.lstShips[i]:select(c_grp.groups.lstShips[i].selected-1)         
            end
            break
		end
	end

    refreshGroupsUIButtons(true)

end


function onGroupShipDownPressed(sender)

    for i, btn in pairs(c_grp.groups.btnMoveDown) do
		if btn.index == sender.index then
            local selidx = c_grp.groups.lstShips[i].selected + 1
            if selidx < c_grp.groups.lstShips[i].rows then
                -- swap table elements & update config data
                local s1, s2 = shipgroups[i][selidx], shipgroups[i][selidx+1]
                shipgroups[i][selidx+1] = s1
                shipgroups[i][selidx] = s2
                config.shipgroups = shipgroups
                -- update list widgets
                local _, bold, italic, color = c_grp.groups.lstShips[i]:getEntry(c_grp.groups.lstShips[i].selected+1)
                c_grp.groups.lstShips[i]:setEntry(c_grp.groups.lstShips[i].selected+1, s1, bold, italic, color)
                local _, bold, italic, color = c_grp.groups.lstShips[i]:getEntry(c_grp.groups.lstShips[i].selected)
                c_grp.groups.lstShips[i]:setEntry(c_grp.groups.lstShips[i].selected, s2, bold, italic, color) 
                -- select moved list entry 
                c_grp.groups.lstShips[i]:select(c_grp.groups.lstShips[i].selected+1)         
            end
            break
		end
	end

    refreshGroupsUIButtons(true)

end


function onRenameGroupPressed(sender)

    for i, btn in pairs(c_conf.groups.btnRename) do
		if btn.index == sender.index then
            showTextDialog("Rename Group", i, onRenameGroupCallback, groupconfig[i].name, groupnamelimit)
		end
	end

end

function onRenameGroupCallback(result, text, param)

    if result and text and text ~= "" then
        -- update UI and config with new group name
        groupconfig[param].name = text
        config.groups = groupconfig
        refreshGroupNames()
    end

end


function onGroupHudChecked(sender)

    for i, chk in pairs(c_conf.groups.chkShowHud) do
		if chk.index == sender.index then
            groupconfig[i].showhud = chk.checked
            config.groups = groupconfig
		end
	end

end


function onPickHudColorPressed(sender)

    for i, btn in pairs(c_conf.groups.btnHudColorPick) do
		if btn.index == sender.index then
            local color = ColorARGB(groupconfig[i].hudcolor.a, groupconfig[i].hudcolor.r, groupconfig[i].hudcolor.g, groupconfig[i].hudcolor.b)
            showColorDialog("Choose HUD Color", i, onPickHudColorCallback, color)
		end
	end

end

function onPickHudColorCallback(result, color, param)

    if result and color then
        -- update UI and config with new group name
        groupconfig[param].hudcolor = {a=color.a,r=color.r,g=color.g,b=color.b}
        config.groups = groupconfig
        refreshConfigUIGroups()
    end

end


function onEnableHudChecked()

    -- update config and save
    hudconfig.enablehud = c_conf.hud.chkEnableHud.checked
    config.hud = hudconfig

    if hudconfig.enablehud then
        subscribeHudCallbacks()
    else
        unsubscribeHudCallbacks()
    end

end


---- DIALOG WINDOWS ----

function buildTextDialog(menu, res)

    local size = vec2(350, 120)

    textdialog.window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    textdialog.window.visible = false
    textdialog.window.showCloseButton = 1
    textdialog.window.moveable = 1
    textdialog.window.closeableWithEscape = 1

    local split1 = UIHorizontalSplitter(Rect(vec2(0, 0), size), 30, 20, 0.5)
    split1.bottomSize = 30

    textdialog.textbox = textdialog.window:createTextBox(split1.top, "")

    local xu, yu = split1.bottom.upper.x, split1.bottom.upper.y
    textdialog.window:createButton(Rect(xu - 170, yu - 30, xu - 90, yu), "OK", "onTextDialogOKPressed")
    textdialog.window:createButton(Rect(xu - 80, yu - 30, xu, yu), "Cancel", "onTextDialogCancelPressed")

end

function onTextDialogOKPressed()

    textdialog.window:hide()

    if textdialog.callback and type(textdialog.callback) == "function" then
        textdialog.callback(true, textdialog.textbox.text, textdialog.param)
    end

end

function onTextDialogCancelPressed()

    textdialog.window:hide()

    if textdialog.callback and type(textdialog.callback) == "function" then
        textdialog.callback(false)
    end

end

function showTextDialog(caption, param, callback, text, maxlen)

    textdialog.window.caption = caption
    textdialog.textbox.text = text or ""
    textdialog.textbox.maxCharacters = maxlen or 256

    textdialog.param = param
    textdialog.callback = callback

    textdialog.window:show()

end


function buildColorDialog(menu, res)

    local size = vec2(500, 375)

    colordialog.window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    colordialog.window.visible = false
    colordialog.window.showCloseButton = 1
    colordialog.window.moveable = 1
    colordialog.window.closeableWithEscape = 1

    local split1 = UIHorizontalSplitter(Rect(vec2(0, 0), size), 30, 20, 0.5)
    split1.bottomSize = 30

    local split2 = UIVerticalSplitter(split1.top, 20, 0, 0.5)
    local split3 = UIHorizontalSplitter(split2.left, 20, 0, 0.5)
    split3.topSize = 30

    local xl, yl = split3.top.lower.x, split3.top.lower.y
    local prevlbl = colordialog.window:createLabel(vec2(xl + 40, yl + 10), "Color Preview:", 16)
    prevlbl.italic = true
    colordialog.colorpreview = colordialog.window:createPicture(split3.bottom, "data/textures/icons/fleetcontrol/white.png")
    colordialog.colorpreview.color = ColorARGB(0, 1, 1, 1)

    local frm = colordialog.window:createFrame(split2.right)

    local msplit1 = UIHorizontalMultiSplitter(split2.right, 30, 30, 3)
    colordialog.sliderR = colordialog.window:createSlider(msplit1:partition(0), 0, 255, 255, "RED", "refreshColorDialogPreview")
    colordialog.sliderG = colordialog.window:createSlider(msplit1:partition(1), 0, 255, 255, "GREEN", "refreshColorDialogPreview")
    colordialog.sliderB = colordialog.window:createSlider(msplit1:partition(2), 0, 255, 255, "BLUE", "refreshColorDialogPreview")
    colordialog.sliderA = colordialog.window:createSlider(msplit1:partition(3), 0, 255, 255, "Alpha", "refreshColorDialogPreview")

    local xu, yu = split1.bottom.upper.x, split1.bottom.upper.y
    colordialog.window:createButton(Rect(xu - 170, yu - 30, xu - 90, yu), "OK", "onColorDialogOKPressed")
    colordialog.window:createButton(Rect(xu - 80, yu - 30, xu, yu), "Cancel", "onColorDialogCancelPressed")

end

function refreshColorDialogPreview()

    local valA = colordialog.sliderA.sliderPosition
    local valR = colordialog.sliderR.sliderPosition
    local valG = colordialog.sliderG.sliderPosition
    local valB = colordialog.sliderB.sliderPosition

    local color = ColorARGB(valA, valR, valG, valB)
    colordialog.colorpreview.color = color
    colordialog.color = color

end

function onColorDialogOKPressed()

    colordialog.window:hide()

    if colordialog.callback and type(colordialog.callback) == "function" then
        colordialog.callback(true, colordialog.color, colordialog.param)
    end

end

function onColorDialogCancelPressed()

    colordialog.window:hide()

    if colordialog.callback and type(colordialog.callback) == "function" then
        colordialog.callback(false)
    end

end

function showColorDialog(caption, param, callback, color)

    colordialog.window.caption = caption
    colordialog.colorpreview.color = color

    -- sync value sliders
    colordialog.sliderA.sliderPosition = color.a
    colordialog.sliderR.sliderPosition = color.r
    colordialog.sliderG.sliderPosition = color.g
    colordialog.sliderB.sliderPosition = color.b

    colordialog.param = param
    colordialog.callback = callback

    colordialog.window:show()

end


---- UI UPDATES ----

function displayShipState(g, s, ship, currloc)

    if g > ordergroupslimit or s > groupshiplimit then return end

    -- display basic ship states
    c_ord.ships.lblName[g][s].caption = ship.name
    c_ord.ships.lblName[g][s]:show()

    -- TODO: colors for states =)
    if ship.isplayer then
        c_ord.ships.lblState[g][s].caption = "Player"
    elseif not ship.hascaptain then
        c_ord.ships.lblState[g][s].caption = "No Captain"
    else
        c_ord.ships.lblState[g][s].caption = ship.aistate or "-"
    end
    c_ord.ships.lblState[g][s].bold = ship.isplayer or false
    --c_ord.ships.lblState[g][s].italic = (not ship.hascaptain)
    c_ord.ships.lblState[g][s]:show()

    -- location/sector of ship
    if ship.location then 
        local loc = vec2(ship.location.x, ship.location.y)
        if  loc.x == currloc.x and loc.y == currloc.y then
            c_ord.ships.lblLoc[g][s].caption = "current"
            c_ord.ships.lblLoc[g][s].italic = true
        else
            c_ord.ships.lblLoc[g][s].caption = tostring(loc) 
            c_ord.ships.lblLoc[g][s].italic = false
        end
        c_ord.ships.lblLoc[g][s]:show()
        c_ord.ships.btnLook[g][s]:show() 
    end
   
    if ship.hascaptain then
        if ship.order then
            if ship.elsewhere or ship.isplayer then
                -- disable orders combobox if ship is controlled by player or elsewhere
                c_ord.ships.lblOrder[g][s].caption = "-"
                for i, oi in pairs(ordersInfo) do 
                    if oi.order == ship.order then
                        c_ord.ships.lblOrder[g][s].caption = oi.text
                        break
                    end
                end
                c_ord.ships.lblOrder[g][s]:show()
            else
                -- set selected order to ship's current order
                c_ord.ships.cmdOrder[g][s]:setSelectedIndexNoCallback(1)    
                for i, oi in pairs(ordersInfo) do 
                    if oi.order == ship.order then
                        c_ord.ships.cmdOrder[g][s]:setSelectedIndexNoCallback(i)
                        break
                    end
                end
                c_ord.ships.cmdOrder[g][s]:show()
            end
        elseif not ship.isplayer then
            c_ord.ships.cmdOrder[g][s]:setSelectedIndexNoCallback(1)
            c_ord.ships.cmdOrder[g][s]:show()
        end
    end

    -- make rest of ship related widgets visible
    c_ord.ships.frame[g][s]:show() 

end


function refreshOrdersUI()

    -- hide all ship list widgets at first
    for g = 1, ordergroupslimit do
        for s = 1, groupshiplimit do
            c_ord.ships.frame[g][s]:hide()
            c_ord.ships.lblName[g][s]:hide()
            c_ord.ships.lblState[g][s]:hide()
            c_ord.ships.lblLoc[g][s]:hide()
            c_ord.ships.btnLook[g][s]:hide()
            c_ord.ships.cmdOrder[g][s]:hide()
            c_ord.ships.lblOrder[g][s]:hide()
        end
    end

    if not shipinfos then return end

    
    local currentcoords = vec2(Sector():getCoordinates())

    for i, g in orderGroupsIter() do
        local ordersequal = #shipinfos[g] > 0
        local lastorder 

        for s, shipinfo in pairs(shipinfos[g]) do 
            -- check if all ships have same order/state
            if lastorder and lastorder ~= shipinfo.order then
                ordersequal = false
            end
            lastorder = shipinfo.order

            displayShipState(i, s, shipinfo, currentcoords)       
        end

        -- pre-select group order
        if ordersequal then
            for j, oi in pairs(ordersInfo) do 
                if oi.order == lastorder then
                    c_ord.cmdGroupOrder[i]:setSelectedIndexNoCallback(j)
                    break
                end
            end
        else
            c_ord.cmdGroupOrder[i]:setSelectedIndexNoCallback(0)
        end
    end

end


function refreshGroupNames()

    -- Orders tab
    for i, g in orderGroupsIter() do
        c_ord.lblGroupName[i].caption = groupconfig[g].name
    end

    for g = 1, 4 do 
        -- Groups tab
        c_grp.groups.lblName[g].caption = groupconfig[g].name
        -- Config tab
        c_conf.groups.lblName[g].caption = groupconfig[g].name      
    end
    
end


function refreshConfigUIGroups()

    for g = 1, 4 do 
        c_conf.groups.lblName[g].caption = groupconfig[g].name
        c_conf.groups.chkShowHud[g].checked = groupconfig[g].showhud or false
        local hudcolor = groupconfig[g].hudcolor
        c_conf.groups.picHudColorPrev[g].color = ColorARGB(hudcolor.a, hudcolor.r, hudcolor.g, hudcolor.b)
    end

end


function refreshConfigUIHud()

    c_conf.hud.chkEnableHud.checked = hudconfig.enablehud

end


function refreshPageInfo()

    local lb = ((currentPage * ordergroupslimit) - ordergroupslimit + 1)
    local ub = (currentPage * ordergroupslimit) 
    c_ord.lblPageInfo.caption = string.format("#%i - #%i", lb, ub)

end


function refreshGroupsInfo()

    for g = 1, 4 do
        local cur, max = c_grp.groups.lstShips[g].rows, groupshiplimit
        c_grp.groups.lblGroupInfo[g].caption = string.format("%i / %i", cur, max)
        if cur < max then
            c_grp.groups.lblGroupInfo[g].color = ColorARGB(0.5, 0, 1, 0)
        else
            c_grp.groups.lblGroupInfo[g].color = ColorARGB(0.5, 1, 0, 0)
        end
    end

end


function refreshGroupsUIShips()

    -- fill group lists with assigned ships
    for i = 1, 4 do
        c_grp.groups.lstShips[i]:clear()
        for _, shipname in pairs(shipgroups[i]) do
            c_grp.groups.lstShips[i]:addEntry(shipname)
        end
    end

    -- fill pool list with rest
    c_grp.lstPool:clear()
    for _, ship in pairs(knownships) do 
        local assigned = false
        for i, shipgrp in pairs(shipgroups) do 
            if table.contains(shipgrp, ship) then
                assigned = true
                break
            end      
        end
        if not assigned then
            c_grp.lstPool:addEntry(ship)
        end
    end
    
end


function refreshGroupsUIButtons(force)

    -- en/disable ship assignment buttons according to list selections 
    if force or c_grp.lstPool.selected ~= shipPoolLastIndex then
        shipPoolLastIndex = c_grp.lstPool.selected
        for i = 1, 4 do 
            c_grp.groups.btnAssign[i].active = (shipPoolLastIndex >= 0) and (c_grp.groups.lstShips[i].rows < groupshiplimit)
        end
    end
    for i = 1, 4 do 
        
        if force or c_grp.groups.lstShips[i].selected ~= groupListsLastIndices[i] then
            groupListsLastIndices[i] = c_grp.groups.lstShips[i].selected
            c_grp.groups.btnUnassign[i].active = (groupListsLastIndices[i] >= 0)
            c_grp.groups.btnMoveUp[i].active = (groupListsLastIndices[i] > 0)
            c_grp.groups.btnMoveDown[i].active = (groupListsLastIndices[i] >= 0 and groupListsLastIndices[i] < (c_grp.groups.lstShips[i].rows-1))
        end
    end

end


function updateUI()

    if selectedtabidx == tabs.groups.index then

        refreshGroupsUIButtons()

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

            -- get all exisiting ships of player in current sector
            local sectorships = getPlayerCrafts()

            -- TODO: add new ship scripts here!!

            -- add new ships to known ones
            local knownshipsupdate = false
            for _, ship in pairs(sectorships) do 
                if not table.contains(knownships, ship.name) then
                    table.insert(knownships, ship.name)
                    knownshipsupdate = true
                end
            end
            if knownshipsupdate then
                alphanumsort(knownships)
                config.knownships = knownships
            end

            -- update ship states and refresh ships UI widgets
            updateShipStates(shipgroups, sectorships)

            laststateupdate = current
            ordersbusy = false
        end

    end

    -- draw HUD elements if enabled
    if hudconfig.enablehud then
        drawHud()
    end

end


function onPreRenderHud()

    debugLog("onPreRenderHud()")
    --drawText("TEST", 10, 500, ColorARGB(0.5, 1, 1, 1), 16, false, false, 0)

end


function drawHud()

    drawText("TEST", 10, 500, ColorARGB(0.5, 1, 1, 1), 16, false, false, 0)

end


function syncShipInfos(data)

    if onServer() then
        invokeClientFunction(Player(callingPlayer), "syncShipInfos", data)
        return
    end

    shipinfos = data

    -- update infos in UI
    if uivisible then
        refreshOrdersUI()
    end

end


---- SERVER-SIDE ----

function updateShipStates(groups, ships)

    if onClient() then
        invokeServerFunction("updateShipStates", groups, ships)
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
    for _, ship in pairs(ships) do 
        if table.contains(updateships, ship.name) then
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
                    local hascaptain = checkShipCaptain(entity)
                    local aistate, order
                    if hascaptain then
                        aistate, order = getShipAIOrderState(entity) 
                    end
                    table.insert(statedata, {
                        name = entity.name,
                        index = entity.index,
                        aistate = aistate,
                        order = order,
                        location = coords,
                        hascaptain = hascaptain
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


-- function requestShipInfoSync()

--     if onClient() then
--         invokeServerFunction("requestShipInfoSync")
--         return
--     end

--     debugLog("shipinfo sync requested")
--     invokeClientFunction(Player(callingPlayer), "syncShipInfos", shipinfos)

-- end



---- UTILITY FUNCTIONS ----

function orderGroupsIter()
    local i = 0
    local lb = ((currentPage * ordergroupslimit) - ordergroupslimit + 1)
    local ub = (currentPage * ordergroupslimit)
    local curr = 0

    return function() 
                i = i + 1
                if curr == 0 then
                    curr = lb
                elseif curr < ub then
                    curr = curr + 1 
                else    
                    return                 
                end
                return i, curr
           end 
end
