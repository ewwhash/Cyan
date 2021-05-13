local GUI = require("GUI")
local internet = require("Internet")
local system = require("System")
local eeprom = component.eeprom

local localizations = {
    ["English"] = {
        flash = "Flash",
        reboot = "Reboot",
        downloading = "Downloading...",
        flashing = "Flashing...",
        done = "Done!",
        users = "Users",
        usersNotSpecified = "If no users are specified, anyone can access the bootloader",
        enterPlayerName = "Enter player name",
        maxLengthExited = "The maximum number of users has been exceeded",
        readonly = "EEPROM readonly:",
        userInput = "Wait for input when booting:",
        options = "Options",
        flashFailed = "Flash failed, reason:",
        downloadFailed = "Download failed, reason:"
    },
    ["Russian"] = {
        flash = "Прошить",
        reboot = "Перезагрузка",
        downloading = "Загрузка...",
        flashing = "Прошивка...",
        done = "Готово!",
        users = "Пользователи",
        usersNotSpecified = "Если пользователи не указаны, любой может получить доступ к загрузчику",
        enterPlayerName = "Введите имя игрока",
        maxLengthExited = "Превышено максимальное количество пользователей",
        readonly = "EEPROM только для чтения:",
        userInput = "Ждать нажатия для загрузки:",
        options = "Опции",
        flashFailed = "Прошивка неудачна, причина:",
        downloadFailed = "Не удалось загрузить файл, приина:"
    }
}

local localization = localizations[system.getUserSettings().localizationLanguage] or localizations["English"]

------------------------------------------------------------------------------------------------------------------------------

local workspace, window = system.addWindow(GUI.titledWindow(1, 1, 52, 17, "Cyan BIOS", true))
local container = window:addChild(GUI.container(1, 2, window.width, window.height - 1))
window.actionButtons.maximize.hidden = true

local function centrizeText(width, text)
    return math.ceil(container.width / 2 - unicode.len(text) / 2)
end

container:addChild(GUI.text(centrizeText(container.width, localization.options), 9, 0x2D2D2D, localization.options))
local readonly = container:addChild(GUI.switch(38, 11, 8, 0x66DB80, 0xE1E1E1, 0xFFFFFF, false))
container:addChild(GUI.text(6, 11, 0xA5A5A5, localization.readonly))
local userInput = container:addChild(GUI.switch(38, 13, 8, 0x66DB80, 0xE1E1E1, 0xFFFFFF, false))
local userInputText = container:addChild(GUI.text(6, 13, 0xA5A5A5, localization.userInput))
userInput.hidden = true
userInputText.hidden = true

container:addChild(GUI.text(centrizeText(container.width, localization.users), 2, 0x2D2D2D, localization.users))
local users = container:addChild(GUI.comboBox(11, 4, 25, 1, 0xE1E1E1, 0x2D2D2D, 0xCCCCCC, 0x888888))
container:addChild(GUI.button(38, 4, 1, 1, 0xE1E1E1, 0x696969, 0x696969, 0xE1E1E1, "+")).onTouch = function()
    container.hidden = true
    local inputContainer = window:addChild(GUI.container(1, 2, container.width, container.height))
    inputContainer:addChild(GUI.text(centrizeText(container.width, localization.enterPlayerName), 7, 0x2D2D2D, localization.enterPlayerName))
    local input = GUI.input(14, 9, 25, 1, 0xEEEEEE, 0x555555, 0x999999, 0xFFFFFF, 0x2D2D2D, "", "")

    input.onInputFinished = function()
        if #input.text > 0 then
            users:addItem(input.text)
            users.selectedItem = users:count()
            userInput.hidden = false
            userInputText.hidden = false
        end
        inputContainer:remove()
        container.hidden = false
    end

    inputContainer:addChild(input)
    input:startInput()
end
container:addChild(GUI.button(41, 4, 1, 1, 0xE1E1E1, 0x696969, 0x696969, 0xE1E1E1, "─")).onTouch = function()
    users:removeItem(users.selectedItem)
    if users:count() == 0 then
        userInput.hidden = true
        userInputText.hidden = true
    end
end
container:addChild(GUI.textBox(8, 6, 36, 1, nil, 0xA5A5A5, {localization.usersNotSpecified}, 1, 0, 0, true, true))

container:addChild(GUI.roundedButton(18, 15, 15, 1, 0xE1E1E1, 0x696969, 0x878787, 0xFFFFFF, localization.flash)).onTouch = function()
    local config = ""

    if users:count() > 0 then
        config = 'cyan="'
        for i = 1, users:count() do
            config = config .. users:getItem(i).text .. '|'
        end
        config = config .. (userInput.state and "$" or "") .. '"'
    end

    if #config > 64 then
        GUI.alert(localization.maxLengthExited)
    else
        container.hidden = true
        local flashContainer = window:addChild(GUI.container(1, 2, container.width, container.height))
        local panel = flashContainer:addChild(GUI.panel(1, 1, container.width, container.height, 0xF0F0F0))
        panel.eventHandler = function(parentContainer, object, e1)
			if e1 == "touch" then
				flashContainer:remove()
                container.hidden = false
                workspace:draw()
			end
		end

        local downloading = flashContainer:addChild(GUI.text(centrizeText(container.width, localization.downloading), 8, 0x878787, localization.downloading))
        workspace:draw()
        local data, reason = internet.request("https://github.com/BrightYC/Cyan/blob/master/stuff/cyan.bin?raw=true")
        downloading:remove()

        if data then
            data = config .. data
            local flashing = flashContainer:addChild(GUI.text(centrizeText(container.width, localization.flashing), 8, 0x878787, localization.flashing))
            workspace:draw()
            local success, reason, reasonFromEeprom = pcall(eeprom.set, data)

            if success and not reasonFromEeprom then
                eeprom.setLabel("Cyan BIOS")
                eeprom.setData(require("filesystem").getProxy().address)
                if readonly.state then
                    eeprom.makeReadonly(eeprom.getChecksum())
                end
                flashing:remove()
                flashContainer:addChild(GUI.text(centrizeText(container.width, localization.done), 8, 0x878787, localization.done))
                flashContainer:addChild(GUI.roundedButton(16, 15, 20, 1, 0xE1E1E1, 0x696969, 0x878787, 0xFFFFFF, localization.reboot)).onTouch = function()
                    computer.shutdown(true)
                end
            else
                GUI.alert(localization.flashFailed .. " " .. (reasonFromEeprom and reasonFromEeprom or reason or "unknown"))
                flashContainer:remove()
                container.hidden = false
            end
        else
            GUI.alert(localization.downloadFailed .. " " .. tostring(reason))
            flashContainer:remove()
            container.hidden = false
        end
    end
end
