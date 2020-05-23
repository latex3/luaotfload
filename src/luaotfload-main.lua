-----------------------------------------------------------------------
--         FILE:  luaotfload-main.lua
--  DESCRIPTION:  OpenType layout system / luaotfload entry point
-- REQUIREMENTS:  luatex v.0.95.0 or later; package lualibs
--       AUTHOR:  Élie Roux, Khaled Hosny, Philipp Gesang, Ulrike Fischer, Marcel Krüger
-----------------------------------------------------------------------

local authors = "\z
    Hans Hagen,\z
    Khaled Hosny,\z
    Elie Roux,\z
    Will Robertson,\z
    Philipp Gesang,\z
    Dohyun Kim,\z
    Reuben Thomas,\z
    David Carlisle,\
    Ulrike Fischer,\z
    Marcel Krüger\z
"
-- version number is used below!
local ProvidesLuaModule = { 
    name          = "luaotfload-main",
    version       = "3.14",       --TAGVERSION
    date          = "2020-05-06", --TAGDATE
    description   = "luaotfload entry point",
    author        = authors,
    copyright     = authors,
    license       = "GPL v2.0"
}

if luatexbase and luatexbase.provides_module then
  luatexbase.provides_module (ProvidesLuaModule)
end  

local osgettimeofday              = os.gettimeofday
local luaotfload                  = luaotfload or { }
_ENV.luaotfload                   = luaotfload
local logreport                   = require "luaotfload-log".report --- Enable logging as soon as possible
luaotfload.version                = ProvidesLuaModule.version
luaotfload.fontloader_package     = "reference"    --- default: from current Context

if not tex or not tex.luatexversion then
    error "this program must be run in TeX mode" --- or call tex.initialize() =)
end

--- version check
local revno   = tonumber(tex.luatexrevision)
local minimum = { 110, 0 }
if tex.luatexversion < minimum[1] or tex.luatexversion == minimum[1] and revno < minimum[2] then
    texio.write_nl ("term and log",
                    string.format ("\tFATAL ERROR\n\z
                                    \tLuaotfload requires a Luatex version >= %d.%d.%d.\n\z
                                    \tPlease update your TeX distribution!\n\n",
                                   math.floor(minimum[1] / 100), minimum[1] % 100, minimum[2]))
    error "version check failed"
end

if not utf8 then
    texio.write_nl("term and log", string.format("\z
        \tluaotfload: module utf8 is unavailable\n\z
        \tutf8 is available in Lua 5.3+; engine\'s _VERSION is %q\n\z
        \tThis probably means that the engine is not supported\n\z
        \n",
        _VERSION))
    error "module utf8 is unavailable"
end

if status.safer_option ~= 0 then
 texio.write_nl("term and log","luaotfload can't run with option --safer. Aborting")
 error("safer_option used")
end 




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


--[[doc--

    \subsection{Module loading}
    We load the files imported from \CONTEXT with function derived this way. It
    automatically prepends a prefix to its argument, so we can refer to the
    files with their actual \CONTEXT name.

--doc]]--

local function loadmodule (name)
    local modname = 'luaotfload-' .. name
    local ok, data = pcall (require, modname)
    if not ok then
        io.write "\n"
        logreport ("both", 0, "load", "FATAL ERROR")
        logreport ("both", 0, "load", "  × Failed to load luaotfload module %q.",
                   tostring (name))
        local lines = string.split (data, "\n\t")
        if not lines then
            logreport ("both", 0, "load", "  × Error message: %q", data)
        else
            logreport ("both", 0, "load", "  × Error message:")
            for i = 1, #lines do
                logreport ("both", 0, "load", "    × %q.", lines [i])
            end
        end
        io.write "\n\n"
        local debug = debug
        if debug then
            io.write (debug.traceback())
            io.write "\n\n"
        end
        os.exit(-1)
    end
    return data
end

local function initialize (name)
    local tmp       = loadmodule (name)
    local init = type(tmp) == "table" and tmp.init or tmp
    if init and type (init) == "function" then
        local t_0 = osgettimeofday ()
        if not init () then
            logreport ("log", 0, "load",
                       "Failed to load module %q.", name)
            return
        end
        local t_end = osgettimeofday ()
        local d_t = t_end - t_0
        logreport ("log", 4, "load",
                   "Module %q loaded in %g ms.",
                   name, d_t * 1000)
    end
end

local luaotfload_initialized = false --- prevent multiple invocations

luaotfload.main = function ()

    if luaotfload_initialized then
        logreport ("log", 0, "load",
                   "Luaotfload initialization requested but is already \z
                   loaded, ignoring.")
        return
    end
    luaotfload_initialized = true

    local starttime = osgettimeofday ()

    if config and config.lualibs then
        config.lualibs.load_extended = true
    end

    -- Feature detect HarfBuzz. This is done early to allow easy HarfBuzz
    -- detection in other modules
    local harfstatus, harfbuzz = pcall(require, 'luaharfbuzz')
    if harfstatus then
        luaotfload.harfbuzz = harfbuzz
    end

    local init      = loadmodule "fontloader" --- fontloader initialization
    init (function ()
        luaotfload.parsers = loadmodule "parsers"         --- fonts.conf and syntax
        initialize "configuration"   --- configuration options
    end)

    initialize "loaders"         --- Font loading; callbacks
    initialize "database"        --- Font management.
    initialize "colors"          --- Per-font colors.

    local init_resolvers = loadmodule "resolvers" --- Font lookup
    init_resolvers ()

    if not config.actions.reconfigure () then
        logreport ("log", 0, "load", "Post-configuration hooks failed.")
    end

    initialize "features"     --- font request and feature handling

    if harfstatus then
        loadmodule "harf-define"
        loadmodule "harf-plug"
    end
    loadmodule "letterspace"  --- extra character kerning
    loadmodule "embolden"     --- fake bold
    loadmodule "notdef"       --- missing glyph handling
    loadmodule "suppress"     --- suppress ligatures by adding ZWNJ
    loadmodule "szss"       --- missing glyph handling
    initialize "auxiliary"    --- additional high-level functionality
    loadmodule "tounicode"

    luaotfload.aux.start_rewrite_fontname () --- to be migrated to fontspec

    logreport ("log", 1, "main",
               "initialization completed in %0.3f seconds\n",
               osgettimeofday() - starttime)
end

-- vim:tw=79:sw=4:ts=4:et
