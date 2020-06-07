local GUI = require("GUI")
local system = require("System")
local component = require("Component")
local filesystem = require("Filesystem")
local internet = require("Internet")
local text = require("Text")
local eeprom = component.eeprom
local freespace = eeprom.getDataSize() - 38

--------------------------------------------------------------------------------

local workspace = system.getWorkspace()
local localization = system.getLocalization(filesystem.path(system.getCurrentScript()) .. "Localizations/")
local container = GUI.addBackgroundContainer(workspace, true, true, "Cyan BIOS")
local users, requireUserPressOnBoot, readOnly = {}, false, false

--------------------------------------------------------------------------------

local readOnlySwitch = container.layout:addChild(GUI.switchAndLabel(1, 1, 11 + unicode.len(localization.readOnly), 8, 0x8400FF, 0x1D1D1D, 0xFFFFFF, 0x878787, localization.readOnly, false))
local whiteListSwitch = container.layout:addChild(GUI.switchAndLabel(1, 4, 11 + unicode.len(localization.whitelist), 8, 0xFFA800, 0x1D1D1D, 0xFFFFFF, 0x878787, localization.whitelist, false))
local whitelistComboBox = container.layout:addChild(GUI.comboBox(3, 2, 30, 3, 0xEEEEEE, 0x2D2D2D, 0xCCCCCC, 0x888888))
local deleteUserButton = container.layout:addChild(GUI.roundedButton(1, 1, unicode.len(localization.deleteUser) + 8, 1, 0xFFFFFF, 0x000000, 0x878787, 0xFFFFFF, localization.deleteUser))
local userInput = container.layout:addChild(GUI.input(1, 1, 30, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", localization.username))
local requireUserPressOnBootSwitch = container.layout:addChild(GUI.switchAndLabel(1, 4, 11 + unicode.len(localization.requireUserPressOnBoot), 8, 0x00fd01, 0x1D1D1D, 0xFFFFFF, 0x878787, localization.requireUserPressOnBoot, false))
local flashButton = container.layout:addChild(GUI.roundedButton(1, 1, unicode.len(localization.flash) + 8, 1, 0xFFFFFF, 0x000000, 0x878787, 0xFFFFFF, localization.flash))

userInput.validator = function(username)
    if #text.serialize(users) + #username + 3 <= freespace then
        return true
    else
        GUI.alert(localization.freeSpaceLimit)
    end
end

userInput.onInputFinished = function()
    if #userInput.text > 0 then
        table.insert(users, userInput.text)
        whitelistComboBox:addItem(userInput.text)
        whitelistComboBox.hidden = false
        deleteUserButton.hidden = false
        userInput.text = ""
        workspace:draw()
    end
end

whiteListSwitch.switch.onStateChanged = function()
    requireUserPressOnBootSwitch.hidden = not requireUserPressOnBootSwitch.hidden
    requireUserPressOnBoot = false
    userInput.hidden = not userInput.hidden
    whitelistComboBox.hidden = true
    whitelistComboBox:clear()
    users = {}
    workspace:draw()
end

deleteUserButton.onTouch = function()
    local username = whitelistComboBox:getItem(whitelistComboBox.selectedItem).text
    for i = 1, #users do
        if users[i] == username then
            table.remove(users, i)
        end
    end
    whitelistComboBox:removeItem(whitelistComboBox.selectedItem)
    if whitelistComboBox:count() == 0 then
        whitelistComboBox:clear()
        deleteUserButton.hidden = true
        whitelistComboBox.hidden = true
    end
    workspace:draw()
end

whitelistComboBox.hidden = true
requireUserPressOnBootSwitch.hidden = true
userInput.hidden = true
deleteUserButton.hidden = true

requireUserPressOnBootSwitch.switch.onStateChanged = function()
    requireUserPressOnBoot = not requireUserPressOnBoot
end

readOnlySwitch.switch.onStateChanged = function()
    readOnly = not readOnly
end

flashButton.onTouch = function()
    whitelistComboBox:remove()
    whiteListSwitch:remove()
    requireUserPressOnBootSwitch:remove()
    userInput:remove()
    readOnlySwitch:remove()
    flashButton:remove()
    deleteUserButton:remove()
    local statusText

    local function status(text)
        if statusText then
            statusText:remove()
        end
        statusText = container.layout:addChild(GUI.text(1, 1, 0x878787, text))
        workspace:draw()
    end

    local data, reason, usersSerialized = internet.request("https://github.com/BrightYC/Cyan/raw/master/cyan.comp"), nil, "#{"

    if not data then
        error(reason)
    end
    if #users > 0 then
        for i = 1, #users do
            usersSerialized = usersSerialized .. ('%s%s%s'):format('"', users[i], ('"%s'):format(i == #users and "" or ","))
        end
        usersSerialized = usersSerialized .. "}#" .. (requireUserPressOnBoot and "*" or "")
    end
    if not data then
        error(reason)
    end

    status(localization.flashing)
    eeprom.set(data)
    eeprom.setData((eeprom.getData():match("[a-f-0-9]+") or eeprom.getData()) .. (#users > 0 and usersSerialized or ""), true)
    eeprom.setLabel("Cyan BIOS")
    if readOnly then
        status(localization.makingReadOnly)
        eeprom.makeReadonly(eeprom.getChecksum())
    end
    status(localization.done)
    container.layout:addChild(GUI.roundedButton(1, 1, unicode.len(localization.reboot) + 8, 1, 0xFFFFFF, 0x000000, 0x878787, 0xFFFFFF, localization.reboot)).onTouch = function() computer.shutdown(true) end
end

workspace:start(0)