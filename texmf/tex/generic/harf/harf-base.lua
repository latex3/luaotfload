local hb = require("luaharfbuzz")

-- LuaTeX’s TFM structure indexes glyphs by character codes, so we fake it by
-- adding the maximum possible Unicode code point to the glyph id. This way
-- we have a simple mapping for all glyphs without interfering with any valid
-- Unicode code point.
--
-- LuaTeX use the first 256 characters above maximum Unicode character for
-- escaping raw bytes, so skip that as well.
hb.CH_GID_PREFIX = 0x110000 + 256

return hb
