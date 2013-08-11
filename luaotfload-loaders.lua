if not modules then modules = { } end modules ["loaders"] = {
    version   = "2.3a",
    comment   = "companion to luaotfload.lua",
    author    = "Hans Hagen, Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local fonts   = fonts
local readers = fonts.readers

---
--- opentype reader (from font-otf.lua):
--- (spec : table) -> (suffix : string) -> (format : string) -> (font : table)
---

local pfb_reader = function (specification)
  return readers.opentype(specification,"pfb","type1")
end

local pfa_reader = function (specification)
  return readers.opentype(specification,"pfa","type1")
end

fonts.formats.pfb  = "type1"
fonts.readers.pfb  = pfb_reader
fonts.handlers.pfb = { }  --- empty, as with tfm

fonts.formats.pfa  = "type1"
fonts.readers.pfa  = pfa_reader
fonts.handlers.pfa = { }


resolvers.openbinfile = function (filename)
    if filename and filename ~= "" then
        local f = io.open(filename,"rb")
        if f then
            --logs.show_load(filename)
            local s = f:read("*a") -- io.readall(f) is faster but we never have large files here
            if checkgarbage then
                checkgarbage(#s)
            end
            f:close()
            if s then
                return true, s, #s
            end
        end
    end
    return loaders.notfound()
end

resolvers.loadbinfile = function (filename, filetype)

    local fname = kpse.find_file (filename, filetype)

    if fname and fname ~= "" then
        return resolvers.openbinfile(fname)
    else
        return resolvers.loaders.notfound()
    end

end

--[[ <EXPERIMENTAL> ]]

--[[doc--

  Here we load extra AFM libraries from Context.
  In fact, part of the AFM support is contained in font-ext.lua, for
  which the font loader has a replacement: luatex-fonts-ext.lua.
  However, this is only a stripped down version with everything AFM
  removed. For example, it lacks definitions of several AFM features
  like italic correction, protrusion, expansion and so on. In order to
  achieve full-fledged AFM support we will either have to implement our
  own version of these or consult with Hans whether he would consider
  including the AFM code with the font loader.

  For the time being we stick with two AFM-specific libraries:
  font-afm.lua and font-afk.lua. When combined, these already supply us
  with basic features like kerning and ligatures. The rest can be added
  in due time.

--doc]]--

require "luaotfload-font-afm.lua"
require "luaotfload-font-afk.lua"

--[[ </EXPERIMENTAL> ]]

-- vim:tw=71:sw=2:ts=2:expandtab
