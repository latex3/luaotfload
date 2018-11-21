local harf = require("harf-base")

local define_font   = require("harf-load")
local process_nodes = require("harf-node")

harf.callbacks = {
  define_font = define_font,
  pre_linebreak_filter = process_nodes,
  hpack_filter = process_nodes,
}

return harf
