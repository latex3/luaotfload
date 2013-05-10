-- 
--  This is file `luaotfload.lua',
--  generated with the docstrip utility.
-- 
--  The original source files were:
-- 
--  luaotfload.dtx  (with options: `lua')
--  This is a generated file.
--  
--  Copyright (C) 2009-2013 by by Elie Roux    <elie.roux@telecom-bretagne.eu>
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
    version       = 1.29,
    date          = "2013/04/25",
    description   = "OpenType layout system.",
    author        = "Elie Roux & Hans Hagen",
    copyright     = "Elie Roux",
    license       = "CC0"
}

local error, warning, info, log = luatexbase.provides_module(luaotfload.module)
kpse.init_prog("", 600, "/")
local luatex_version = 60

if tex.luatexversion < luatex_version then
    warning("LuaTeX v%.2f is old, v%.2f is recommended.",
             tex.luatexversion/100,
             luatex_version   /100)
end


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

loadmodule"luaotfload-legacy-merged.lua"

if not fonts then
  loadmodule("otfl-luat-dum.lua") -- not used in context at all
  loadmodule("otfl-luat-ovr.lua") -- override some luat-dum functions
  loadmodule("otfl-data-con.lua") -- maybe some day we don't need this one
  loadmodule("otfl-font-ini.lua")
  loadmodule("otfl-node-dum.lua")
  loadmodule("otfl-node-inj.lua")
  loadmodule("luaotfload-legacy-attributes.lua") -- patch attributes
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
  loadmodule("otfl-font-xtx.lua")
  loadmodule("otfl-font-dum.lua")
  loadmodule("otfl-font-clr.lua")
end
loadmodule"luaotfload-legacy-database.lua" --- unmerged coz needed in db script

if fonts and fonts.tfm and fonts.tfm.readers then
    fonts.tfm.readers.ofm = fonts.tfm.readers.tfm
end
luatexbase.create_callback("luaotfload.patch_font", "simple", function() end)
local function def_font(...)
    local fontdata = fonts.define.read(...)
    if type(fontdata) == "table" and fontdata.shared then
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
        luatexbase.call_callback("luaotfload.patch_font", fontdata)
    end
    return fontdata
end
--fonts.define.resolvers.file = fonts.define.resolvers.name
fonts.mode = "node"
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
-- 
--  End of File `luaotfload.lua'.
