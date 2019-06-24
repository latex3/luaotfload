if not pcall(require, "luaharfbuzz") then
  luatexbase.module_error("harf", "'luaharfbuzz' module is required.")
end

local harf = require("harf")

local define_font     = harf.callbacks.define_font

-- Change luaotfload’s default of preferring system fonts.
fonts.names.set_location_precedence {
  "local", "texmf", "system"
}

local readers = {
  opentype = fonts.readers.opentype,
  otf = fonts.readers.otf,
  ttf = fonts.readers.ttf,
  ttc = fonts.readers.ttc,
}

local function harf_reader(spec)
  local features = {}
  local options = {}
  local rawfeatures = spec.features and spec.features.raw or {}

  local mode = rawfeatures.mode
  if mode and mode ~= "harf" then
    return readers[spec.forced](spec)
  end

  -- Rewrite luaotfload specification to look like what we expect.
  local specification = {
    features = features,
    options = options,
    path = spec.resolved or spec.name,
    index = spec.sub and spec.sub - 1 or 0,
    size = spec.size,
    specification = spec.specification,
  }

  for key, val in next, rawfeatures do
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

-- Register font readers. We override the default ones to always use HarfBuzz
-- if no mode is explicitly set or when `mode=harf` is used, otherwise we
-- fallback to the old readers. Fonts we load will be shaped by the callbacks
-- we register below.
fonts.readers.harf = harf_reader
fonts.readers.opentype = harf_reader
fonts.readers.otf = harf_reader
fonts.readers.ttf = harf_reader
fonts.readers.ttc = harf_reader

local GSUBtag = harf.Tag.new("GSUB")
local GPOStag = harf.Tag.new("GPOS")
local dflttag = harf.Tag.new("dflt")

local aux = luaotfload.aux

local aux_provides_script = aux.provides_script
aux.provides_script = function(fontid, script)
  local fontdata = font.getfont(fontid)
  local hbdata = fontdata and fontdata.hb
  if hbdata then
    local hbshared = hbdata.shared
    local hbface = hbshared.face

    local script = harf.Tag.new(script)
    for _, tag in next, { GSUBtag, GPOStag } do
      local scripts = hbface:ot_layout_get_script_tags(tag) or {}
      for i = 1, #scripts do
        if script == scripts[i] then return true end
      end
    end
    return false
  end
  return aux_provides_script(fontid, script)
end

local aux_provides_language = aux.provides_language
aux.provides_language = function(fontid, script, language)
  local fontdata = font.getfont(fontid)
  local hbdata = fontdata and fontdata.hb
  if hbdata then
    local hbshared = hbdata.shared
    local hbface = hbshared.face

    local script = harf.Tag.new(script)
    -- fontspec seems to incorrectly use “DFLT” for language instead of “dflt”.
    local language = harf.Tag.new(language == "DFLT" and "dflt" or language)

    for _, tag in next, { GSUBtag, GPOStag } do
      local scripts = hbface:ot_layout_get_script_tags(tag) or {}
      for i = 1, #scripts do
        if script == scripts[i] then
          if language == dflttag then
            -- By definition “dflt” language is always present.
            return true
          else
            local languages = hbface:ot_layout_get_language_tags(tag, i - 1) or {}
            for j = 1, #languages do
              if language == languages[j] then return true end
            end
          end
        end
      end
    end
    return false
  end
  return aux_provides_language(fontid, script, language)
end

local aux_provides_feature = aux.provides_feature
aux.provides_feature = function(fontid, script, language, feature)
  local fontdata = font.getfont(fontid)
  local hbdata = fontdata and fontdata.hb
  if hbdata then
    local hbshared = hbdata.shared
    local hbface = hbshared.face

    local script = harf.Tag.new(script)
    -- fontspec seems to incorrectly use “DFLT” for language instead of “dflt”.
    local language = harf.Tag.new(language == "DFLT" and "dflt" or language)
    local feature = harf.Tag.new(feature)

    for _, tag in next, { GSUBtag, GPOStag } do
      local _, script_idx = hbface:ot_layout_find_script(tag, script)
      local _, language_idx = hbface:ot_layout_find_language(tag, script_idx, language)
      if hbface:ot_layout_find_feature(tag, script_idx, language_idx, feature) then
        return true
      end
    end
    return false
  end
  return aux_provides_feature(fontid, script, language, feature)
end

local aux_font_has_glyph = aux.font_has_glyph
aux.font_has_glyph = function(fontid, codepoint)
  local fontdata = font.getfont(fontid)
  local hbdata = fontdata and fontdata.hb
  if hbdata then
    local hbshared = hbdata.shared
    local unicodes = hbshared.unicodes
    return unicodes[codepoint] ~= nil
  end
  return aux_font_has_glyph(fontid, codepoint)
end

local aux_slot_of_name = aux.slot_of_name
aux.slot_of_name = function(fontid, glyphname, unsafe)
  local fontdata = font.getfont(fontid)
  local hbdata = fontdata and fontdata.hb
  if hbdata then
    local hbshared = hbdata.shared
    local hbfont = hbshared.font

    local gid = hbfont:get_glyph_from_name(glyphname)
    if gid ~= nil then
      return gid + harf.CH_GID_PREFIX
    end
    return nil
  end
  return aux_slot_of_name(fontid, glyphname, unsafe)
end

local aux_name_of_slot = aux.name_of_slot
aux.name_of_slot = function(fontid, codepoint)
  local fontdata = font.getfont(fontid)
  local hbdata = fontdata and fontdata.hb
  if hbdata then
    local hbshared = hbdata.shared
    local hbfont = hbshared.font
    local characters = fontdata.characters
    local character = characters[codepoint]

    if character then
      local gid = characters[codepoint].index
      return hbfont:get_glyph_name(gid)
    end
    return nil
  end
  return aux_name_of_slot(fontid, codepoint)
end

-- luatexbase does not know how to handle `wrapup_run` callback, teach it.
luatexbase.callbacktypes.wrapup_run = 1 -- simple
luatexbase.callbacktypes.get_char_tounicode = 1 -- simple
luatexbase.callbacktypes.get_glyph_string = 1 -- simple

local base_callback_descriptions = luatexbase.callback_descriptions
local base_add_to_callback = luatexbase.add_to_callback
local base_remove_from_callback = luatexbase.remove_from_callback

-- Remove all existing functions from given callback, insert ours, then
-- reinsert the removed ones, so ours takes a priority.
local function add_to_callback(name, func)
  local saved_callbacks = {}, ff, dd
  for k, v in next, base_callback_descriptions(name) do
    saved_callbacks[k] = { base_remove_from_callback(name, v) }
  end
  base_add_to_callback(name, func, "Harf "..name.." callback")
  for _, v in next, saved_callbacks do
    base_add_to_callback(name, v[1], v[2])
  end
end

-- Register all Harf callbacks, except `define_font` which is handled above.
for name, func in next, harf.callbacks do
  if name ~= "define_font" then
    add_to_callback(name, func)
  end
end
