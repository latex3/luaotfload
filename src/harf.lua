local harf = require("harf-base")

local define_font = require("harf-load")
local harf_node   = require("harf-node")

harf.callbacks = {
  define_font = define_font,
  pre_linebreak_filter = harf_node.process,
  hpack_filter = harf_node.process,
  post_linebreak_filter = harf_node.post_process,
  wrapup_run = harf_node.cleanup,
}

return harf
