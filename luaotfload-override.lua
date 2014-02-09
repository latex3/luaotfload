if not modules then modules = { } end modules ["luaotfload-override"] = {
    version   = "2.5",
    comment   = "companion to Luaotfload",
    author    = "Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2.0"
}

local findfile      = resolvers.findfile
local encodings     = fonts.encodings

local log           = luaotfload.log
local names_report  = log.names_report

--[[doc--

    Adobe Glyph List.
    -------------------------------------------------------------------

    Context provides a somewhat different font-age.lua from an unclear
    origin. Unfortunately, the file name it reads from is hard-coded
    in font-enc.lua, so we have to replace the entire table.

    This shouldn’t cause any complications. Due to its implementation
    the glyph list will be loaded upon loading a OTF or TTF for the
    first time during a TeX run. (If one sticks to TFM/OFM then it is
    never read at all.) For this reason we can install a metatable that
    looks up the file of our choosing and only falls back to the
    Context one in case it cannot be found.

--doc]]--

encodings.agl = { }

setmetatable(fonts.encodings.agl, { __index = function (t, k)
    if k ~= "unicodes" then
        return nil
    end
    local glyphlist = findfile "luaotfload-glyphlist.lua"
    if glyphlist then
        names_report("log", 1, "load", "loading the Adobe glyph list")
    else
        glyphlist = findfile "font-age.lua"
        names_report("both", 0, "load",
                     "loading the extended glyph list from ConTeXt")
    end
    local unicodes = dofile(glyphlist)
    encodings.agl  = { unicodes = unicodes }
    return unicodes
end })

-- vim:tw=71:sw=4:ts=4:expandtab
