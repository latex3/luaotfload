local hb = require("luaharfbuzz")

-- LuaTeX’s TFM structure indexes glyphs by character codes, so we fake it by
-- adding the maximum possible Unicode code point to the glyph id. This way
-- we have a simple mapping for all glyphs without interfering with any valid
-- Unicode code point.
hb.CH_GID_PREFIX = 0x110000

return hb
