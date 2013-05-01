#!/usr/bin/env texlua
-----------------------------------------------------------------------
--         FILE:  luaotfload-auxiliary.lua
--  DESCRIPTION:  part of luaotfload
-- REQUIREMENTS:  luaotfload 2.2
--       AUTHOR:  Khaled Hosny, Élie Roux, Philipp Gesang
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

local aux           = luaotfload.aux
local log           = luaotfload.log
local identifiers   = fonts.hashes.identifiers

local fontid        = font.id
local texsprint     = tex.sprint

local utf8          = unicode.utf8
local stringlower   = string.lower
local stringformat  = string.format
local stringgsub    = string.gsub
local stringbyte    = string.byte

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

--[[doc--

Comment from fontspec:

 “Here we patch fonts tfm table to emulate \XeTeX's \cs{fontdimen8},
  which stores the caps-height of the font. (Cf.\ \cs{fontdimen5} which
  stores the x-height.)

  Falls back to measuring the glyph if the font doesn't contain the
  necessary information.
  This needs to be extended for fonts that don't contain an `X'.”

--doc]]--

local set_capheight = function (fontdata)
    local shared     = fontdata.shared
    local parameters = fontdata.parameters
    local capheight
    if shared then
      local units_per_em   = parameters.units
      local size           = parameters.size
      local os2_capheight  = shared.rawdata.metadata.pfminfo.os2_capheight

      if os2_capheight > 0 then
        capheight = os2_capheight / units_per_em * size
      else
        local X8 = stringbyte"X"
        if fontdata.characters[X8] then
          capheight = fontdata.characters[X8].height
        else
          capheight = parameters.ascender / units_per_em * size
        end
      end
    else
      local X8 = stringbyte"X"
      if fontdata.characters[X8] then
        capheight = fontdata.characters[X8].height
      end
    end
    if capheight then
      --- is this legit? afaics there’s nothing else on the
      --- array part of that table
      fontdata.parameters[8] = capheight
    end
end

luatexbase.add_to_callback(
  "luaotfload.patch_font",
  set_capheight,
  "luaotfload.aux.set_capheight")

-----------------------------------------------------------------------
---                             glyphs
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

--- this one is approximately “name_to_slot” from the microtype
--- package

--- string -> (int | false)
local codepoint_of_name = function (glyphname)
  local fontdata = identifiers[font.current()]
  if fontdata then
    local unicode = fontdata.resources.unicodes[glyphname]
    if unicode and type(unicode) == "number" then
      return unicode
    else
      return unicode[1] --- again, does that even happen?
    end
  end
  return false
end

aux.codepoint_of_name = codepoint_of_name

--- inverse of above

local indices

--- int -> (string | false)
local name_of_codepoint = function (codepoint)
  if not indices then --- this will load the glyph list
    local unicodes = fonts.encodings.agl.unicodes
    indices = table.swapped(unicodes)
  end
  local glyphname = indices[codepoint]
  if glyphname then
    return glyphname
  end
  return false
end

aux.name_of_codepoint = name_of_codepoint

-----------------------------------------------------------------------
---                 features / scripts / languages
-----------------------------------------------------------------------
--- lots of arrowcode ahead

--[[doc--
This function, modeled after “check_script()” from fontspec, returns
true if in the given font, the script “asked_script” is accounted for in at
least one feature.
--doc]]--

--- int -> string -> bool
local provides_script = function (font_id, asked_script)
  asked_script = stringlower(asked_script)
  if font_id and font_id > 0 then
    local fontdata = identifiers[font_id].shared.rawdata
    if fontdata then
      local fontname = fontdata.metadata.fontname
      local features = fontdata.resources.features
      for method, featuredata in next, features do
        --- where method: "gpos" | "gsub"
        for feature, data in next, featuredata do
          if data[asked_script] then
            log(stringformat(
              "font no %d (%s) defines feature %s for script %s",
              font_id, fontname, feature, asked_script))
            return true
          end
        end
      end
      log(stringformat(
        "font no %d (%s) defines no feature for script %s",
        font_id, fontname, asked_script))
    end
  end
  log(stringformat("no font with id %d", font_id))
  return false
end

aux.provides_script = provides_script

--[[doc--
This function, modeled after “check_language()” from fontspec, returns
true if in the given font, the language with tage “asked_language” is
accounted for in the script with tag “asked_script” in at least one
feature.
--doc]]--

--- int -> string -> string -> bool
local provides_language = function (font_id, asked_script, asked_language)
  asked_script     = stringlower(asked_script)
  asked_language   = stringlower(asked_language)
  if font_id and font_id > 0 then
    local fontdata = identifiers[font_id].shared.rawdata
    if fontdata then
      local fontname = fontdata.metadata.fontname
      local features = fontdata.resources.features
      for method, featuredata in next, features do
        --- where method: "gpos" | "gsub"
        for feature, data in next, featuredata do
          local scriptdata = data[asked_script]
          if scriptdata and scriptdata[asked_language] then
            log(stringformat("font no %d (%s) defines feature %s "
                          .. "for script %s with language %s",
                             font_id, fontname, feature,
                             asked_script, asked_language))
            return true
          end
        end
      end
      log(stringformat(
        "font no %d (%s) defines no feature for script %s with language %s",
        font_id, fontname, asked_script, asked_language))
    end
  end
  log(stringformat("no font with id %d", font_id))
  return false
end

aux.provides_language = provides_language

--[[doc--
We strip the syntax elements from feature definitions (shouldn’t
actually be there in the first place, but who cares ...)
--doc]]--

local lpeg        = require"lpeg"
local C, P, S     = lpeg.C, lpeg.P, lpeg.S
local lpegmatch   = lpeg.match

local sign            = S"+-"
local rhs             = P"=" * P(1)^0 * P(-1)
local strip_garbage   = sign^-1 * C((1 - rhs)^1)

--s   = "+foo"        --> foo
--ss  = "-bar"        --> bar
--sss = "baz"         --> baz
--t   = "foo=bar"     --> foo
--tt  = "+bar=baz"    --> bar
--ttt = "-baz=true"   --> baz
--
--print(lpeg.match(strip_garbage, s))
--print(lpeg.match(strip_garbage, ss))
--print(lpeg.match(strip_garbage, sss))
--print(lpeg.match(strip_garbage, t))
--print(lpeg.match(strip_garbage, tt))
--print(lpeg.match(strip_garbage, ttt))

--[[doc--
This function, modeled after “check_feature()” from fontspec, returns
true if in the given font, the language with tag “asked_language” is
accounted for in the script with tag “asked_script” in feature
“asked_feature”.
--doc]]--

--- int -> string -> string -> string -> bool
local provides_feature = function (font_id,        asked_script,
                                   asked_language, asked_feature)
  asked_script    = stringlower(asked_script)
  asked_language  = stringlower(asked_language)
  asked_feature   = lpegmatch(strip_garbage, asked_feature)

  if font_id and font_id > 0 then
    local fontdata = identifiers[font_id].shared.rawdata
    if fontdata then
      local features = fontdata.resources.features
      local fontname = fontdata.metadata.fontname
      for method, featuredata in next, features do
        --- where method: "gpos" | "gsub"
        local feature = featuredata[asked_feature]
        if feature then
          local scriptdata = feature[asked_script]
          if scriptdata and scriptdata[asked_language] then
            log(stringformat("font no %d (%s) defines feature %s "
                          .. "for script %s with language %s",
                             font_id, fontname, asked_feature,
                             asked_script, asked_language))
            return true
          end
        end
      end
      log(stringformat(
        "font no %d (%s) does not define feature %s for script %s with language %s",
        font_id, fontname, asked_feature, asked_script, asked_language))
    end
  end
  log(stringformat("no font with id %d", font_id))
  return false
end

aux.provides_feature = provides_feature

-----------------------------------------------------------------------
---                         font dimensions
-----------------------------------------------------------------------

--- string -> string -> int
local get_math_dimension = function (csname, dimenname)
  local fontdata  = identifiers[fontid(csname)]
  local mathdata  = fontdata.mathparameters
  if mathdata then return mathdata[dimenname] or 0 end
  return 0
end

aux.get_math_dimension = get_math_dimension

--- string -> string -> unit
local sprint_math_dimension = function (csname, dimenname)
  local dim = get_math_dimension(csname, dimenname)
  texsprint(luatexbase.catcodetables["latex-package"], dim)
  texsprint(luatexbase.catcodetables["latex-package"], "sp")
end

aux.sprint_math_dimension = sprint_math_dimension

-- vim:tw=71:sw=2:ts=2:expandtab
