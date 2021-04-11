local GUI = require("GUI")
local internet = require("Internet")
local system = require("System")
local filesystem = require("Filesystem")
local workspace = system.getWorkspace()
local eeprom = component.eeprom

local localizations = {
    ["English"] = {
        flash = "Flash",
        reboot = "Reboot",
        downloading = "Downloading...",
        flashing = "Flashing...",
        done = "Done!",
    },
    ["Russian"] = {
        flash = "Прошить",
        reboot = "Перезагрузка",
        downloading = "Загрузка...",
        flashing = "Прошивка...",
        done = "Готово!"
    }
}

local localization = localizations[system.getUserSettings().localizationLanguage] or localizations["English"]

local container = GUI.addBackgroundContainer(workspace, true, true, "Cyan BIOS")
local flash = container.layout:addChild(GUI.roundedButton(1, 1, unicode.len(localization.flash) + 8, 1, 0xFFFFFF, 0x000000, 0x878787, 0xFFFFFF, localization.flash)) 

flash.onTouch = function()
    flash:remove()
    local downloading = container.layout:addChild(GUI.text(1, 1, 0x878787, localization.downloading))
    workspace:draw()
    local data, reason = internet.request("https://github.com/BrightYC/Cyan/blob/master/stuff/cyan.bin?raw=true")

    if data then
        downloading:remove()
        local flashing = container.layout:addChild(GUI.text(1, 1, 0x878787, localization.downloading))
        workspace:draw()
        eeprom.set(data)
        eeprom.setLabel("Cyan BIOS")
        flashing:remove()
        container.layout:addChild(GUI.text(1, 1, 0x878787, localization.done))
        container.layout:addChild(GUI.roundedButton(1, 1, unicode.len(localization.reboot) + 8, 1, 0xFFFFFF, 0x000000, 0x878787, 0xFFFFFF, localization.reboot)).onTouch = function()
            computer.shutdown(true)
        end
        workspace:draw()
    else
        GUI.alert(reason)
        container:remove()
    end
end