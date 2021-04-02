local component = require("component")
local computer = require("computer")
local unicode = require("unicode")
local serialization = require("serialization")

local eeprom = component.eeprom
local config = {computer.getBootAddress(), {}, 0}
local readOnly

local function read()
    return io.read() or os.exit()
end

local function QA(text, defaultY)
    io.write(("%s %s "):format(text, defaultY and "[Y/n]" or "[y/N]"))
    local data = read()

    if unicode.lower(data) == "y" or defaultY and data == "" then
        return true
    end
end

if QA("Create a whitelist?") then
    while true do
        io.write('Whitelist example: {"hohserg", "Fingercomp", "Saghetti"}\nWhitelist: ')
        local users, reason = serialization.unserialize(read())

        if users then
            config[2] = users

            if QA("Require user input to boot?") then
                config[3] = 1
            end
            
            if #serialization.serialize(config) > 256 then
                io.stderr:write("Whitelist is too big.\n")
            else
                break
            end
        else
            io.stderr:write(reason .. "\n")
        end
    end
end

readOnly = QA("Make EEPROM read only?")
os.execute("wget -f https://github.com/BrightYC/Cyan/blob/master/cyan.comp?raw=true /tmp/cyan")
if QA("Reboot?", true) then
    local success, reason = eeprom.set(([=[
        local config = [[%s]]
        local readOnly = %s
        local tmpfs = component.proxy(computer.tmpAddress())
        local eeprom = component.proxy(component.list("eeprom")())

        local handle, data, chunk = tmpfs.open("/cyan", "r"), ""

        while true do
            chunk = tmpfs.read(handle, math.huge)

            if chunk then
                data = data .. chunk
            else
                break
            end
        end

        tmpfs.close(handle)
        eeprom.set(data)
        eeprom.setLabel("Cyan BIOS")
        eeprom.setData(config)
        if readOnly then
            eeprom.makeReadonly(eeprom.getChecksum())
        end
        computer.shutdown(true)
    ]=]):format(serialization.serialize(config), readOnly and true or false))

    if reason == "storage is readonly" then
        io.stderr:write("EEPROM is read only. Please insert an not read-only EEPROM.")
    else
        computer.shutdown(true)
    end
end