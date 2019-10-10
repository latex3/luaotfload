local harf = luaharfbuzz or require'luaharfbuzz'

local define_font = require("harf-load")
local harf_node   = require("harf-node")

local callback_warning = true
if callback_warning then
  local callbacks = callback.list()
  if callbacks["get_glyph_string"] == nil then
    luatexbase.module_warning("harf",
      "'get_glyph_string' callback is missing, " ..
      "log messages might show garbage.")
  end
  callback_warning = false
end

-- Register a reader for `harf` mode (`mode=harf` font option) so that we only
-- load fonts when explicitly requested. Fonts we load will be shaped by the
-- callbacks we register below.
fonts.readers.harf = function(spec)
  local rawfeatures = spec.features.raw
  local hb_features = {}
  spec.hb_features = hb_features

  if rawfeatures.language then
    spec.language = harf.Language.new(rawfeatures.language)
  end
  if rawfeatures.script then
    spec.script = harf.Script.new(rawfeatures.script)
  end
  for key, val in next, rawfeatures do
    if key:len() == 4 then
      -- 4-letter options are likely font features, but not always, so we do
      -- some checks below. We put non feature options in the `options` dict.
      if val == true or val == false then
        val = (val and '+' or '-')..key
        hb_features[#hb_features + 1] = harf.Feature.new(val)
      elseif tonumber(val) then
        val = '+'..key..'='..tonumber(val) - 1
        hb_features[#hb_features + 1] = harf.Feature.new(val)
      end
    end
  end
  return define_font(spec)
end

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
    local nominals = hbshared.nominals
    local hbfont = hbshared.font

    local gid = hbfont:get_glyph_from_name(glyphname)
    if gid ~= nil then
      return nominals[gid] or gid + hbshared.gid_offset
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

add_to_callback('pre_output_filter', harf_node.post_process)
add_to_callback('wrapup_run', harf_node.cleanup)
add_to_callback('finish_pdffile', harf_node.set_tounicode)
add_to_callback('get_glyph_string', harf_node.get_glyph_string)
