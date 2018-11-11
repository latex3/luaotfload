local hb = require("harf-base")

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

local function parse(str)
  local spec = { variants = {}, features = {}, options = {}}
  local name, options = str:match("%s*(.*)%s*:%s*(.*)%s*")

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
      else
        local key, val = opt:match("(.*)%s*=%s*(.*)")
        spec.options[key or opt] = val or true
      end
    end
  end
  return spec
end

local function define_font(name, size)
  local spec
  local tfmdata = nil
  local filename, index = nil, 0

  spec = type(name) == "string" and parse(name) or name

  if spec.file then
    filename = kpse.find_file(spec.file, "truetype fonts") or
               kpse.find_file(spec.file, "opentype fonts")
    index = spec.index
  else
    -- XXX support font names
  end

  local face = filename and hb.Face.new(filename, index)
  if face then
    if size < 0 then
      size = (-655.36) * size
    end

    local font = hb.Font.new(face)

    tfmdata = {}

    font:set_scale(size, size)

    tfmdata.name = name
    tfmdata.psname = face:get_name(hb.ot.NAME_ID_POSTSCRIPT_NAME)
    tfmdata.fullname = face:get_name(hb.ot.NAME_ID_FULL_NAME)
    tfmdata.filename = filename
    tfmdata.designsize = size
    tfmdata.size = size

    -- All LuaTeX seem to care about in font type is whether it has CFF table
    -- or not, so we check for that here.
    local fonttype = "truetype"
    local hasos2 = false
    local haspost = false
    local tags = face:get_table_tags()
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
    tfmdata.format = fonttype

    tfmdata.type = "real"
    tfmdata.embedding = "subset"
    tfmdata.tounicode = 1
    tfmdata.nomath = true

    local fontextents = font:get_h_extents()
    local ascender = fontextents and fontextents.ascender
    local descender = fontextents and fontextents.descender

    local characters = {}

    -- Add dummy entries for all glyphs in the font. Shouldn’t be needed, but
    -- some glyphs disappear from the PDF otherwise. The actual loading is done
    -- after shaping.
    --
    -- We don’t add entries for character supported by the font as the shaped
    -- output will use glyph indices so these characters will be unused.
    -- Skipping loading all the characters should speed loading fonts with
    -- large character sets.
    --
    local glyphcount = face:get_glyph_count() - 1
    for gid = 0, glyphcount do
      characters[hb.CH_GID_PREFIX + gid] = { index = gid }
    end

    local spacegid = font:get_nominal_glyph(0x0020)
    local space = spacegid and font:get_glyph_h_advance(spacegid)

    local upem =  face:get_upem()
    local mag = size / upem
    local xheight, capheight, stemv
    if hasos2 then
      local os2 = face:get_table(os2tag)
      local length = os2:get_length()
      local data = os2:get_data()
      if length >= 96 and string.unpack(">H", data) > 1 then
        local weightclass

        -- We don’t need much of the table, so we read from hard-coded offsets.
        weightclass = string.unpack(">H", data, 5)
        xheight = string.unpack(">H", data, 87) * mag
        capheight = string.unpack(">H", data, 89) * mag
        -- Magic formula from dvipdfmx.
        stemv = ((weightclass / 65) * (weightclass / 65) + 50) * mag
      end
    end

    local slant = 0
    if haspost then
      local post = face:get_table(posttag)
      local length = post:get_length()
      local data = post:get_data()
      if length >= 32 and string.unpack(">i4", data) <= 0x00030000 then
        local italicangle = string.unpack(">i4", data, 5) / 2^16
        if italicangle ~= 0 then
          slant = -math.tan(italicangle * math.pi / 180) * 65536.0
        end
      end
    end

    xheight = xheight or ascender / 2
    capheight = capheight or ascender
    stemv = stemv or 80 * mag
    space = space or size / 2

    -- LuaTeX (ab)uses the metrics of these characters for some font metrics.
    --
    -- `char_width(f, '.') / 3` for StemV.
    characters[0x002E] = { width  = stemv * 3 }
    -- `char_height(f, 'H')` for CapHeight.
    characters[0x0048] = { height = capheight }
    -- `char_height(f, 'h')` for Ascent.
    characters[0x0068] = { height = ascender }
    -- `-char_depth(f, 'y')` for Descent.
    characters[0x0079] = { depth = -descender }

    tfmdata.characters = characters

    tfmdata.hb = {
      spec = spec,
      face = face,
      font = font,
      ascender = ascender,
      descender = descender,
      loaded = {}, -- Cached loaded glyph data.
    }

    tfmdata.parameters = {
      slant = slant,
      space = space,
      space_stretch = space / 2,
      space_shrink = space / 3,
      x_height = xheight,
      quad = size,
      extra_space = space / 3,
      [8] = capheight, -- for XeTeX compatibility.
    }
  else
    tfmdata = font.read_tfm(name, size)
  end
  return tfmdata
end

return define_font
