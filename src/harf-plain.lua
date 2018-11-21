local define_font   = require("harf-load")
local process_nodes = require("harf-node")

callback.register("define_font",          define_font)
callback.register('pre_linebreak_filter', process_nodes)
callback.register('hpack_filter',         process_nodes)
