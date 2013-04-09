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
function luaotfload.loadmodule(name, prefix)
    local prefix = prefix or "otfl"
    local tofind = prefix .."-"..name
    local found = kpse.find_file(tofind,"tex")
    if found then
        log("loading file %s.", found)
        dofile(found)
    else
        --error("file %s not found.", tofind)
        error("file %s not found.", tofind)
    end
end

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
  which takes care loading the merged file.
  that’s it, go thank Hans!
--]]--

--luaotfload.loadmodule("fonts.lua", "luatex")
luaotfload.loadmodule("fonts.lua")

--- now load luatexbase (from the TEX end)
--- then continue in luaotfload-deferred.lua

--  End of File `luaotfload.lua'.
