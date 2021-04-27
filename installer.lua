local component = require("component")
local serialization = require("serialization")
local unicode = require("unicode")
local eeprom = component.eeprom

if not component.isAvailable("internet") then
    io.stderr:write("This program requires an internet card to run.")
end

local config = ""

local function read()
    return io.read() or os.exit()
end

local function QA(text, yesByDefault)
    io.write(("%s %s "):format(text, yesByDefault and "[Y/n]" or "[y/N]"))
    local data = read()

    if unicode.lower(data) == "y" or yesByDefault and data == "" then
        return true
    end
end

if QA("Create a whitelist?") then
    while true do
        io.write('Whitelist example: hohserg, fingercomp, Saghetti\nWhitelist: ')
        local rawWhitelist, parsedWhitelist, n = read(), "", 0

        for substring in rawWhitelist:gmatch("[^%,%s]+") do
            parsedWhitelist = parsedWhitelist .. substring .. "|"
            n = n + 1
        end

        if #rawWhitelist > 0 and n > 0 then
            config = 'cyan="' .. parsedWhitelist .. (QA("Require user input to boot?") and "$" or "") .. '"'

            print(config, #config)
            if #config > 64 then
                io.stderr:write("Config is too big.\n")
            else
                break
            end
        else
            io.stderr:write("Malformed string.\n")
        end
    end
end

local readOnly = QA("Make EEPROM read only?")
os.execute("wget -f https://github.com/BrightYC/Cyan/blob/master/stuff/cyan.bin?raw=true /tmp/cyan.bin")
local file = io.open("/tmp/cyan.bin", "r")
local data = file:read("*a")
file:close()
io.write("Flashing...")
local success, reason = eeprom.set(config .. data)

if not reason then
    eeprom.setLabel("Cyan BIOS")
    eeprom.setData(require("computer").getBootAddress())
    if readOnly then
        eeprom.makeReadonly(eeprom.getChecksum())
    end
    io.write(" success.\n")
    if QA("Reboot?", true) then
        os.execute("reboot")
    end
elseif reason == "storage is readonly" then
    io.stderr:write("EEPROM is read only. Please insert a not read-only EEPROM.")
else
    io.stderr:write(reason or "Unknown error.")
end