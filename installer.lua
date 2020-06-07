local component = require("component")
local computer = require("computer")
local unicode = require("unicode")
local serialization = require("serialization")

local eeprom = component.eeprom
local freespace = eeprom.getDataSize() - 38
local users, readOnly = false, false

local function read(hint)
    return io.read() or os.exit()
end

local function QA(text)
    io.write(("%s [Y/n] "):format(text))
    local input = unicode.lower(read())

    if input == "y" or input == "" then
        return true
    end
end

if QA("Create whitelist for bootloader access?") then
    repeat
        io.write('Whitelist example: {"Jako", "Berserk29", "Elds01", "svchost2"}\nWhitelist: ')
        users = read()
        local err = select(2, require("serialization").unserialize(users))

        if err then
            io.stderr:write(err .. "\n")
        else
            if #users > freespace then
                io.stderr:write(("\nMaximum whitelist size is %s and you used %s\n"):format(freespace, #users))
            elseif #users > 0 then
                users = ("#%s%s"):format(users, QA("Request user press on boot?") and "*" or "")
            end
        end
    until users and #users > 0 and not err
end

readOnly = QA("Make EEPROM read only?")
os.execute("wget -f https://github.com/BrightYC/Cyan/raw/master/cyan.comp /tmp/cyan.comp")
local file = io.open("/tmp/cyan.comp", "r")
local data = file:read("*a")
file:close()
print("Flashing...")
eeprom.set(data)
eeprom.setData((eeprom.getData():match("[a-f-0-9]+") or eeprom.getData()) .. (users or ""), true)
eeprom.setLabel("Cyan BIOS")
if readOnly then
    print("Making EEPROM read only...")
    eeprom.makeReadonly(eeprom.getChecksum())
end
computer.shutdown(true)