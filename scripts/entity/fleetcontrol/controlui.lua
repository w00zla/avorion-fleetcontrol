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

-- namespace FleetControlUi
FleetControlUi = {}

local Me = FleetControlUi
local Co = FleetControlCommon


-- UI widget collections
local mywindow
local tabs = {
    window = nil,
    orders = nil,
    groups = nil,
    config = nil
}

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
local hudposdialog = {
    window = nil,
    resolution = nil,
    hudanchor = nil,
    stepsize = 5,
    lblHudPos = nil,
    sliderStepSize = nil,
    btnPosUp = nil,
    btnPosDown = nil,
    btnPosLeft = nil,
    btnPosRight= nil,
    btnAlignTL = nil,
    btnAlignTC = nil,
    btnAlignTR = nil,
    btnAlignML = nil,
    btnAlignMC = nil,
    btnAlignMR = nil,
    btnAlignBL = nil,
    btnAlignBC = nil,
    btnAlignBR = nil
}
local shipseldialog = {
    visible = false,
    lastselidx = nil,
    window = nil,
    param = nil,
    callback = nil,
    selectedship = nil,
    ships = nil,
    lblInfo = nil,
    lstShips = nil,
    btnOk = nil
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
        lblOrder = {},
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
    cntCatUIGeneral = nil,
    cntCatUIColors = nil,
    groups = {
        lblName = {},
        btnRename = {},
        chkShowHud = {},
        picHudColorPrev = {},
        btnHudColorPick = {}
    },
    hud = {
        chkShowHud = nil,
        lblHudNotice = nil,
        btnPosHud = nil,
        cmbHudStyle = nil,
        chkShowGrpNames = nil,
        chkShowShpStates = nil,
        chkShowShpOrders = nil,
        chkShowShpLocs = nil,
        chkHideUncaptained = nil,
        chkUseUiStateClrs = nil,
    },
    uigeneral = {
        chkSelectOrdersTab = nil,
        chkSelectOrdersFirstPage = nil,
        chkCloseWindowOnLookAt = nil,
        chkEnableOrderSounds = nil,
        lblOrderSoundFile = nil,
        btnOrderSoundFile = nil,
    },
    uicolors = {
        picStateColorPrev = {},
        btnStateColorPick = {}
    }
}

--  UI limits
local ordergroupslimit = 2
local groupshiplimit = 6
local groupnamelimit = 18

-- UI widget indices
local shipPoolLastIndex
local configCatsLastIndex
local groupListsLastIndices = {}
local currentPage = 1
local selectedtabidx
local groupordermapping = {}
local shipordermapping = {}

-- client config buffers
local pconfig
local sconfig
local ordersInfo
local aiStates
local groupconfig
local hudconfig
local uiconfig
local knownships
local shipgroups

-- client runtime data
local shipinfos
local hudanchoroverride

-- client flags and timestamps
local uivisible = false
local doupdatestates = false
local laststateupdate = 0
local ordersbusy = false
local hudsubscribed = false
local eventsactive = false

function FleetControlUi.initialize()

    if onServer() then 
        -- SERVER
        sconfig = Co.getConfig("server", Co.getServerConfigDefaults())
        Co.enableDebugOutput(sconfig.debugoutput)         
        deferredCallback(1, "syncServerConfig", sconfig)
        return 
    end

    -- CLIENT

    -- initial debug options
    if not sconfig then
        sconfig = Co.getServerConfigDefaults()
        Co.enableDebugOutput(sconfig.debugoutput)
    end

    ordersInfo = Co.getOrdersInfo()
    aiStates = Co.getAiStates()

    -- load player config values
    pconfig = Co.getConfig("player", Co.getPlayerConfigDefaults())
    groupconfig = pconfig.groups
    hudconfig = pconfig.hud
    uiconfig = pconfig.ui
    shipgroups = pconfig.shipgroups
    knownships = pconfig.knownships

    if hudconfig.showhud then
        Me.subscribeHudCallbacks()
        doupdatestates = true
    end
end


function FleetControlUi.syncServerConfig(config, playeridx)

    if onServer() then
		local player 
		if playeridx then
			player = Player(playeridx)
		else
			player = Player(callingPlayer)
		end
        invokeClientFunction(player, "syncServerConfig", config)
        return
    end 

    -- re-creation of config object is required because metatable gets lost via serialization
    sconfig = Co.copyConfig(config)
    Co.enableDebugOutput(sconfig.debugoutput)

    if sconfig.debugoutput then 
        Co.debugLog("synced mod server configuration to client:")
        printTable(sconfig) 
    end

end


function FleetControlUi.savePlayerConfig(config)

    -- force this function to run server-side only
    if onClient() then
        pconfig.groups = groupconfig 
        pconfig.hud = hudconfig 
        pconfig.ui = uiconfig 
        pconfig.shipgroups = shipgroups 
        pconfig.knownships = knownships 

        invokeServerFunction("savePlayerConfig", pconfig)
        return
    end

    pconfig = config
    Co.saveConfig(pconfig)

end


function FleetControlUi.getIcon(seed, rarity)
    return "data/textures/icons/fleetcontrol/commander.png"
end


function FleetControlUi.interactionPossible(player)
    return true, ""
end


function FleetControlUi.subscribeHudCallbacks()

    -- debugLog("subscribeHudCallbacks()")

    if not hudsubscribed then
        Player():registerCallback("onPreRenderHud", "onPreRenderHud")
        hudsubscribed = true
    end   

end

function FleetControlUi.unsubscribeHudCallbacks()

    -- debugLog("unsubscribeHudCallbacks()")

    Player():unregisterCallback("onPreRenderHud", "onPreRenderHud")
    hudsubscribed = false

end


function FleetControlUi.forceImmediateUpdate()

    laststateupdate = sconfig.updatedelay + 1

end


function FleetControlUi.onShowWindow()

    -- pre-select orders tab everytime window is opened
    Me.forceImmediateUpdate()

    if uiconfig.preselectorderstab then
        tabs.window:selectTab(tabs.orders)
    end  

    -- trigger updates of UI widgets
    uivisible = true   
    -- trigger update of ship states and orders
    doupdatestates = true

end


function FleetControlUi.onCloseWindow()

    uivisible = false
    doupdatestates = hudconfig.showhud

    -- handle dialog windows and related vars
    if textdialog.window then textdialog.window:hide() end
    if colordialog.window then colordialog.window:hide() end
    if c_conf.uigeneral.inputOrderSoundFile.visible then c_conf.uigeneral.inputOrderSoundFile:hide() end

    if hudposdialog.window then hudposdialog.window:hide() end
    hudanchoroverride = nil

    if shipseldialog.window then 
        shipseldialog.window:hide() 
        shipseldialog.visible = false
    end

end


function FleetControlUi.playOrderSound()

    if uiconfig.enableordersounds and uiconfig.ordersoundfile and uiconfig.ordersoundfile ~= "" then
        
        local soundfile
        if string.find(uiconfig.ordersoundfile, ",") then
            local files = {}
            for file in string.gmatch(uiconfig.ordersoundfile, "([^,]+)") do
                table.insert(files, file)
            end
            soundfile = files[math.random(#files)]
        else
            soundfile = uiconfig.ordersoundfile
        end

        local sfPath = "interface/" .. soundfile
        Co.debugLog("order sounds enabled -> playing sound '%s'", sfPath)
        -- TODO: enable random playing of multiple defined sounds
        playSound(sfPath, SoundType.UI, 1)
    end

end


function FleetControlUi.initUI()

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
    Me.buildOrdersUI(tabs.orders)

    tabs.groups = tabs.window:createTab("Groups", "data/textures/icons/fleetcontrol/shipgroups.png", "Fleet Groups")
    Me.buildGroupsUI(tabs.groups)

    tabs.config = tabs.window:createTab("Config", "data/textures/icons/spanner.png", "Configuration")
    Me.buildConfigUI(tabs.config)

    -- build dialogs
    Me.buildTextDialog(menu, res)
    Me.buildColorDialog(menu, res)
    Me.buildHudPositioningDialog(menu, res)
    Me.buildShipSelectionDialog(menu, res)

    -- init with first tab
    tabs.window:selectTab(tabs.orders)

    eventsactive = true

    Co.scriptLog(nil, "client UI initialized successfully")
    
end


function FleetControlUi.buildOrdersUI(parent)

    -- create mappings
    for _, oi in pairs(ordersInfo) do
        if not oi.nongrouporder then
            -- groupordermapping[oi.order] = oi.text
            table.insert(groupordermapping, oi.text)
        end
        if not oi.nonshiporder then
            -- shipordermapping[oi.order] = oi.text
            table.insert(shipordermapping, oi.text)
        end
    end  

    -- create widgets
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
        for _, ordertxt in pairs(groupordermapping) do
            cbox:addEntry(ordertxt)
        end    

        c_ord.lblGroupName[g] = groupname
        c_ord.cmdGroupOrder[g] = cbox
        
        -- create ship list widgets 
        local nameLabelX = 10
        local stateLabelX = -220
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
            for _, ordertxt in pairs(shipordermapping) do
                cbox:addEntry(ordertxt)
            end   
            local orderlbl = parent:createLabel(vec2(split2.right.lower.x + 5, split2.right.lower.y + 6), "", 14)
            orderlbl.font = "Arial"

            -- hide controls initially and add to reference table
            frame:hide()
            nameLabel:hide()
            stateLabel:hide()
            locLabel:hide()
            lookat:hide()
            cbox:hide()
            orderlbl:hide()

            c_ord.ships.frame[g][s] = frame
            c_ord.ships.lblName[g][s] = nameLabel
            c_ord.ships.lblState[g][s] = stateLabel
            c_ord.ships.lblLoc[g][s] = locLabel
            c_ord.ships.btnLook[g][s] = lookat
            c_ord.ships.cmdOrder[g][s] = cbox
            c_ord.ships.lblOrder[g][s] = orderlbl
	   
        end

        y_grp = y_shp + 65

    end

end


function FleetControlUi.buildGroupsUI(parent)

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
        cappool.color = ColorRGB(0, 0.3, 1)   
        nrlbl.color = ColorRGB(0.2, 0.2, 0.2)     
        grpinfo.color = ColorRGB(0.2, 0.2, 0.2)
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


function FleetControlUi.buildConfigUI(parent)

    -- IDEAS for configs
    --------------------
    -- "HUD" category:
    -- # define hotkey for HUD display
    -- # define font-size(s)
    -- # shadow/outline text options
    -- 
    -- "UI General" category:
    -- # enable and define sound for order action
    -- 
    -- "Custom Orders" category for option related to "builtin" custom orders
    -- "Integration" category for options regarding other mods


    local size = parent.size

    local split0 = UIHorizontalSplitter(Rect(10, 10, size.x - 10, size.y - 10), 0, 0, 0.5)
    split0.bottomSize = 18

    -- mod info label
    local modinfolbl = parent:createLabel(vec2(split0.bottom.upper.x - 210, split0.bottom.lower.y + 6), Co.getModInfoLine(), 12)
    modinfolbl.color = ColorRGB(0.2, 0.2, 0.2)

    local split1 = UIVerticalSplitter(split0.top, 30, 0, 0.5)
    split1.leftSize = 150

    local split2 = UIHorizontalSplitter(split1.left, 10, 0, 0.5)
    split2.topSize = 20

    -- option categories list
    local catlbl = parent:createLabel(vec2(split2.top.lower.x, split2.top.lower.y + 4), "Categories:", 12)
    catlbl.color = ColorRGB(0.8, 0.4, 0.2)  
    catlbl.italic = true
    c_conf.lstCategories = parent:createListBox(split2.bottom)

    -- GROUPS options

    c_conf.lstCategories:addEntry("Groups")
    c_conf.cntCatGroups = parent:createContainer(split1.right)

    local rs = c_conf.cntCatGroups.size

    c_conf.cntCatGroups:createLabel(vec2(0, 0), "Groups Options", 16)
    c_conf.cntCatGroups:createLine(vec2(0, 30), vec2(rs.x, 30))

    local splitgrp1 = UIHorizontalMultiSplitter(Rect(0, 40, rs.x, rs.y), 20, 10, 3)
    for p = 0, 3 do
        local g = p + 1
        local r = splitgrp1:partition(p)  

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
        hudcolorprev.color = ColorARGB(0, 0, 0, 0)

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

    local splithud1 = UIHorizontalSplitter(Rect(0, 40, rs.x, rs.y), 20, 10, 0.5)
    splithud1.topSize = 60
    local splithud2 = UIVerticalSplitter(splithud1.top, 10, 10, 0.5)

    local xl, yl = splithud2.left.lower.x, splithud2.left.lower.y
    c_conf.hud.chkShowHud = c_conf.cntCatHUD:createCheckBox(Rect(xl, yl + 10, xl + 220, yl + 30), "Enable HUD Display", "onShowHudChecked")
    c_conf.hud.chkShowHud.fontSize = 16
    c_conf.hud.lblHudNotice = c_conf.cntCatHUD:createLabel(vec2(xl, yl + 5), "HUD display is disabled on this server", 14)
    c_conf.hud.lblHudNotice.color = ColorRGB(1, 0, 0)
    c_conf.hud.lblHudNotice:hide()

    c_conf.hud.btnPosHud = c_conf.cntCatHUD:createButton(splithud2.right, "Set HUD Position", "onSetHudPositionPressed")

    local splithud3 = UIVerticalSplitter(splithud1.bottom, 0, 0, 0.5)
    local splithud4 = UIHorizontalMultiSplitter(splithud3.left, 20, 20, 6)

    local shudstyle = UIVerticalSplitter(splithud4:partition(0), 0, 0, 0.5)
    c_conf.cntCatHUD:createLabel(vec2(shudstyle.left.lower.x, shudstyle.left.lower.y + 5), "Listing Style:", 14)
    local r = shudstyle.right
    c_conf.hud.cmbHudStyle = c_conf.cntCatHUD:createComboBox(Rect(r.lower.x, r.lower.y, r.upper.x, r.lower.y + 30), "onHudStyleSelected")
    c_conf.hud.cmbHudStyle:addEntry("Vertical")
    c_conf.hud.cmbHudStyle:addEntry("Horizontal")
    c_conf.hud.cmbHudStyle:addEntry("Horizontal Wide")

    local r = splithud4:partition(1)
    c_conf.hud.chkShowGrpNames = c_conf.cntCatHUD:createCheckBox(Rect(r.lower.x, r.lower.y, r.upper.x, r.lower.y + 20), "Show group names", "onHudOptionChecked")
    local r = splithud4:partition(2)
    c_conf.hud.chkShowShpStates = c_conf.cntCatHUD:createCheckBox(Rect(r.lower.x, r.lower.y, r.upper.x, r.lower.y + 20), "Show ship states", "onHudOptionChecked")
    local r = splithud4:partition(3)
    c_conf.hud.chkShowShpOrders = c_conf.cntCatHUD:createCheckBox(Rect(r.lower.x, r.lower.y, r.upper.x, r.lower.y + 20), "Show ship orders", "onHudOptionChecked")
    local r = splithud4:partition(4)
    c_conf.hud.chkShowShpLocs = c_conf.cntCatHUD:createCheckBox(Rect(r.lower.x, r.lower.y, r.upper.x, r.lower.y + 20), "Show ship locations", "onHudOptionChecked")
    local r = splithud4:partition(5)
    c_conf.hud.chkHideUncaptained = c_conf.cntCatHUD:createCheckBox(Rect(r.lower.x, r.lower.y, r.upper.x, r.lower.y + 20), "Hide Player/NoCaptain ships", "onHudOptionChecked")
    local r = splithud4:partition(6)
    c_conf.hud.chkUseUiStateClrs = c_conf.cntCatHUD:createCheckBox(Rect(r.lower.x, r.lower.y, r.upper.x, r.lower.y + 20), "Use UI colors for states", "onHudOptionChecked")

    -- UI General options

    c_conf.lstCategories:addEntry("UI General")
    c_conf.cntCatUIGeneral = parent:createContainer(split1.right)

    local rs = c_conf.cntCatUIGeneral.size

    c_conf.cntCatUIGeneral:createLabel(vec2(0, 0), "General UI Options", 16)
    c_conf.cntCatUIGeneral:createLine(vec2(0, 30), vec2(rs.x, 30))

    local splituig1 = UIHorizontalSplitter(Rect(0, 40, rs.x, rs.y), 20, 30, 0.35)
    local splituig2 = UIHorizontalMultiSplitter(splituig1.top, 10, 0, 4)

    local r = splituig2:partition(0)
    c_conf.uigeneral.chkSelectOrdersTab = c_conf.cntCatUIGeneral:createCheckBox(Rect(r.lower.x, r.lower.y, r.lower.x + 350, r.lower.y + 20), "Select orders tab on window open", "onUiGeneralOptionChecked")
    local r = splituig2:partition(1)
    c_conf.uigeneral.chkSelectOrdersFirstPage = c_conf.cntCatUIGeneral:createCheckBox(Rect(r.lower.x, r.lower.y, r.lower.x + 350, r.lower.y + 20), "Select first page on orders tab", "onUiGeneralOptionChecked")
    local r = splituig2:partition(2)
    c_conf.uigeneral.chkCloseWindowOnLookAt = c_conf.cntCatUIGeneral:createCheckBox(Rect(r.lower.x, r.lower.y, r.lower.x + 350, r.lower.y + 20), "Close window on 'Look At' action", "onUiGeneralOptionChecked")
      
    local r = splituig2:partition(4)
    c_conf.uigeneral.chkEnableOrderSounds = c_conf.cntCatUIGeneral:createCheckBox(Rect(r.lower.x, r.lower.y + 7, r.lower.x + 205, r.lower.y + 27), "Enable order sounds", "onUiGeneralOptionChecked")   
    local sflbl = c_conf.cntCatUIGeneral:createLabel(vec2(r.lower.x, r.lower.y + 38), "Sounds:", 13)
    sflbl.color = ColorRGB(0.3, 0.3, 0.3)
    c_conf.uigeneral.lblOrderSoundFile = c_conf.cntCatUIGeneral:createLabel(vec2(r.lower.x + 75, r.lower.y + 38), "", 12)
    c_conf.uigeneral.lblOrderSoundFile.rect.upper.x = r.upper.x - 150
    c_conf.uigeneral.btnOrderSoundFile = c_conf.cntCatUIGeneral:createButton(Rect(r.upper.x - 140, r.lower.y + 38, r.upper.x, r.lower.y + 66), "Change Sounds", "onChangeOrderSoundFilePressed")
    c_conf.uigeneral.inputOrderSoundFile = c_conf.cntCatUIGeneral:createInputWindow()
    c_conf.uigeneral.inputOrderSoundFile.onOKFunction = "onOrderSoundFileNameEntered"
    c_conf.uigeneral.inputOrderSoundFile.caption = "Sound Files"

    -- UI Colors options

    c_conf.lstCategories:addEntry("UI Colors")
    c_conf.cntCatUIColors = parent:createContainer(split1.right)

    local rs = c_conf.cntCatUIColors.size

    c_conf.cntCatUIColors:createLabel(vec2(0, 0), "UI Color Options", 16)
    c_conf.cntCatUIColors:createLine(vec2(0, 30), vec2(rs.x, 30))

    local splituic1 = UIHorizontalMultiSplitter(Rect(0, 40, rs.x, rs.y), 10, 25, #aiStates-1)

    for i, state in pairs(aiStates) do
        local r = splituic1:partition(i-1)
        local xl, yl = r.lower.x, r.lower.y
        local stateclrlblpre = c_conf.cntCatUIColors:createLabel(vec2(xl, yl + 5), "State: ", 13)
        stateclrlblpre.color = ColorRGB(0.3, 0.3, 0.3)
        local stateclrlbl = c_conf.cntCatUIColors:createLabel(vec2(xl + 55, yl + 5), state, 14)
        local clrprev = c_conf.cntCatUIColors:createPicture(Rect(xl + 200, yl, xl + 230, yl + 30), "data/textures/icons/fleetcontrol/white.png")
        local colorpic = c_conf.cntCatUIColors:createButton(Rect(xl + 235, yl, xl + 265, yl + 30), "", "onPickStateColorPressed")
        colorpic.icon = "data/textures/icons/fleetcontrol/colorpicker.png"
        colorpic.tooltip = "Choose state color"

        table.insert(c_conf.uicolors.picStateColorPrev, clrprev)
        table.insert(c_conf.uicolors.btnStateColorPick, colorpic)
    end

    -- pre-select groups category 
    c_conf.lstCategories:select(0)
    c_conf.cntCatHUD:hide()
    c_conf.cntCatUIGeneral:hide()
    c_conf.cntCatUIColors:hide()

end

function FleetControlUi.onTabSelected()

    selectedtabidx = tabs.window:getActiveTab().index

    if tabs.orders and tabs.orders.index == selectedtabidx then

        Me.forceImmediateUpdate()
        if uiconfig.preselectordersfirstpage then
            currentPage = 1
            c_ord.btnPrevPage.active = false
            c_ord.btnNextPage.active = true
        end  
        -- update groupnames and shown groups in related widgets
        Me.refreshGroupNames()
        Me.refreshPageInfo()
        
    elseif tabs.groups and tabs.groups.index == selectedtabidx then

        -- update groups tab widgets
        Me.refreshGroupsUIShips()
        Me.refreshGroupsInfo()

    elseif tabs.config and tabs.config.index == selectedtabidx then

        -- update config tab widgets
        Me.refreshConfigUIGroups()
        Me.refreshConfigUIHud()
        Me.refreshConfigUIGeneral()
        Me.refreshConfigUIColors()

    end

end


function FleetControlUi.onPrevPagePressed()
    
    currentPage = currentPage - 1
    Me.forceImmediateUpdate()

    Me.refreshGroupNames()
    Me.refreshPageInfo()

    if currentPage == 1 then
        c_ord.btnPrevPage.active = false
    end
    c_ord.btnNextPage.active = true

end


function FleetControlUi.onNextPagePressed()

    currentPage = currentPage + 1
    Me.forceImmediateUpdate()

    Me.refreshGroupNames()
    Me.refreshPageInfo()

    if currentPage == 2 then
        c_ord.btnNextPage.active = false
    end
    c_ord.btnPrevPage.active = true

end


function FleetControlUi.onLookAtPressed(sender)

    for i, g in Me.orderGroupsIter() do
        for s, btn in pairs(c_ord.ships.btnLook[i]) do
            if btn.index == sender.index then
                if not shipinfos[g][s].elsewhere then
                    local entity = Entity(shipinfos[g][s].index)
                    if entity then
                        Player().selectedObject = entity
                    end
                elseif shipinfos[g][s].location then
                    local coords = shipinfos[g][s].location
                    GalaxyMap():setSelectedCoordinates(coords.x, coords.y)
                    GalaxyMap():show(coords.x, coords.y)
                end 
                if uiconfig.closewindowonlookat then
                    mywindow:hide()
                    ScriptUI():stopInteraction() -- close all windows
                end    
                return          
            end
        end
    end

end


function FleetControlUi.onGroupOrderSelected(sender)

    local cbox, grp
    for i, g in Me.orderGroupsIter() do
        if sender.index == c_ord.cmdGroupOrder[i].index then
            cbox = c_ord.cmdGroupOrder[i]
            grp = g
            break
        end
    end

    if cbox.selectedIndex < 1 then return end
    
    if ordersbusy then return end
    ordersbusy = true

    local oi = Co.table_childByKeyVal(ordersInfo, "text", cbox.selectedEntry)
    if not oi then return end

    -- issue orders to all group ships excluding player driven ships
    local indices = {}
    for i, ship in pairs(shipinfos[grp]) do     
        if not ship.isplayer and ship.hascaptain then
            indices[i] = ship.index
        end
	end
    Me.playOrderSound()
    Me.invokeOrdersScript(indices, oi)

end


function FleetControlUi.onShipOrderSelected(sender)

    if ordersbusy then return end
    ordersbusy = true

    for i, g in Me.orderGroupsIter() do
        for s, cmd in pairs(c_ord.ships.cmdOrder[i]) do
            if cmd.index == sender.index then
                if cmd.selectedIndex < 1 then return end
                local oi = Co.table_childByKeyVal(ordersInfo, "text", cmd.selectedEntry)
                if oi then 
                    local indices = {shipinfos[g][s].index}	
                    if not oi.invokecurrent then
                        Me.playOrderSound()
                    end
                    Me.invokeOrdersScript(indices, oi)
                end                   
                break
            end
        end
    end

end


function FleetControlUi.onAssignShipGroupPressed(sender)

    local shipname = c_grp.lstPool:getEntry(c_grp.lstPool.selected)
    local shipidx = Co.table_childByKeyVal(knownships, "name", shipname).index

    for i, btn in pairs(c_grp.groups.btnAssign) do
		if btn.index == sender.index then
            -- update config data
            table.insert(shipgroups[i], shipidx)
            Me.savePlayerConfig()
            -- update list widgets
            c_grp.groups.lstShips[i]:addEntry(shipname)
            c_grp.lstPool:removeEntry(c_grp.lstPool.selected)
            break
		end
	end

    Me.refreshGroupsUIButtons(true)
    Me.refreshGroupsInfo()

end


function FleetControlUi.onUnassignShipGroupPressed(sender)

    for i, btn in pairs(c_grp.groups.btnUnassign) do
		if btn.index == sender.index then
            -- update config data
            table.remove(shipgroups[i], c_grp.groups.lstShips[i].selected + 1)
            Me.savePlayerConfig()
            -- update list widgets
            local shipname = c_grp.groups.lstShips[i]:getEntry(c_grp.groups.lstShips[i].selected)       
            c_grp.lstPool:addEntry(shipname)
            c_grp.groups.lstShips[i]:removeEntry(c_grp.groups.lstShips[i].selected)
            break
		end
	end

    -- TODO: sort ship list alphanum style

    Me.refreshGroupsUIButtons(true)
    Me.refreshGroupsInfo()

end


function FleetControlUi.onGroupShipUpPressed(sender)

    for i, btn in pairs(c_grp.groups.btnMoveUp) do
		if btn.index == sender.index then
            local selidx = c_grp.groups.lstShips[i].selected + 1
            if selidx > 1 then
                -- swap table elements & update config data
                local s1, s2 = shipgroups[i][selidx], shipgroups[i][selidx-1]
                shipgroups[i][selidx-1] = s1
                shipgroups[i][selidx] = s2
                Me.savePlayerConfig()
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

    Me.refreshGroupsUIButtons(true)

end


function FleetControlUi.onGroupShipDownPressed(sender)

    for i, btn in pairs(c_grp.groups.btnMoveDown) do
		if btn.index == sender.index then
            local selidx = c_grp.groups.lstShips[i].selected + 1
            if selidx < c_grp.groups.lstShips[i].rows then
                -- swap table elements & update config data
                local s1, s2 = shipgroups[i][selidx], shipgroups[i][selidx+1]
                shipgroups[i][selidx+1] = s1
                shipgroups[i][selidx] = s2
                Me.savePlayerConfig()
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

    Me.refreshGroupsUIButtons(true)

end


function FleetControlUi.onRenameGroupPressed(sender)

    for i, btn in pairs(c_conf.groups.btnRename) do
		if btn.index == sender.index then
            Me.showTextDialog("Rename Group", i, Me.onRenameGroupCallback, groupconfig[i].name, groupnamelimit)
		end
	end

end

function FleetControlUi.onRenameGroupCallback(result, text, param)

    if result and text and text ~= "" then
        -- update UI and config with new group name
        groupconfig[param].name = text
        Me.savePlayerConfig()
        Me.refreshGroupNames()
    end

end


function FleetControlUi.onChangeOrderSoundFilePressed() 
    
    c_conf.uigeneral.inputOrderSoundFile:show("Names of sound files to use (comma to seperate, without extension):")
    c_conf.uigeneral.inputOrderSoundFile.textBox.text = uiconfig.ordersoundfile or ""

end


function FleetControlUi.onOrderSoundFileNameEntered(windows, text)
    if text and text ~= "" then
        uiconfig.ordersoundfile = text
        Me.savePlayerConfig()
        Me.refreshConfigUIGeneral()
    end

end


function FleetControlUi.onGroupHudChecked(sender)

    if not eventsactive then return end

    for i, chk in pairs(c_conf.groups.chkShowHud) do
		if chk.index == sender.index then
            groupconfig[i].showhud = chk.checked
            Me.savePlayerConfig()
		end
	end

end


function FleetControlUi.onPickHudColorPressed(sender)

    for i, btn in pairs(c_conf.groups.btnHudColorPick) do
		if btn.index == sender.index then
            local color = ColorARGB(groupconfig[i].hudcolor.a, groupconfig[i].hudcolor.r, groupconfig[i].hudcolor.g, groupconfig[i].hudcolor.b)
            Me.showColorDialog("Choose HUD Color", i, Me.onPickHudColorCallback, color, true)
            break
		end
	end

end

function FleetControlUi.onPickHudColorCallback(result, color, param)

    Co.debugLog("result: %s color: %s", result, color)

    if result and color then
        -- update UI and pconfig with new group name
        groupconfig[param].hudcolor = {a=color.a,r=color.r,g=color.g,b=color.b}
        Me.savePlayerConfig()
        Me.refreshConfigUIGroups()
    end

end


function FleetControlUi.onShowHudChecked()

    if not eventsactive then return end

    -- update config and save
    c_conf.hud.btnPosHud.active = c_conf.hud.chkShowHud.checked
    hudconfig.showhud = c_conf.hud.chkHud.checked    

    Me.savePlayerConfig()

    if hudconfig.showhud then
        Me.subscribeHudCallbacks()
    else
        Me.unsubscribeHudCallbacks()
    end

end


function FleetControlUi.onSetHudPositionPressed(sender)

    Me.showHudPositioningDialog()

end


function FleetControlUi.onHudStyleSelected()

    hudconfig.hudstyle = c_conf.hud.cmbHudStyle.selectedIndex
    Me.savePlayerConfig()

end


function FleetControlUi.onHudOptionChecked(sender)

    if not eventsactive then return end

    hudconfig.showgroupnames = c_conf.hud.chkShowGrpNames.checked
    hudconfig.showshipstates = c_conf.hud.chkShowShpStates.checked
    hudconfig.showshiporders = c_conf.hud.chkShowShpOrders.checked
    hudconfig.showshiplocations = c_conf.hud.chkShowShpLocs.checked
    hudconfig.hideuncaptained = c_conf.hud.chkHideUncaptained.checked
    hudconfig.useuistatecolors = c_conf.hud.chkUseUiStateClrs.checked

    Me.savePlayerConfig()

end


function FleetControlUi.onUiGeneralOptionChecked(sender)

    if not eventsactive then return end

    uiconfig.preselectorderstab = c_conf.uigeneral.chkSelectOrdersTab.checked
    uiconfig.preselectordersfirstpage = c_conf.uigeneral.chkSelectOrdersFirstPage.checked
    uiconfig.closewindowonlookat = c_conf.uigeneral.chkCloseWindowOnLookAt.checked
    uiconfig.enableordersounds = c_conf.uigeneral.chkEnableOrderSounds.checked

    Me.savePlayerConfig()

end


function FleetControlUi.onPickStateColorPressed(sender)

    for i, btn in pairs(c_conf.uicolors.btnStateColorPick) do
		if btn.index == sender.index then
            local clrval = uiconfig.statecolors[aiStates[i]]
            Me.showColorDialog("Choose State Color", i, Me.onPickStateColorCallback, ColorRGB(clrval.r, clrval.g, clrval.b), false)
            break
		end
	end

end

function FleetControlUi.onPickStateColorCallback(result, color, param)

    if result and color then
        -- update config with new state color
        uiconfig.statecolors[aiStates[param]] = {r=color.r,g=color.g,b=color.b}

        Me.savePlayerConfig()
        Me.refreshConfigUIColors()
    end

end


function FleetControlUi.onEscortShipButtonPressed(shipidx)

    if onServer() then
        invokeClientFunction(Player(), "onEscortShipButtonPressed", shipidx)
        return
    end

    Me.showShipSelectionDialog("Select ship to escort:", shipidx, Me.onEscortShipSelectionCallback)

end

function FleetControlUi.onEscortShipSelectionCallback(result, selectedship, param)

    if result and selectedship then
        local indices = {param}	
        local oi = Co.table_childByKeyVal(ordersInfo, "order", "Escort")
        Me.playOrderSound()
        Me.invokeOrdersScript(indices, oi, selectedship.index)                 
    end

end


---- DIALOG WINDOWS ----

function FleetControlUi.buildTextDialog(menu, res)

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

function FleetControlUi.onTextDialogOKPressed()

    textdialog.window:hide()

    if textdialog.callback and type(textdialog.callback) == "function" then
        textdialog.callback(true, textdialog.textbox.text, textdialog.param)
    end

end

function FleetControlUi.onTextDialogCancelPressed()

    textdialog.window:hide()

    if textdialog.callback and type(textdialog.callback) == "function" then
        textdialog.callback(false)
    end

end

function FleetControlUi.showTextDialog(caption, param, callback, text, maxlen)

    textdialog.window.caption = caption
    textdialog.textbox.text = text or ""
    textdialog.textbox.maxCharacters = maxlen or 256

    textdialog.param = param
    textdialog.callback = callback

    textdialog.window:show()

end


function FleetControlUi.buildColorDialog(menu, res)

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

function FleetControlUi.refreshColorDialogPreview()

    local valA = colordialog.sliderA.sliderPosition
    local valR = colordialog.sliderR.sliderPosition
    local valG = colordialog.sliderG.sliderPosition
    local valB = colordialog.sliderB.sliderPosition

    local color = ColorARGB(valA, valR, valG, valB)
    colordialog.colorpreview.color = color
    colordialog.color = color

end

function FleetControlUi.onColorDialogOKPressed()

    colordialog.window:hide()

    if colordialog.callback and type(colordialog.callback) == "function" then
        colordialog.callback(true, colordialog.color, colordialog.param)
    end

end

function FleetControlUi.onColorDialogCancelPressed()

    colordialog.window:hide()

    if colordialog.callback and type(colordialog.callback) == "function" then
        colordialog.callback(false)
    end

end

function FleetControlUi.showColorDialog(caption, param, callback, color, showalpha)

    colordialog.window.caption = caption
    colordialog.colorpreview.color = color

    -- sync value sliders
    colordialog.sliderA.sliderPosition = color.a
    if showalpha then
        colordialog.sliderA:show()
    else
        colordialog.sliderA:hide()
    end
    colordialog.sliderR.sliderPosition = color.r
    colordialog.sliderG.sliderPosition = color.g
    colordialog.sliderB.sliderPosition = color.b

    colordialog.param = param
    colordialog.callback = callback

    colordialog.window:show()

end


function FleetControlUi.buildHudPositioningDialog(menu, res)

    local size = vec2(800, 260)

    hudposdialog.window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    hudposdialog.window.caption = "Set HUD Position"
    hudposdialog.window.visible = false
    hudposdialog.window.showCloseButton = 0
    hudposdialog.window.moveable = 1
    hudposdialog.window.closeableWithEscape = 0

    local split1 = UIHorizontalSplitter(Rect(vec2(0, 0), size), 30, 20, 0.5)
    split1.bottomSize = 50

    local hudanchlbl = hudposdialog.window:createLabel(vec2(split1.bottom.lower.x + 10, split1.bottom.lower.y + 5), "Current Position:", 16)
    hudanchlbl.italic = true
    hudposdialog.lblHudPos = hudposdialog.window:createLabel(vec2(split1.bottom.lower.x + 175, split1.bottom.lower.y + 5), "", 16)

    local xu, yu = split1.bottom.upper.x, split1.bottom.upper.y
    hudposdialog.window:createButton(Rect(xu - 170, yu - 30, xu - 90, yu), "OK", "onHudPositioningDialogOKPressed")
    hudposdialog.window:createButton(Rect(xu - 80, yu - 30, xu, yu), "Cancel", "onHudPositioningDialogCancelPressed")

    -- local split2 = UIVerticalMultiSplitter(split1.top, 10, 0, 3)
    local split2 = UIVerticalSplitter(split1.top, 10, 0, 0.5)
    split2.rightSize = 450

    local frm1 = hudposdialog.window:createFrame(split2.left)
    local frm2 = hudposdialog.window:createFrame(split2.right)

    -- create widgets for HUD positioning
    local split4 = UIVerticalSplitter(split2.left, 25, 15, 0.5)
    split4.leftSize = 120
    local split5 = UIHorizontalSplitter(split4.left, 10, 10, 0.5)
    split5.bottomSize = 30

    local movelbl = hudposdialog.window:createLabel(vec2(split5.top.lower.x + 15, split5.top.lower.y), "Move\nHUD", 18)
    movelbl.color = ColorRGB(0,1,0)
    hudposdialog.sliderStepSize = hudposdialog.window:createSlider(split5.bottom, 5, 100, 19, "Step Size", "onHudStepSizeChanged")
    hudposdialog.sliderStepSize.unit = "px"
    hudposdialog.sliderStepSize.value = hudposdialog.stepsize

    local splithudpos0 = UIHorizontalMultiSplitter(split4.right, 5, 0, 2)
    local splithudpos1 = UIVerticalMultiSplitter(splithudpos0:partition(0), 0, 0, 2)
    local splithudpos2 = UIVerticalMultiSplitter(splithudpos0:partition(1), 0, 0, 2)
    local splithudpos3 = UIVerticalMultiSplitter(splithudpos0:partition(2), 0, 0, 2)

    hudposdialog.btnPosUp = hudposdialog.window:createButton(splithudpos1:partition(1), "", "onPositionHudPressed")
    hudposdialog.btnPosUp.icon = "data/textures/icons/fleetcontrol/arrowup.png"
    hudposdialog.btnPosUp.tooltip = "Move HUD position up"
    hudposdialog.btnPosLeft = hudposdialog.window:createButton(splithudpos2:partition(0), "", "onPositionHudPressed")
    hudposdialog.btnPosLeft.icon = "data/textures/icons/fleetcontrol/arrowleft.png"
    hudposdialog.btnPosLeft.tooltip = "Move HUD position left"
    hudposdialog.btnPosRight = hudposdialog.window:createButton(splithudpos2:partition(2), "", "onPositionHudPressed")
    hudposdialog.btnPosRight.icon = "data/textures/icons/fleetcontrol/arrowright.png"
    hudposdialog.btnPosRight.tooltip = "Move HUD position right"
    hudposdialog.btnPosDown = hudposdialog.window:createButton(splithudpos3:partition(1), "", "onPositionHudPressed")
    hudposdialog.btnPosDown.icon = "data/textures/icons/fleetcontrol/arrowdown.png"
    hudposdialog.btnPosDown.tooltip = "Move HUD position down"
    
    -- create widgets for HUD alignment
    -- TODO: align to center of roughly calculated HUD display size (problem here is label size...)
    local split3 = UIVerticalSplitter(split2.right, 10, 15, 0.5)
    split3.leftSize = 120

    local alignlbl = hudposdialog.window:createLabel(vec2(split3.left.lower.x + 20, split3.left.lower.y + 35), "Align\nHUD", 18)
    alignlbl.color = ColorRGB(0,0,1)

    local splithudalign0 = UIHorizontalMultiSplitter(split3.right, 10, 0, 2)
    local splithudalign1 = UIVerticalMultiSplitter(splithudalign0:partition(0), 10, 0, 2)
    local splithudalign2 = UIVerticalMultiSplitter(splithudalign0:partition(1), 10, 0, 2)
    local splithudalign3 = UIVerticalMultiSplitter(splithudalign0:partition(2), 10, 0, 2)

    hudposdialog.btnAlignTL = hudposdialog.window:createButton(splithudalign1:partition(0), "Top Left", "onAlignHudPressed")
    hudposdialog.btnAlignTL.tooltip = "Align HUD to top-left of screen"
    hudposdialog.btnAlignTL.textSize = 12
    hudposdialog.btnAlignTC = hudposdialog.window:createButton(splithudalign1:partition(1), "Top Center", "onAlignHudPressed")
    hudposdialog.btnAlignTC.tooltip = "Align HUD to top-center of screen"
    hudposdialog.btnAlignTC.textSize = 12
    hudposdialog.btnAlignTR = hudposdialog.window:createButton(splithudalign1:partition(2), "Top Right", "onAlignHudPressed")
    hudposdialog.btnAlignTR.tooltip = "Align HUD to top-right of screen"
    hudposdialog.btnAlignTR.textSize = 12

    hudposdialog.btnAlignML = hudposdialog.window:createButton(splithudalign2:partition(0), "Mid Left", "onAlignHudPressed")
    hudposdialog.btnAlignML.tooltip = "Align HUD to mid-left of screen"
    hudposdialog.btnAlignML.textSize = 12
    hudposdialog.btnAlignMC = hudposdialog.window:createButton(splithudalign2:partition(1), "Mid Center", "onAlignHudPressed")
    hudposdialog.btnAlignMC.tooltip = "Align HUD to mid-center of screen"
    hudposdialog.btnAlignMC.textSize = 12
    hudposdialog.btnAlignMR = hudposdialog.window:createButton(splithudalign2:partition(2), "Mid Right", "onAlignHudPressed")
    hudposdialog.btnAlignMR.tooltip = "Align HUD to mid-right of screen"
    hudposdialog.btnAlignMR.textSize = 12

    hudposdialog.btnAlignBL = hudposdialog.window:createButton(splithudalign3:partition(0), "Bottom Left", "onAlignHudPressed")
    hudposdialog.btnAlignBL.tooltip = "Align HUD to bottom-left of screen"
    hudposdialog.btnAlignBL.textSize = 12
    hudposdialog.btnAlignBC = hudposdialog.window:createButton(splithudalign3:partition(1), "Bot. Center", "onAlignHudPressed")
    hudposdialog.btnAlignBC.tooltip = "Align HUD to bottom-center of screen"
    hudposdialog.btnAlignBC.textSize = 12
    hudposdialog.btnAlignBR = hudposdialog.window:createButton(splithudalign3:partition(2), "Bottom Right", "onAlignHudPressed")
    hudposdialog.btnAlignBR.tooltip = "Align HUD to bottom-right of screen"
    hudposdialog.btnAlignBR.textSize = 12

    hudposdialog.window:hide()

end

function FleetControlUi.onHudStepSizeChanged()

    hudposdialog.stepsize = hudposdialog.sliderStepSize.value

end

function FleetControlUi.onAlignHudPressed(sender)

    if sender.index == hudposdialog.btnAlignTL.index then
        -- top-left
        hudposdialog.hudanchor.x = 50
        hudposdialog.hudanchor.y = 50
    elseif sender.index == hudposdialog.btnAlignTC.index then
        -- top-center
        hudposdialog.hudanchor.x = hudposdialog.resolution.x / 2
        hudposdialog.hudanchor.y = 50
    elseif sender.index == hudposdialog.btnAlignTR.index then
        -- top-right
        hudposdialog.hudanchor.x = hudposdialog.resolution.x - 350
        hudposdialog.hudanchor.y = 50
    elseif sender.index == hudposdialog.btnAlignML.index then
        -- mid-left
        hudposdialog.hudanchor.x = 50
        hudposdialog.hudanchor.y = hudposdialog.resolution.y / 2
    elseif sender.index == hudposdialog.btnAlignMC.index then
        -- mid-center
        hudposdialog.hudanchor.x = hudposdialog.resolution.x / 2
        hudposdialog.hudanchor.y = hudposdialog.resolution.y / 2
    elseif sender.index == hudposdialog.btnAlignMR.index then
        -- mid-right
        hudposdialog.hudanchor.x = hudposdialog.resolution.x - 350
        hudposdialog.hudanchor.y = hudposdialog.resolution.y / 2
    elseif sender.index == hudposdialog.btnAlignBL.index then
        -- bottom-left
        hudposdialog.hudanchor.x = 50
        hudposdialog.hudanchor.y = hudposdialog.resolution.y - 150
    elseif sender.index == hudposdialog.btnAlignBC.index then
        -- bottom-center
        hudposdialog.hudanchor.x = hudposdialog.resolution.x / 2
        hudposdialog.hudanchor.y = hudposdialog.resolution.y - 150
    elseif sender.index == hudposdialog.btnAlignBR.index then
        -- bottom-right
        hudposdialog.hudanchor.x = hudposdialog.resolution.x - 350
        hudposdialog.hudanchor.y = hudposdialog.resolution.y - 150
    end

    hudanchoroverride = hudposdialog.hudanchor
    hudposdialog.lblHudPos.caption = Co.formatPosition(hudposdialog.hudanchor)

end

function FleetControlUi.onPositionHudPressed(sender)

    if sender.index == hudposdialog.btnPosUp.index then
        -- up
        local newY = hudposdialog.hudanchor.y - hudposdialog.stepsize
        if newY >= 0 then
            hudposdialog.hudanchor.y = newY
        else
            hudposdialog.hudanchor.y = 0
        end
    elseif sender.index == hudposdialog.btnPosDown.index then
        -- down
        local newY = hudposdialog.hudanchor.y + hudposdialog.stepsize
        if newY <= hudposdialog.resolution.y then
            hudposdialog.hudanchor.y = newY
        else
            hudposdialog.hudanchor.y = hudposdialog.resolution.y
        end
    elseif sender.index == hudposdialog.btnPosLeft.index then
        -- left
        local newX = hudposdialog.hudanchor.x - hudposdialog.stepsize
        if newX >= 0 then
            hudposdialog.hudanchor.x = newX
        else
            hudposdialog.hudanchor.x = 0
        end
    elseif sender.index == hudposdialog.btnPosRight.index then
        -- right
        local newX = hudposdialog.hudanchor.x + hudposdialog.stepsize
        if newX <= hudposdialog.resolution.x then
            hudposdialog.hudanchor.x = newX
        else
            hudposdialog.hudanchor.x = hudposdialog.resolution.x
        end
    end

    hudanchoroverride = hudposdialog.hudanchor
    hudposdialog.lblHudPos.caption = Co.formatPosition(hudposdialog.hudanchor)

end

function FleetControlUi.onHudPositioningDialogOKPressed()

    hudposdialog.window:hide()
    hudconfig.hudanchor = { x=hudposdialog.hudanchor.x, y=hudposdialog.hudanchor.y }

    Me.savePlayerConfig()

    hudanchoroverride = nil

end

function FleetControlUi.onHudPositioningDialogCancelPressed()

    hudposdialog.window:hide()
    hudanchoroverride = nil

end

function FleetControlUi.showHudPositioningDialog()

    hudposdialog.resolution = getResolution()
    hudposdialog.hudanchor = { x=hudconfig.hudanchor.x, y=hudconfig.hudanchor.y }
    hudanchoroverride = hudposdialog.hudanchor

    hudposdialog.lblHudPos.caption = Co.formatPosition(hudposdialog.hudanchor)
    hudposdialog.window:show()

end


function FleetControlUi.buildShipSelectionDialog(menu, res)

    local size = vec2(350, 400)

    shipseldialog.window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    shipseldialog.window.caption = "Select Ship"
    shipseldialog.window.visible = false
    shipseldialog.window.showCloseButton = 1
    shipseldialog.window.moveable = 1
    shipseldialog.window.closeableWithEscape = 1

    local split1 = UIHorizontalSplitter(Rect(vec2(0, 0), size), 30, 20, 0.5)
    split1.bottomSize = 30

    local split2 = UIHorizontalSplitter(split1.top, 10, 0, 0.5)
    split2.topSize = 25

    shipseldialog.lblInfo = shipseldialog.window:createLabel(vec2(split2.top.lower.x + 5, split2.top.lower.y), "Select ship:", 16)
    shipseldialog.lblInfo.color = ColorRGB(0.3, 0.3, 0.3)
    shipseldialog.lstShips = shipseldialog.window:createListBox(split2.bottom)

    local xu, yu = split1.bottom.upper.x, split1.bottom.upper.y
    shipseldialog.btnOk = shipseldialog.window:createButton(Rect(xu - 170, yu - 30, xu - 90, yu), "Select", "onShipSelectionDialogOKPressed")
    shipseldialog.window:createButton(Rect(xu - 80, yu - 30, xu, yu), "Cancel", "onShipSelectionDialogCancelPressed")

    shipseldialog.window:hide()

end

function FleetControlUi.onShipSelectionDialogOKPressed()

    shipseldialog.window:hide()

    if shipseldialog.callback and type(shipseldialog.callback) == "function" then
        shipseldialog.callback(true, shipseldialog.selectedship, shipseldialog.param)
    end

end

function FleetControlUi.onShipSelectionDialogCancelPressed()

    shipseldialog.window:hide()
    shipseldialog.visible = false

end

function FleetControlUi.showShipSelectionDialog(infotext, param, callback)

    shipseldialog.lblInfo.caption = infotext
    shipseldialog.lstShips:clear()
    shipseldialog.btnOk.active = false

    local sectorships = Co.sortShipsArray(Co.getPlayerCrafts())
    shipseldialog.ships = {}
    for i, ship in pairs(sectorships) do
        if ship.index ~= param then
            table.insert(shipseldialog.ships, ship)
            shipseldialog.lstShips:addEntry(ship.name)
            -- TODO: colorize Player/NoCaptain ships
        end
    end

    shipseldialog.param = param
    shipseldialog.callback = callback

    shipseldialog.window:show()
    shipseldialog.visible = true

end

function FleetControlUi.refreshShipSelectionDialog()

    if shipseldialog.lstShips.selected ~= shipseldialog.lastselidx then
        shipseldialog.lastselidx = shipseldialog.lstShips.selected
        shipseldialog.selectedship = shipseldialog.ships[shipseldialog.lastselidx+1]
        shipseldialog.btnOk.active = (shipseldialog.lastselidx >= 0)
    end
end

---- UI UPDATES ----

function FleetControlUi.refreshGroupNames()

    -- Orders tab
    for i, g in Me.orderGroupsIter() do
        c_ord.lblGroupName[i].caption = groupconfig[g].name
    end

    for g = 1, 4 do 
        -- Groups tab
        c_grp.groups.lblName[g].caption = groupconfig[g].name
        -- Config tab
        c_conf.groups.lblName[g].caption = groupconfig[g].name      
    end

end


function FleetControlUi.refreshOrdersUI()

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

    for i, g in Me.orderGroupsIter() do
        local ordersequal = #shipinfos[g] > 0
        local lastorder = nil

        for s, shipinfo in pairs(shipinfos[g]) do 
            -- check if all ships have same order/state
            if lastorder and shipinfo.order and lastorder ~= shipinfo.order then
                ordersequal = false
            end
            lastorder = shipinfo.order

            Me.displayShipState(i, s, shipinfo, currentcoords)       
        end

        -- pre-select group order
        if ordersequal then
            local oi = Co.table_childByKeyVal(ordersInfo, "order", lastorder)
            if oi and not oi.nongrouporder then
                for j, otxt in pairs(groupordermapping) do
                    if otxt == oi.text then
                        c_ord.cmdGroupOrder[i]:setSelectedIndexNoCallback(j)
                        break
                    end
                end
            end
        else
            c_ord.cmdGroupOrder[i]:setSelectedIndexNoCallback(0)
        end
    end

end


function FleetControlUi.displayShipState(g, s, ship, currloc)

    if g > ordergroupslimit or s > groupshiplimit then return end

    -- display basic ship states
    c_ord.ships.lblName[g][s].caption = ship.name
    c_ord.ships.lblName[g][s]:show()

    -- state of ship (AI)
    local statetxt = "-"
    local stateclr = ColorRGB(1,1,1)
    if not ship.elsewhere and ship.state then
        statetxt = ship.state
        local sc = uiconfig.statecolors[ship.state]
        if sc then
            stateclr = ColorRGB(sc.r, sc.g, sc.b)
        end 
    end
    c_ord.ships.lblState[g][s].caption = statetxt
    c_ord.ships.lblState[g][s].color = stateclr
    c_ord.ships.lblState[g][s]:show()

    -- location/sector of ship
    if ship.location and not ship.isplayer then 
        local loc = vec2(ship.location.x, ship.location.y)
        if  loc.x == currloc.x and loc.y == currloc.y then
            c_ord.ships.lblLoc[g][s].caption = "(current)"
            c_ord.ships.lblLoc[g][s].italic = true
        else
            c_ord.ships.lblLoc[g][s].caption = tostring(loc) 
            c_ord.ships.lblLoc[g][s].italic = false
        end
        c_ord.ships.lblLoc[g][s]:show()
        c_ord.ships.btnLook[g][s]:show() 
    end
   
    -- ship order
    if not ship.elsewhere then
        if ship.isplayer then
            c_ord.ships.lblOrder[g][s].caption = "Player"
            --c_ord.ships.lblOrder[g][s].color = ColorRGB(0.3, 0.3, 0.3)
            c_ord.ships.lblOrder[g][s]:show()
        elseif not ship.hascaptain then
            c_ord.ships.lblOrder[g][s].caption = "No Captain"
            --c_ord.ships.lblOrder[g][s].color = ColorRGB(0.3, 0.3, 0.3)
            c_ord.ships.lblOrder[g][s]:show()
        else
            c_ord.ships.cmdOrder[g][s]:setSelectedIndexNoCallback(1)
            c_ord.ships.cmdOrder[g][s]:show()
            if ship.order then
                local oi = Co.table_childByKeyVal(ordersInfo, "order", ship.order)
                if oi and not oi.nonshiporder then
                    for j, otxt in pairs(shipordermapping) do
                        if otxt == oi.text then
                            c_ord.ships.cmdOrder[g][s]:setSelectedIndexNoCallback(j)
                            break
                        end
                    end
                end
            end
        end
    end

    -- make rest of ship related widgets visible
    c_ord.ships.frame[g][s]:show() 

end


function FleetControlUi.refreshPageInfo()

    local lb = ((currentPage * ordergroupslimit) - ordergroupslimit + 1)
    local ub = (currentPage * ordergroupslimit) 
    c_ord.lblPageInfo.caption = string.format("#%i - #%i", lb, ub)

end


function FleetControlUi.refreshGroupsInfo()

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


function FleetControlUi.refreshGroupsUIShips()

    -- fill group lists with assigned ships
    for i = 1, 4 do
        c_grp.groups.lstShips[i]:clear()
        for _, shipidx in pairs(shipgroups[i]) do           
            local shipname = Co.table_childByKeyVal(knownships, "index", shipidx).name
            c_grp.groups.lstShips[i]:addEntry(shipname)
        end
    end

    -- fill pool list with rest
    c_grp.lstPool:clear()
    for _, ship in pairs(knownships) do 
        local assigned = false
        for i, shipgrp in pairs(shipgroups) do 
            if Co.table_contains(shipgrp, ship.index) then
                assigned = true
                break
            end      
        end
        if not assigned then
            c_grp.lstPool:addEntry(ship.name)
        end
    end
    
end


function FleetControlUi.refreshGroupsUIButtons(force)

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


function FleetControlUi.refreshConfigUICategory()

    -- show selected options category widgets
    if c_conf.lstCategories.selected ~= configCatsLastIndex then  
        configCatsLastIndex = c_conf.lstCategories.selected
        if configCatsLastIndex == 0 then
            c_conf.cntCatHUD:hide()
            c_conf.cntCatUIGeneral:hide()
            c_conf.cntCatUIColors:hide()
            c_conf.cntCatGroups:show()
        elseif configCatsLastIndex == 1 then
            c_conf.cntCatGroups:hide()
            c_conf.cntCatUIGeneral:hide()
            c_conf.cntCatUIColors:hide()
            c_conf.cntCatHUD:show()
        elseif configCatsLastIndex == 2 then
            c_conf.cntCatGroups:hide()
            c_conf.cntCatHUD:hide()
            c_conf.cntCatUIGeneral:show()
            c_conf.cntCatUIColors:hide()       
        elseif configCatsLastIndex == 3 then
            c_conf.cntCatGroups:hide()
            c_conf.cntCatHUD:hide()
            c_conf.cntCatUIGeneral:hide()
            c_conf.cntCatUIColors:show()
        end        
    end

end


function FleetControlUi.refreshConfigUIGroups()

    eventsactive = false

    for g = 1, 4 do 
        c_conf.groups.lblName[g].caption = groupconfig[g].name
        c_conf.groups.chkShowHud[g].checked = groupconfig[g].showhud or false
        local hudcolor = groupconfig[g].hudcolor
        c_conf.groups.picHudColorPrev[g].color = ColorARGB(hudcolor.a, hudcolor.r, hudcolor.g, hudcolor.b)
    end

    eventsactive = true

end


function FleetControlUi.refreshConfigUIHud()

    eventsactive = false

    c_conf.hud.chkShowHud.checked = hudconfig.showhud
    c_conf.hud.btnPosHud.active = hudconfig.showhud

    if not sconfig.enablehud then
        c_conf.hud.chkShowHud:hide()
        c_conf.hud.btnPosHud:hide()
        c_conf.hud.lblHudNotice:show()
    else
        c_conf.hud.lblHudNotice:hide()
        c_conf.hud.chkShowHud:show()
        c_conf.hud.btnPosHud:show()
    end

    c_conf.hud.cmbHudStyle:setSelectedIndexNoCallback(hudconfig.hudstyle)

    c_conf.hud.chkShowGrpNames.checked = hudconfig.showgroupnames
    c_conf.hud.chkShowShpStates.checked = hudconfig.showshipstates
    c_conf.hud.chkShowShpOrders.checked = hudconfig.showshiporders
    c_conf.hud.chkShowShpLocs.checked = hudconfig.showshiplocations
    c_conf.hud.chkHideUncaptained.checked = hudconfig.hideuncaptained
    c_conf.hud.chkUseUiStateClrs.checked = hudconfig.useuistatecolors

    eventsactive = true

end


function FleetControlUi.refreshConfigUIGeneral()

    eventsactive = false

    c_conf.uigeneral.chkSelectOrdersTab.checked = uiconfig.preselectorderstab
    c_conf.uigeneral.chkSelectOrdersFirstPage.checked = uiconfig.preselectordersfirstpage
    c_conf.uigeneral.chkCloseWindowOnLookAt.checked = uiconfig.closewindowonlookat
    c_conf.uigeneral.chkEnableOrderSounds.checked = uiconfig.enableordersounds
    c_conf.uigeneral.lblOrderSoundFile.caption = uiconfig.ordersoundfile or ""

    eventsactive = true

end


function FleetControlUi.refreshConfigUIColors()

    eventsactive = false

    for i, state in pairs(aiStates) do
        local sc = uiconfig.statecolors[state]
        if sc then
            c_conf.uicolors.picStateColorPrev[i].color = ColorRGB(sc.r, sc.g, sc.b)
        else
            c_conf.uicolors.picStateColorPrev[i].color = ColorRGB(1, 1, 1)
        end
    end

    eventsactive = true

end


function FleetControlUi.updateUI()

    -- refresh widgets in window tabs
    if selectedtabidx == tabs.groups.index then
        Me.refreshGroupsUIButtons()
    elseif selectedtabidx == tabs.config.index then
        Me.refreshConfigUICategory()
    end

    -- refresh widgets in dialog windows
    if shipseldialog.visible then
        Me.refreshShipSelectionDialog()
    end

end


function FleetControlUi.updateClient(timeStep)

    if doupdatestates and sconfig then
        
        -- TODO: Replace with getUpdateInterval()
        laststateupdate = laststateupdate + (timeStep * 1000)

        -- only do update if configured delay has passed
        if sconfig.updatedelay and laststateupdate >= sconfig.updatedelay then

            shipgroups = pconfig.shipgroups
            knownships = pconfig.knownships

            -- get all exisiting ships of player in current sector
            local sectorships = Co.getPlayerCrafts()

            local cx, cy = Sector():getCoordinates()
            local coords = {x=cx, y=cy}          
            
            local knownshipsupdate = false
            for _, s in pairs(sectorships) do 

                local ship, idx = Co.table_childByKeyVal(knownships, "index", s.index.string)
                if not ship then
                    Co.debugLog("updateClient() -> new known ship '%s' (%s)", s.name, s.index)
                    -- add new ships to known ones
                    table.insert(knownships, {index=s.index.string,name=s.name,location=coords})
                    knownshipsupdate = true
                else                   
                    -- update location info
                    if ship.location.x ~= coords.x or ship.location.y ~= coords.y then
                        Co.debugLog("updateClient() -> update location info of ship '%s' (%s)", ship.name, ship.index)
                        knownships[idx].location = coords
                        knownshipsupdate = true
                    end
                end
            end
            if knownshipsupdate then
                Co.debugLog("updateClient() -> updating player knownships")
                Co.sortShipsArray(knownships)
                pconfig.knownships = knownships
            end

            -- update ship states and refresh ships UI widgets
            -- create flat array of ship names to update
            local updateindices = {}
            for _, grp in pairs(shipgroups) do
                for _, sidx in pairs(grp) do
                    table.insert(updateindices, sidx)
                end
            end
        
            Me.updateShipStates(updateindices, sectorships)

            laststateupdate = 0
            ordersbusy = false
        end     
    end

end


function FleetControlUi.onPreRenderHud()

    -- draw HUD elements if enabled
    if shipinfos and sconfig and sconfig.enablehud and hudconfig and hudconfig.showhud then
    
        local coords = vec2(Sector():getCoordinates())

        local fontsize_group = 15
        local fontsize_ship = 12
        local offsetX = hudconfig.hudanchor.x
        local offsetY = hudconfig.hudanchor.y

        -- use alternate HUD position for display (used when re-positioning HUD via dialog)
        if hudanchoroverride then
            offsetX = hudanchoroverride.x
            offsetY = hudanchoroverride.y
        end

        for g, group in pairs(shipgroups) do 
            local gconf = groupconfig[g]
            if gconf.showhud and #shipinfos[g] > 0 then
                local gcolor = ColorARGB(gconf.hudcolor.a, gconf.hudcolor.r, gconf.hudcolor.g, gconf.hudcolor.b)

                if hudconfig.showgroupnames then
                    drawText(gconf.name, offsetX, offsetY, gcolor, fontsize_group, false, false, 1) 
                    offsetY = offsetY + 20
                end
    
                for s, ship in pairs(shipinfos[g]) do
                    
                    if not hudconfig.hideuncaptained or (not ship.isplayer and ship.hascaptain) then
                        local offshipX = offsetX

                        local name
                        if hudconfig.hudstyle == 0 then
                            name = ship.name
                        elseif hudconfig.hudstyle == 1 then                      
                            name = Co.shortenText(ship.name, 15) -- shorten text to max size for horizontal style
                        else
                            name = Co.shortenText(ship.name, 25) -- shorten text to max size for horiz.wide style
                        end
                        drawText(name, offshipX + 5, offsetY, gcolor, fontsize_ship, false, false, 1) 

                        if hudconfig.hudstyle == 0 then
                            offsetY = offsetY + 18
                            offshipX = offshipX + 30
                        elseif hudconfig.hudstyle == 1 then
                            offshipX = offshipX + 170
                        else
                            offshipX = offshipX + 270
                        end 
                
                        if hudconfig.showshipstates then
                            local statetxt = "-"
                            local stateclr = gcolor
                            if not ship.elsewhere and ship.state then
                                statetxt = ship.state
                                if hudconfig.useuistatecolors then
                                    local sc = uiconfig.statecolors[ship.state]
                                    if sc then
                                        stateclr = ColorARGB(gconf.hudcolor.a, sc.r, sc.g, sc.b)
                                    end
                                end
                            end                         
                            drawText(statetxt, offshipX, offsetY, stateclr, fontsize_ship, false, false, 0)    
                            offshipX = offshipX + 90                  
                        end

                        if hudconfig.showshiporders then
                            local ordertxt = "-"
                            if ship.isplayer then
                                ordertxt = "Player"
                            elseif not ship.hascaptain then
                                ordertxt = "No Captain"
                            elseif not ship.elsewhere and ship.order then
                                local oi, i = Co.table_childByKeyVal(ordersInfo, "order", ship.order)
                                if oi then
                                    ordertxt = oi.text
                                end
                            end                          
                            drawText(ordertxt, offshipX, offsetY, gcolor, fontsize_ship, false, false, 0)
                            offshipX = offshipX + 120
                        end

                        if hudconfig.showshiplocations then
                            local loctxt = "-"
                            if ship.location then
                                local loc = vec2(ship.location.x, ship.location.y)
                                if  loc.x == coords.x and loc.y == coords.y then
                                    loctxt = "(current)"
                                else
                                    loctxt = tostring(loc)
                                end
                            end
                            drawText(loctxt, offshipX, offsetY, gcolor, fontsize_ship, false, false, 0)
                        end

                        if hudconfig.hudstyle == 0 then
                            offsetY = offsetY + 23
                        else
                            offsetY = offsetY + 18
                        end 
                    end
                end

                offsetY = offsetY + 5
            end
        end

    end

end


function FleetControlUi.syncShipInfos(statedata)

    -- merge states and known infos like location
    local newstates = {}
    for gi, gships in pairs(shipgroups) do
        newstates[gi] = {}
        for _, shipidx in pairs(gships) do
            local info 
            local data = Co.table_childByKeyVal(statedata, "index", shipidx)
            local known = Co.table_childByKeyVal(knownships, "index", shipidx)
            if data then
                info = data
                if known then
                    info.location = known.location
                end
            else
                -- ship elsewhere -> reuse known info and mark it             
                if known then
                    --debugLog("syncShipInfos() -> ship '%s' not in player sector, restoring known info", shipname)
                    info = {
                        index = shipidx,
                        name = known.name,
                        location = known.location,
                        elsewhere = true
                    }
                else
                    Co.debugLog("syncShipInfos() -> no known info for '%s'!", shipname)
                end
            end
            table.insert(newstates[gi], info)
        end
    end

    shipinfos = newstates

    -- update infos in UI
    if uivisible then
        Me.refreshOrdersUI()
    end

end


---- SERVER-SIDE ----

function FleetControlUi.updateShipStates(updateindices, ships)

    if onClient() then
        invokeServerFunction("updateShipStates", updateindices, ships)
        return
    end

    local statedata = {}
    local pshipIndex = Player(callingPlayer).craftIndex

    -- compare existing ships in sector and get their states 
    for _, ship in pairs(ships) do 
        if Co.table_contains(updateindices, ship.index.string) then
            local entity = Entity(ship.index)
            if entity and entity.isShip then
                -- TODO: check also if ship is controlled by another player
                local state, order = Co.getShipAIOrderState(entity, pshipIndex) 
                table.insert(statedata, {
                    name = entity.name,
                    index = entity.index.string,
                    state = state,
                    order = order,
                    hascaptain = Co.checkShipCaptain(entity),
                    -- TODO: also check if other player controls ship
                    isplayer = (entity.index == pshipIndex)
                })
            end
        end
    end    

    -- set server-side data and return to client
    invokeClientFunction(Player(callingPlayer), "syncShipInfos", statedata)

end


function FleetControlUi.invokeOrdersScript(shipindices, orderinfo, paramoverride)

    -- make this function run server-side only
    if onClient() then
        invokeServerFunction("invokeOrdersScript", shipindices, orderinfo, paramoverride)
        return
    end

    for _, idx in pairs(shipindices) do

        local ship
        if orderinfo.invokecurrent then
            -- use player ship as invokation target
            ship = Entity(Player(callingPlayer).craftIndex)
        else   
            ship = Entity(idx)
        end

        if ship and ship.isShip then
            Co.ensureEntityScript(ship, Co.fc_script_craftorders);
            ship:invokeFunction(orderinfo.script, "setCurrentPlayerIndex", callingPlayer)

            Co.debugLog("invokeOrdersScript() --> ship: %s (%s) | order: %s | script: %s | func: %s | param: %s | paramoverride: %s", ship.name, ship.index, orderinfo.order, orderinfo.script, orderinfo.func, orderinfo.param, paramoverride)

            if paramoverride then
                ship:invokeFunction(orderinfo.script, orderinfo.func, paramoverride)
            elseif orderinfo.param then
                if orderinfo.param == "playercraftindex" then
                    ship:invokeFunction(orderinfo.script, orderinfo.func, Player(callingPlayer).craftIndex) 
                elseif orderinfo.param == "selectedcraftindex" then
                    ship:invokeFunction(orderinfo.script, orderinfo.func, idx)
                else
                    Co.debugLog("invokeOrdersScript() --> unknown order function parameter!", idx)
                end
            else
                ship:invokeFunction(orderinfo.script, orderinfo.func) 
            end
        else
            Co.debugLog("invokeOrdersScript() --> no ship/entity with index %s found!", idx)
        end

    end

end

---- UTILITY FUNCTIONS ----

function FleetControlUi.orderGroupsIter()
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
