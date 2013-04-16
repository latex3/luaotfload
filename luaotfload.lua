module("luaotfload", package.seeall)

luaotfload.module = {
    name          = "luaotfload",
    version       = 2.2,
    date          = "2013/04/15",
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

local dummy_function = function () end

--[[doc--
No final decision has been made on how to handle font definition.  At
the moment, there are three candidates: The \identifier{generic}
callback as hard-coded in the font loader, the \identifier{old}
wrapper, and a simplified version of the latter (\identifier{patch})
that does nothing besides applying font patches.
--doc]]--
luaotfload.font_definer = "patch" --- | “generic” | “old”

local error, warning, info, log =
    luatexbase.provides_module(luaotfload.module)

--[[doc--
This is a necessary initalization in order not to rebuild an existing
font.
Maybe 600 should be replaced by \texmacro{pdfpkresolution} %% (why?)
or \luafunction{texconfig.pk_dpi} (and it should be replaced
dynamically), but we don't have access (yet) to the
\identifier{texconfig} table, so we let it be 600.
Anyway, it does still work fine even if \texmacro{pdfpkresolution} is
changed.
--doc]]--

kpse.init_prog("", 600, "/")

--[[doc--
We set the minimum version requirement for \LUATEX to v0.74, as it was
the first version to include version 5.2 of the \LUA interpreter.
--doc]]--

local luatex_version = 74

if tex.luatexversion < luatex_version then
    warning("LuaTeX v%.2f is old, v%.2f is recommended.",
             tex.luatexversion/100,
             luatex_version   /100)
end

--[[doc--
\subsection{Module loading}

We load the files imported from \CONTEXT with this function.
It automatically prepends the prefix \fileent{otfl-} to its argument,
so we can refer to the files with their actual \CONTEXT name.
--doc]]--

local fl_prefix = "otfl" -- “luatex” for luatex-plain
local loadmodule = function (name)
    local tofind = fl_prefix .."-"..name
    local found = find_file(tofind,"tex")
    if found then
        log("loading file %s.", found)
        dofile(found)
    else
        error("file %s not found.", tofind)
    end
end

--[[doc--
Virtual fonts are resolved via a callback.
\luafunction{find_vf_file} derives the name of the virtual font file
from the filename.
(NB: \CONTEXT handles this likewise in \fileent{font-vf.lua}.)
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

--[[doc--

\subsection{Preparing the Font Loader}
We treat the fontloader as a black box so behavior is consistent
between formats.
The wrapper file is \fileent{otfl-fonts.lua} which we imported from
\href{http://standalone.contextgarden.net/current/context/experimental/tex/generic/context/luatex/}{\LUATEX-Plain}.
It has roughly two purposes:

\begin{enumerate}

   \item insert the functionality required for fontloader; and

   \item put it in place via the respective callbacks.

\end{enumerate}

How the first step is executed depends on the presence on the
\emph{merged font loader code}.
In \identifier{luaotfload} this is contained in the file
\fileent{otfl-fonts-merged.lua}.
If this file cannot be found,  the original libraries from \CONTEXT of
which the merged code was composed are loaded instead.

Hans provides two global tables to control the font loader:

  \begin{itemize}
    \item  \luafunction{generic_context}:
           encapsulation mechanism, callback functions
    \item  \luafunction{non generic_context}:
           customized code insertion
  \end{itemize}


With \luafunction{non_generic_context} we can tailor the font loader
insertion to our file naming habits (key \luafunction{load_before}).
Additionally, \luafunction{skip_loading} can be unset to force loading
of the original libraries as though the merged code was absent.
Another key, \luafunction{load_after} is called at the time when the
font loader is actually inserted.
In combination with the option \luafunction{no_callbacks_yet} in
\luafunction{generic_context}, we can insert our own,
\identifier{luatexbase}-style callback handling here.
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
The imported font loader will call \luafunction{callback.register} once
while reading \fileent{font-def.lua}.
This is unavoidable unless we modify the imported files, but harmless
if we make it call a dummy instead.
--doc]]--

local trapped_register = callback.register
callback.register      = dummy_function

--[[doc--
Now that things are sorted out we can finally load the fontloader.
--doc]]--

loadmodule"fonts.lua"

--[[doc--
By default, the fontloader requires a number of \emph{private
attributes} for internal use.
These must be kept consistent with the attribute handling methods as
provided by \identifier{luatexbase}.
Previously, when \identifier{luaotfload} imported individual files from
\CONTEXT, the strategy was to override the function that allocates new
attributes at the appropriate time during initialization, making it a
wrapper around \luafunction{luatexbase.new_attribute}.

\begin{verbatim}
attributes.private = function (name)
    local attr   = "otfl@" .. name
    local number = luatexbase.attributes[attr]
    if not number then
        number = luatexbase.new_attribute(attr)
    end
    return number
end
\end{verbatim}

Now that the fontloader comes as a package, this hack is no longer
applicable.
The attribute handler installed by \identifier{luatex-fonts} (see the
file \fileent{otfl-basics-nod.lua}) cannot be intercepted before the
first call to it takes place.
While it is not feasible to prevent insertion of attributes at the
wrong places, we can still retrieve them from the closure surrounding
the allocation function \luafunction{attributes.private}
using \LUA’s introspection features.

The recovered attribute identifiers are prefixed “\fileent{otfl@}” to
avoid name clashes.
--doc]]--

do
    local debug_getupvalue = debug.getupvalue

    local nups = debug.getinfo(attributes.private, "u").nups
    local nup, numbers = 0
    while nup <= nups do
        nup = nup + 1
        local upname, upvalue = debug_getupvalue(attributes.private, nup)
        if upname == "numbers" then
            numbers = upvalue
            break
        end
    end
    if numbers then
        local luatexbase_attributes = luatexbase.attributes
        local prefix = "otfl@"
        --- re-register attributes from “numbers”
        --- ... pull request for luatexbase pending
        for name, num in next, numbers do
            name = prefix .. name
            luatexbase_attributes[name] = num
        end
    end
    --- The definitions used by the fontloader are never
    --- called again so it is safe to nil them, I suppose.
    debug.setupvalue(attributes.private, nup, { })
    _G.attributes = nil --- needed for initialization only
end

--[[doc--

\subsection{Callbacks}

After the fontloader is ready we can restore the callback trap from
\identifier{luatexbase}.
--doc]]--

callback.register = trapped_register

--[[doc--
We do our own callback handling with the means provided by luatexbase.

Note: \luafunction{pre_linebreak_filter} and \luafunction{hpack_filter}
are coupled in \CONTEXT in the concept of \emph{node processor}.
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
  fonts.handlers.ofm = fonts.handlers.tfm --- empty anyways
  fonts.formats.ofm  = fonts.formats.tfm  --- “type1”
  --- fonts.readers.sequence[#fonts.readers.sequence+1] = "ofm"
  --------------------------------------------------------------------
end

--[[doc--

Now we load the modules written for \identifier{luaotfload}.

--doc]]--
loadmodule"font-pfb.lua"    --- new in 2.0, added 2011
loadmodule"font-nms.lua"
loadmodule"font-clr.lua"
loadmodule"font-ltx.lua"    --- new in 2.0, added 2011

--[[doc--

We create a callback for patching fonts on the fly, to be used by other
packages.
It initially contains the empty function that we are going to override
below.

--doc]]--

create_callback("luaotfload.patch_font", "simple", dummy_function)

--[[doc--

This is a wrapper for the imported font loader.
As of 2013, everything it does appear to be redundand, so we won’t use
it unless somebody points out a cogent reason.
Nevertheless, it has been adapted to work with the current structure of
font data objects and will stay here for reference / until breakage is
reported.

\emphasis{TODO}
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

\subsection{\CONTEXT override}

We provide a simplified version of the original font definition
callback.

--doc]]--

local read_font_file = fonts.definers.read
local patch_defined_font = function (...)
    local tfmdata = read_font_file(...)-- spec -> size -> id -> tmfdata
    if type(tfmdata) == "table" then
        call_callback("luaotfload.patch_font", tfmdata)
    end
    return tfmdata
end

caches.compilemethod = "both"

reset_callback("define_font")

--[[doc--
Finally we register the callbacks
--doc]]--

if luaotfload.font_definer == "old"  then
  add_to_callback("define_font",
                  define_font_wrapper,
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

-- vim:tw=71:sw=4:ts=4:expandtab
