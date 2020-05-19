local GUI = require("GUI")
local system = require("System")
local component = require("Component")
local filesystem = require("Filesystem")
local internet = require("Internet")
local lzss = require("LZSS")
local eeprom = component.eeprom

--------------------------------------------------------------------------------

local workspace = system.getWorkspace()
local currentScript = system.getCurrentScript()
local localization = system.getLocalization(filesystem.path(currentScript) .. "Localizations/")
local userSettings = system.getUserSettings()
local container = GUI.addBackgroundContainer(workspace, true, true, "Cyan BIOS")
local password, requestPasswordAtBoot, readOnly = false, false, false

--------------------------------------------------------------------------------

local readOnlySwitch = container.layout:addChild(GUI.switchAndLabel(1, 1, 11 + unicode.len(localization.readOnly), 8, 0x8400FF, 0x1D1D1D, 0xFFFFFF, 0x878787, localization.readOnly, false))
local passwordSwitch = container.layout:addChild(GUI.switchAndLabel(1, 4, 11 + unicode.len(localization.password), 8, 0xFFA800, 0x1D1D1D, 0xFFFFFF, 0x878787, localization.password, false))
local passwordInput = container.layout:addChild(GUI.input(1, 1, 30, 3, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", localization.password, nil, "•"))
local passwordAtBootSwitch = container.layout:addChild(GUI.switchAndLabel(1, 4, 11 + unicode.len(localization.requestPasswordAtBoot), 8, 0x00fd01, 0x1D1D1D, 0xFFFFFF, 0x878787, localization.requestPasswordAtBoot, false))
local flashButton = container.layout:addChild(GUI.roundedButton(1, 1, 17, 1, 0xFFFFFF, 0x000000, 0x878787, 0xFFFFFF, localization.flash))

passwordInput.validator = function(text)
    if unicode.len(text) <= 12 then
        return true
    else
        GUI.alert(localization.maximumPasswordLen)
    end
end

passwordInput.hidden = true
passwordAtBootSwitch.hidden = true

passwordSwitch.switch.onStateChanged = function()
    passwordInput.hidden = not passwordInput.hidden
    passwordAtBootSwitch.hidden = not passwordAtBootSwitch.hidden

    if not passwordSwitch.switch.state then
        password = false
        requestPasswordAtBoot = false
    end
    workspace:draw()
end

passwordAtBootSwitch.switch.onStateChanged = function()
    requestPasswordAtBoot = not requestPasswordAtBoot
end

passwordInput.onInputFinished = function()
    password = passwordInput.text
end

readOnlySwitch.switch.onStateChanged = function()
    readOnly = not readOnly
end

flashButton.onTouch = function()
    passwordSwitch:remove()
    passwordInput:remove()
    passwordAtBootSwitch:remove()
    readOnlySwitch:remove()
    flashButton:remove()
    local statusText

    local function status(text)
        if statusText then
            statusText:remove()
        end

        statusText = container.layout:addChild(GUI.text(1, 1, 0x878787, text))
        workspace:draw()
    end

    local data, reason = internet.request("https://raw.githubusercontent.com/BrightYC/Cyan/master/Minified.lua")

    if not data then
        GUI.alert(reason)
    end

    status(localization.compressing)
    local compressed = lzss.getSXF(lzss.compress(
        data:gsub(
            "%%(%w+)%%",
            {
                pass = password or "",
                passOnBoot = requestPasswordAtBoot and "1" or "F"}
            )
        ),
        true
    )

    package.loaded.lzss = nil

    if load(compressed) then
        status(localization.flashing)
        eeprom.set(compressed)
        eeprom.setLabel("Cyan BIOS")
        if readOnly then
            status(localization.makingReadOnly)
            eeprom.makeReadonly(eeprom.getChecksum())
        end

        status(localization.done)
        container.layout:addChild(GUI.roundedButton(1, 1, 18, 1, 0xFFFFFF, 0x000000, 0x878787, 0xFFFFFF, localization.reboot)).onTouch = function() computer.shutdown(true) end
    else
        GUI.alert(localization.malformedSrc)
        container:remove()
        workspace:stop()
    end
end

if computer.getArchitecture() == "Lua 5.2" then
    table.insert(userSettings.tasks, {
        path = currentScript,
        enabled = true,
        mode = 1
    })

    system.saveUserSettings()
    computer.setArchitecture("Lua 5.3")
end

for i = 1, #userSettings.tasks do
    if userSettings.tasks[i].path == currentScript then
        table.remove(userSettings.tasks, i)
        break
    end
end

workspace:start(0)