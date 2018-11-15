local hb = require("harf-base")
local define_font   = require("harf-load")
local process_nodes = require("harf-node")

-- Change luaotfload’s default of preferring system fonts.
fonts.names.set_location_precedence {
  "local", "texmf", "system"
}

fonts.readers.harf = function(spec)
  local features = {}
  local options = {}
  local specefication = {
    features = features,
    options = options,
    path = spec.lookup == "path" and spec.name or spec.resolved,
    index = spec.sub and spec.sub - 1 or 0,
    size = spec.size,
    specification = spec.specification,
  }
  for key, val in next, spec.features.raw do
    if val == true or val == false then
      val = (val and '+' or '-')..key
      features[#features + 1] = hb.Feature.new(val)
    elseif key:len() == 4 and tonumber(val) then
      val = '+'..key..'='..tonumber(val) - 1
      features[#features + 1] = hb.Feature.new(val)
    else
      if key == "language" then val = hb.Language.new(val) end
      options[key] = val
    end
  end
  return define_font(specefication)
end

luatexbase.add_to_callback("pre_linebreak_filter", process_nodes,
                           "harf.process_nodes", 1)
luatexbase.add_to_callback("hpack_filter",         process_nodes,
                           "harf.process_nodes", 1)
