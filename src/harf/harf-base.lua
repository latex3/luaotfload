local hb = require("luaharfbuzz")

-- The engine’s TFM structure indexes glyphs by character codes, which means
-- all our glyphs need character codes. We fake them by adding the maximum
-- possible Unicode code point to the glyph id. This way we have a simple
-- mapping for all glyphs without interfering with any valid Unicode code
-- point.
--
-- The engine uses the first 256 code points outside valid Unicode code space
-- for escaping raw bytes, so we skip them in our prefix.
hb.CH_GID_PREFIX = 0x110000 + 256

-- Legacy TeX Input Method Disguised as Font Ligatures hack.
--
-- Single replacements, keyed by character to replace. Handled separately
-- because TeX ligaturing mechanism does not support one-to-one replacements.
local trep = {
  [0x0022] = 0x201D, -- ["]
  [0x0027] = 0x2019, -- [']
  [0x0060] = 0x2018, -- [`]
}

-- Ligatures. The value is a character "ligature" table as described in the
-- manual.
local tlig ={
  [0x2013] = { [0x002D] = { char = 0x2014 } }, -- [---]
  [0x002D] = { [0x002D] = { char = 0x2013 } }, -- [--]
  [0x0060] = { [0x0060] = { char = 0x201C } }, -- [``]
  [0x0027] = { [0x0027] = { char = 0x201D } }, -- ['']
  [0x0021] = { [0x0060] = { char = 0x00A1 } }, -- [!`]
  [0x003F] = { [0x0060] = { char = 0x00BF } }, -- [?`]
  [0x002C] = { [0x002C] = { char = 0x201E } }, -- [,,]
  [0x003C] = { [0x003C] = { char = 0x00AB } }, -- [<<]
  [0x003E] = { [0x003E] = { char = 0x00BB } }, -- [>>]
}

hb.texrep = trep
hb.texlig = tlig

return hb
