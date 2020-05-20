local password, passwordOnBoot, bootFiles, bootCandidates, keys, computerPullSignal, passwordChecked, selectedElementsLine, centerY, width, height = "", false, {"/init.lua", "/OS.lua"}, {}, {}, computer.pullSignal

computer.pullSignal = function(timeout, onHardInterrupt)
    local signal = {computerPullSignal(timeout)}

    if signal[1] == "key_down" then
        keys[signal[4]] = true
    elseif signal[1] == "key_up" then
        keys[signal[4]] = nil
    end

    if keys[29] and keys[56] and keys[46] then
        if onHardInterrupt then
            onHardInterrupt()
        end

        return "interrupted"
    elseif keys[29] and keys[32] then
        return "interrupted"
    else
        return table.unpack(signal)
    end
end

local function proxy(componentType)
    local address = component.list(componentType)()
    return address and component.proxy(address)
end

local function execute(code, stdin, env)
    local chunk, err = load("return " .. code, stdin, false, env)

    if not chunk then
        chunk, err = load(code, stdin, false, env)
    end

    if chunk then
        return xpcall(chunk, debug.traceback)
    else
        return false, err
    end
end

local function split(text, tabulate)
    local lines = {}

    for line in text:gmatch"[^\r\n]+" do
        lines[#lines + 1] = line:gsub("\t", tabulate and "    " or "")
    end

    return lines
end

local function sleep(timeout, breakCode, onBreak)
    local deadline, signalType, code, _ = computer.uptime() + (timeout or math.huge)

    repeat
        signalType, _, _, code = computer.pullSignal(deadline - computer.uptime())

        if signalType == "interrupted" or signalType == "key_down" and (code == breakCode or breakCode == 0) then
            if onBreak then
                onBreak()
            end
            return true
        end
    until computer.uptime() >= deadline
end

local gpu, eeprom, screen = proxy"gpu" or {}, proxy"eeprom", component.list"screen"()

computer.setBootAddress = eeprom.setData
computer.getBootAddress = eeprom.getData
eeprom.get = eeprom.getData

if gpu and screen then
    gpu.bind((screen))
    width, height = gpu.maxResolution()
    centerY = height / 2
    gpu.setPaletteColor(9, 0x002b36)
    gpu.setPaletteColor(11, 0x8cb9c5)
end

local function set(x, y, string, background, foreground)
    gpu.setBackground(background or 0x002b36)
    gpu.setForeground(foreground or 0x8cb9c5)
    gpu.set(x, y, string)
end

local function fill(x, y, w, h, symbol, background, foreground)
    gpu.setBackground(background or 0x002b36)
    gpu.setForeground(foreground or 0x8cb9c5)
    gpu.fill(x, y, w, h, symbol)
end

local function clear()
    fill(1, 1, width, height, " ")
end

local function centrize(len)
    return math.ceil(width / 2 - len / 2)
end

local function centrizedSet(y, text, background, foreground)
    set(centrize(unicode.len(text)), y, text, background, foreground)
end

local function status(text, title, wait, breakCode, onBreak, booting, beep)
    if gpu and screen then
        local lines, y, gpuSet = split(text), computer.uptime() + (wait or 0), gpu.set
        y = math.ceil(centerY - #lines / 2)
        gpu.setPaletteColor(9, 0x002b36)
        gpu.setPaletteColor(11, 0x8cb9c5)
        clear()

        if title then
            centrizedSet(y - 1, title, 0x002b36, 0xFFFFFF)
            y = y + 1
        end

        for i = 1, #lines do
            centrizedSet(y, lines[i])
            y = y + 1
        end

        if booting and gpu and screen then
            gpu.set = function(...)
                gpu.setPaletteColor(9, 0x969696)
                gpu.setPaletteColor(11, 0xb4b4b4)
                gpuSet(...)
                gpu.set = gpuSet
            end
        end

        if beep then
            computer.beep(1000, .4)
            computer.beep(1000, .4)
        end
        
        return sleep(wait or 0, breakCode, onBreak)
    end
end

local function ERROR(err)
    return gpu and screen and status(err, [[¯\_(ツ)_/¯]], math.huge, 0, computer.shutdown, true) or error(err)
end

local function addCandidate(address)
    local proxy = component.proxy(address)

    if proxy and proxy.spaceTotal then
        bootCandidates[#bootCandidates + 1] = {
            proxy, proxy.getLabel() or "N/A", address
        }

        for i = 1, #bootFiles do
            if proxy.exists(bootFiles[i]) then
                bootCandidates[#bootCandidates][4] = bootFiles[i]
            end
        end
    end
end

local function updateCandidates()
    bootCandidates = {}
    addCandidate(eeprom.getData())

    for filesystem in pairs(component.list("filesystem")) do
        addCandidate((eeprom.getData() ~= filesystem and computer.tmpAddress() ~= filesystem) and filesystem or "")
    end
end

local function cutText(text, maxLength)
    return unicode.len(text) > maxLength and unicode.sub(text, 1, maxLength) .. "…" or text
end

local function input(prefix, X, y, centrized, hide, lastInput)
    local input, prefixLen, cursorPos, cursorState, x, cursorX, signalType, char, code, _ = "", unicode.len(prefix), 1, true

    while true do
        signalType, _, char, code = computer.pullSignal(.5)

        if signalType == "interrupted" then
            input = false
            break
        elseif signalType == "key_down" then
            if char >= 32 and unicode.len(prefixLen .. input) < width - prefixLen - 1 then
                input = unicode.sub(input, 1, cursorPos - 1) .. unicode.char(char) .. unicode.sub(input, cursorPos, -1)
                cursorPos = cursorPos + 1
            elseif char == 8 and #input > 0 then
                input = unicode.sub(unicode.sub(input, 1, cursorPos - 1), 1, -2) .. unicode.sub(input, cursorPos, -1)
                cursorPos = cursorPos - 1
            elseif char == 13 then
                break
            elseif code == 203 and cursorPos > 1 then
                cursorPos = cursorPos - 1
            elseif code == 205 and cursorPos <= unicode.len(input) then
                cursorPos = cursorPos + 1
            elseif code == 200 and lastInput then
                input = lastInput
                cursorPos = unicode.len(lastInput) + 1
            elseif code == 208 and lastInput then
                input = ""
                cursorPos = true
            end

            cursorState = true
        elseif signalType == "clipboard" then
            input = unicode.sub(input, 1, cursorPos - 1) .. char .. unicode.sub(input, cursorPos, -1)
            cursorPos = cursorPos + unicode.len(char)
        elseif signalType ~= "key_up" then
            cursorState = not cursorState
        end

        x = centrized and centrize(unicode.len(input) + prefixLen) or X
        cursorX = x + prefixLen + cursorPos - 1
        fill(1, y, width, 1, " ")
        set(x, y, prefix .. (hide and ("*"):rep(unicode.len(input)) or input), 0x002b36, 0xFFFFFF)
        if cursorX <= width then
            set(cursorX, y, gpu.get(cursorX, y), cursorState and 0xFFFFFF or 0x002b36, cursorState and 0x002b36 or 0xFFFFFF)
        end
    end

    fill(1, y, width, 1, " ")
    return input
end

local function print(...)
    local text, lines = table.pack(...)

    for i = 1, text.n do
        text[i] = tostring(text[i])
    end

    lines = split(table.concat(text, "    "), true)

    for i = 1, #lines do
        gpu.copy(1, 1, width, height - 1, 0, -1)
        fill(1, height - 1, width, 1, " ")
        set(1, height - 1, lines[i])
    end
end

local function checkPassword()
    if #password > 0 and not passwordChecked then
        local passwordFromUser = input("Password: ", false, centerY, 1, 1)

        if not passwordFromUser then
            computer.shutdown()
        elseif passwordFromUser ~= password then
            ERROR("Access denied")
        end

        passwordChecked = true
    end
end

local function bootPreview(drive, booting)
    address = cutText(drive[3], booting and 36 or 6)
    return drive[4] and ("Boot%s %s from %s (%s)")
    :format(
        booting and "ing" or "",
        drive[4],
        drive[2],
        address
    )
    or ("Boot from %s (%s) is not available")
    :format(
        drive[2],
        address
    )
end

local function boot(drive)
    if drive[4] then
        local handle, data, chunk, success, err = drive[1].open(drive[4], "r"), ""

        ::LOOP::
        chunk = drive[1].read(handle, math.huge)

        if chunk then
            data = data .. chunk
            goto LOOP
        end

        computer.pullSignal = computerPullSignal
        drive[1].close(handle)
        if passwordOnBoot then
            checkPassword()
        end
        status(bootPreview(drive, true), false, .5, false, false, true)
        if eeprom.getData() ~= drive[3] then
            eeprom.setData(drive[3])
        end
        success, err = execute(data, "=" .. drive[4])
        if not success then
            ERROR(err)
        end

        return true
    end
end

local function createElements(elements, y, borderType, onArrowKeyUpOrDown, onDraw)
    -- borderType - 1 == small border
    -- borderType - 2 == big border

    return {
        e = elements,
        s = 1,
        y = y,
        k = onArrowKeyUpOrDown,
        b = borderType,
        d = function(SELF, withoutBorder, withoutSelect) -- draw()
            y = SELF.y
            borderType = SELF.b
            fill(1, y - 1, width, 3, " ", 0x002b36)
            selectedElementsLine = withoutSelect and selectedElementsLine or SELF
            local elementsAndBorderLength, borderSpaces, elementLength, x, selectedElement, element = 0, borderType == 1 and 6 or 8

            if onDraw then
                onDraw(SELF)
            end

            for i = 1, #SELF.e do
                elementsAndBorderLength = elementsAndBorderLength + unicode.len(SELF.e[i].t) + borderSpaces
            end

            elementsAndBorderLength = elementsAndBorderLength -  borderSpaces
            x = centrize(elementsAndBorderLength)

            for i = 1, #SELF.e do
                selectedElement, element = SELF.s == i and true, SELF.e[i]
                elementLength = unicode.len(element.t)

                if selectedElement and not withoutBorder then
                    fill(x - borderSpaces / 2, y - (borderType == 1 and 0 or 1), elementLength + borderSpaces, borderType == 1 and 1 or 3, " ", 0x8cb9c5)
                    set(x, y, element.t, 0x8cb9c5, 0x002b36)
                else
                    set(x, y, element.t, 0x002b36, 0x8cb9c5)
                end

                x = x + elementLength + borderSpaces
            end
        end
    }
end

local function bootLoader()
    checkPassword()
    ::REFRESH::
    internet = proxy"internet"
    updateCandidates()
    local env, signalType, code, data, options, drives, draw, drive, proxy, readOnly, newLabel, url, handle, chunk, correction, spaceTotal, _ = setmetatable({
        print = print,
        proxy = proxy,
        os = {
            sleep = function(timeout) sleep(timeout, false, function() error("interrupted") end) end
        }
    }, {__index = _G})

    options = createElements({
        {t = "Power off", a = function() computer.shutdown() end},
        {t = "Lua 5.3", a = function()
            clear()

            ::LOOP::
                data = input("> ", 1, height, false, false, data)

                if data then
                    print("> " .. data)
                    set(1, height, ">")
                    print(select(2, execute(data, "=stdin", env)))
                    goto LOOP
                end
            draw(false, false, true, true)
        end},
    }, centerY + 2, 1, function()
        selectedElementsLine = drives
        draw(true, true, false, false)
    end)

    options.e[#options.e + 1] = internet and {t = "Internet boot", a = function()
        url, data = input("URL: ", false, centerY + 7, true), ""

        if url and url ~= "" then
            handle, chunk = internet.request(url), ""

            if handle then
                status("Downloading...")
                ::LOOP::

                chunk = handle.read()

                if chunk then
                    data = data .. chunk
                    goto LOOP
                end

                handle.close()
                status(select(2, execute(data, "=internet boot")) or "is empty", "Internet boot result", math.huge, 0)
            else
                status("Malformed URL", "Internet boot result", math.huge, 0)
            end
        end

        draw(false, false, true, true)
    end}

    if #bootCandidates > 0 then
        correction = #options.e + 1
        drives = createElements({}, centerY - 2, 2, function()
            selectedElementsLine = options
            draw(false, false, true, true)
        end, function(SELF)
            drive = bootCandidates[SELF.s]
            proxy = drive[1]
            spaceTotal = proxy.spaceTotal()
            readOnly = proxy.isReadOnly()
            fill(1, centerY + 5, width, 3, " ")
            centrizedSet(centerY + 5, bootPreview(drive), false, 0xFFFFFF)
            centrizedSet(centerY + 7, ("Disk usage %s%% / %s / %s")
                :format(
                    math.floor(proxy.spaceUsed() / (spaceTotal / 100)),
                    readOnly and "Read only" or "Read & Write",
                    spaceTotal < 2 ^ 20 and "FDD" or "HDD"
                )
            )

            for i = correction, #options.e do
                options.e[i] = nil
            end

            if readOnly then
                options.s = options.s > #options.e and #options.e or options.s
            else
                options.e[correction] = {t = "Rename", a = function()
                    newLabel = input("New label: ", false, centerY + 7, true)

                    if newLabel and newLabel ~= "" then
                        pcall(proxy.setLabel, newLabel)
                        drive[2] = cutText(newLabel, 16)
                        drives.e[SELF.s].t = cutText(newLabel, 6)
                    end

                    drives:d(true, true)
                    options:d()
                end}
                options.e[#options.e + 1] = {t = "Format", a = function() drive[4] = false proxy.remove("/") drives:d(true, true) options:d() end}
            end

            options:d(true, true)
        end)

        for i = 1, #bootCandidates do
            drives.e[i] = {t = cutText(bootCandidates[i][2], 6), a = function(SELF)
                boot(bootCandidates[SELF.s])
            end}
        end
    else
        options.y = centerY
        options.b = 2
    end

    draw = function(optionsWithoutBorder, optionsWithoutSelect, drivesWithoutBorder, drivesWithoutSelect)
        clear()
        if drives then
            drives:d(drivesWithoutBorder, drivesWithoutSelect)
            options:d(optionsWithoutBorder, optionsWithoutSelect)
        else
            centrizedSet(centerY + 4, "No drives available", 0x002b36, 0xFFFFFF)
            options:d()
        end

        centrizedSet(height, "Use ← ↑ → keys to move cursor; Enter to boot; CTRL+ALT+C to shutdown")
    end

    draw(true, true)

    ::LOOP::
        signalType, _, _, code = computer.pullSignal(math.huge, computer.shutdown)

        if signalType == "key_down" then
            if code == 200 then -- Up
                selectedElementsLine.k()
            elseif code == 208 then -- Down
                selectedElementsLine.k()
            elseif code == 203 and selectedElementsLine.s > 1 then -- Left
                selectedElementsLine.s = selectedElementsLine.s - 1
                selectedElementsLine:d()
            elseif code == 205 and selectedElementsLine.s < #selectedElementsLine.e then -- Right
                selectedElementsLine.s = selectedElementsLine.s + 1
                selectedElementsLine:d()
            elseif code == 28 then -- Enter
                selectedElementsLine.e[selectedElementsLine.s].a(selectedElementsLine)
            end
        elseif signalType == "component_added" or signalType == "component_removed" then
            goto REFRESH
        end
    goto LOOP
end

computer.beep(1000, .2)
updateCandidates()
status("Hold CTRL to stay in bootloader", false, .5, 29, bootLoader)
for i = 1, #bootCandidates do
    if boot(bootCandidates[i]) then
        computer.shutdown()
    end
end
if gpu and screen then
    bootLoader()
else
    error("No bootable medium found")
end