local hb = require("harf-base")

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

    tfmdata = { }

    tfmdata.hb = {
      face = face,
      font = font,
    }

    font:set_scale(size, size)

    tfmdata.name = name
  -- XXX HarfBuzz does not expose name table yet
  -- https://github.com/harfbuzz/harfbuzz/pull/1254
  --tfmdata.psname = ??
  --tfmdata.fullname = ??
    tfmdata.filename = filename
    tfmdata.designsize = size
    tfmdata.size = size

    -- All LuaTeX seem to care about in font type is whether it has CFF table
    -- or not, so we check for that here.
    local fonttype = "truetype"
    local tags = face:get_table_tags()
    for i = 1, #tags do
      local tag = tostring(tags[i])
      if tag == "CFF " or tag == "CFF2" then
          fonttype = "opentype"
          break
      end
    end
    tfmdata.format = fonttype

    tfmdata.type = "real"
    tfmdata.embedding = "subset"
    tfmdata.tounicode = 1

    local fextents = font:get_h_extents()
    local ascender = fextents and fextents.ascender
    local descender = fextents and fextents.descender

    local characters = { }
    tfmdata.characters = characters

    -- Load all glyphs in the font and set basic info about them.
    for gid = 0, face:get_glyph_count() - 1 do
      local uni = hb.CH_GID_PREFIX + gid
      local extents = font:get_glyph_extents(gid)
      characters[uni] = {
        index = gid,
        width = font:get_glyph_h_advance(gid),
        height = extents and extents.y_bearing or ascender,
        depth = -(extents and extents.y_bearing + extents.height or descender),
      }
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
    --local unicodes = face:get_unicodes()
    local unicodes = { 0x0020, 0x0078, 0x0048, 0x002E } -- space, x, H, .
    local space, xheight
    for _, uni in next, unicodes do
      local gid = font:get_nominal_glyph(uni)
      if gid then
        characters[uni] = {}
        if uni == 0x0020 then -- SPACE
          space = characters[hb.CH_GID_PREFIX + gid].width
        elseif uni == 0x0078 then
          xheight = characters[hb.CH_GID_PREFIX + gid].height
        elseif uni == 0x0048 then
          characters[uni] = characters[hb.CH_GID_PREFIX + gid]
        elseif uni == 0x002E then
          characters[uni] = characters[hb.CH_GID_PREFIX + gid]
        end
      end
    end

    -- LuaTeX checks for these characters to calculate the corresponding font
    -- metrics.
  --characters[0x0048] = { height = capheight } -- LATIN CAPITAL LETTER H, XXX get from OS/2
  --characters[0x002E] = { width  = stemv     } -- FULL STOP, XXX What is stemv

    local upem =  face:get_upem()
    local mag = size / upem
    tfmdata.parameters = {
      slant = 0,
      space = space or mag * upem/2,
      space_stretch = mag * upem/2,
      space_shrink = mag * upem/3,
      x_height = xheight or 2 * mag * upem/5,
      quad = mag * upem,
    }
  else
    tfmdata = font.read_tfm(name, size)
  end
  return tfmdata
end

callback.register("define_font", define_font)
