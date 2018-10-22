local hb = require("luaharfbuzz")

-- buffer cluster levels
hb.Buffer.HB_BUFFER_CLUSTER_LEVEL_MONOTONE_GRAPHEMES  = 0
hb.Buffer.HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS = 1
hb.Buffer.HB_BUFFER_CLUSTER_LEVEL_CHARACTERS          = 2
hb.Buffer.HB_BUFFER_CLUSTER_LEVEL_DEFAULT             = hb.Buffer.HB_BUFFER_CLUSTER_LEVEL_MONOTONE_GRAPHEMES

-- special tags
hb.Tag.HB_TAG_NONE = hb.Tag.new()

-- special script codes (ISO 15924)
hb.Script.HB_SCRIPT_COMMON    = hb.Script.new("Zyyy")
hb.Script.HB_SCRIPT_INHERITED = hb.Script.new("Zinh")
hb.Script.HB_SCRIPT_UNKNOWN   = hb.Script.new("Zzzz")
hb.Script.HB_SCRIPT_INVALID   = hb.Script.from_iso15924_tag(hb.Tag.HB_TAG_NONE)

-- directions
hb.Direction.HB_DIRECTION_INVALID = hb.Direction.new("invalid")
hb.Direction.HB_DIRECTION_LTR = hb.Direction.new("ltr")
hb.Direction.HB_DIRECTION_RTL = hb.Direction.new("rtl")
hb.Direction.HB_DIRECTION_TTB = hb.Direction.new("ttb")
hb.Direction.HB_DIRECTION_BTT = hb.Direction.new("btt")

-- special languages
hb.Language.HB_LANGUAGE_INVALID = hb.Language.new()

hb.shape = function(font, buf, options)
  options = options or { }

  -- Apply options to buffer if they are set.
  if options.language then buf:set_language(options.language) end
  if options.script then buf:set_script(options.script) end
  if options.direction then buf:set_direction(options.direction) end

  -- Guess segment properties, in case all steps above have failed
  -- to set the right properties.
  buf:guess_segment_properties()

  local features = {}

  -- Parse features
  if type(options.features) == "string" then
    for fs in string.gmatch(options.features, '([^,]+)') do
      table.insert(features, hb.Feature.new(fs))
    end
  elseif type(options.features) == "table" then
    features = options.features
  elseif options.features then -- non-nil but not a string or table
    error("Invalid features option")
  end

  return hb.shape_full(font,buf,features)
end

return hb
