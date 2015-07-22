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
local setmetatable     = setmetatable
local type, next       = type, next
local stringlower      = string.lower
local stringformat     = string.format

local kpsefind_file    = kpse.find_file
local lfsisfile        = lfs.isfile

local add_to_callback  = luatexbase.add_to_callback
local create_callback  = luatexbase.create_callback
local reset_callback   = luatexbase.reset_callback
local call_callback    = luatexbase.call_callback

local dummy_function = function () end --- XXX this will be moved to the luaotfload namespace when we have the init module

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

load_luaotfload_module "parsers"         --- fonts.conf and syntax
load_luaotfload_module "configuration"   --- configuration options

if not config.actions.apply_defaults () then
    logreport ("log", 0, "load", "Configuration unsuccessful.")
end

luaotfload.init.main (store)

load_luaotfload_module "loaders"         --- Type1 font wrappers
load_luaotfload_module "database"        --- Font management.
load_luaotfload_module "colors"          --- Per-font colors.

if not config.actions.reconfigure () then
    logreport ("log", 0, "load", "Post-configuration hooks failed.")
end

--[[doc--

    Relying on the \verb|name:| resolver for everything has been the
    source of permanent trouble with the database.
    With the introduction of the new syntax parser we now have enough
    granularity to distinguish between the \XETEX emulation layer and
    the genuine \verb|name:| and \verb|file:| lookups of \LUATEX-Fonts.
    Another benefit is that we can now easily plug in or replace new
    lookup behaviors if necessary.
    The name resolver remains untouched, but it calls
    \luafunction{fonts.names.resolve()} internally anyways (see
    \fileent{luaotfload-database.lua}).

--doc]]--

local filesuffix          = file.suffix
local fileremovesuffix    = file.removesuffix
local request_resolvers   = fonts.definers.resolvers
local formats             = fonts.formats
local names               = fonts.names
formats.ofm               = "type1"

fonts.encodings.known     = fonts.encodings.known or { }

--[[doc--

    \identifier{luaotfload} promises easy access to system fonts.
    Without additional precautions, this cannot be achieved by
    \identifier{kpathsea} alone, because it searches only the
    \fileent{texmf} directories by default.
    Although it is possible for \identifier{kpathsea} to include extra
    paths by adding them to the \verb|OSFONTDIR| environment variable,
    this is still short of the goal »\emphasis{it just works!}«.
    When building the font database \identifier{luaotfload} scans
    system font directories anyways, so we already have all the
    information for looking sytem fonts.
    With the release version 2.2 the file names are indexed in the
    database as well and we are ready to resolve \verb|file:| lookups
    this way.
    Thus we no longer need to call the \identifier{kpathsea} library in
    most cases when looking up font files, only when generating the
    database, and when verifying the existence of a file in the
    \fileent{texmf} tree.

--doc]]--

local resolve_file        = names.font_file_lookup

local file_resolver = function (specification)
    local name    = resolve_file (specification.name)
    local suffix  = filesuffix(name)
    if formats[suffix] then
        specification.forced      = stringlower (suffix)
        specification.forcedname  = file.removesuffix(name)
    else
        specification.name = name
    end
end

request_resolvers.file = file_resolver

--[[doc--

    We classify as \verb|anon:| those requests that have neither a
    prefix nor brackets. According to Khaled\footnote{%
        \url{https://github.com/phi-gamma/luaotfload/issues/4#issuecomment-17090553}.
    }
    they are the \XETEX equivalent of a \verb|name:| request, so we
    will be treating them as such.

--doc]]--

--request_resolvers.anon = request_resolvers.name

--[[doc--

    There is one drawback, though.
    This syntax is also used for requesting fonts in \identifier{Type1}
    (\abbrev{tfm}, \abbrev{ofm}) format.
    These are essentially \verb|file:| lookups and must be caught
    before the \verb|name:| resolver kicks in, lest they cause the
    database to update.
    Even if we were to require the \verb|file:| prefix for all
    \identifier{Type1} requests, tests have shown that certain fonts
    still include further fonts (e.~g. \fileent{omlgcb.ofm} will ask
    for \fileent{omsecob.tfm}) \emphasis{using the old syntax}.
    For this reason, we introduce an extra check with an early return.

--doc]]--

local type1_formats = { "tfm", "ofm", "TFM", "OFM", }

request_resolvers.anon = function (specification)
    local name = specification.name
    for i=1, #type1_formats do
        local format = type1_formats[i]
        local suffix = filesuffix (name)
        if resolvers.findfile(name, format) then
            local usename = suffix == format and file.removesuffix (name) or name
            specification.forcedname = file.addsuffix (usename, format)
            specification.forced     = format
            return
        end
    end
    --- under some weird circumstances absolute paths get
    --- passed to the definer; we have to catch them
    --- before the name: resolver misinterprets them.
    name = specification.specification
    local exists, _ = lfsisfile(name)
    if exists then --- garbage; we do this because we are nice,
                   --- not because it is correct
        logreport ("log", 1, "load", "file %q exists", name)
        logreport ("log", 1, "load",
                   "... overriding borked anon: lookup with path: lookup")
        specification.name = name
        request_resolvers.path(specification)
        return
    end
    request_resolvers.name(specification)
end

--[[doc--

    Prior to version 2.2, \identifier{luaotfload} did not distinguish
    \verb|file:| and \verb|path:| lookups, causing complications with
    the resolver.
    Now we test if the requested name is an absolute path in the file
    system, otherwise we fall back to the \verb|file:| lookup.

--doc]]--

request_resolvers.path = function (specification)
    local name       = specification.name
    local exists, _  = lfsisfile(name)
    if not exists then -- resort to file: lookup
        logreport ("log", 0, "load",
                   "path lookup of %q unsuccessful, falling back to file:",
                   name)
        file_resolver (specification)
    else
        local suffix = filesuffix (name)
        if formats[suffix] then
            specification.forced      = stringlower (suffix)
            specification.name        = file.removesuffix(name)
            specification.forcedname  = name
        else
            specification.name = name
        end
    end
end

--[[doc--

    {\bfseries EXPERIMENTAL}:
    \identifier{kpse}-only resolver, for those who can do without
    system fonts.

--doc]]--

request_resolvers.kpse = function (specification)
    local name       = specification.name
    local suffix     = filesuffix(name)
    if suffix and formats[suffix] then
        name = file.removesuffix(name)
        if resolvers.findfile(name, suffix) then
            specification.forced       = stringlower (suffix)
            specification.forcedname   = name
            return
        end
    end
    for t, format in next, formats do --- brute force
        if kpse.find_file (name, format) then
            specification.forced = t
            specification.name   = name
            return
        end
    end
end

--[[doc--

    The \verb|name:| resolver.

--doc]]--

--- fonts.names.resolvers.name -- Customized version of the
--- generic name resolver.

request_resolvers.name = function (specification)
    local resolver = names.resolve_cached
    if config.luaotfload.run.resolver == "normal" then
        resolver = names.resolve_name
    end
    local resolved, subfont = resolver (specification)
    if resolved then
        logreport ("log", 0, "load", "Lookup/name: %q -> \"%s%s\"",
                   specification.name,
                   resolved,
                   subfont and stringformat ("(%d)", subfont) or "")
        specification.resolved   = resolved
        specification.sub        = subfont
        specification.forced     = stringlower (filesuffix (resolved) or "")
        specification.forcedname = resolved
        specification.name       = fileremovesuffix (resolved)
    else
        file_resolver (specification)
    end
end

--[[doc--

    Also {\bfseries EXPERIMENTAL}: custom file resolvers via callback.

--doc]]--
create_callback("luaotfload.resolve_font", "simple", dummy_function)

request_resolvers.my = function (specification)
    call_callback("luaotfload.resolve_font", specification)
end

--[[doc--

    We create callbacks for patching fonts on the fly, to be used by
    other packages. In addition to the regular \identifier{patch_font}
    callback there is an unsafe variant \identifier{patch_font_unsafe}
    that will be invoked even if the target font lacks certain essential
    tfmdata tables.

    The callbacks initially contain the empty function that we are going to
    override below.

--doc]]--

create_callback("luaotfload.patch_font",        "simple", dummy_function)
create_callback("luaotfload.patch_font_unsafe", "simple", dummy_function)

--[[doc--

    \subsection{\CONTEXT override}
    \label{define-font}
    We provide a simplified version of the original font definition
    callback.

--doc]]--


local definers = { } --- (string, spec -> size -> id -> tmfdata) hash_t
do
    local read = fonts.definers.read

    local patch = function (specification, size, id)
        local fontdata = read (specification, size, id)
        if type (fontdata) == "table" and fontdata.shared then
            --- We need to test for the “shared” field here
            --- or else the fontspec capheight callback will
            --- operate on tfm fonts.
            call_callback ("luaotfload.patch_font", fontdata, specification)
        else
            call_callback ("luaotfload.patch_font_unsafe", fontdata, specification)
        end
        return fontdata
    end

    local mk_info = function (name)
        local definer = name == "patch" and patch or read
        return function (specification, size, id)
            logreport ("both", 0, "main", "defining font no. %d", id)
            logreport ("both", 0, "main", "   > active font definer: %q", name)
            logreport ("both", 0, "main", "   > spec %q", specification)
            logreport ("both", 0, "main", "   > at size %.2f pt", size / 2^16)
            local result = definer (specification, size, id)
            if not result then
                logreport ("both", 0, "main", "   > font definition failed")
                return
            elseif type (result) == "number" then
                logreport ("both", 0, "main", "   > font definition yielded id %d", result)
                return result
            end
            logreport ("both", 0, "main", "   > font definition successful")
            logreport ("both", 0, "main", "   > name %q",     result.name     or "<nil>")
            logreport ("both", 0, "main", "   > fontname %q", result.fontname or "<nil>")
            logreport ("both", 0, "main", "   > fullname %q", result.fullname or "<nil>")
            return result
        end
    end

    definers.patch          = patch
    definers.generic        = read
    definers.info_patch     = mk_info "patch"
    definers.info_generic   = mk_info "generic"
end

reset_callback "define_font"

--[[doc--

    Finally we register the callbacks.

--doc]]--

local definer = config.luaotfload.run.definer
add_to_callback ("define_font", definers[definer], "luaotfload.define_font", 1)

load_luaotfload_module "features"     --- font request and feature handling
load_luaotfload_module "letterspace"  --- extra character kerning
load_luaotfload_module "auxiliary"    --- additional high-level functionality

luaotfload.aux.start_rewrite_fontname () --- to be migrated to fontspec

-- vim:tw=79:sw=4:ts=4:et
