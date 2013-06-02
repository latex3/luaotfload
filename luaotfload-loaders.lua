if not modules then modules = { } end modules ["loaders"] = {
    version   = 2.3,
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

-- vim:tw=71:sw=2:ts=2:expandtab
