local harf = require("harf-base")

local define_font = require("harf-load")
local harf_node   = require("harf-node")

harf.callbacks = {
  define_font = define_font,
  pre_linebreak_filter = harf_node.process,
  hpack_filter = harf_node.process,
  pre_output_filter = harf_node.post_process,
  wrapup_run = harf_node.cleanup,
  get_char_tounicode = harf_node.get_tounicode,
  get_glyph_string = harf_node.get_glyph_string,
}

return harf
