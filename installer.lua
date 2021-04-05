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
    local success, reason = eeprom.set(([=[local a=[[%s]]local b=%s;local function c(d)return component.list(d)()and component.proxy(component.list(d)())end;local e=component.proxy(computer.tmpAddress())local f=c("eeprom")local g=c("gpu")local h,i;if g then h,i=g.maxResolution()g.setPaletteColor(9,0x002b36)g.setPaletteColor(11,0x8cb9c5)end;local function j(k,l,m,n,o)if g then g.setBackground(n or 0x002b36)g.setForeground(o or 0x8cb9c5)g.set(k,l,m)end end;local function p(k,l,q,r,n,o)if g then g.setBackground(n or 0x002b36)g.setForeground(o or 0x8cb9c5)g.fill(k,l,q,r," ")end end;local function s()if g then p(1,1,h,i)end end;local function t(u)return math.ceil(h/2-u/2)end;local function v(l,w,n,o)if g then j(t(unicode.len(w)),l,w,n,o)end end;local x,y,z,A,B=e.open("/cyan","r"),"","Cyan BIOS"s()if x then v(i/2-1,"Flashing...")v(i/2+1,"Please do not turn off the computer")while true do A=e.read(x,math.huge)if A then y=y..A else break end end;e.close(x)else B=true;v(i/2,"What an idiot... Fail-safe flashing (Lua BIOS)")y=[[local a;do local b=component.invoke;local function c(d,e,...)local f=table.pack(pcall(b,d,e,...))if not f[1]then return nil,f[2]else return table.unpack(f,2,f.n)end end;local g=component.list("eeprom")()computer.getBootAddress=function()return c(g,"getData")end;computer.setBootAddress=function(d)return c(g,"setData",d)end;do local h=component.list("screen")()local i=component.list("gpu")()if i and h then c(i,"bind",h)end end;local function j(d)local k,l=c(d,"open","/init.lua")if not k then return nil,l end;local m=""repeat local n,l=c(d,"read",k,math.huge)if not n and l then return nil,l end;m=m..(n or"")until not n;c(d,"close",k)return load(m,"=init")end;local l;if computer.getBootAddress()then a,l=j(computer.getBootAddress())end;if not a then computer.setBootAddress()for d in component.list("filesystem")do a,l=j(d)if a then computer.setBootAddress(d)break end end end;if not a then error("no bootable medium found"..(l and": "..tostring(l)or""),0)end;computer.beep(1000,0.2)end;a()]]z="EEPROM (Lua BIOS)"end;f.set(y)f.setLabel(z)if not B then f.setData(a)end;if b and not B then f.makeReadonly(f.getChecksum())end;if g then g.setPaletteColor(9,0x969696)g.setPaletteColor(11,0xb4b4b4)p(1,1,h,i,0x0000000)end;computer.shutdown(true)]=]):format(serialization.serialize(config), readOnly and true or false))

    if reason == "storage is readonly" then
        io.stderr:write("EEPROM is read only. Please insert an not read-only EEPROM.")
    else
        computer.shutdown(true)
    end
end