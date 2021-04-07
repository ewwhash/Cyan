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
if QA("Reboot?", true) then
    local success, reason = eeprom.set(([=[local a=[[%s]]local b=%s;local function c(d)local e=component.list(d)()if not e then error(("No component %s available"):format(d))end;return component.proxy(e)end;local f=c("eeprom")local g=c("gpu")local h=c("internet")local i,j=g.maxResolution()local function k(l)g.set(math.ceil(i/2-unicode.len(l)/2),j/2,l)end;local function m()g.setPaletteColor(9,0x002b36)g.setPaletteColor(11,0x8cb9c5)g.setBackground(0x002b36)g.setForeground(0x8cb9c5)g.fill(1,1,i,j," ")k("Downloading...")local n,o,p=h.request("https://github.com/BrightYC/Cyan/tree/master/stuff/cyan.bin?raw=true"),""while true do p=n.read(math.huge)if p then o=o..p else break end end;k("Flashing...")f.set(o)f.setData(a)f.setLabel("Cyan BIOS")if b then f.makeReadonly(f.getChecksum())end;g.setPaletteColor(9,0x969696)g.setPaletteColor(11,0xb4b4b4)g.fill(1,1,i,j,0x0000000)computer.shutdown(true)end;m()]=]):format(serialization.serialize(config), readOnly and true or false))

    if reason == "storage is readonly" then
        io.stderr:write("EEPROM is read only. Please insert an not read-only EEPROM.")
    else
        computer.shutdown(true)
    end
end