#!/usr/bin/env texlua
-----------------------------------------------------------------------
--         FILE:  luaotfload-resolvers.lua
--        USAGE:  ./luaotfload-resolvers.lua 
--  DESCRIPTION:  Resolvers for hooking into the fontloader
-- REQUIREMENTS:  Luaotfload and a decent bit of courage
--       AUTHOR:  Philipp Gesang (Phg), <phg@phi-gamma.net>
-----------------------------------------------------------------------
--
--- The bare fontloader uses a set of simplistic file name resolvers
--- that must be overloaded by the user (i. e. us).

if not lualibs    then error "this module requires Luaotfload" end
if not luaotfload then error "this module requires Luaotfload" end

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

local next                = next
local kpsefind_file       = kpse.find_file
local lfsisfile           = lfs.isfile
local stringlower         = string.lower
local stringformat        = string.format
local filesuffix          = file.suffix
local fileremovesuffix    = file.removesuffix
local luatexbase          = luatexbase
local logreport           = luaotfload.log.report

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

local resolve_file
resolve_file = function (specification)
    local name   = fonts.names.lookup_font_file (specification.name)
    local suffix = filesuffix (name)
    if fonts.formats[suffix] then
        specification.forced      = stringlower (suffix)
        specification.forcedname  = fileremovesuffix(name)
    else
        specification.name = name
    end
end

--[[doc--

    Prior to version 2.2, \identifier{luaotfload} did not distinguish
    \verb|file:| and \verb|path:| lookups, causing complications with
    the resolver.
    Now we test if the requested name is an absolute path in the file
    system, otherwise we fall back to the \verb|file:| lookup.

--doc]]--

local resolve_path
resolve_path = function (specification)
    local name       = specification.name
    local exists, _  = lfsisfile(name)
    if not exists then -- resort to file: lookup
        logreport ("log", 0, "load",
                   "path lookup of %q unsuccessful, falling back to file:",
                   name)
        resolve_file (specification)
    else
        local suffix = filesuffix (name)
        if fonts.formats[suffix] then
            specification.forced      = stringlower (suffix)
            specification.name        = fileremovesuffix(name)
            specification.forcedname  = name
        else
            specification.name = name
        end
    end
end

--[[doc--

    The \verb|name:| resolver.

--doc]]--

--- fonts.names.resolvers.name -- Customized version of the
--- generic name resolver.

local resolve_name
resolve_name = function (specification)
    local resolver = fonts.names.lookup_font_name_cached
    if config.luaotfload.run.resolver == "normal" then
        resolver = fonts.names.lookup_font_name
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
        resolve_file (specification)
    end
end

--[[doc--

    We classify as \verb|anon:| those requests that have neither a
    prefix nor brackets. According to Khaled\footnote{%
        % XXX dead link‽
        \url{https://github.com/phi-gamma/luaotfload/issues/4#issuecomment-17090553}.
    }
    they are the \XETEX equivalent of a \verb|name:| request, so we
    will be treating them as such or, at least, in a similar fashion.

    Not distinguishing between “anon” and “name” requests has a serious
    drawback: The syntax is overloaded for requesting fonts in
    \identifier{Type1} (\abbrev{tfm}, \abbrev{ofm}) format.
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

local resolve_anon
resolve_anon = function (specification)
    local name = specification.name
    for i=1, #type1_formats do
        local format = type1_formats[i]
        local suffix = filesuffix (name)
        if resolvers.findfile(name, format) then
            local usename = suffix == format and fileremovesuffix (name) or name
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
        resolve_path (specification)
        return
    end
    resolve_name (specification)
end

--[[doc--

    {\bfseries EXPERIMENTAL}:
    \identifier{kpse}-only resolver, for those who can do without
    system fonts.

--doc]]--

local resolve_kpse
resolve_kpse = function (specification)
    local name       = specification.name
    local suffix     = filesuffix (name)
    if suffix and fonts.formats[suffix] then
        name = fileremovesuffix (name)
        if resolvers.findfile (name, suffix) then
            specification.forced       = stringlower (suffix)
            specification.forcedname   = name
            return
        end
    end
    for t, format in next, fonts.formats do --- brute force
        if kpsefind_file (name, format) then
            specification.forced = t
            specification.name   = name
            return
        end
    end
end

--[[doc--

    Also {\bfseries EXPERIMENTAL}: custom file resolvers via callback.

--doc]]--

local resolve_my = function (specification)
    luatexbase.call_callback ("luaotfload.resolve_font", specification)
end

return {
    init = function ( )
        if luatexbase and luatexbase.create_callback then
            luatexbase.create_callback ("luaotfload.resolve_font",
                                        "simple", function () end)
        end
        logreport ("log", 5, "resolvers", "installing font resolvers", name)
        local request_resolvers = fonts.definers.resolvers
        request_resolvers.file = resolve_file
        request_resolvers.name = resolve_name
        request_resolvers.anon = resolve_anon
        request_resolvers.path = resolve_path
        request_resolvers.kpse = resolve_kpse
        request_resolvers.my   = resolve_my
        fonts.formats.ofm      = "type1"
        fonts.encodings        = fonts.encodings       or { }
        fonts.encodings.known  = fonts.encodings.known or { }
        return true
    end, --- [.init]
}

--- vim:ft=lua:ts=8:sw=4:et

