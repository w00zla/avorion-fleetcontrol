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


-- client / UI vars

local mywindow
local tabs = {
    window = nil,
    orders = nil,
    groups = nil
}
local c_ord = {
	btnPrevPage = nil,
    btnNextPage = nil,
    {
        lblName = nil,
        lblState = nil,
        cmdOrder = nil,
        ships = {
            frame = {},
            lblName = {},
            lblState = {},
            lblLoc = {},
            btnLook = {},
            cmdOrder = {}
        }
    },
    {
        lblName = nil,
        lblState = nil,
        cmdOrder = nil,
        ships = {
            frame = {},
            lblName = {},
            lblState = {},
            lblLoc = {},
            btnLook = {},
            cmdOrder = {}
        }
    }
}
local c_grp = {
    lstPool = nil,
    groups = {
        lblName = {},
        chkHud = {},
        btnRename = {},
        lstShips = {},
        btnAssign = {},
        btnUnassign = {}
    }
}

local ordersInfo = {
    { order="idle", text="Idle"},
    { order="passive", text="Passive"},
    { order="guard", text="Guard Position"},
    { order="patrol", text="Patrol Sector"},
    { order="escort", text="Escort Me"},
    { order="attack", text="Attack Enemies"},
    { order="mine", text="Mine"},
    { order="salvage", text="Salvage"}
}

local shipgroups = {
    {
        name="Group 1",
        state="Passive",
        ships = {
            {
                index=123,
                name="Ship1",
                state="Passive",
                order="longtestorder",
                loc="current"
            },
            {
                index=321,
                name="Ship2",
                state="Passive",
                order="longtestorder",
                loc="(234:345)"
            },
            {
                index=321,
                name="Ship3",
                state="Passive",
                order="longtestorder",
                loc="(234:345)"
            },
            {
                index=321,
                name="Ship4",
                state="Passive",
                order="longtestorder",
                loc="(234:345)"
            },
            {
                index=321,
                name="Ship5",
                state="Passive",
                order="longtestorder",
                loc="(234:345)"
            },
            {
                index=321,
                name="Ship6",
                state="Passive",
                order="longtestorder",
                loc="(234:345)"
            },
            {
                index=321,
                name="Ship7",
                state="Passive",
                order="longtestorder",
                loc="(234:345)"
            },
            {
                index=321,
                name="Ship8",
                state="Passive",
                order="longtestorder",
                loc="(234:345)"
            },
            {
                index=321,
                name="Ship9",
                state="Passive",
                order="longtestorder",
                loc="(234:345)"
            },
            {
                index=321,
                name="Ship10",
                state="Passive",
                order="longtestorder",
                loc="(234:345)"
            },
            {
                index=321,
                name="Ship11",
                state="Passive",
                order="longtestorder",
                loc="(234:345)"
            },
            {
                index=321,
                name="Ship12",
                state="Passive",
                order="longtestorder",
                loc="(234:345)"
            }
        }
    },
    {
        name="Group 2",
        state="-",
        ships = {}
    },
    {
        name="Group 3",
        state="-",
        ships = {}
    },
    {
        name="Group 4",
        state="-",
        ships = {}
    }    
}


function getIcon(seed, rarity)
    return "data/textures/icons/caged-ball.png"
end


function interactionPossible(player)
    return true, ""
end


function onShowWindow()
	
    tabs.window:selectTab(tabs.orders)
    c_ord.btnPrevPage.active = false
    c_ord.btnNextPage.active = false

end


function onCloseWindow()

end


function initUI()

    local size = vec2(1000, 650)
    local res = getResolution()

	-- create window
    local menu = ScriptUI()
    mywindow = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(mywindow, "Fleet Control")

    mywindow.caption = "Fleet Control"
    mywindow.showCloseButton = 1
    mywindow.moveable = 1
	
    tabs.window = mywindow:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    tabs.orders = tabs.window:createTab("Orders", "data/textures/icons/ship.png", "Fleet Orders")
    buildOrdersUI(tabs.orders)

    tabs.groups = tabs.window:createTab("Groups", "data/textures/icons/spanner.png", "Fleet Groups")
    buildGroupsUI(tabs.groups)

	scriptLog(nil, "fleet control UI initialized successfully")
	
end


function buildOrdersUI(parent)

    local size = parent.size

    -- footer
    c_ord.btnPrevPage = parent:createButton(Rect(10, size.y - 40, 60, size.y - 10), "<", "onPrevPagePressed")	
    c_ord.btnNextPage = parent:createButton(Rect(size.x - 60, size.y - 40, size.x - 10, size.y - 10), ">", "onNextPagePressed")	

    local groupStateX = -120
    local nameLabelX = 10
    local stateLabelX = -150
	local locLabelX = -50

    local x_grp = 0
    for g = 1, 2 do  

        local split_grp = UIVerticalSplitter(Rect(x_grp + 10, 0, x_grp + 485, 35), 10, 0, 0.5)
        split_grp.rightSize = 120

        local xl = split_grp.left.lower.x
		local xu = split_grp.left.upper.x

        -- group labels
        local groupname = parent:createLabel(vec2(xl, 10), "<groupname>", 16)
        local groupstate = parent:createLabel(vec2(xu + groupStateX, 12), "<groupstate>", 14)
 
        -- group controls
        local cbox = parent:createComboBox(split_grp.right, "onGroupOrderSelected")
        for _, btninfo in pairs(ordersInfo) do
            cbox:addEntry(btninfo.text)
        end    
        
        groupname:hide()
        groupstate:hide()
        cbox:hide()

        c_ord[g].lblName = groupname
        c_ord[g].lblState = groupstate
        c_ord[g].cmdOrder = cbox
       
        -- create ship list controls 
        local y_shp = 40
        for s = 1, 14 do 

            local yText = y_shp + 6
            
            local split1 = UIVerticalSplitter(Rect(x_grp + 10, y_shp, x_grp + 485, y_shp +  30), 10, 0, 0.5)
            split1.rightSize = 140

            local frame = parent:createFrame(split1.left)
            
            -- ship labels

            local xl = split1.left.lower.x
            local xu = split1.left.upper.x         
            
            local nameLabel = parent:createLabel(vec2(xl + nameLabelX, yText), "", 15)
            local stateLabel = parent:createLabel(vec2(xu + stateLabelX, yText), "", 15)
            local locLabel = parent:createLabel(vec2(xu + locLabelX, yText), "", 15)
            
            nameLabel.font = "Arial"
            stateLabel.font = "Arial"
            locLabel.font = "Arial"
            
            -- ship controls

            local split2 = UIVerticalSplitter(split1.right, 10, 0, 0.5)
            split2.leftSize = 30

            local lookat = parent:createButton(split2.left, "", "onLookAtPressed")
		    lookat.icon = "data/textures/icons/look-at.png"

            local cbox = parent:createComboBox(split2.right, "onShipOrderSelected")
            for _, btninfo in pairs(ordersInfo) do
                cbox:addEntry(btninfo.text)
            end

            -- hide controls initially and add to reference table
            frame:hide()
            nameLabel:hide()
            stateLabel:hide()
            locLabel:hide()
            lookat:hide()
            cbox:hide()

            table.insert(c_ord[g].ships.frame, frame)
            table.insert(c_ord[g].ships.lblName, nameLabel)
            table.insert(c_ord[g].ships.lblState, stateLabel)
            table.insert(c_ord[g].ships.lblLoc, locLabel)
            table.insert(c_ord[g].ships.btnLook, lookat)
            table.insert(c_ord[g].ships.cmdOrder, cbox)
                
            y_shp = y_shp + 35	   
        end

        x_grp = x_grp + 490
    end

end


function buildGroupsUI(parent)

    local size = parent.size

    local split1 = UIVerticalSplitter(Rect(10, 10, size.x - 10, size.y - 10), 30, 0, 0.5)
    split1.rightSize = 680

    -- ships pool list

    local split_sp = UIHorizontalSplitter(split1.left, 10, 0, 0.5)
    split_sp.topSize = 20

    parent:createLabel(vec2(split_sp.top.lower.x, split_sp.top.lower.y + 6), "Unassigend ships with captains:", 12)
    local listBox = parent:createListBox(split_sp.bottom)

    parent:createLine(vec2(split1.left.upper.x + 15, split1.left.lower.y), vec2(split1.left.upper.x + 15, split1.left.upper.y))

    -- ship groups sections

    local x, y = split1.right.lower.x, split1.right.lower.y
    local r_size = split1.right.size

    -- quarter splitters
    parent:createLine(vec2(x + (r_size.x / 2), y), vec2(x + (r_size.x / 2), split1.right.upper.y))
    parent:createLine(vec2(x, y + (r_size.y / 2)), vec2(split1.right.upper.x, y + (r_size.y / 2)))

    for j = 1, 4 do

        local r_quarter     
        if j == 1 then
        	r_quarter = Rect(x, y, x + (r_size.x / 2) - 15, y + (r_size.y / 2) - 15)
        elseif j == 2 then
            r_quarter = Rect(x + (r_size.x / 2) + 15, y, x + r_size.x, y + (r_size.y / 2) - 15)
        elseif j == 3 then
            r_quarter = Rect(x, y + (r_size.y / 2) + 15, x + (r_size.x / 2) - 15, y + r_size.y)
        elseif j == 4 then
            r_quarter = Rect(x + (r_size.x / 2) + 15, y + (r_size.y / 2) + 15, x + r_size.x, y + r_size.y)
        end

        local split_grp1 = UIHorizontalSplitter(r_quarter, 10, 0, 0.5)
        split_grp1.topSize = 30

        local split_grp2 = UIVerticalSplitter(split_grp1.top, 10, 0, 0.5)
        split_grp2.rightSize = 125

        -- group labels

        parent:createLabel(vec2(split_grp2.left.lower.x, split_grp2.left.lower.y + 6), string.format("Group %i", j), 16)

        local split_grp3 = UIVerticalSplitter(split_grp2.right, 10, 0, 0.4)

        -- group controls

        local showhud = parent:createCheckBox(Rect(vec2(split_grp3.left.lower.x, split_grp3.left.lower.y + 5), split_grp3.left.upper), "HUD", "onGroupHudChecked")
        local rengroup = parent:createButton(split_grp3.right, "Rename", "onRenameGroupPressed")
        
        local split_grp4 = UIVerticalSplitter(split_grp1.bottom, 10, 0, 0.5)
        split_grp4.rightSize = 30

        -- group ship list
        local list_grp = parent:createListBox(split_grp4.left)

        local x, y = split_grp4.right.lower.x, split_grp4.right.lower.y
        local r_size = split_grp4.right.size

        local shipassign   = parent:createButton(Rect(x, y + (r_size.y / 2) - 35, x + 30, y + (r_size.y / 2) - 5), "+", "onAssignShipGroupPressed")   
        local shipunassign = parent:createButton(Rect(x, y + (r_size.y / 2) + 5, x + 30, y + (r_size.y / 2) + 35), "-", "onUnassignShipGroupPressed")     

        shipassign.textSize = 18  
        shipunassign.textSize = 18  
        
    end  

end


function onLookAtPressed(sender)

end



function onGroupOrderPressed(sender)


end


function onGroupOrderSelected(sender)


end


function onShipOrderSelected(sender)


end


function onPrevPagePressed()

	
end


function onNextPagePressed()


end


function onLookAtPressed(sender)


end


function onAssignShipGroupPressed(sender)


end


function onUnassignShipGroupPressed(sender)


end


function onRenameGroupPressed(sender)


end


function onGroupHudChecked(sender)

end


function onGroupNameChanged(sender)


end


function updateClient(timeStep)

    -- local res = getResolution()
    -- drawText("Fleet Group 1:", res.x - 325, 200, ColorRGB(1, 1, 1), 16, 0, 0, 0) 
    -- drawText("Aggressive", res.x - 175, 200, ColorRGB(1, 0, 0), 16, 0, 0, 0) 
    -- drawText("Fleet Group 2:", res.x - 325, 225, ColorRGB(1, 1, 1), 16, 0, 0, 0) 
    -- drawText("Passive", res.x - 175, 225, ColorRGB(0, 0, 1), 16, 0, 0, 0) 

end



function onSectorChanged()

end