-----------------------------------------------------------------------
--         FILE:  luaotfload-main.lua
--  DESCRIPTION:  Luaotfload entry point
-- REQUIREMENTS:  luatex v.0.80 or later; packages lualibs, luatexbase
--       AUTHOR:  Élie Roux, Khaled Hosny, Philipp Gesang
--      VERSION:  same as Luaotfload
--     MODIFIED:  2015-06-09 23:08:18+0200
-----------------------------------------------------------------------
--
--- Note:
--- This file was part of the original luaotfload.dtx and has been
--- converted to a pure Lua file during the transition from Luaotfload
--- version 2.4 to 2.5. Thus, the comments are still in TeX (Latex)
--- markup.

local initial_log_level           = 0
luaotfload                        = luaotfload or { }
config                            = config     or { }
local luaotfload                  = luaotfload
luaotfload.log                    = luaotfload.log or { }
luaotfload.version                = "2.6"
luaotfload.loaders                = { }
luaotfload.min_luatex_version     = 79             --- i. e. 0.79
luaotfload.fontloader_package     = "reference"    --- default: from current Context

local authors = "\z
    Hans Hagen,\z
    Khaled Hosny,\z
    Elie Roux,\z
    Will Robertson,\z
    Philipp Gesang,\z
    Dohyun Kim,\z
    Reuben Thomas\z
"


luaotfload.module = {
    name          = "luaotfload-main",
    version       = 2.60001,
    date          = "2015/05/26",
    description   = "OpenType layout system.",
    author        = authors,
    copyright     = authors,
    license       = "GPL v2.0"
}

--[[doc--

    This file initializes the system and loads the font loader. To
    minimize potential conflicts between other packages and the code
    imported from \CONTEXT, several precautions are in order. Some of
    the functionality that the font loader expects to be present, like
    raw access to callbacks, are assumed to have been disabled by
    \identifier{luatexbase} when this file is processed. In some cases
    it is possible to trick it by putting dummies into place and
    restoring the behavior from \identifier{luatexbase} after
    initilization. Other cases such as attribute allocation require
    that we hook the functionality from \identifier{luatexbase} into
    locations where they normally wouldn’t be.

    Anyways we can import the code base without modifications, which is
    due mostly to the extra effort by Hans Hagen to make \LUATEX-Fonts
    self-contained and encapsulate it, and especially due to his
    willingness to incorporate our suggestions.

--doc]]--

local luatexbase       = luatexbase
local require          = require
local type             = type

local error, warning, info, log =
    luatexbase.provides_module(luaotfload.module)

luaotfload.log.tex        = {
    error        = error,
    warning      = warning,
    info         = info,
    log          = log,
}

--[[doc--

     We set the minimum version requirement for \LUATEX to v0.76,
     because the font loader requires recent features like direct
     attribute indexing and \luafunction{node.end_of_math()} that aren’t
     available in earlier versions.\footnote{%
      See Taco’s announcement of v0.76:
      \url{http://comments.gmane.org/gmane.comp.tex.luatex.user/4042}
      and this commit by Hans that introduced those features.
      \url{http://repo.or.cz/w/context.git/commitdiff/a51f6cf6ee087046a2ae5927ed4edff0a1acec1b}.
    }

--doc]]--

if tex.luatexversion < luaotfload.min_luatex_version then
    warning ("LuaTeX v%.2f is old, v%.2f or later is recommended.",
             tex.luatexversion  / 100,
             luaotfload.min_luatex_version / 100)
    warning ("using fallback fontloader -- newer functionality not available")
    luaotfload.fontloader_package = "tl2014" --- TODO fallback should be configurable too
    --- we install a fallback for older versions as a safety
end

--[[doc--

    \subsection{Module loading}
    We load the files imported from \CONTEXT with function derived this way. It
    automatically prepends a prefix to its argument, so we can refer to the
    files with their actual \CONTEXT name.

--doc]]--

local make_loader_name = function (prefix, name)
    local msg = luaotfload.log and luaotfload.log.report or print
    if prefix then
        msg ("log", 7, "load",
             "Composing fontloader name from constitutents %s, %s",
             prefix, name)
        return prefix .. "-" .. name .. ".lua"
    end
    msg ("log", 7, "load",
         "Loading fontloader file %s literally.",
         name)
    return name
end

local make_loader = function (prefix)
    return function (name)
        local modname = make_loader_name (prefix, name)
        return require (modname)
    end
end

local load_luaotfload_module = make_loader "luaotfload"
----- load_luaotfload_module = make_loader "luatex" --=> for Luatex-Plain
local load_fontloader_module = make_loader "fontloader"

luaotfload.loaders.luaotfload = load_luaotfload_module
luaotfload.loaders.fontloader = load_fontloader_module

luaotfload.init = load_luaotfload_module "init" --- fontloader initialization

local store           = luaotfload.init.early ()
local log             = luaotfload.log
local logreport       = log.report

--[[doc--

    Now we load the modules written for \identifier{luaotfload}.

--doc]]--

luaotfload.init.main (store)

luaotfload.main = function ()
    local starttime = os.gettimeofday ()

    local tmp = load_luaotfload_module "parsers" --- fonts.conf and syntax
    if not tmp.init () then
        logreport ("log", 0, "load", "Failed to install the parsers.")
    end

    local tmp = load_luaotfload_module "configuration"   --- configuration options
    if not tmp.init() or not config.actions.apply_defaults () then
        logreport ("log", 0, "load", "Configuration unsuccessful.")
    end

    luaotfload.loaders = load_luaotfload_module "loaders" --- Font loading; callbacks
    if not luaotfload.loaders.install () then
        logreport ("log", 0, "load", "Callback and loader initialization failed.")
    end

    load_luaotfload_module "database"        --- Font management.
    load_luaotfload_module "colors"          --- Per-font colors.

    luaotfload.resolvers = load_luaotfload_module "resolvers" --- Font lookup
    luaotfload.resolvers.install ()

    if not config.actions.reconfigure () then
        logreport ("log", 0, "load", "Post-configuration hooks failed.")
    end

    load_luaotfload_module "features"     --- font request and feature handling
    load_luaotfload_module "letterspace"  --- extra character kerning
    load_luaotfload_module "auxiliary"    --- additional high-level functionality

    luaotfload.aux.start_rewrite_fontname () --- to be migrated to fontspec

    logreport ("both", 0, "main",
               "initialization completed in %0.3f seconds",
               os.gettimeofday() - starttime)
end

-- vim:tw=79:sw=4:ts=4:et
