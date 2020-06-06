local file = io.open("cyan.lua", "r")
local data = file:read("*a")
file:close()

local lzss = require("lzss")
local file = io.open("cyan.comp", "w")
file:write(lzss.getSXF(lzss.compress(data), true))