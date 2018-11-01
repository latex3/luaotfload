local hb = require("harf-base")

local cfftag  = hb.Tag.new("CFF ")
local cff2tag = hb.Tag.new("CFF2")
local os2tag  = hb.Tag.new("OS/2")

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
    local tags = face:get_table_tags()
    for i = 1, #tags do
      local tag = tags[i]
      if tag == cfftag or tag == cff2tag then
        fonttype = "opentype"
      elseif tag == os2tag then
        hasos2 = true
      end
    end
    tfmdata.format = fonttype

    tfmdata.type = "real"
    tfmdata.embedding = "subset"
    tfmdata.tounicode = 1

    local fontextents = font:get_h_extents()
    local ascender = fontextents and fontextents.ascender
    local descender = fontextents and fontextents.descender

    local characters = {}
    tfmdata.characters = characters

    -- Add dummy entries for all glyphs in the font. Shouldn’t be needed, but
    -- some glyphs disappear from the PDF otherwise. The actual loading is done
    -- after shaping.
    local glyphcount = face:get_glyph_count() - 1
    for gid = 0, glyphcount do
      characters[hb.CH_GID_PREFIX + gid] = { index = gid }
    end


    -- Then load all characters supported by the font, we reused the glyph data
    -- we loaded earlier.
    --
    -- Looks this is not strictly needed, though, since the shaped output will
    -- use glyph indices so these characters will be unused. Skipping loading
    -- all the characters speeds loading fonts with large character sets.
    --
    -- We sill load a handful of characters that LuaTeX either use for font
    -- metrics (ideally, LuaTeX should be updated to read these metrics from
    -- the font) or we for calculating space and xheight.
    --
    -- Note this makes the loader completely unusable without the shaper, but
    -- it wasn’t that much useful before.
    --
    local unicodes = { 0x0020 } -- space
    local space
    for _, uni in next, unicodes do
      local gid = font:get_nominal_glyph(uni)
      if gid then
        if uni == 0x0020 then -- SPACE
          space = font:get_glyph_h_advance(gid)
        end
      end
    end

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

    xheight = xheight or ascender / 2
    capheight = capheight or ascender
    stemv = stemv or 80 * mag

    -- LuaTeX uses `char_height(f, 'H')` for CapHeight.
    characters[0x0048] = { height = capheight }

    -- LuaTeX uses `char_width(f, '.') / 3` for StemV.
    characters[0x002E] = { width  = stemv * 3 }

    tfmdata.parameters = {
      slant = 0,
      space = space or mag * upem / 2,
      space_stretch = mag * upem / 2,
      space_shrink = mag * upem / 3,
      x_height = xheight,
      quad = mag * upem,
    }
  else
    tfmdata = font.read_tfm(name, size)
  end
  return tfmdata
end

callback.register("define_font", define_font)
