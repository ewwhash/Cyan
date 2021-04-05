local config = [[%s]]
local readOnly = false

local function proxy(componentType)
    return component.list(componentType)() and component.proxy(component.list(componentType)())
end

local tmpfs = component.proxy(computer.tmpAddress())
local eeprom = proxy("eeprom")
local gpu = proxy("gpu")
local width, height

if gpu then
    width, height = gpu.maxResolution()
    gpu.setPaletteColor(9, 0x002b36)
    gpu.setPaletteColor(11, 0x8cb9c5)
end

local function set(x, y, string, background, foreground)
    if gpu then
        gpu.setBackground(background or 0x002b36)
        gpu.setForeground(foreground or 0x8cb9c5)
        gpu.set(x, y, string)
    end
end

local function fill(x, y, w, h, background, foreground)
    if gpu then
        gpu.setBackground(background or 0x002b36)
        gpu.setForeground(foreground or 0x8cb9c5)
        gpu.fill(x, y, w, h, " ")
    end
end

local function clear()
    if gpu then
        fill(1, 1, width, height)
    end
end

local function centrize(len)
    return math.ceil(width / 2 - len / 2)
end

local function centrizedSet(y, text, background, foreground)
    if gpu then
        set(centrize(unicode.len(text)), y, text, background, foreground)
    end
end

local handle, data, label, chunk, failsafe = tmpfs.open("/cyan", "r"), "", "Cyan BIOS"

clear()
if handle then
    centrizedSet(height / 2 - 1, "Flashing...")
    centrizedSet(height / 2 + 1, "Please do not turn off the computer")

    while true do
        chunk = tmpfs.read(handle, math.huge)

        if chunk then
            data = data .. chunk
        else
            break
        end
    end

    tmpfs.close(handle)
else
    failsafe = true
    centrizedSet(height / 2, "What an idiot... Fail-safe flashing (Lua BIOS)")
    data = [[local a;do local b=component.invoke;local function c(d,e,...)local f=table.pack(pcall(b,d,e,...))if not f[1]then return nil,f[2]else return table.unpack(f,2,f.n)end end;local g=component.list("eeprom")()computer.getBootAddress=function()return c(g,"getData")end;computer.setBootAddress=function(d)return c(g,"setData",d)end;do local h=component.list("screen")()local i=component.list("gpu")()if i and h then c(i,"bind",h)end end;local function j(d)local k,l=c(d,"open","/init.lua")if not k then return nil,l end;local m=""repeat local n,l=c(d,"read",k,math.huge)if not n and l then return nil,l end;m=m..(n or"")until not n;c(d,"close",k)return load(m,"=init")end;local l;if computer.getBootAddress()then a,l=j(computer.getBootAddress())end;if not a then computer.setBootAddress()for d in component.list("filesystem")do a,l=j(d)if a then computer.setBootAddress(d)break end end end;if not a then error("no bootable medium found"..(l and": "..tostring(l)or""),0)end;computer.beep(1000,0.2)end;a()]]
    label = "EEPROM (Lua BIOS)"
end

eeprom.set(data)
eeprom.setLabel(label)
if not failsafe then
    eeprom.setData(config)
end
if readOnly and not failsafe then  
    eeprom.makeReadonly(eeprom.getChecksum())
end
if gpu then
    gpu.setPaletteColor(9, 0x969696)
    gpu.setPaletteColor(11, 0xb4b4b4)
    fill(1, 1, width, height, 0x0000000)
end
computer.shutdown(true)