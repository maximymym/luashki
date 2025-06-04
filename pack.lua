-- pack.lua: lua54 pack.lua input.lua output.lua
local src, out = arg[1], arg[2]
local f        = assert(loadfile(src))
local bin      = string.dump(f, true)

-- простая Base64-поддержка, возьми любой чисто-Lua модуль
local b64mod   = require("base64")
local b64      = b64mod.encode(bin)

local template = [[
local b64    = %q
local dec    = require("base64").decode
local chunk  = dec(b64)
local fn     = assert(load(chunk, "@%s", "b"))
return fn(...)
]]
local outf = assert(io.open(out, "w"))
outf:write(template:format(b64, src))
outf:close()
print("Packed to "..out)
