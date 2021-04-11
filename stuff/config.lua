local component = require("component")
local serialization = require("serialization")
local unicode = require("unicode")
local eeprom = component.eeprom
local data = eeprom.get():match("(computer.setArchitecture.+)")
local config = {{}}

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

while true do
    io.write('Whitelist example: hohserg, fingercomp, Saghetti\nWhitelist: ')
    local whitelistStr, whitelist = read(), {}
    whitelistStr = whitelistStr:gsub("%s+", "")

    for substring in whitelistStr:gmatch("[^%,]+") do
        table.insert(whitelist, substring)
    end

    if whitelist then
        for i = 1, #whitelist do
            config[1][whitelist[i]] = 1
        end
        
        config[1].n = #whitelist

        if QA("Require user input to boot?") then
            config[2] = 1
        end
        
        if #serialization.serialize(config) > 64 then
            io.stderr:write("Config is too big.\n")
        else
            break
        end
    else
        io.stderr:write("Malformed string\n")
    end
end

local readOnly = QA("Make EEPROM read only?")
data = "cyan=" .. serialization.serialize(config) .. data
print("Flashing...")
local success, reason = eeprom.set(data)

if reason == "storage is readonly" then
    io.stderr:write("EEPROM is read only. Please insert an not read-only EEPROM.")
else
    if readOnly then
        eeprom.makeReadonly(eeprom.getChecksum())
    end
    print("Done!")
end