local handle, data, chunk = component.proxy(component.list("internet")()).request("http://localhost:8080/cyan.lua"), ""

while true do
    chunk = handle.read(math.huge)
    if chunk then
        data = data .. chunk
    else
        break
    end
end
handle.close()

local chunk, err = load(data, "=stdin", "t")
if chunk then
    local success, err = xpcall(chunk, debug.traceback)

    if not success then
        error(err)
    end
else
    error(err)
end