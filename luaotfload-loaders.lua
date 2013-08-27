if not modules then modules = { } end modules ["loaders"] = {
    version   = "2.4",
    comment   = "companion to luaotfload.lua",
    author    = "Hans Hagen, Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local fonts           = fonts
local readers         = fonts.readers
local handlers        = fonts.handlers
local formats         = fonts.formats

local pfb_reader = function (specification)
  return readers.opentype (specification, "pfb", "type1")
end 
 
local pfa_reader = function (specification)
  return readers.opentype (specification, "pfa", "type1")
end

formats.pfa  = "type1"
readers.pfa  = pfa_reader
handlers.pfa = { }

formats.pfb  = "type1"
readers.pfb  = pfb_reader
handlers.pfb = { }

-- vim:tw=71:sw=2:ts=2:expandtab
