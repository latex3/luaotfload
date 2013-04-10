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

local fl_prefix = "otfl" -- “luatex” for luatex-plain

--- these will be overloaded later by luatexbase
local error = function(...) print("err", string.format(...)) end
local log   = function(...) print("log", string.format(...)) end

kpse.init_prog("", 600, "/")
local luatex_version = 60

if tex.luatexversion < luatex_version then
    warning("LuaTeX v%.2f is old, v%.2f is recommended.",
             tex.luatexversion/100,
             luatex_version   /100)
end
local loadmodule = function (name)
    local tofind = fl_prefix .."-"..name
    local found = kpse.find_file(tofind,"tex")
    if found then
        log("loading file %s.", found)
        dofile(found)
    else
        --error("file %s not found.", tofind)
        error("file %s not found.", tofind)
    end
end
luaotfload.loadmodule = loadmodule --- required in deferred code

--[[-- keep --]]
--- from Hans (all merged):

---   file name              modified include name
--- × basics-gen.lua         t        luat-basics-gen
--- × font-def -> fonts-def  t        luatex-font-def (there’s also the normal font-def!)
--- × fonts-enc              f        luatex-font-enc
--- × fonts-ext              t        luatex-fonts-ext
--- × fonts-lua              f        luatex-fonts-lua
---   fonts-tfm              f        luatex-fonts-tfm
--- × fonts-cbk              f        luatex-fonts-lua

--- from luaotfload:
---   otfl-luat-ovr.lua    -- override some luat-dum functions
---   otfl-font-clr.lua
---   otfl-font-ltx.lua
---   otfl-font-nms.lua
---   otfl-font-otc.lua
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

--[[doc
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

generic_context.no_callbacks_yet = true

_G.non_generic_context = { luatex_fonts = {
    load_before     = "otfl-fonts-merged.lua",
     -- load_after      = nil, --- TODO, this is meant for callbacks
    skip_loading    = true,
}}

loadmodule("fonts.lua")

--- now load luatexbase (from the TEX end)
--- then continue in luaotfload-deferred.lua

-- vim:tw=71:sw=2:ts=2:expandtab

--  End of File `luaotfload.lua'.
