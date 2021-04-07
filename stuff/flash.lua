local config = '' -- replace to [[%s]]
local readOnly = false -- replace to %s

local function proxy(componentType)
    local address = component.list(componentType)()

    if not address then
        error(("No component %s available"):format(componentType))
    end

    return component.proxy(address)
end

local eeprom = proxy("eeprom")
local gpu = proxy("gpu")
local internet = proxy("internet")
local width, height = gpu.maxResolution()

local function status(text)
    gpu.set(math.ceil(width / 2 - unicode.len(text) / 2), height / 2, text)
end

local function flash()
    gpu.setPaletteColor(9, 0x002b36)
    gpu.setPaletteColor(11, 0x8cb9c5)
    gpu.setBackground(0x002b36)
    gpu.setForeground(0x8cb9c5)
    gpu.fill(1, 1, width, height, " ")
    status("Downloading...")

    local handle, data, chunk = internet.request("https://github.com/BrightYC/Cyan/tree/master/stuff/cyan.bin?raw=true"), ""

    while true do
        chunk = handle.read(math.huge)

        if chunk then
            data = data .. chunk
        else
            break
        end
    end

    gpu.fill(1, 1, width, height, " ")
    status("Flashing...")
    eeprom.set(data)
    eeprom.setData(config)
    eeprom.setLabel("Cyan BIOS")

    if readOnly then
        eeprom.makeReadonly(eeprom.getChecksum())
    end

    gpu.setPaletteColor(9, 0x969696)
    gpu.setPaletteColor(11, 0xb4b4b4)
    gpu.setBackground(0x000000)
    gpu.fill(1, 1, width, height, " ")
    computer.shutdown(true)
end

flash()