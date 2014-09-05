#!/usr/bin/env texlua
-----------------------------------------------------------------------
--         FILE:  luaotfload-auxiliary.lua
--  DESCRIPTION:  part of luaotfload
-- REQUIREMENTS:  luaotfload 2.5
--       AUTHOR:  Khaled Hosny, Élie Roux, Philipp Gesang
--      VERSION:  2.5
--     MODIFIED:  2014-01-02 21:24:25+0100
-----------------------------------------------------------------------
--

--- this file addresses issue #24
--- https://github.com/lualatex/luaotfload/issues/24#

luaotfload                  = luaotfload or {}
luaotfload.aux              = luaotfload.aux or { }

local aux                   = luaotfload.aux
local log                   = luaotfload.log
local report                = log.report
local fonthashes            = fonts.hashes
local identifiers           = fonthashes.identifiers
local fontnames             = fonts.names

local fontid                = font.id
local texsprint             = tex.sprint

local dofile                = dofile
local getmetatable          = getmetatable
local setmetatable          = setmetatable
local utf8                  = unicode.utf8
local stringlower           = string.lower
local stringformat          = string.format
local stringgsub            = string.gsub
local stringbyte            = string.byte
local stringfind            = string.find
local tablecopy             = table.copy

-----------------------------------------------------------------------
---                          font patches
-----------------------------------------------------------------------

--- https://github.com/khaledhosny/luaotfload/issues/54

local rewrite_fontname = function (tfmdata, specification)
  tfmdata.name = [["]] .. specification .. [["]]
end

local rewriting = false

local start_rewrite_fontname = function ()
  if rewriting == false then
    luatexbase.add_to_callback (
      "luaotfload.patch_font",
      rewrite_fontname,
      "luaotfload.rewrite_fontname")
    rewriting = true
    report ("log", 1, "aux",
            "start rewriting tfmdata.name field")
  end
end

aux.start_rewrite_fontname = start_rewrite_fontname

local stop_rewrite_fontname = function ()
  if rewriting == true then
    luatexbase.remove_fromt_callback
      ("luaotfload.patch_font", "luaotfload.rewrite_fontname")
    rewriting = false
    report ("log", 1, "aux",
            "stop rewriting tfmdata.name field")
  end
end

aux.stop_rewrite_fontname = stop_rewrite_fontname


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
    if shared and shared.rawdata.metadata.pfminfo then
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
  a subset of the fields of each character defined.

  Currently, these are (compare the mkcharacters script!)

    · "direction"
    · "mirror"
    · "category"
    · "textclass"

  The directional information is required for packages like Simurgh [0]
  to work correctly. In an early stage [1] it was necessary to load
  further files from Context directly, including the full blown version
  of char-def.  Since we have no use for most of the so imported
  functionality, the required parts have been isolated and are now
  instated along with luaotfload-characters.lua. We can extend the set
  of imported features easily should it not be enough.

  [0] https://github.com/persian-tex/simurgh
  [1] http://tex.stackexchange.com/a/132301/14066

--doc]]--

characters         = characters or { } --- should be created in basics-gen
characters.data    = nil
local chardef      = "luaotfload-characters"

do
  local setmetatableindex = function (t, f)
    local mt = getmetatable (t)
    if mt then
      mt.__index = f
    else
      setmetatable (t, { __index = f })
    end
  end

  --- there are some special tables for each field that provide access
  --- to fields of the character table by means of a metatable

  local mkcharspecial = function (characters, tablename, field)

    local chardata = characters.data

    if chardata then
      local newspecial        = { }
      characters [tablename]  = newspecial --> e.g. “characters.data.mirrors”

      local idx = function (t, char)
        local c = chardata [char]
        if c then
          local m = c [field] --> e.g. “mirror”
          if m then
            t [char] = m
            return m
          end
        end
        newspecial [char] = false
        return char
      end

      setmetatableindex (newspecial, idx)
    end

  end

  local mkcategories = function (characters) -- different from the others

    local chardata = characters.data

    setmetatable (characters, { __index = function (t, char)
      if char then
        local c = chardata [char]
        c = c.category or char
        t [char] = c
        return c
      end
    end})

  end

  local load_failed = false
  local chardata --> characters.data; loaded on demand

  local load_chardef = function ()

    report ("both", 1, "aux", "Loading character metadata from %s.", chardef)
    chardata = dofile (kpse.find_file (chardef, "lua"))

    if chardata == nil then
      warning ("Could not load %s; continuing \z
                with empty character table.",
                chardef)
      chardata    = { }
      load_failed = true
    end

    characters      = { } --- nuke metatable
    characters.data = chardata

    --- institute some of the functionality from char-ini.lua

    mkcharspecial (characters, "mirrors",     "mirror")
    mkcharspecial (characters, "directions",  "direction")
    mkcharspecial (characters, "textclasses", "textclass")
    mkcategories  (characters)

  end

  local charindex = function (t, k)
    if chardata == nil and load_failed ~= true then
      load_chardef ()
    end

    return characters [k]
  end

  setmetatableindex (characters, charindex)

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
    local tfmdata  = identifiers[font_id] if not tfmdata  then return false end
    local shared   = tfmdata.shared       if not shared   then return false end
    local fontdata = shared.rawdata       if not fontdata then return false end
    if fontdata then
      local fontname = fontdata.metadata.fontname
      local features = fontdata.resources.features
      for method, featuredata in next, features do
        --- where method: "gpos" | "gsub"
        for feature, data in next, featuredata do
          if data[asked_script] then
            report ("log", 1, "aux",
                    "font no %d (%s) defines feature %s for script %s",
                    font_id, fontname, feature, asked_script)
            return true
          end
        end
      end
      report ("log", 0, "aux",
              "font no %d (%s) defines no feature for script %s",
              font_id, fontname, asked_script)
    end
  end
  report ("log", 0, "aux", "no font with id %d", font_id)
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
    local tfmdata  = identifiers[font_id] if not tfmdata  then return false end
    local shared   = tfmdata.shared       if not shared   then return false end
    local fontdata = shared.rawdata       if not fontdata then return false end
    if fontdata then
      local fontname = fontdata.metadata.fontname
      local features = fontdata.resources.features
      for method, featuredata in next, features do
        --- where method: "gpos" | "gsub"
        for feature, data in next, featuredata do
          local scriptdata = data[asked_script]
          if scriptdata and scriptdata[asked_language] then
            report ("log", 1, "aux",
                    "font no %d (%s) defines feature %s "
                    .. "for script %s with language %s",
                    font_id, fontname, feature,
                    asked_script, asked_language)
            return true
          end
        end
      end
      report ("log", 0, "aux",
              "font no %d (%s) defines no feature "
              .. "for script %s with language %s",
              font_id, fontname, asked_script, asked_language)
    end
  end
  report ("log", 0, "aux", "no font with id %d", font_id)
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
    local tfmdata  = identifiers[font_id] if not tfmdata  then return false end
    local shared   = tfmdata.shared       if not shared   then return false end
    local fontdata = shared.rawdata       if not fontdata then return false end
    if fontdata then
      local features = fontdata.resources.features
      local fontname = fontdata.metadata.fontname
      for method, featuredata in next, features do
        --- where method: "gpos" | "gsub"
        local feature = featuredata[asked_feature]
        if feature then
          local scriptdata = feature[asked_script]
          if scriptdata and scriptdata[asked_language] then
            report ("log", 1, "aux",
                    "font no %d (%s) defines feature %s "
                    .. "for script %s with language %s",
                    font_id, fontname, asked_feature,
                    asked_script, asked_language)
            return true
          end
        end
      end
      report ("log", 0, "aux",
              "font no %d (%s) does not define feature %s for script %s with language %s",
              font_id, fontname, asked_feature, asked_script, asked_language)
    end
  end
  report ("log", 0, "aux", "no font with id %d", font_id)
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

local namesresolve      = fontnames.resolve
local namesscan_dir     = fontnames.scan_dir

--[====[-- TODO -> port this to new db model

--- local directories -------------------------------------------------

--- migrated from luaotfload-database.lua
--- https://github.com/lualatex/luaotfload/pull/61#issuecomment-17776975

--- string -> (int * int)
local scan_external_dir = function (dir)
  local old_names, new_names = names.data()
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

--]====]--

aux.scan_external_dir = function ()
  print "ERROR: scan_external_dir() is not implemented"
end

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

--- index access ------------------------------------------------------

--- Based on a discussion on the Luatex mailing list:
--- http://tug.org/pipermail/luatex/2014-June/004881.html

--[[doc--

  aux.read_font_index -- Read the names index from the canonical
  location and return its contents. This does not affect the behavior
  of Luaotfload: The returned table is independent of what the font
  resolvers use internally. Access is raw: each call to the function
  will result in the entire table being re-read from disk.

--doc]]--

local load_names        = fontnames.load
local access_font_index = fontnames.access_font_index

local read_font_index = function ()
  return load_names (true) or { }
end

--[[doc--

  aux.font_index -- Access Luaotfload’s internal database. If the
  database hasn’t been loaded yet this will cause it to be loaded, with
  all the possible side-effects like for instance creating the index
  file if it doesn’t exist, reading all font files, &c.

--doc]]--

local font_index = function () return access_font_index () end

aux.read_font_index = read_font_index
aux.font_index      = font_index

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
