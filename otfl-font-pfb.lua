local fonts = fonts

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
