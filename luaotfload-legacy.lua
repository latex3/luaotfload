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

    We override the cleanname function as it outputs garbage for exotic font
    names

--doc]]--

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

-- vim:ts=2:sw=2:expandtab:ft=lua
