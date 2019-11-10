-----------------------------------------------------------------------
--         FILE:  luaotfload-harf-define.lua
--  DESCRIPTION:  part of luaotfload / HarfBuzz / font definition
-----------------------------------------------------------------------
do -- block to avoid to many local variables error
 local ProvidesLuaModule = { 
     name          = "luaotfload-harf-define",
     version       = "3.11",       --TAGVERSION
     date          = "2019-11-10", --TAGDATE
     description   = "luaotfload submodule / database",
     license       = "GPL v2.0",
     author        = "Khaled Hosny, Marcel Krüger",
     copyright     = "Luaotfload Development Team",     
 }

 if luatexbase and luatexbase.provides_module then
  luatexbase.provides_module (ProvidesLuaModule)
 end  
end

local stringlower = string.lower
local stringupper = string.upper
local gsub = string.gsub

local hb = luaotfload.harfbuzz
local scriptlang_to_harfbuzz = require'luaotfload-scripts'.to_harfbuzz

local hbfonts = {}

local cfftag  = hb.Tag.new("CFF ")
local cff2tag = hb.Tag.new("CFF2")
local os2tag  = hb.Tag.new("OS/2")
local posttag = hb.Tag.new("post")
local glyftag = hb.Tag.new("glyf")

local invalid_l         = hb.Language.new()
local invalid_s         = hb.Script.new()

local containers = luaotfload.fontloader.containers
local hbcacheversion = 1.0
local facecache = containers.define("fonts", "hb", hbcacheversion, true)

local function loadfont(spec)
  local path, sub = spec.resolved, spec.sub or 1

  local key = string.format("%s:%d", gsub(path, "[/\\]", ":"), sub)

  local attributes = lfs.attributes(path)
  local size, date = attributes.size or 0, attributes.modification or 0

  local cached = containers.read(facecache, key)
  local iscached = cached and cached.date == date and cached.size == size

  local hbface = iscached and cached.face or hb.Face.new(path, sub - 1)
  local tags = hbface and hbface:get_table_tags()
  -- If the face has no table tags then it isn’t a valid SFNT font that
  -- HarfBuzz can handle.
  if not tags then return end
  local hbfont = iscached and cached.font or hb.Font.new(hbface)

  if not iscached then
    local upem = hbface:get_upem()

    -- The engine seems to use the font type to tell whether there is a CFF
    -- table or not, so we check for that here.
    local fonttype = nil
    local hasos2 = false
    local haspost = false
    for i = 1, #tags do
      local tag = tags[i]
      if tag == cfftag or tag == cff2tag then
        fonttype = "opentype"
      elseif tag == glyftag then
        fonttype = "truetype"
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

    -- Load glyph metrics for all glyphs in the font. We used to do this on
    -- demand to make loading fonts faster, but hit many limitations inside
    -- the engine (mainly with shared backend fonts, where the engine would
    -- assume all fonts it decides to share load the same set of glyphs).
    --
    -- Getting glyph advances is fast enough, but glyph extents are slower
    -- especially in CFF fonts. We might want to have an option to ignore exact
    -- glyph extents and use font ascender and descender if this proved to be
    -- too slow.
    local glyphcount = hbface:get_glyph_count()
    local glyphs = {}
    for gid = 0, glyphcount - 1 do
      local width = hbfont:get_glyph_h_advance(gid)
      local height, depth, italic = nil, nil, nil
      local extents = hbfont:get_glyph_extents(gid)
      if extents then
        height = extents.y_bearing
        depth = extents.y_bearing + extents.height
        if extents.x_bearing < 0 then
          italic = -extents.x_bearing
        end
      end
      glyphs[gid] = {
        width  = width,
        height = height or ascender,
        depth  = -(depth or descender),
        italic = italic or 0,
      }
    end

    local unicodes = hbface:collect_unicodes()
    local characters = {}
    local nominals = {}
    for _, uni in next, unicodes do
      local glyph = hbfont:get_nominal_glyph(uni)
      if glyph then
        characters[uni] = glyph
        nominals[glyph] = uni
      end
    end

    local xheight, capheight = 0, 0
    if hasos2 then
      local os2 = hbface:get_table(os2tag)
      local length = os2:get_length()
      local data = os2:get_data()
      if length >= 96 and string.unpack(">H", data) > 1 then
        -- We don’t need much of the table, so we read from hard-coded offsets.
        xheight = string.unpack(">H", data, 87)
        capheight = string.unpack(">H", data, 89)
      end
    end

    if xheight == 0 then
      local gid = characters[120] -- x
      if gid then
        xheight = glyphs[gid].height
      else
        xheight = ascender / 2
      end
    end

    if capheight == 0 then
      local gid = characters[88] -- X
      if gid then
        capheight = glyphs[gid].height
      else
        capheight = ascender
      end
    end

    cached = {
      date = date,
      size = size,
      gid_offset = 0x120000,
      upem = upem,
      fonttype = fonttype,
      space = space,
      xheight = xheight,
      capheight = capheight,
      slant = slant,
      glyphs = glyphs,
      nominals = nominals,
      unicodes = characters,
      psname = hbface:get_name(hb.ot.NAME_ID_POSTSCRIPT_NAME),
      fullname = hbface:get_name(hb.ot.NAME_ID_FULL_NAME),
      haspng = hbface:ot_color_has_png(),
      loaded = {}, -- Cached loaded glyph data.
    }

    containers.write(facecache, key, cached)
  end
  cached.face = hbface
  cached.font = hbfont
  return cached
end

-- Drop illegal characters from PS Name, per the spec
-- https://docs.microsoft.com/en-us/typography/opentype/spec/name#nid6
local function sanitize(psname)
  return psname:gsub('[][\0-\32\127-\255(){}<>/%%]', '-')
end

-- Ligatures. The value is a character "ligature" table as described in the
-- manual.
local tlig ={
  [0x2013] = { [0x002D] = { char = 0x2014 } }, -- [---]
  [0x002D] = { [0x002D] = { char = 0x2013 } }, -- [--]
  [0x0060] = { [0x0060] = { char = 0x201C } }, -- [``]
  [0x0027] = { [0x0027] = { char = 0x201D } }, -- ['']
  [0x0021] = { [0x0060] = { char = 0x00A1 } }, -- [!`]
  [0x003F] = { [0x0060] = { char = 0x00BF } }, -- [?`]
  [0x002C] = { [0x002C] = { char = 0x201E } }, -- [,,]
  [0x003C] = { [0x003C] = { char = 0x00AB } }, -- [<<]
  [0x003E] = { [0x003E] = { char = 0x00BB } }, -- [>>]
}

local function scalefont(data, spec)
  local size = spec.size
  local features = spec.features.normal
  features.mode = 'plug'
  features.features = 'harf'
  fonts.constructors.checkedfeatures("otf", features)
  local hbface = data.face
  local hbfont = data.font
  local upem = data.upem
  local space = data.space
  local gid_offset = data.gid_offset

  if size < 0 then
    size = -655.36 * size
  end

  -- We shape in font units (at UPEM) and then scale output with the desired
  -- sfont size.
  local scale = size / upem
  hbfont:set_scale(upem, upem)

  -- Populate font’s characters table.
  local glyphs = data.glyphs
  local characters = {}
  for gid, glyph in next, glyphs do
    characters[gid_offset + gid] = {
      index  = gid,
      width  = glyph.width  * scale,
      height = glyph.height * scale,
      depth  = glyph.depth  * scale,
      italic = glyph.italic * scale,
    }
  end

  local unicodes = data.unicodes
  for uni, gid in next, unicodes do
    characters[uni] = characters[gid_offset + gid]
  end

  -- Select font palette, we support `palette=index` option, and load the first
  -- one otherwise.
  local paletteidx = tonumber(features.palette or features.colr) or 1

  -- Load CPAL palette from the font.
  local palette = nil
  if hbface:ot_color_has_palettes() and hbface:ot_color_has_layers() then
    local count = hbface:ot_color_palette_get_count()
    if paletteidx <= count then
      palette = hbface:ot_color_palette_get_colors(paletteidx)
    end
  end

  local letterspace = 0
  if features.letterspace then
    letterspace = tonumber(features.letterspace) / 100 * upem
  elseif features.kernfactor then
    letterspace = tonumber(features.kernfactor) * upem
  end
  space = space + letterspace

  local slantfactor = nil
  if features.slant then
    slantfactor = tonumber(features.slant) * 1000
  end

  local mode = nil
  local width = nil
  if features.embolden then
    mode = 2
    -- The multiplication by 7200.0/7227 is to undo the opposite conversion
    -- the engine is doing and make the final number written in the PDF file
    -- match XeTeX’s.
    width = (size * tonumber(features.embolden) / 6553.6) * (7200.0/7227)
  end

  local hscale = upem
  local extendfactor = nil
  if features.extend then
    extendfactor = tonumber(features.extend) * 1000
    hscale = hscale * tonumber(features.extend)
  end

  local vscale = upem
  local squeezefactor = nil
  if features.squeeze then
    squeezefactor = tonumber(features.squeeze) * 1000
    vscale = vscale * tonumber(features.squeeze)
  end

  if features.tlig then
    for char in next, characters do
      local ligatures = tlig[char]
      if ligatures then
        characters[char].ligatures = ligatures
      end
    end
  end

  local tfmdata = {
    name = spec.specification,
    filename = spec.resolved,
    subfont = spec.sub or 1,
    designsize = size,
    psname = sanitize(data.psname),
    fullname = data.fullname,
    index = spec.index,
    size = size,
    units_per_em = upem,
    embedding = "subset",
    tounicode = 1,
    nomath = true,
    format = data.fonttype,
    slant = slantfactor,
    mode = mode,
    width = width,
    extend = extendfactor,
    squeeze = squeezefactor,
    characters = characters,
    parameters = {
      slant = data.slant,
      space = space * scale,
      space_stretch = space * scale / 2,
      space_shrink = space * scale / 3,
      x_height = data.xheight * scale,
      quad = size,
      extra_space = space * scale / 3,
      [8] = data.capheight * scale, -- for XeTeX compatibility.
    },
    hb = {
      scale = scale,
      spec = spec,
      palette = palette,
      shared = data,
      letterspace = letterspace,
      hscale = hscale,
      vscale = vscale,
    },
    specification = spec,
    shared = {},
    properties = {},
  }
  tfmdata.shared.processes = fonts.handlers.otf.setfeatures(tfmdata, features)
  return tfmdata
end

-- Register a reader for `harf` mode (`mode=harf` font option) so that we only
-- load fonts when explicitly requested. Fonts we load will be shaped by the
-- harf plugin in luaotfload-harf-plug.
fonts.readers.harf = function(spec)
  if not spec.resolved then return end
  local rawfeatures = spec.features.raw
  local hb_features = {}
  spec.hb_features = hb_features

  if rawfeatures.script then
    local script = stringlower(rawfeatures.script)
    if script == "dflt" then -- Probably a noop, HarfBuzz normalizes anyway
      script = "DFLT"
    end
    local language = stringupper(rawfeatures.language or 'dflt')
    language = language == "DFLT" and "dflt" or language
    local hb_script, hb_lang = scriptlang_to_harfbuzz(script, language)
    spec.script, spec.language = hb.Script.new(hb_script), hb.Language.new(hb_lang)
  elseif rawfeatures.language then
    local language = stringupper(rawfeatures.language)
    spec.language = hb.Language.new(language == "DFLT" and "dflt"
                                                        or language)
    spec.script = invalid_s
  else
    spec.script = invalid_s
    spec.language = invalid_l
  end
  for key, val in next, rawfeatures do
    if key:len() == 4 then
      -- 4-letter options are likely font features, but not always, so we do
      -- some checks below. Other options will be queried
      -- from spec.features.normal.
      if val == true or val == false then
        val = (val and '+' or '-')..key
        hb_features[#hb_features + 1] = hb.Feature.new(val)
      elseif tonumber(val) then
        val = '+'..key..'='..tonumber(val) - 1
        hb_features[#hb_features + 1] = hb.Feature.new(val)
      end
    end
  end
  return scalefont(loadfont(spec), spec)
end
