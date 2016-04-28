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
local tableconcat         = table.concat
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
    local name, _format, success = fonts.names.lookup_font_file (specification.name)
    local suffix = filesuffix (name)
    if fonts.formats[suffix] then
        specification.forced      = stringlower (suffix)
        specification.forcedname  = fileremovesuffix (name)
    else
        specification.name = name
    end
    if success ~= true then
        logreport ("log", 1, "resolve", "file lookup of %q unsuccessful", name)
    end
    return success
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
    local exists, _  = lfsisfile (name)
    if not exists then -- resort to file: lookup
        logreport ("log", 1, "resolve",
                   "path lookup of %q unsuccessful, falling back to file:",
                   name)
        return resolve_file (specification)
    end
    local suffix = filesuffix (name)
    if fonts.formats [suffix] then
        specification.forced      = stringlower (suffix)
        specification.name        = fileremovesuffix (name)
        specification.forcedname  = name
    else
        specification.name = name
    end
    return true
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
        logreport ("log", 1, "resolve", "name lookup %q -> \"%s%s\"",
                   specification.name, resolved,
                   subfont and stringformat ("(%d)", subfont) or "")
        specification.resolved   = resolved
        specification.sub        = subfont
        specification.forced     = stringlower (filesuffix (resolved) or "")
        specification.forcedname = resolved
        specification.name       = fileremovesuffix (resolved)
        return true
    end
    return resolve_file (specification)
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

local tex_formats = { "tfm", "ofm", "TFM", "OFM", }

local resolve_tex_format = function (specification)
    local name = specification.name
    for i=1, #tex_formats do
        local format = tex_formats [i]
        local suffix = filesuffix (name)
        if resolvers.findfile (name, format) then
            local usename = suffix == format and fileremovesuffix (name) or name
            specification.forcedname = file.addsuffix (usename, format)
            specification.forced     = format
            return true
        end
    end
    return false
end

local resolve_path_if_exists = function (specification)
    local spec = specification.specification
    local exists, _void = lfsisfile (spec)
    if exists then
        --- If this path is taken a file matching the specification
        --- literally was found. In this situation, Luaotfload is
        --- expected to load that file directly, even though we provide
        --- explicit “file” and “path” lookups to address exactly this
        --- situation.
        logreport ("log", 1, "resolve",
                   "file %q exists, performing path lookup", spec)
        specification.name = spec
        return resolve_path (specification)
    end
    return false
end

local resolve_methods = {
    tex  = resolve_tex_format,
    path = resolve_path_if_exists,
    name = resolve_name,
}

local resolve_sequence = function (seq, specification)
    for i = 1, #seq do
        local id  = seq [i]
        local mth = resolve_methods [id]
        logreport ("both", 3, "resolve", "step %d: apply method %q (%s)", i, id, mth)
        if mth (specification) == true then
            logreport ("both", 3, "resolve",
                       "%d: method %q resolved %q -> %s (%s).",
                       i, id, specification.specification,
                       specification.name,
                       specification.forcedname)
            return true
        end
    end
    logreport ("both", 0, "resolve",
               "sequence of %d lookups yielded nothing appropriate.", #seq)
    return false
end

local default_anon_sequence = {
    "tex", "path", "name",
}

local resolve_anon
resolve_anon = function (specification)
    local seq = default_anon_sequence
    if config and config.luaotfload then
        local anonseq = config.luaotfload.run.anon_sequence
        if anonseq and next (anonseq) then
            seq = anonseq
        end
    end
    return resolve_sequence (seq, specification)
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
            return true
        end
    end
    for t, format in next, fonts.formats do --- brute force
        if kpsefind_file (name, format) then
            specification.forced = t
            specification.name   = name
            return true
        end
    end
    return false
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

--- vim:ft=lua:ts=8:sw=4:et:tw=79

