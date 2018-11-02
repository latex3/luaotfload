local hb = require("harf-base")

local cfftag  = hb.Tag.new("CFF ")
local cff2tag = hb.Tag.new("CFF2")
local os2tag  = hb.Tag.new("OS/2")
local posttag = hb.Tag.new("post")

local function define_font(name, size)
  local tfmdata
  local filename = kpse.find_file(name, "truetype fonts") or
                   kpse.find_file(name, "opentype fonts")

  local face = filename and hb.Face.new(filename)
  if face then
    if size < 0 then
      size = (-655.36) * size
    end

    local font = hb.Font.new(face)

    tfmdata = {}

    tfmdata.hb = {
      face = face,
      font = font,
      loaded = {}, -- { gid=true } for glyphs we loaded their metrics.
    }

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
    tfmdata.characters = characters

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


    tfmdata.parameters = {
      slant = slant,
      space = space,
      space_stretch = space / 2,
      space_shrink = space / 3,
      x_height = xheight,
      quad = size,
      extra_space = space / 3,
    }
  else
    tfmdata = font.read_tfm(name, size)
  end
  return tfmdata
end

callback.register("define_font", define_font)
