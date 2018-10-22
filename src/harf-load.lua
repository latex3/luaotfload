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
    local unicodes = face:get_unicodes()
    local space, xheight
    for _, uni in next, unicodes do
      local gid = font:get_nominal_glyph(uni)
      characters[uni] = characters[hb.CH_GID_PREFIX + gid]
      characters[uni].index = gid

      -- If this is space or no break space, save its advance width, we will
      -- need below.
      if uni == 0x0020 then
        space = characters[uni].width
      elseif space == nil and uni == 0x00A0 then
        space = characters[uni].width
      elseif xheight == nil and uni == 0x0078 then -- XXX get this from OS/2 table
        xheight = characters[uni].height
      end
    end

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
