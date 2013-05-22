module("luaotfload", package.seeall)

luaotfload.module = {
    name          = "luaotfload-legacy",
    version       = 1.31,
    date          = "2013/04/25",
    description   = "Unsupported Luaotfload",
    author        = "Elie Roux & Hans Hagen",
    copyright     = "Elie Roux",
    license       = "GPL v2"
}

local error, warning, info, log = luatexbase.provides_module(luaotfload.module)

--[[doc--

   This used to be a necessary initalization in order not to rebuild an
   existing font.  Maybe 600 should be replaced by |\pdfpkresolution|
   or |texconfig.pk_dpi| (and it should be replaced dynamically), but
   we don't have access (yet) to the |texconfig| table, so we let it be
   600. Anyway, it does still work fine even if |\pdfpkresolution| is
   changed.

--doc]]--

kpse.init_prog("", 600, "/")

--[[doc--

   The minimal required \luatex version.
   We are tolerant folks.

--doc]]--

local luatex_version = 60
if tex.luatexversion < luatex_version then
    warning("LuaTeX v%.2f is old, v%.2f is required, v0.76 recommended.",
             tex.luatexversion/100,
             luatex_version   /100)
end

--[[doc--

    \subsection{Module loading}
    We load the outdated \context files with this function. It
    automatically adds the |otfl-| prefix to it, so that we call it with
    the actual \context name.

--doc]]--

function luaotfload.loadmodule(tofind)
    local found = kpse.find_file(tofind,"tex")
    if found then
        log("loading file %s.", found)
        dofile(found)
    else
        error("file %s not found.", tofind)
    end
end
local loadmodule = luaotfload.loadmodule

--[[doc--

    Keep away from these lines!

--doc]]--
loadmodule"luaotfload-legacy-merged.lua"

if not fonts then
  loadmodule("otfl-luat-dum.lua") -- not used in context at all
  loadmodule("otfl-luat-ovr.lua") -- override some luat-dum functions
  loadmodule("otfl-data-con.lua") -- maybe some day we don't need this one
  loadmodule("otfl-font-ini.lua")
  loadmodule("otfl-node-dum.lua")
  loadmodule("otfl-node-inj.lua")
--[[doc--
   By default \context takes some private attributes for internal use. To
   avoide attribute clashes with other packages, we override the function
   that allocates new attributes, making it a wraper around
   |luatexbase.new_attribute()|. We also prefix attributes with |otfl@| to
   avoid possiple name clashes.
--doc]]--
  loadmodule("luaotfload-legacy-attributes.lua") -- patch attributes
--[[doc--
   Font handling modules.
--doc]]--
  loadmodule("otfl-font-tfm.lua")
  loadmodule("otfl-font-cid.lua")
  loadmodule("otfl-font-ott.lua")
  loadmodule("otfl-font-map.lua")
  loadmodule("otfl-font-otf.lua")
  loadmodule("otfl-font-otd.lua")
  loadmodule("otfl-font-oti.lua")
  loadmodule("otfl-font-otb.lua")
  loadmodule("otfl-font-otn.lua")
  loadmodule("otfl-font-ota.lua")
  loadmodule("otfl-font-otc.lua")
  loadmodule("otfl-font-def.lua")
--[[doc--
   \textsf{old luaotfload} specific modules.
--doc]]--
  loadmodule("otfl-font-xtx.lua")
  loadmodule("otfl-font-dum.lua")
  loadmodule("otfl-font-clr.lua")
end
loadmodule"luaotfload-legacy-database.lua" --- unmerged coz needed in db script

--[[doc--

    This is a patch for |otfl-font-def.lua|, that defines a reader for ofm
    fonts, this is necessary if we set the forced field of the specification
    to |ofm|.

--doc]]--

if fonts and fonts.tfm and fonts.tfm.readers then
    fonts.tfm.readers.ofm = fonts.tfm.readers.tfm
end

--[[doc--

    \subsection{Post-processing TFM table}
    Here we do some final touches to the loaded TFM table before passing it
    to the \tex end.
    First we create a callback for patching fonts on the fly, to be used by
    other packages.

--doc]]--

luatexbase.create_callback("luaotfload.patch_font", "simple", function() end)

--[[doc--

    then define a function where font manipulation will take place.

--doc]]--

local function def_font(...)
    local fontdata = fonts.define.read(...)
    if type(fontdata) == "table" and fontdata.shared then
--[[doc--

    Then we populate |MathConstants| table, which is required for
    OpenType math.

    Note: actually it isn’t, but you’re asking for it by using outdated
    code.

--doc]]--
        local otfdata = fontdata.shared.otfdata
        if otfdata.metadata.math then
            local mc = { }
            for k,v in next, otfdata.metadata.math do
                if k:find("Percent") then
                    -- keep percent values as is
                    mc[k] = v
                else
                    mc[k] = v / fontdata.units * fontdata.size
                end
            end
            -- for \overwithdelims
            mc.FractionDelimiterSize             = 1.01 * fontdata.size
            mc.FractionDelimiterDisplayStyleSize = 2.39 * fontdata.size

            fontdata.MathConstants = mc
        end
--[[doc--

    Execute any registered font patching callbacks.

--doc]]--
        luatexbase.call_callback("luaotfload.patch_font", fontdata)
    end
    return fontdata
end

--[[doc--
\subsection{\context override}

    We have a unified function for both file and name resolver. This
    line is commented as it makes database reload too often. This means
    that in some cases, a font in the database will not be found if
    it's not in the texmf tree. A similar thing will reappear in next
    version.

--doc]]--

--fonts.define.resolvers.file = fonts.define.resolvers.name

--[[doc--

    Overriding some defaults set in \context code.

--doc]]--

fonts.mode = "node"

--[[doc--

    The following features are useful in math (e.g. in XITS Math font),
    but \textsf{luaotfload} does not recognize them in |base| mode.

--doc]]--

local register_base_sub = fonts.otf.features.register_base_substitution
local gsubs = {
    "ss01", "ss02", "ss03", "ss04", "ss05",
    "ss06", "ss07", "ss08", "ss09", "ss10",
    "ss11", "ss12", "ss13", "ss14", "ss15",
    "ss16", "ss17", "ss18", "ss19", "ss20",
}

for _,v in next, gsubs do
    register_base_sub(v)
end

--[[doc--

    Finally we register the callbacks

--doc]]--

luatexbase.add_to_callback("pre_linebreak_filter",
                            nodes.simple_font_handler,
                           "luaotfload.pre_linebreak_filter")
luatexbase.add_to_callback("hpack_filter",
                            nodes.simple_font_handler,
                           "luaotfload.hpack_filter")
luatexbase.reset_callback("define_font")
luatexbase.add_to_callback("define_font",
                            def_font,
                           "luaotfload.define_font", 1)
luatexbase.add_to_callback("find_vf_file",
                            fonts.vf.find,
                           "luaotfload.find_vf_file")
--[[doc--

    XXX: see https://github.com/wspr/unicode-math/issues/185
    \luatex does not provide interface to accessing
    |(Script)ScriptPercentScaleDown| math constants, so we
    emulate \xetex behaviour by setting |\fontdimen10| and
    |\fontdimen11|.

    Note: actually, it does now, but not unless you update.

--doc]]--

local function set_sscale_diments(fontdata)
    local mc = fontdata.MathConstants
    if mc then
        if mc["ScriptPercentScaleDown"] then
            fontdata.parameters[10] = mc.ScriptPercentScaleDown
        else -- resort to plain TeX default
            fontdata.parameters[10] = 70
        end
        if mc["ScriptScriptPercentScaleDown"] then
            fontdata.parameters[11] = mc.ScriptScriptPercentScaleDown
        else -- resort to plain TeX default
            fontdata.parameters[11] = 50
        end
    end
end

luatexbase.add_to_callback("luaotfload.patch_font", set_sscale_diments, "unicodemath.set_sscale_diments")

--[[doc--
  Version 2.3c of fontspec dropped a couple features that are now
  provided in the luaotfload auxiliary libraries. To avoid breaking
  Mik\TEX (again), which is sorta the entire point of distributing the
  legacy codebase, we temporarily restore those functions here.

  Note that apart from cosmetic changes these are still the same as in
  pre-TL2013 fontspec, relying on pairs() and other inefficient methods.
--doc]]--

luaotfload.aux      = luaotfload.aux or { }
local aux           = luaotfload.aux

local stringlower   = string.lower
local fontid        = font.id

local identifiers   = fonts.identifiers

local check_script = function (id, script)
  local s = stringlower(script)
  if id and id > 0 then
    local tfmdata = identifiers[id]
    local otfdata = tfmdata.shared and tfmdata.shared.otfdata
    if otfdata then
      local features = otfdata.luatex.features
      for i, _ in pairs(features) do
        for j, _ in pairs(features[i]) do
          if features[i][j][s] then
            fontspec.log("script '%s' exists in font '%s'",
                         script, tfmdata.fullname)
            return true
          end
        end
      end
    end
  end
end

local check_language = function (id, script, language)
  local s = stringlower(script)
  local l = stringlower(language)
  if id and id > 0 then
    local tfmdata = identifiers[id]
    local otfdata = tfmdata.shared and tfmdata.shared.otfdata
    if otfdata then
      local features = otfdata.luatex.features
      for i, _ in pairs(features) do
        for j, _ in pairs(features[i]) do
          if features[i][j][s] and features[i][j][s][l] then
            fontspec.log("language '%s' for script '%s' exists in font '%s'",
                         language, script, tfmdata.fullname)
            return true
          end
        end
      end
    end
  end
end

local check_feature = function (id, script, language, feature)
  local s = stringlower(script)
  local l = stringlower(language)
  local f = stringlower(feature:gsub("^[+-]", ""):gsub("=.*$", ""))
  if id and id > 0 then
    local tfmdata = identifiers[id]
    local otfdata = tfmdata.shared and tfmdata.shared.otfdata
    if otfdata then
      local features = otfdata.luatex.features
      for i, _ in pairs(features) do
        if features[i][f] and features[i][f][s] then
          if features[i][f][s][l] == true then
            fontspec.log("feature '%s' for language '%s' and script '%s' exists in font '%s'",
                         feature, language, script, tfmdata.fullname)
            return true
          end
        end
      end
    end
  end
end

local get_math_dimension = function(fnt, str)
  if type(fnt) == "string" then
    fnt = fontid(fnt)
  end
  local tfmdata = identifiers[fnt]
  if tfmdata then
    local mathdata = tfmdata.MathConstants
    if mathdata then
      return mathdata[str]
    end
  end
end

aux.check_script          = check_script
aux.check_language        = check_language
aux.check_feature         = check_feature
aux.get_math_dimension    = get_math_dimension

local set_capheight = function (tfmdata)
    local capheight
    local shared = tfmdata.shared
    if shared then
      local metadata       = shared.otfdata.metadata
      local units_per_em   = metadata.units_per_em or tfmdata.units
      local os2_capheight  = shared.otfdata.pfminfo.os2_capheight
      local size           = tfmdata.size

      if os2_capheight > 0 then
          capheight = os2_capheight / units_per_em * size
      else
          local X8 = string.byte"X"
          if tfmdata.characters[X8] then
              capheight = tfmdata.characters[X8].height
          else
              capheight = metadata.ascent / units_per_em * size
          end
      end
    else
        local X8 = string.byte"X"
        if tfmdata.characters[X8] then
            capheight = tfmdata.characters[X8].height
        end
    end
    if capheight then
        tfmdata.parameters[8] = capheight
    end
end
luatexbase.add_to_callback("luaotfload.patch_font",
                           set_capheight,
                           "luaotfload.set_capheight")

--[[doc--
End of auxiliary functionality that was moved from fontspec.lua.
--doc]]--

-- vim:ts=2:sw=2:expandtab:ft=lua
