-- 
--  This is file `luaotfload.lua',
--  generated with the docstrip utility.
-- 
--  The original source files were:
-- 
--  luaotfload.dtx  (with options: `lua')
--  This is a generated file.
--  
--  Copyright (C) 2009-2010 by by Elie Roux    <elie.roux@telecom-bretagne.eu>
--                            and Khaled Hosny <khaledhosny@eglug.org>
--                                 (Support: <lualatex-dev@tug.org>.)
--  
--  This work is under the CC0 license.
--  
--  This work consists of the main source file luaotfload.dtx
--  and the derived files
--      luaotfload.sty, luaotfload.lua
--  
module("luaotfload", package.seeall)

luaotfload.module = {
    name          = "luaotfload",
    version       = 1.27,
    date          = "2012/05/28",
    description   = "OpenType layout system.",
    author        = "Elie Roux & Hans Hagen",
    copyright     = "Elie Roux",
    license       = "CC0"
}

local luatexbase = luatexbase

local type, next, dofile = type, next, dofile
local stringfind = string.find
local find_file  = kpse.find_file

local add_to_callback, create_callback =
      luatexbase.add_to_callback, luatexbase.create_callback
local reset_callback, call_callback =
      luatexbase.reset_callback, luatexbase.call_callback

local dummy_function   = function () end

--[[doc--
No final decision has been made on how to handle font definition.
At the moment, there are three candidates: The \textsf{generic}
callback as hard-coded in the font loader, the \textsf{old} wrapper,
and a simplified version of the latter (\textsf{patch}) that does
nothing besides applying font patches.
--doc]]--
luaotfload.font_definer = "patch" --- | “generic” | “old”

local fl_prefix = "otfl" -- “luatex” for luatex-plain

local error, warning, info, log = luatexbase.provides_module(luaotfload.module)

local luatex_version = 75

if tex.luatexversion < luatex_version then
    warning("LuaTeX v%.2f is old, v%.2f is recommended.",
             tex.luatexversion/100,
             luatex_version   /100)
end
local loadmodule = function (name)
    local tofind = fl_prefix .."-"..name
    local found = find_file(tofind,"tex")
    if found then
        log("loading file %s.", found)
        dofile(found)
    else
        --error("file %s not found.", tofind)
        error("file %s not found.", tofind)
    end
end

--[[doc--
Virtual fonts are resolved via a callback.
\verb|find_vf_file| derives the name of the virtual font file from the
filename.
(NB: \CONTEXT\ handles this likewise in \textsf{font-vf.lua}.)
--doc]]--
local Cs, P, lpegmatch = lpeg.Cs, lpeg.P, lpeg.match

local p_dot, p_slash = P".",  P"/"
local p_suffix       = (p_dot * (1 - p_dot - p_slash)^1 * P(-1)) / ""
local p_removesuffix = Cs((p_suffix + 1)^1)

local find_vf_file = function (name)
    local fullname = find_file(name, "ovf")
    if not fullname then
        --fullname = find_file(file.removesuffix(name), "ovf")
        fullname = find_file(lpegmatch(p_removesuffix, name), "ovf")
    end
    if fullname then
        log("loading virtual font file %s.", fullname)
    end
    return fullname
end

--[[-- keep --]]
--- from Hans (all merged):

---   file name              modified  include name
--- × basics-gen.lua         t         luat-basics-gen
--- × font-def -> fonts-def  t         luatex-font-def (there’s also the normal font-def!)
--- × fonts-enc              f         luatex-font-enc
--- × fonts-ext              t         luatex-fonts-ext
--- × fonts-lua              f         luatex-fonts-lua
---   fonts-tfm              f         luatex-fonts-tfm
--- × fonts-cbk              f         luatex-fonts-lua

--- from Hans (unmerged):
---   font-otc.lua -> otfl-font-otc.lua

--- from luaotfload:
---   otfl-luat-ovr.lua    -- override some luat-dum functions
---   otfl-font-clr.lua
---   otfl-font-ltx.lua
---   otfl-font-nms.lua
---   otfl-font-pfb.lua    -- ?

--[[-- new --]]
--- basics-nod          (merged as fonts-nod !)
--- fonts-demo-vf-1.lua
--- fonts-syn           (merged)

--[[-- merged, to be dropped --]]
--- otfl-data-con.lua
--- otfl-font-cid.lua
--- otfl-font-con.lua
--- otfl-font-ini.lua
--- otfl-font-ota.lua
--- otfl-font-otb.lua
--- otfl-font-otf.lua
--- otfl-font-oti.lua
--- otfl-font-otn.lua

--[[--
  it all boils down to this: we load otfl-fonts.lua
  which takes care of loading the merged file.
  that’s it, go thank Hans!
--]]--

--[[doc--
We treat the fontloader as a black box so behavior is consistent
between formats.
The wrapper file is |otfl-fonts.lua| which we imported from
\LUATEX-Plain.
It has roughly two purposes:
(\textit{1}) insert the functionality required for fontloader, and
(\textit{2}) put it in place via the respective callbacks.
How the first step is executed depends on the presence on the
\emph{merged font loader code}.
In \textsf{luaotfload} this is contained in the file
|otfl-fonts-merged.lua|.
If this file cannot be found,  the original libraries from \CONTEXT of
which the merged code was composed are loaded instead.

Hans provides two global tables to control the font loader:
\begin{tabular}{ll}
  \texttt{generic\textunderscore context}                    & 
  encapsulation mechanism, callback functions
  \\
  \texttt{non\textunderscore generic\textunderscore context} & 
  customized code insertion
  \\
\end{tabular}
With \verb|non_generic_context| we can tailor the font loader insertion
to our file naming habits (key \verb|load_before|).
Additionally, \verb|skip_loading| can be unset to force loading of
the original libraries as though the merged code was absent.
Another key, \verb|load_after| is called at the time when the font
loader is actually inserted.
In combination with the option \verb|no_callbacks_yet| in
\verb|generic_context|, we can insert our own,
\textsf{luatexbase}-style callback handling here.
--doc]]--
if not _G.    generic_context then _G.    generic_context = { } end
if not _G.non_generic_context then _G.non_generic_context = { } end

local     generic_context =    generic_context
local non_generic_context =non_generic_context

generic_context.no_callbacks_yet = true

_G.non_generic_context = { luatex_fonts = {
        load_before     = "otfl-fonts-merged.lua",
        -- load_after      = nil, --- TODO, this is meant for callbacks
        skip_loading    = true,
}}

--[[doc--
The imported font loader will call \verb|callback.register| once
(during \verb|font-def.lua|).
This is unavoidable but harmless, so we make it call a dummy instead.
--doc]]--
local trapped_register = callback.register
callback.register      = dummy_function

--[[doc--
Now that things are sorted out we can load the fontloader.
--doc]]--
loadmodule"fonts.lua"

--[[doc--
After the fontloader is ready we can restore the callback trap from
\textsf{luatexbase}.
--doc]]--

callback.register = trapped_register

--[[doc--
We do our own callback handling with the means provided by luatexbase.

Note: \verb|pre_linebreak_filter| and \verb|hpack_filter| are coupled
in \CONTEXT\ in the concept of \emph{node processor}.
--doc]]--

add_to_callback("pre_linebreak_filter",
                generic_context.callback_pre_linebreak_filter,
                "luaotfload.node_processor",
                1)
add_to_callback("hpack_filter",
                generic_context.callback_hpack_filter,
                "luaotfload.node_processor",
                1)
add_to_callback("find_vf_file",
                find_vf_file, "luaotfload.find_vf_file")

loadmodule"font-otc.lua"   -- TODO check what we can drop from otfl-features

loadmodule"lib-dir.lua"    -- required by font-nms
loadmodule"luat-ovr.lua"

if fonts and fonts.readers.tfm then
  --------------------------------------------------------------------
  --- OFM; read this first
  --------------------------------------------------------------------
  --- I can’t quite make out whether this is still relevant
  --- as those ofm fonts always fail, even in the 2011 version
  --- (mktexpk:  don't know how to create bitmap font for omarabb.ofm)
  --- the font loader appears to read ofm like tfm so if this
  --- hack was supposed achieve that, we should excise it anyways
  fonts.readers.ofm  = fonts.readers.tfm
  fonts.handlers.ofm = fonts.handlers.tfm
  fonts.formats.ofm  = fonts.formats.tfm
  --------------------------------------------------------------------
end
loadmodule"font-nms.lua"
loadmodule"font-clr.lua"
loadmodule"font-ltx.lua"

create_callback("luaotfload.patch_font", "simple", dummy_function)

--[[doc--
This is a wrapper for the imported font loader.
As of 2013, everything it does appears to be redundand, so we won’t use
it.
Nevertheless, it has been adapted to work with the current structure of
font data objects and will stay here for reference / until somebody
reports breakage.

TODO
This one also enables patching fonts.
The current fontloader apparently comes with a dedicated mechanism for
that already: enhancers.
How those work remains to be figured out.
--doc]]--
local define_font_wrapper = function (...)
    --- we use “tfmdata” (not “fontdata”) for consistency with the
    --- font loader
    local tfmdata = fonts.definers.read(...)
    if type(tfmdata) == "table" and tfmdata.shared then
        local metadata = tfmdata.shared.rawdata.metadata
        local mathdata = metadata.math --- do all fonts have this field?
        if mathdata then
            local mathconstants = { } --- why new hash, not modify in place?
            local units_per_em  = metadata.units_per_em
            local size          = tfmdata.size
            for k,v in next, mathdata do
                --- afaics this is alread taken care of by
                --- definers.read
                if stringfind(k, "Percent") then
                    -- keep percent values as is
                    print(k,v)
                    mathconstants[k] = v
                else
                    mathconstants[k] = v / units_per_em * size
                end
            end
            --- for \overwithdelims
            --- done by definers.read as well
            mathconstants.FractionDelimiterSize             = 1.01 * size
            --- fontloader has 2.4 × size
            mathconstants.FractionDelimiterDisplayStyleSize = 2.39 * size
            tfmdata.MathConstants = mathconstants
        end
        call_callback("luaotfload.patch_font", tfmdata)
    end
    return tfmdata
end

--[[doc--
We provide a simplified version of the original font definition
callback.
--doc]]--
local patch_defined_font = function (...)
    local tfmdata = fonts.definers.read(...)
    if type(tfmdata) == "table" then
        call_callback("luaotfload.patch_font", tfmdata)
    end
    --inspect(tfmdata.shared.features)
    return tfmdata
end

fonts.mode = "node"
caches.compilemethod = "both"

function attributes.private(name)
    local attr   = "otfl@" .. name
    local number = luatexbase.attributes[attr]
    if not number then
        number = luatexbase.new_attribute(attr)
    end
    return number
end

reset_callback("define_font")

if luaotfload.font_definer == "old"  then
  add_to_callback("define_font",
                  old_define_font_wrapper,
                  "luaotfload.define_font",
                  1)
elseif luaotfload.font_definer == "generic"  then
  add_to_callback("define_font",
                  generic_context.callback_define_font,
                  "luaotfload.define_font",
                  1)
elseif luaotfload.font_definer == "patch"  then
  add_to_callback("define_font",
                  patch_defined_font,
                  "luaotfload.define_font",
                  1)
end

loadmodule"features.lua"

--[==[
---- is this still necessary?
local set_sscale_diments = function (tfmdata)
    local mathconstants = tfmdata.MathConstants
    if mathconstants then
        local tfmparameters = tfmdata.parameters
        if mathconstants.ScriptPercentScaleDown then
            tfmparameters[10] = mathconstants.ScriptPercentScaleDown
        else -- resort to plain TeX default
            tfmparameters[10] = 70
        end
        if mathconstants.ScriptScriptPercentScaleDown then
            tfmparameters[11] = mathconstants.ScriptScriptPercentScaleDown
        else -- resort to plain TeX default
            tfmparameters[11] = 50
        end
    end
end

add_to_callback("luaotfload.patch_font",
                set_sscale_diments,
                "unicodemath.set_sscale_diments")
]==]

-- vim:tw=71:sw=4:ts=4:expandtab

--  End of File `luaotfload.lua'.
