local hb = require("harf-base")

local hbfonts = hb.fonts
local hbfonts = hbfonts or {}

local cfftag  = hb.Tag.new("CFF ")
local cff2tag = hb.Tag.new("CFF2")
local os2tag  = hb.Tag.new("OS/2")
local posttag = hb.Tag.new("post")

local function trim(str)
  return str:gsub("^%s*(.-)%s*$", "%1")
end

local function split(str, sep)
  if str then
    local result = string.explode(str, sep.."+")
    for i, s in next, result do
      result[i] = trim(result[i])
    end
    return result
  end
end

local function parse(str, size)
  if size < 0 then
    size = -655.36 * size
  end

  local name, options = str:match("%s*(.*)%s*:%s*(.*)%s*")
  local spec = {
    specification = str,
    size = size,
    variants = {}, features = {}, options = {},
  }

  name = trim(name or str)

  local filename = name:match("%[(.*)%]")
  if filename then
    -- [file]
    -- [file:index]
    filename = string.explode(filename, ":+")
    spec.file = filename[1]
    spec.index = tonumber(filename[2]) or 0
  else
    -- name
    -- name/variants
    local fontname, variants = name:match("(.-)%s*/%s*(.*)")
    spec.name = fontname or name
    spec.variants = split(variants, "/")
  end
  if options then
    options = split(options, ";+")
    for _, opt in next, options do
      if opt:find("[+-]") == 1 then
        local feature = hb.Feature.new(opt)
        spec.features[#spec.features + 1] = feature
      elseif opt ~= "" then
        local key, val = opt:match("(.*)%s*=%s*(.*)")
        if key == "language" then val = hb.Language.new(val) end
        spec.options[key or opt] = val or true
      end
    end
  end
  return spec
end

local function loadfont(spec)
  local path, index = spec.path, spec.index
  if not path then
    return nil
  end

  local key = string.format("%s:%d", path, index)
  local data = hbfonts[key]
  if data then
    return data
  end

  local hbface = hb.Face.new(path, index)
  if hbface then
    local hbfont = hb.Font.new(hbface)
    local upem = hbface:get_upem()

    -- All LuaTeX seem to care about in font type is whether it has CFF table
    -- or not, so we check for that here.
    local fonttype = "truetype"
    local hasos2 = false
    local haspost = false
    local tags = hbface:get_table_tags()
    for i = 1, #tags do
      local tag = tags[i]
      if tag == cfftag or tag == cff2tag then
        fonttype = "opentype"
      elseif tag == os2tag then
        hasos2 = true
      elseif tag == posttag then
        haspost = true
      end
    end

    local fontextents = hbfont:get_h_extents()
    local ascender = fontextents and fontextents.ascender or upem * .8
    local descender = fontextents and fontextents.descender or upem * .2

    local gid = hbfont:get_nominal_glyph(0x0020)
    local space = gid and hbfont:get_glyph_h_advance(gid) or upem / 2

    local xheight, capheight, stemv = nil, nil, nil
    if hasos2 then
      local os2 = hbface:get_table(os2tag)
      local length = os2:get_length()
      local data = os2:get_data()
      if length >= 96 and string.unpack(">H", data) > 1 then
        -- We don’t need much of the table, so we read from hard-coded offsets.
        local weightclass = string.unpack(">H", data, 5)
        -- Magic formula from dvipdfmx.
        stemv = ((weightclass / 65) * (weightclass / 65) + 50)
        xheight = string.unpack(">H", data, 87)
        capheight = string.unpack(">H", data, 89)
      end
    end

    xheight = xheight or ascender / 2
    capheight = capheight or ascender
    stemv = stemv or 80

    local slant = 0
    if haspost then
      local post = hbface:get_table(posttag)
      local length = post:get_length()
      local data = post:get_data()
      if length >= 32 and string.unpack(">i4", data) <= 0x00030000 then
        local italicangle = string.unpack(">i4", data, 5) / 2^16
        if italicangle ~= 0 then
          slant = -math.tan(italicangle * math.pi / 180) * 65536.0
        end
      end
    end

    -- Load CPAL palettes if avialable in the font.
    local palettes = nil
    if hbface:ot_color_has_palettes() and hbface:ot_color_has_layers() then
      local count = hbface:ot_color_palette_get_count()
      palettes = {}
      for i = 1, count do
        palettes[#palettes + 1] = hbface:ot_color_palette_get_colors(i)
      end
    end

    data = {
      face = hbface,
      font = hbfont,
      upem = upem,
      fonttype = fonttype,
      ascender = ascender,
      descender = descender,
      space = space,
      xheight = xheight,
      capheight = capheight,
      stemv = stemv,
      slant = slant,
      glyphcount = hbface:get_glyph_count(),
      psname = hbface:get_name(hb.ot.NAME_ID_POSTSCRIPT_NAME),
      fullname = hbface:get_name(hb.ot.NAME_ID_FULL_NAME),
      palettes = palettes,
      haspng = hbface:ot_color_has_png(),
      loaded = {}, -- Cached loaded glyph data.
    }

    hbfonts[key] = data
    return data
  end
end

local function scalefont(data, spec)
  local size = spec.size
  local options = spec.options
  local hbfont = data.font
  local upem = data.upem
  local ascender = data.ascender
  local descender = data.descender
  local space = data.space
  local stemv = data.stemv
  local capheight = data.capheight

  -- We shape in font units (at UPEM) and then scale output with the desired
  -- sfont size.
  local scale = size / upem
  hbfont:set_scale(upem, upem)

  -- Add dummy entries for all glyphs in the font. Shouldn’t be needed, but
  -- some glyphs disappear from the PDF otherwise. The actual loading is done
  -- after shaping.
  --
  -- We don’t add entries for character supported by the font as the shaped
  -- output will use glyph indices so these characters will be unused.
  -- Skipping loading all the characters should speed loading fonts with
  -- large character sets.
  --
  local characters = {}
  local glyphcount = data.glyphcount
  for gid = 0, glyphcount - 1 do
    characters[hb.CH_GID_PREFIX + gid] = { index = gid }
  end

  -- LuaTeX (ab)uses the metrics of these characters for some font metrics.
  --
  -- `char_width(f, '.') / 3` for StemV.
  characters[0x002E] = { width  = stemv * scale * 3 }
  -- `char_height(f, 'H')` for CapHeight.
  characters[0x0048] = { height = capheight * scale }
  -- `char_height(f, 'h')` for Ascent.
  characters[0x0068] = { height = ascender * scale }
  -- `-char_depth(f, 'y')` for Descent.
  characters[0x0079] = { depth = -descender * scale }

  -- Select font palette, we support `palette=index` option, and load the first
  -- one otherwise.
  local palettes = data.palettes
  local palette = palettes and palettes[tonumber(options.palette) or 1]

  return {
    name = spec.specification,
    filename = spec.path,
    designsize = size,
    psname = data.psname,
    fullname = data.fullname,
    size = size,
    type = "real",
    embedding = "subset",
    tounicode = 1,
    nomath = true,
    format = data.fonttype,
    characters = characters,
    parameters = {
      slant = data.slant,
      space = space * scale,
      space_stretch = space * scale / 2,
      space_shrink = space * scale / 3,
      x_height = data.xheight * scale,
      quad = size,
      extra_space = space * scale / 3,
      [8] = capheight * scale, -- for XeTeX compatibility.
    },
    hb = {
      scale = scale,
      spec = spec,
      palette = palette,
      shared = data,
    },
  }
end

local function define_font(name, size)
  local spec = type(name) == "string" and parse(name, size) or name
  if spec.file then
    spec.path = kpse.find_file(spec.file, "truetype fonts") or
                kpse.find_file(spec.file, "opentype fonts")
  else
    -- XXX support font names
  end

  local tfmdata = nil
  local hbdata = loadfont(spec)
  if hbdata then
    tfmdata = scalefont(hbdata, spec)
  else
    tfmdata = font.read_tfm(name, size)
  end
  return tfmdata
end

return define_font
