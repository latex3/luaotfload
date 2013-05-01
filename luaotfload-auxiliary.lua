#!/usr/bin/env texlua
-----------------------------------------------------------------------
--         FILE:  luaotfload-auxiliary.lua
--  DESCRIPTION:  part of luaotfload
-- REQUIREMENTS:  luaotfload 2.2
--       AUTHOR:  Philipp Gesang (Phg), <phg42.2a@gmail.com>
--      VERSION:  1.0
--      CREATED:  2013-05-01 14:40:50+0200
-----------------------------------------------------------------------
--

--- this file addresses issue #24
--- https://github.com/lualatex/luaotfload/issues/24#

luaotfload                  = luaotfload or {}
luaotfload.aux              = luaotfload.aux or { }

config                      = config or { }
config.luaotfload           = config.luaotfload or { }

local utf8 = unicode.utf8

local aux = luaotfload.aux

-----------------------------------------------------------------------
---                          font patches
-----------------------------------------------------------------------

--[[doc--
This sets two dimensions apparently relied upon by the unicode-math
package.
--doc]]--

local set_sscale_dimens = function (fontdata)
  local mathconstants = fontdata.MathConstants
  local parameters    = fontdata.parameters
  if mathconstants then
    parameters[10] = mathconstants.ScriptPercentScaleDown or 70
    parameters[11] = mathconstants.ScriptScriptPercentScaleDown or 50
  end
  return fontdata
end

luatexbase.add_to_callback(
  "luaotfload.patch_font",
  set_sscale_dimens,
  "luaotfload.aux.set_sscale_dimens")

--- fontobj -> int
local lookup_units = function (fontdata)
  local metadata = fontdata.shared and fontdata.shared.rawdata.metadata
  if metadata and metadata.units_per_em then
    return metadata.units_per_em
  elseif fontdata.parameters and fontdata.parameters.units then
    return fontdata.parameters.units
  elseif fontdata.units then --- v1.x
    return fontdata.units
  end
  return 1000
end

--[[doc--
This callback corrects some values of the Cambria font.
--doc]]--
local patch_cambria_domh = function (fontdata)
  local mathconstants = fontdata.MathConstants
  if mathconstants and fontdata.psname == "CambriaMath" then
    --- my test Cambria has 2048
    local units_per_em = fontdata.units_per_em or lookup_units(fontdata)
    local sz           = fontdata.parameters.size or fontdata.size
    local mh           = 2800 / units_per_em * sz
    if mathconstants.DisplayOperatorMinHeight < mh then
      mathconstants.DisplayOperatorMinHeight = mh
    end
  end
end

luatexbase.add_to_callback(
  "luaotfload.patch_font",
  patch_cambria_domh,
  "luaotfload.aux.patch_cambria_domh")

-----------------------------------------------------------------------
---                              fonts
-----------------------------------------------------------------------

--- int -> int -> bool
local font_has_glyph = function (font_id, codepoint)
  local fontdata = fonts.hashes.identifiers[font_id]
  if fontdata then
    if fontdata.characters[codepoint] ~= nil then return true end
  end
  return false
end

aux.font_has_glyph = font_has_glyph

--- int -> bool
local current_font_has_glyph = function (codepoint)
  return font_has_glyph (font.current(), codepoint)
end

aux.current_font_has_glyph = current_font_has_glyph

local do_if_glyph_else = function (chr, positive, negative)
  local codepoint = tonumber(chr)
  if not codepoint then codepoint = utf8.byte(chr) end
  if current_font_has_glyph(codepoint) then
    tex.sprint(positive)
  else
    tex.sprint(negative)
  end
end

aux.do_if_glyph_else = do_if_glyph_else

-- vim:tw=71:sw=2:ts=2:expandtab
