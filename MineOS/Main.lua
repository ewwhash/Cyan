local GUI = require("GUI")
local system = require("System")
local component = require("Component")
local filesystem = require("Filesystem")
local eeprom = component.eeprom

if not component.isAvailable("internet") then
    GUI.alert("Please insert an internet card")
    return
end

--------------------------------------------------------------------------------

local workspace = system.getWorkspace()
local localization = system.getLocalization(filesystem.path(system.getCurrentScript()) .. "Localizations/")

-- Add a new window to MineOS workspace
local workspace, window, menu = system.addWindow(GUI.filledWindow(1, 1, 60, 20, 0xE1E1E1))

-- Add single cell layout to window
local layout = window:addChild(GUI.layout(1, 1, window.width, window.height, 1, 1))

-- Add nice gray text object to layout
layout:addChild(GUI.text(1, 1, 0x4B4B4B, "Hello, " .. system.getUser()))

-- Customize MineOS menu for this application by your will
local contextMenu = menu:addContextMenuItem("File")
contextMenu:addItem("New")
contextMenu:addSeparator()
contextMenu:addItem("Open")
contextMenu:addItem("Save", true)
contextMenu:addItem("Save as")
contextMenu:addSeparator()
contextMenu:addItem("Close").onTouch = function()
	window:remove()
end

-- You can also add items without context menu
menu:addItem("Example item").onTouch = function()
	GUI.alert("It works!")
end

-- Create callback function with resizing rules when window changes its' size
window.onResize = function(newWidth, newHeight)
  window.backgroundPanel.width, window.backgroundPanel.height = newWidth, newHeight
  layout.width, layout.height = newWidth, newHeight
end

---------------------------------------------------------------------------------

-- Draw changes on screen after customizing your window
workspace:draw()