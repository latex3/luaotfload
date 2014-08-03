-----------------------------------------------------------------------
--         FILE:  luaotfload-main.lua
--  DESCRIPTION:  Luatex fontloader initialization
-- REQUIREMENTS:  luatex v.0.79 or later; packages lualibs, luatexbase
--       AUTHOR:  Élie Roux, Khaled Hosny, Philipp Gesang
--      VERSION:  same as Luaotfload
--     MODIFIED:  2014-08-03 10:13:55+0200
-----------------------------------------------------------------------
--
--- Note:
--- This file was part of the original luaotfload.dtx and has been
--- converted to a pure Lua file during the transition from Luaotfload
--- version 2.4 to 2.5. Thus, the comments are still in TeX (Latex)
--- markup.

if not modules then modules = { } end modules ["luaotfload-main"] = {
    version   = "2.5",
    comment   = "fontloader initialization",
    author    = "Hans Hagen, Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "GNU General Public License v. 2.0"
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

local initial_log_level = 0

luaotfload                        = luaotfload or { }
local luaotfload                  = luaotfload
luaotfload.log                    = luaotfload.log or { }
luaotfload.version                = "2.5-3" -- FIXME version belongs in common init

luaotfload.module = {
    name          = "luaotfload-main",
    version       = 2.50002,
    date          = "2014/08/03",
    description   = "OpenType layout system.",
    author        = "Elie Roux & Hans Hagen",
    copyright     = "Elie Roux",
    license       = "GPL v2.0"
}

local luatexbase       = luatexbase

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

local dummy_function    = function () end --- XXX this will be moved to the luaotfload namespace when we have the init module

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

local min_luatex_version = 79

if tex.luatexversion < min_luatex_version then
    warning ("LuaTeX v%.2f is old, v%.2f or later is recommended.",
             tex.luatexversion  / 100,
             min_luatex_version / 100)
    --- we install a fallback for older versions as a safety
    if not node.end_of_math then
        local math_t          = node.id "math"
        local traverse_nodes  = node.traverse_id
        node.end_of_math = function (n)
            for n in traverse_nodes (math_t, n.next) do
                return n
            end
        end
    end
end

--[[doc--

    \subsection{Module loading}
    We load the files imported from \CONTEXT with this function. It
    automatically prepends the prefix \fileent{luaotfload-} to its
    argument, so we can refer to the files with their actual \CONTEXT
    name.

--doc]]--

local fl_prefix = "luaotfload" -- “luatex” for luatex-plain
local loadmodule = function (name)
    require (fl_prefix .."-"..name)
end

loadmodule "log.lua"             --- log messages
--loadmodule "parsers.lua"         --- new in 2.5; fonts.conf and syntax
--loadmodule "configuration.lua"   --- configuration options

local log             = luaotfload.log
local logreport       = log.report

log.set_loglevel (default_log_level)

--[[doc--

  Before \TeX Live 2013 version, \LUATEX had a bug that made ofm fonts
  fail when called with their extension. There was a side-effect making
  ofm totally unloadable when luaotfload was present. The following
  lines are a patch for this bug. The utility of these lines is
  questionable as they are not necessary since \TeX Live 2013. They
  should be removed in the next version.

--doc]]--

local Cs, P, lpegmatch = lpeg.Cs, lpeg.P, lpeg.match

local p_dot, p_slash = P".",  P"/"
local p_suffix       = (p_dot * (1 - p_dot - p_slash)^1 * P(-1)) / ""
local p_removesuffix = Cs((p_suffix + 1)^1)

local find_vf_file = function (name)
    local fullname = kpsefind_file(name, "ovf")
    if not fullname then
        --fullname = kpsefind_file(file.removesuffix(name), "ovf")
        fullname = kpsefind_file(lpegmatch(p_removesuffix, name), "ovf")
    end
    if fullname then
        logreport ("log", 0, "main",
                   "loading virtual font file %s.", fullname)
    end
    return fullname
end

--[[doc--

    \subsection{Preparing the Font Loader}
    We treat the fontloader as a black box so behavior is consistent
    between formats.
    We load the fontloader code directly in the same fashion as the
    Plain format \identifier{luatex-fonts} that is part of Context.
    How this is executed depends on the presence on the
    \emphasis{merged font loader code}.
    In \identifier{luaotfload} this is contained in the file
    \fileent{luaotfload-merged.lua}.
    If this file cannot be found, the original libraries from \CONTEXT
    of which the merged code was composed are loaded instead.
    Since these files are not shipped with Luaotfload, an installation
    of Context is required.
    (Since we pull the fontloader directly from the Context minimals,
    the necessary Context version is likely to be more recent than that
    of other TeX distributions like Texlive.)
    The imported font loader will call \luafunction{callback.register}
    once while reading \fileent{font-def.lua}.
    This is unavoidable unless we modify the imported files, but
    harmless if we make it call a dummy instead.
    However, this problem might vanish if we decide to do the merging
    ourselves, like the \identifier{lualibs} package does.
    With this step we would obtain the freedom to load our own
    overrides in the process right where they are needed, at the cost
    of losing encapsulation.
    The decision on how to progress is currently on indefinite hold.

--doc]]--

local starttime         = os.gettimeofday ()
local trapped_register  = callback.register
callback.register       = dummy_function

--[[doc--

    By default, the fontloader requires a number of \emphasis{private
    attributes} for internal use.
    These must be kept consistent with the attribute handling methods
    as provided by \identifier{luatexbase}.
    Our strategy is to override the function that allocates new
    attributes before we initialize the font loader, making it a
    wrapper around \luafunction{luatexbase.new_attribute}.\footnote{%
        Many thanks, again, to Hans Hagen for making this part
        configurable!
    }
    The attribute identifiers are prefixed “\fileent{luaotfload@}” to
    avoid name clashes.

--doc]]--

do
    local new_attribute    = luatexbase.new_attribute
    local the_attributes   = luatexbase.attributes

    attributes = attributes or { }

    attributes.private = function (name)
        local attr   = "luaotfload@" .. name --- used to be: “otfl@”
        local number = the_attributes[attr]
        if not number then
            number = new_attribute(attr)
        end
        return number
    end
end

--[[doc--

    These next lines replicate the behavior of
    \fileent{luatex-fonts.lua}.

--doc]]--

local context_environment = { }

local push_namespaces = function ()
    logreport ("log", 1, "main", "push namespace for font loader")
    local normalglobal = { }
    for k, v in next, _G do
        normalglobal[k] = v
    end
    return normalglobal
end

local pop_namespaces = function (normalglobal, isolate)
    if normalglobal then
        local _G = _G
        local mode = "non-destructive"
        if isolate then mode = "destructive" end
        logreport ("log", 1, "main", "pop namespace from font loader -- " .. mode)
        for k, v in next, _G do
            if not normalglobal[k] then
                context_environment[k] = v
                if isolate then
                    _G[k] = nil
                end
            end
        end
        for k, v in next, normalglobal do
            _G[k] = v
        end
        -- just to be sure:
        setmetatable(context_environment,_G)
    else
        logreport ("both", 0, "main",
                   "irrecoverable error during pop_namespace: no globals to restore")
        os.exit()
    end
end

luaotfload.context_environment  = context_environment
luaotfload.push_namespaces      = push_namespaces
luaotfload.pop_namespaces       = pop_namespaces

local our_environment = push_namespaces()

--[[doc--

    The font loader requires that the attribute with index zero be
    zero. We happily oblige.
    (Cf. \fileent{luatex-fonts-nod.lua}.)

--doc]]--

tex.attribute[0] = 0

--[[doc--

    Now that things are sorted out we can finally load the fontloader.

--doc]]--

loadmodule "fontloader.lua"
---loadmodule"font-odv.lua" --- <= Devanagari support from Context

if fonts then

    if not fonts._merge_loaded_message_done_ then
        logreport ("log", 5, "main", [["I am using the merged fontloader here.]])
        logreport ("log", 5, "main", [[ If you run into problems or experience unexpected]])
        logreport ("log", 5, "main", [[ behaviour, and if you have ConTeXt installed you can try]])
        logreport ("log", 5, "main", [[ to delete the file 'luaotfload-fontloader.lua' as I might]])
        logreport ("log", 5, "main", [[ then use the possibly updated libraries. The merged]])
        logreport ("log", 5, "main", [[ version is not supported as it is a frozen instance.]])
        logreport ("log", 5, "main", [[ Problems can be reported to the ConTeXt mailing list."]])
    end
    fonts._merge_loaded_message_done_ = true

else--- the loading sequence is known to change, so this might have to
    --- be updated with future updates!
    --- do not modify it though unless there is a change to the merged
    --- package!
    loadmodule("l-lua.lua")
    loadmodule("l-lpeg.lua")
    loadmodule("l-function.lua")
    loadmodule("l-string.lua")
    loadmodule("l-table.lua")
    loadmodule("l-io.lua")
    loadmodule("l-file.lua")
    loadmodule("l-boolean.lua")
    loadmodule("l-math.lua")
    loadmodule("util-str.lua")
    loadmodule('luatex-basics-gen.lua')
    loadmodule('data-con.lua')
    loadmodule('luatex-basics-nod.lua')
    loadmodule('font-ini.lua')
    loadmodule('font-con.lua')
    loadmodule('luatex-fonts-enc.lua')
    loadmodule('font-cid.lua')
    loadmodule('font-map.lua')
    loadmodule('luatex-fonts-syn.lua')
    loadmodule('luatex-fonts-tfm.lua')
    loadmodule('font-oti.lua')
    loadmodule('font-otf.lua')
    loadmodule('font-otb.lua')
    loadmodule('luatex-fonts-inj.lua')  --> since 2014-01-07, replaces node-inj.lua
    loadmodule('font-ota.lua')
    loadmodule('luatex-fonts-otn.lua')  --> since 2014-01-07, replaces font-otn.lua
    loadmodule('font-otp.lua')          --> since 2013-04-23
    loadmodule('luatex-fonts-lua.lua')
    loadmodule('font-def.lua')
    loadmodule('luatex-fonts-def.lua')
    loadmodule('luatex-fonts-ext.lua')
    loadmodule('luatex-fonts-cbk.lua')
end --- non-merge fallback scope

--[[doc--

    Here we adjust the globals created during font loader
    initialization. If the second argument to
    \luafunction{pop_namespaces()} is \verb|true| this will restore the
    state of \luafunction{_G}, eliminating every global generated since
    the last call to \luafunction{push_namespaces()}. At the moment we
    see no reason to do this, and since the font loader is considered
    an essential part of \identifier{luatex} as well as a very well
    organized piece of code, we happily concede it the right to add to
    \luafunction{_G} if needed.

--doc]]--

pop_namespaces(our_environment, false)-- true)

logreport ("both", 0, "main",
           "fontloader loaded in %0.3f seconds", os.gettimeofday()-starttime)

--[[doc--

    \subsection{Callbacks}
    After the fontloader is ready we can restore the callback trap from
    \identifier{luatexbase}.

--doc]]--

callback.register = trapped_register

--[[doc--

    We do our own callback handling with the means provided by
    luatexbase.
    Note: \luafunction{pre_linebreak_filter} and
    \luafunction{hpack_filter} are coupled in \CONTEXT in the concept
    of \emphasis{node processor}.

--doc]]--

add_to_callback("pre_linebreak_filter",
                nodes.simple_font_handler,
                "luaotfload.node_processor",
                1)
add_to_callback("hpack_filter",
                nodes.simple_font_handler,
                "luaotfload.node_processor",
                1)
add_to_callback("find_vf_file",
                find_vf_file, "luaotfload.find_vf_file")

loadmodule "override.lua"   --- load glyphlist on demand

--[[doc--

    Now we load the modules written for \identifier{luaotfload}.

--doc]]--

loadmodule "parsers.lua"         --- fonts.conf and syntax
loadmodule "configuration.lua"   --- configuration options

if not config.actions.apply_defaults () then
    logreport ("log", 0, "load", "Configuration unsuccessful.")
end

loadmodule "loaders.lua"         --- Type1 font wrappers
loadmodule "database.lua"        --- Font management.
loadmodule "colors.lua"          --- Per-font colors.

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
        if resolvers.findfile(name, format) then
            specification.forcedname = file.addsuffix(name, format)
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

    We create a callback for patching fonts on the fly, to be used by
    other packages.
    It initially contains the empty function that we are going to
    override below.

--doc]]--

create_callback("luaotfload.patch_font", "simple", dummy_function)

--[[doc--

    \subsection{\CONTEXT override}
    \label{define-font}
    We provide a simplified version of the original font definition
    callback.

--doc]]--

local read_font_file = fonts.definers.read

local definers = {
    generic = read_font_file,
    --- spec -> size -> id -> tmfdata
    patch = function (specification, size, id)
        local tfmdata = read_font_file (specification, size, id)
        if type (tfmdata) == "table" and tfmdata.shared then
            --- We need to test for the “shared” field here
            --- or else the fontspec capheight callback will
            --- operate on tfm fonts.
            call_callback ("luaotfload.patch_font", tfmdata, specification)
        end
        return tfmdata
    end,
}

reset_callback "define_font"

--[[doc--

    Finally we register the callbacks.

--doc]]--

local definer = config.luaotfload.run.definer
add_to_callback ("define_font", definers[definer], "luaotfload.define_font", 1)

loadmodule "features.lua"     --- font request and feature handling
loadmodule "letterspace.lua"  --- extra character kerning
loadmodule "auxiliary.lua"    --- additional high-level functionality

luaotfload.aux.start_rewrite_fontname () --- to be migrated to fontspec

-- vim:tw=79:sw=4:ts=4:et
