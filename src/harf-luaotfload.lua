if not pcall(require, "luaharfbuzz") then
  luatexbase.module_error("harf", "'luaharfbuzz' module is required.")
end

local harf = require("harf")

local add_to_callback = luatexbase.add_to_callback
local define_font     = harf.callbacks.define_font

-- Change luaotfload’s default of preferring system fonts.
fonts.names.set_location_precedence {
  "local", "texmf", "system"
}

-- Register a reader for `harf` mode (`mode=harf` font option) so that we only
-- load fonts when explicitly requested. Fonts we load will be shaped by the
-- callbacks we register below.
fonts.readers.harf = function(spec)
  local features = {}
  local options = {}

  -- Rewrite luaotfload specification to look like what we expect.
  local specification = {
    features = features,
    options = options,
    path = spec.resolved or spec.name,
    index = spec.sub and spec.sub - 1 or 0,
    size = spec.size,
    specification = spec.specification,
  }

  for key, val in next, spec.features.raw do
    if key == "language" then val = harf.Language.new(val) end
    if key == "colr" then key = "palette" end
    if key:len() == 4 then
      -- 4-letter options are likely font features, but not always, so we do
      -- some checks below. We put non feature options in the `options` dict.
      if val == true or val == false then
        val = (val and '+' or '-')..key
        features[#features + 1] = harf.Feature.new(val)
      elseif tonumber(val) then
        val = '+'..key..'='..tonumber(val) - 1
        features[#features + 1] = harf.Feature.new(val)
      else
        options[key] = val
      end
    else
      options[key] = val
    end
  end
  return define_font(specification)
end

-- luatexbase does not know how to handle `wrapup_run` callback, teach it.
luatexbase.callbacktypes.wrapup_run = 1 -- simple
luatexbase.callbacktypes.get_char_tounicode = 1 -- simple

-- Register all Harf callbacks, except `define_font` which is handled above.
for name, func in next, harf.callbacks do
  if name ~= "define_font" then
    add_to_callback(name, func, "Harf "..name.." callback", 1)
  end
end
