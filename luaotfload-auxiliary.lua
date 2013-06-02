#!/usr/bin/env texlua
-----------------------------------------------------------------------
--         FILE:  luaotfload-auxiliary.lua
--  DESCRIPTION:  part of luaotfload
-- REQUIREMENTS:  luaotfload 2.3
--       AUTHOR:  Khaled Hosny, Élie Roux, Philipp Gesang
--      VERSION:  2.3
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
local warning       = luaotfload.log
local fonthashes    = fonts.hashes
local identifiers   = fonthashes.identifiers

local fontid        = font.id
local texsprint     = tex.sprint

local dofile        = dofile
local getmetatable  = getmetatable
local setmetatable  = setmetatable
local utf8          = unicode.utf8
local stringlower   = string.lower
local stringformat  = string.format
local stringgsub    = string.gsub
local stringbyte    = string.byte
local stringfind    = string.find
local tablecopy     = table.copy

-----------------------------------------------------------------------
---                          font patches
-----------------------------------------------------------------------

--- https://github.com/khaledhosny/luaotfload/issues/54

local rewrite_fontname = function (tfmdata, specification)
  tfmdata.name = [["]] .. specification .. [["]]
end

luatexbase.add_to_callback(
  "luaotfload.patch_font",
  rewrite_fontname,
  "luaotfload.rewrite_fontname")

--- as of 2.3 the compatibility hacks for TL 2013 are made optional

if config.luaotfload.compatibility == true then

--[[doc--

The font object (tfmdata) structure has changed since version 1.x, so
in case other packages haven’t been updated we put fallbacks in place
where they’d expect them. Specifically we have in mind:

  · fontspec
  · unicode-math
  · microtype (most likely fixed till TL2013)

--doc]]--

--- fontobj -> fontobj
local add_fontdata_fallbacks = function (fontdata)
  if type(fontdata) == "table" then
    local fontparameters = fontdata.parameters
    local metadata
    if not fontdata.shared then --- that would be a tfm
      --- we can’t really catch everything that
      --- goes wrong; for some reason, fontspec.lua
      --- just assumes it always gets an otf object,
      --- so its capheight callback, which does not
      --- bother to do any checks, will access
      --- fontdata.shared no matter what ...
      fontdata.units = fontdata.units_per_em

    else --- otf
      metadata         = fontdata.shared.rawdata.metadata
      fontdata.name    = metadata.origname or fontdata.name
      fontdata.units   = fontdata.units_per_em
      fontdata.size    = fontdata.size or fontparameters.size
      local resources  = fontdata.resources
      --- for legacy fontspec.lua and unicode-math.lua
      fontdata.shared.otfdata = {
        pfminfo   = { os2_capheight = metadata.pfminfo.os2_capheight },
        metadata  = { ascent = metadata.ascent },
      }
      --- for microtype and fontspec
      --local fake_features = { }
      local fake_features = table.copy(resources.features)
      setmetatable(fake_features, { __index = function (tab, idx)
          warning("some package (probably fontspec) is outdated")
          warning(
            "attempt to index " ..
            "tfmdata.shared.otfdata.luatex.features (%s)",
            idx)
          --os.exit(1)
          return tab[idx]
        end,
      })
      fontdata.shared.otfdata.luatex = {
        unicodes = resources.unicodes,
        features = fake_features,
      }
    end
  end
  return fontdata
end

luatexbase.add_to_callback(
  "luaotfload.patch_font",
  add_fontdata_fallbacks,
  "luaotfload.fontdata_fallbacks")

--[[doc--

Additionally, the font registry is expected at fonts.identifiers
(fontspec) or fonts.ids (microtype), but in the meantime it has been
migrated to fonts.hashes.identifiers.  We’ll make luaotfload satisfy
those assumptions. (Maybe it’d be more appropriate to use
font.getfont() since Hans made it a harmless wrapper [1].)

[1] http://www.ntg.nl/pipermail/ntg-context/2013/072166.html

--doc]]--

fonts.identifiers = fonts.hashes.identifiers
fonts.ids         = fonts.hashes.identifiers

end

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
--- fontobj -> unit
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
---                      glyphs and characters
-----------------------------------------------------------------------

local agl = fonts.encodings.agl

--- int -> int -> bool
local font_has_glyph = function (font_id, codepoint)
  local fontdata = fonts.hashes.identifiers[font_id]
  if fontdata then
    if fontdata.characters[codepoint] ~= nil then return true end
  end
  return false
end

aux.font_has_glyph = font_has_glyph

--- undocumented

local raw_slot_of_name = function (font_id, glyphname)
  local fontdata = font.fonts[font_id]
  if fontdata.type == "virtual" then --- get base font for glyph idx
    local codepoint  = agl.unicodes[glyphname]
    local glyph      = fontdata.characters[codepoint]
    if fontdata.characters[codepoint] then
      return codepoint
    end
  end
  return false
end

--[[doc--

  This one is approximately “name_to_slot” from the microtype package;
  note that it is all about Adobe Glyph names and glyph slots in the
  font. The names and values may diverge from actual Unicode.

  http://www.adobe.com/devnet/opentype/archives/glyph.html

  The “unsafe” switch triggers a fallback lookup in the raw fonts
  table. As some of the information is stored as references, this may
  have unpredictable side-effects.

--doc]]--

--- int -> string -> bool -> (int | false)
local slot_of_name = function (font_id, glyphname, unsafe)
  local fontdata = identifiers[font_id]
  if fontdata then
    local unicode = fontdata.resources.unicodes[glyphname]
    if unicode then
      if type(unicode) == "number" then
        return unicode
      else
        return unicode[1] --- for multiple components
      end
--  else
--    --- missing
    end
  elseif unsafe == true then -- for Robert
    return raw_slot_of_name(font_id, glyphname)
  end
  return false
end

aux.slot_of_name = slot_of_name

--[[doc--

  Inverse of above; not authoritative as to my knowledge the official
  inverse of the AGL is the AGLFN. Maybe this whole issue should be
  dealt with in a separate package that loads char-def.lua and thereby
  solves the problem for the next couple decades.

  http://partners.adobe.com/public/developer/en/opentype/aglfn13.txt

--doc]]--

local indices

--- int -> (string | false)
local name_of_slot = function (codepoint)
  if not indices then --- this will load the glyph list
    local unicodes = agl.unicodes
    indices = table.swapped(unicodes)
  end
  local glyphname = indices[codepoint]
  if glyphname then
    return glyphname
  end
  return false
end

aux.name_of_slot      = name_of_slot

--[[doc--

  In Context, characters.data is where the data from char-def.lua
  resides. The file is huge (>3.7 MB as of 2013) and not part of the
  isolated font loader. Nevertheless, we include a partial version
  generated by the mkcharacters script that contains only the
  “direction” and “mirror” fields of each character defined.

--doc]]--

characters      = characters or { } --- should be created in basics-gen
characters.data = { }
local chardef   = "luaotfload-characters"

do
  local chardata
  local index = function (t, k)
    if chardata == nil then
      log("Loading character metadata from %s.", chardef)
      chardata = dofile(kpse.find_file("luaotfload-characters.lua"))
      if chardata == nil then
        warning("Could not load %s; continuing with empty character table.",
                chardef)
        chardata = { }
      end
    end
    return chardata[k]
  end

  local mt = getmetatable(characters.data)
  if mt then
    mt.__index = index
  else
    setmetatable(characters.data, { __index = index })
  end
end

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

--- int -> string -> int
local get_math_dimension = function (font_id, dimenname)
  if type(font_id) == "string" then
    font_id = fontid(font_id) --- safeguard
  end
  local fontdata  = identifiers[font_id]
  local mathdata  = fontdata.mathparameters
  if mathdata then
    return mathdata[dimenname] or 0
  end
  return 0
end

aux.get_math_dimension = get_math_dimension

--- int -> string -> unit
local sprint_math_dimension = function (font_id, dimenname)
  if type(font_id) == "string" then
    font_id = fontid(font_id)
  end
  local dim = get_math_dimension(font_id, dimenname)
  texsprint(luatexbase.catcodetables["latex-package"], dim, "sp")
end

aux.sprint_math_dimension = sprint_math_dimension

-----------------------------------------------------------------------
---                    extra database functions
-----------------------------------------------------------------------

local namesresolve      = fonts.names.resolve
local namesscan_dir     = fonts.names.scan_dir

--- local directories -------------------------------------------------

--- migrated from luaotfload-database.lua
--- https://github.com/lualatex/luaotfload/pull/61#issuecomment-17776975

--- string -> (int * int)
local scan_external_dir = function (dir)
  local old_names, new_names = names.data
  if not old_names then
    old_names = load_names()
  end
  new_names = tablecopy(old_names)
  local n_scanned, n_new = scan_dir(dir, old_names, new_names)
  --- FIXME
  --- This doesn’t seem right. If a db update is triggered after this
  --- point, then the added fonts will be saved along with it --
  --- which is not as “temporarily” as it should be. (This should be
  --- addressed during a refactoring of names_resolve().)
  names.data = new_names
  return n_scanned, n_new
end

aux.scan_external_dir = scan_external_dir

--- db queries --------------------------------------------------------

--- https://github.com/lualatex/luaotfload/issues/74
--- string -> (string * int)
local resolve_fontname = function (name)
  local foundname, subfont, success = namesresolve(nil, nil, {
          name          = name,
          lookup        = "name",
          optsize       = 0,
          specification = "name:" .. name,
  })
  if success then
    return foundname, subfont
  end
  return false, false
end

aux.resolve_fontname = resolve_fontname

--- string list -> (string * int)
local resolve_fontlist
resolve_fontlist = function (names, n)
  if not n then
    return resolve_fontlist(names, 1)
  end
  local this = names[n]
  if this then
    local foundname, subfont = resolve_fontname(this)
    if foundname then
      return foundname, subfont
    end
    return resolve_fontlist(names, n+1)
  end
  return false, false
end

aux.resolve_fontlist = resolve_fontlist

--- loaded fonts ------------------------------------------------------

--- just a proof of concept

--- fontobj -> string list -> (string list) list
local get_font_data get_font_data = function (tfmdata, keys, acc, n)
  if not acc then
    return get_font_data(tfmdata, keys, {}, 1)
  end
  local key = keys[n]
  if key then
    local val = tfmdata[key]
    if val then
      acc[#acc+1] = val
    else
      acc[#acc+1] = false
    end
    return get_font_data(tfmdata, keys, acc, n+1)
  end
  return acc
end

--[[doc--

    The next one operates on the fonts.hashes.identifiers table.
    It returns a list containing tuples of font ids and the
    contents of the fields specified in the first argument.
    Font table entries that were created indirectly -- e.g. by
    \letterspacefont or during font expansion -- will not be
    listed.

--doc]]--

local default_keys = { "fullname" }

--- string list -> (int * string list) list
local get_loaded_fonts get_loaded_fonts = function (keys, acc, lastid)
  if not acc then
    if not keys then
      keys = default_keys
    end
    return get_loaded_fonts(keys, {}, lastid)
  end
  local id, tfmdata = next(identifiers, lastid)
  if id then
    local data = get_font_data(tfmdata, keys)
    acc[#acc+1] = { id, data }
    return get_loaded_fonts (keys, acc, id)
  end
  return acc
end

aux.get_loaded_fonts = get_loaded_fonts

--- Raw access to the font.* namespace is unsafe so no documentation on
--- this one.
local get_raw_fonts = function ( )
  local res = { }
  for i, v in font.each() do
    if v.filename then
      res[#res+1] = { i, v }
    end
  end
  return res
end

aux.get_raw_fonts = get_raw_fonts

-----------------------------------------------------------------------
---                         font parameters
-----------------------------------------------------------------------
--- analogy of font-hsh

fonthashes.parameters    = fonthashes.parameters or { }
fonthashes.quads         = fonthashes.quads or { }

local parameters         = fonthashes.parameters or { }
local quads              = fonthashes.quads or { }

setmetatable(parameters, { __index = function (t, font_id)
  local tfmdata = identifiers[font_id]
  if not tfmdata then --- unsafe; avoid
    tfmdata = font.fonts[font_id]
  end
  if tfmdata and type(tfmdata) == "table" then
    local fontparameters = tfmdata.parameters
    t[font_id] = fontparameters
    return fontparameters
  end
  return nil
end})

--[[doc--

  Note that the reason as to why we prefer functions over table indices
  is that functions are much safer against unintended manipulation.
  This justifies the overhead they cost.

--doc]]--

--- int -> (number | false)
local get_quad = function (font_id)
  local quad = quads[font_id]
  if quad then
    return quad
  end
  local fontparameters = parameters[font_id]
  if fontparameters then
    local quad     = fontparameters.quad or 0
    quads[font_id] = quad
    return quad
  end
  return false
end

aux.get_quad = get_quad

-- vim:tw=71:sw=2:ts=2:expandtab
