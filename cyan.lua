local bootFiles, bootCandidates, key, userChecked, width, height, gpu, redraw, lines, elementsBootables = {"/init.lua", "OS.lua"}, {}, {}

local function pullSignal(timeout)
    local signal = {computer.pullSignal(timeout)}
    signal[1] = signal[1] or ""

    -- if #signal > 0 and #config[2] > 0 and (signal[1]:match("ey") and not config[2][signal[5]] or signal[1]:match("cl") and not config[2][signal[4]]) then
    --     return ""
    -- end

    key[signal[4] or ""] = signal[1]:match"do" and 1

    if key[29] and (key[46] or key[32]) and signal[1]:match"do" then
        return "F"
    end

    return table.unpack(signal)
end

local function execute(code, stdin, env, palette)
    local chunk, err = load("return " .. code, stdin, F, env)

    if not chunk then
        chunk, err = load(code, stdin, F, env)
    end

    if chunk then
        env = component.invoke
        component.invoke = palette and gpu and gpu.address and function(address, method, ...)
            if gpu and address == gpu.address and method == "set" then
                gpu.setPaletteColor(9, 0x969696)
                gpu.setPaletteColor(11, 0xb4b4b4)
            end
    
            component.invoke = env
            return env(address, method, ...)
        end or env

        return xpcall(chunk, debug.traceback)
    end
        
    return F, err
end

local function proxy(componentType)
    return component.list(componentType)() and component.proxy(component.list(componentType)())
end

local function split(text, tabulate)
    lines = {}

    for line in text:gmatch"[^\r\n]+" do
        lines[#lines + 1] = line:gsub("\t", tabulate and "    " or "")
    end
end

local function sleep(timeout, breakCode, onBreak)
    local deadline, signalType, code, _ = computer.uptime() + (timeout or math.huge)

    ::LOOP::
    signalType, _, _, code = pullSignal(deadline - computer.uptime())

    if signalType == "F" or signalType:match"do" and (code == breakCode or breakCode == 0) then
        return 1, onBreak and onBreak()
    elseif computer.uptime() <= deadline then
        goto LOOP
    end
end

local function set(x, y, string, background, foreground)
    gpu.setBackground(background or 0x002b36)
    gpu.setForeground(foreground or 0x8cb9c5)
    gpu.set(x, y, string)
end

local function fill(x, y, w, h, background, foreground)
    gpu.setBackground(background or 0x002b36)
    gpu.setForeground(foreground or 0x8cb9c5)
    gpu.fill(x, y, w, h, " ")
end

local function clear()
    fill(1, 1, width, height)
end

local function centrize(len)
    return math.ceil(width / 2 - len / 2)
end

local function centrizedSet(y, text, background, foreground)
    set(centrize(unicode.len(text)), y, text, background, foreground)
end

local function gpuCheck()
    gpu = proxy"gp"

    if gpu and gpu.bind((component.list"sc"())) then
        gpu.setPaletteColor(9, 0x002b36)
        gpu.setPaletteColor(11, 0x8cb9c5)
        width, height = gpu.maxResolution()
        clear()
        return 1
    end

    width, height = 0, 0
end

local function status(text, title, wait, breakCode, onBreak, err, actionImmidiately)    
    if actionImmidiately then
        onBreak()
    elseif gpuCheck() then
        split(text)
        local y = math.ceil(height / 2 - #lines / 2)

        if title then
            centrizedSet(y - 1, title, 0x002b36, 0xFFFFFF)
            y = y + 1
        end
        for i = 1, #lines do
            centrizedSet(y, lines[i])
            y = y + 1
        end

        return sleep(wait or 0, breakCode, onBreak)
    elseif err then
        error(text)
    end
end

local function cutText(text, maxLength)
    return unicode.len(text) > maxLength and unicode.sub(text, 1, maxLength) .. "…" or text
end

local function input(prefix, X, y, centrized, lastInput)
    local input, prefixLen, cursorPos, firstBlink, cursorState, x, cursorX, signalType, char, code, _ = "", unicode.len(prefix), 1, 1

    ::LOOP::
    signalType, _, char, code = pullSignal(firstBlink and 0 or 0.5)

    if signalType:match"do" then
        if char >= 32 and unicode.len(prefixLen .. input) < width - prefixLen then
            input = unicode.sub(input, 1, cursorPos - 1) .. unicode.char(char) .. unicode.sub(input, cursorPos, -1)
            cursorPos = cursorPos + 1
        elseif char == 8 and #input > 0 and cursorPos > 1 then
            input = unicode.sub(unicode.sub(input, 1, cursorPos - 1), 1, -2) .. unicode.sub(input, cursorPos, -1)
            cursorPos = cursorPos - 1
        elseif char == 13 then
            fill(1, y, width, 1)
            return input
        elseif code == 203 and cursorPos > 1 then
            cursorPos = cursorPos - 1
        elseif code == 205 and cursorPos <= unicode.len(input) then
            cursorPos = cursorPos + 1
        elseif code == 200 and lastInput then
            input = lastInput
            cursorPos = unicode.len(lastInput) + 1
        elseif code == 208 and lastInput then
            input = ""
            cursorPos = 1
        end

        cursorState = 1
    elseif signalType:match"cl" then
        input = unicode.sub(input, 1, cursorPos - 1) .. char .. unicode.sub(input, cursorPos, -1)
        cursorPos = cursorPos + unicode.len(char)
    elseif signalType:match"mp" or signalType == "F" then
        redraw = signalType:match"mp" and 1
        return
    elseif not signalType:match"up" then
        cursorState = not cursorState
    end

    firstBlink = F
    x = centrized and centrize(unicode.len(input) + prefixLen) or X
    cursorX = x + prefixLen + cursorPos - 1
    fill(1, y, width, 1)
    set(x, y, prefix .. input, 0x002b36, 0xFFFFFF)
    if cursorX <= width then
        set(cursorX, y, gpu.get(cursorX, y), cursorState and 0xFFFFFF or 0x002b36, cursorState and 0x002b36 or 0xFFFFFF)
    end
    goto LOOP
end

local function print(...)
    local text = table.pack(...)
    for i = 1, text.n do
        text[i] = tostring(text[i])
    end
    split(table.concat(text, "    "), 1)

    for i = 1, #lines do
        gpu.copy(1, 1, width, height - 1, 0, -1)
        fill(1, height - 1, width, 1)
        set(1, height - 1, lines[i])
    end
end

local function addCandidate(address)
    local proxy, bootFile, i = component.proxy(address)

    if proxy and address ~= computer.tmpAddress() then
        i = #bootCandidates + 1

        for j = 1, #bootFiles do
            if proxy.exists(bootFiles[j]) then
                bootFile = bootFiles[j]
                break
            end
        end

        bootCandidates[i] = {
            r = proxy,
            p = function(booting, y)
                centrizedSet(y, bootFile and ("Boot%s /%s from %s (%s)"):format(
                    booting and "ing" or "",
                    bootFile,
                    cutText(proxy.getLabel() or "N/A", 6),
                    cutText(address, booting and width > 80 and 36 or 6)
                ) or ("Boot from /%s (%s) isn't available"):format(
                    proxy.getLabel() or "N/A",
                    cutText(address, booting and width > 80 and 36 or 6)
                ), F, not booting and 0xFFFFFF)
            end
        }

        bootCandidates[i].b = function()
            local handle, data, chunk, success, err = proxy.open(bootFile, "r"), ""

            ::LOOP::
            chunk = proxy.read(handle, math.huge)
    
            if chunk then
                data = data .. chunk
                goto LOOP
            end
    
            proxy.close(handle)
            status("Hold any button to boot", F, math.huge, 0, function()
                if gpu then
                    clear()
                    bootCandidates[i].p(1, height / 2)
                end
                if computer.getBootAddress() ~= address then
                    computer.setBootAddress(address)
                end
                success, err = execute(data, "=" .. bootFile, setmetatable({}, {__index = _G}), 1)
                status(err, [[¯\_(ツ)_/¯]], math.huge, 0, computer.shutdown, err, success)
            end, F, 1) -- or config[3] == 0 --todo
        end or computer.uptime

        elementsBootables[i] = {
            proxy.getLabel() or "N/A",
            bootCandidates[i].b
        }
    end
end

local function updateCandidates(selected)
    bootCandidates = {}
    elementsBootables = {s = selected or 1}
    addCandidate(computer.getBootAddress())

    for address in next, component.list"file" do
        addCandidate(address ~= computer.getBootAddress() and address or "")
    end
end

local function bootloader()
    userChecked = 1
    ::UPDATE::
    local drawElements, correction, elementsPrimary, draw, selectedElements, signalType, code, newLabel, data, url, y, _ =
    
    function(elements, y, spaces, borderHeight, drawSelected, onDraw)
        local elementsLineLength, x = 0

        for i = 1, #elements do
            elementsLineLength = elementsLineLength + unicode.len(elements[i][1]) + spaces
        end

        elementsLineLength = elementsLineLength - spaces
        x = centrize(elementsLineLength)

        if onDraw then
            onDraw()
        end

        for i = 1, #elements do
            if elements.s == i and drawSelected then
                fill(x - spaces / 2, y - math.floor(borderHeight / 2), unicode.len(elements[i][1]) + spaces, borderHeight, 0x8cb9c5)
                set(x, y, elements[i][1], 0x8cb9c5, 0x002b36)
            else
                set(x, y, elements[i][1], 0x002b36, 0x8cb9c5)
            end

            x = x + unicode.len(elements[i][1]) + spaces
        end
    end

    draw = function()
        y = height / 2 - (#bootCandidates > 0 and -1 or 1)

        clear()
        drawElements(elementsBootables, y - 4, 8, 3, not selectedElements.p and 1, function()
            if #bootCandidates > 0 then
                _ = bootCandidates[elementsBootables.s].r

                bootCandidates[elementsBootables.s].p(F, y + 3)

                centrizedSet(y + 5, ("Storage %s%% / %s / %s"):format(
                    math.floor(_.spaceUsed() / (_.spaceTotal() / 100)),
                    _.isReadOnly() and "Read only" or "Read & Write",
                    _.spaceTotal() < 2 ^ 20 and "FDD" or _.spaceTotal() < 2 ^ 20 * 12 and "HDD" or "RAID")
                )

                for i = correction, #elementsPrimary do
                    elementsPrimary[i] = F
                end

                if not _.isReadOnly() then
                    elementsPrimary[correction] = {"Rename", function()
                        fill(1, y + 3, width, 3)
                        newLabel = input("New label: ", F, y + 3, 1)
            
                        if newLabel and #newLabel > 0 then
                            _.setLabel(newLabel)
                            updateCandidates(elementsBootables.s)
                        end
                    end}

                    elementsPrimary[correction + 1] = {"Format", function()
                        _.remove("/")
                        _.setLabel(F)
                        updateCandidates(elementsBootables.s)
                    end}
                end
            else
                centrizedSet(y + 3, "No drives available", F, 0xFFFFFF)
            end
        end)
        drawElements(elementsPrimary, y, 6, 1, selectedElements.p and 1 or F)
    end

    elementsPrimary = {
        s = 1,
        p = 1,
        {"Halt", computer.shutdown},
        {"Shell", function()
            clear()
            _ = setmetatable({
                print = print,
                proxy = proxy,
                sleep = sleep
            }, {__index = _G})

            ::LOOP::
            data = input("> ", 1, height, F, data)

            if data then
                print("> " .. data)
                set(1, height, ">")
                print(select(2, execute(data, "=shell", _)))
                goto LOOP
            end
        end},
        {"URL boot", function()
            fill(1, y + 3, width, 3)
            url = input("URL: ", F, y + 3, 1)

            if url and #url > 0 then
                local handle, data, chunk = proxy"net".request(url, F, F, {["user-agent"]="Cyan"}), ""

                if handle then
                    status"Downloading..."
                    ::LOOP::
                    chunk = handle.read()

                    if chunk then
                        data = data .. chunk
                        goto LOOP
                    end

                    status(select(2, execute(data, "=URL boot", setmetatable({}, {__index = _G}), 1)) or "is empty", "URL boot", math.huge, 0)
                else
                    status("Invalid URL", "Internet boot", math.huge, 0)
                end
            end
        end}
    }

    correction = #elementsPrimary + 1
    redraw = F
    gpuCheck()
    updateCandidates()
    selectedElements = #bootCandidates > 0 and elementsBootables or elementsPrimary
    draw()

    ::LOOP::
        signalType, _, _, code = pullSignal()

        if signalType == "F" then
            computer.shutdown()
        elseif signalType:match"mp" or redraw then
            goto UPDATE
        elseif signalType:match"do" then -- if you read this message please help they they forced me to do this
            selectedElements = 
            (code == 200 or code == 208) and (
                #bootCandidates > 0 and ( -- Up
                    selectedElements.p and elementsBootables or elementsPrimary
                ) or selectedElements
            ) or selectedElements

            selectedElements.s = 
            code == 203 and ( -- Left
                selectedElements.s == 1 and #selectedElements or selectedElements.s - 1
            ) or code == 205 and (
                selectedElements.s == #selectedElements and 1 or selectedElements.s + 1 -- Right
            ) or selectedElements.s
                
            if code == 28 then -- Enter
                selectedElements[selectedElements.s][2]()
            end

            draw()
        end
    goto LOOP
end

computer.getBootAddress = proxy"pro".getData
computer.setBootAddress = proxy"pro".setData
updateCandidates()
status("Hold ALT to stay in bootloader", F, math.huge, 56, bootloader, F)
for i = 1, #bootCandidates do
    bootCandidates[i].b()
end
status("No drives available", F, 0, F, bootloader, F, 1)