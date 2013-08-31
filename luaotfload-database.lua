if not modules then modules = { } end modules ['luaotfload-database'] = {
    version   = "2.3b",
    comment   = "companion to luaotfload.lua",
    author    = "Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2"
}

--- TODO: if the specification is an absolute filename with a font not in the
--- database, add the font to the database and load it. There is a small
--- difficulty with the filenames of the TEXMF tree that are referenced as
--- relative paths...

local lpeg = require "lpeg"

local P, R, S, lpegmatch
    = lpeg.P, lpeg.R, lpeg.S, lpeg.match

local C, Cc, Cf, Cg, Cs, Ct
    = lpeg.C, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Cs, lpeg.Ct

--- Luatex builtins
local load                    = load
local next                    = next
local pcall                   = pcall
local require                 = require
local tonumber                = tonumber
local unpack                  = table.unpack

local fontloaderinfo          = fontloader.info
local fontloaderclose         = fontloader.close
local fontloaderopen          = fontloader.open
local fontloaderto_table      = fontloader.to_table
local iolines                 = io.lines
local ioopen                  = io.open
local kpseexpand_path         = kpse.expand_path
local kpseexpand_var          = kpse.expand_var
local kpsefind_file           = kpse.find_file
local kpselookup              = kpse.lookup
local kpsereadable_file       = kpse.readable_file
local lfsattributes           = lfs.attributes
local lfschdir                = lfs.chdir
local lfscurrentdir           = lfs.currentdir
local lfsdir                  = lfs.dir
local mathabs                 = math.abs
local mathmin                 = math.min
local osremove                = os.remove
local stringfind              = string.find
local stringformat            = string.format
local stringgmatch            = string.gmatch
local stringgsub              = string.gsub
local stringlower             = string.lower
local stringsub               = string.sub
local stringupper             = string.upper
local tableconcat             = table.concat
local tablesort               = table.sort
local texiowrite_nl           = texio.write_nl
local utf8gsub                = unicode.utf8.gsub
local utf8lower               = unicode.utf8.lower

--- these come from Lualibs/Context
local getwritablepath         = caches.getwritablepath
local filebasename            = file.basename
local filecollapsepath        = file.collapsepath or file.collapse_path
local filedirname             = file.dirname
local fileextname             = file.extname
local fileiswritable          = file.iswritable
local filejoin                = file.join
local filenameonly            = file.nameonly
local filereplacesuffix       = file.replacesuffix
local filesplitpath           = file.splitpath or file.split_path
local filesuffix              = file.suffix
local lfsisdir                = lfs.isdir
local lfsisfile               = lfs.isfile
local lfsmkdirs               = lfs.mkdirs
local stringis_empty          = string.is_empty
local stringsplit             = string.split
local stringstrip             = string.strip
local tableappend             = table.append
local tablecopy               = table.copy
local tablefastcopy           = table.fastcopy
local tabletofile             = table.tofile
local tabletohash             = table.tohash

--- the font loader namespace is “fonts”, same as in Context
--- we need to put some fallbacks into place for when running
--- as a script
fonts                = fonts          or { }
fonts.names          = fonts.names    or { }
fonts.definers       = fonts.definers or { }

local names          = fonts.names

config                         = config or { }
config.luaotfload              = config.luaotfload or { }
config.luaotfload.resolver     = config.luaotfload.resolver or "normal"
config.luaotfload.formats      = config.luaotfload.formats or "otf,ttf,ttc,dfont"

if config.luaotfload.update_live ~= false then
    --- this option allows for disabling updates
    --- during a TeX run
    config.luaotfload.update_live = true
end

names.version        = 2.4
names.data           = nil      --- contains the loaded database
names.lookups        = nil      --- contains the lookup cache

names.path           = { index = { }, lookups = { } }
names.path.globals   = {
    prefix           = "", --- writable_path/names_dir
    names_dir        = config.luaotfload.names_dir or "names",
    index_file       = config.luaotfload.index_file
                    or "luaotfload-names.lua",
    lookups_file     = "luaotfload-lookup-cache.lua",
}

--- string -> (string * string)
local make_luanames = function (path)
    return filereplacesuffix(path, "lua"),
           filereplacesuffix(path, "luc")
end

local report = logs.names_report

names.patterns          = { }
local patterns          = names.patterns

local trailingslashes   = P"/"^1 * P(-1)
local stripslashes      = C((1 - trailingslashes)^0)
patterns.stripslashes   = stripslashes

local comma             = P","
local noncomma          = 1-comma
local splitcomma        = Ct((C(noncomma^1) + comma)^1)
patterns.splitcomma     = splitcomma

--[[doc--
    We use the functions in the cache.* namespace that come with the
    fontloader (see luat-basics-gen). it’s safe to use for the most part
    since most checks and directory creations are already done. It
    uses TEXMFCACHE or TEXMFVAR as starting points.

    There is one quirk, though: ``getwritablepath()`` will always
    assume that files in subdirectories of the cache tree are writable.
    It gives no feedback at all if it fails to open a file in write
    mode. This may cause trouble when the index or lookup cache were
    created by different user.
--doc]]--

if caches then
    local globals   = names.path.globals
    local names_dir = globals.names_dir

    prefix = getwritablepath (names_dir, "")
    if not prefix then
        luaotfload.error
            ("Impossible to find a suitable writeable cache...")
    else
        prefix = lpegmatch (stripslashes, prefix)
        report ("log", 0, "db",
                "root cache directory is " .. prefix)
    end

    globals.prefix     = prefix
    local lookups      = names.path.lookups
    local index        = names.path.index
    local lookups_file = filejoin (prefix, globals.lookups_file)
    local index_file   = filejoin (prefix, globals.index_file)
    lookups.lua, lookups.luc = make_luanames (lookups_file)
    index.lua, index.luc     = make_luanames (index_file)
else --- running as script, inject some dummies
    caches = { }
    logs   = { report = function () end }
end


--[[doc--
Auxiliary functions
--doc]]--

--- string -> string
local sanitize_string = function (str)
    if str ~= nil then
        return utf8gsub(utf8lower(str), "[^%a%d]", "")
    end
    return nil
end

local find_files_indeed
find_files_indeed = function (acc, dirs, filter)
    if not next (dirs) then --- done
        return acc
    end

    local pwd   = lfscurrentdir ()
    local dir   = dirs[#dirs]
    dirs[#dirs] = nil

    if lfschdir (dir) then
        lfschdir (pwd)

        local newfiles = { }
        for ent in lfsdir (dir) do
            if ent ~= "." and ent ~= ".." then
                local fullpath = dir .. "/" .. ent
                if filter (fullpath) == true then
                    if lfsisdir (fullpath) then
                        dirs[#dirs+1] = fullpath
                    elseif lfsisfile (fullpath) then
                        newfiles[#newfiles+1] = fullpath
                    end
                end
            end
        end
        return find_files_indeed (tableappend (acc, newfiles),
                                  dirs, filter)
    end
    --- could not cd into, so we skip it
    return find_files_indeed (acc, dirs, filter)
end

local dummyfilter = function () return true end

--- the optional filter function receives the full path of a file
--- system entity. a filter applies if the first argument it returns is
--- true.

--- string -> function? -> string list
local find_files = function (root, filter)
    if lfsisdir (root) then
        return find_files_indeed ({}, { root }, filter or dummyfilter)
    end
end


--[[doc--
This is a sketch of the luaotfload db:

    type dbobj = {
        families    : familytable;
        filenames   : filemap;
        status      : filestatus;
        mappings    : fontentry list;
        meta        : metadata;
        names       : namedata; // TODO: check for relevance after db is finalized
    }
    and familytable = {
        local  : (format, familyentry) hash; // specified with include dir
        texmf  : (format, familyentry) hash;
        system : (format, familyentry) hash;
    }
    and familyentry = {
        regular     : sizes;
        italic      : sizes;
        bold        : sizes;
        bolditalic  : sizes;
    }
    and sizes = {
        default : int;              // points into mappings or names
        optical : (int, int) list;  // design size -> index entry
    }
    and metadata = {
        formats     : string list; // { "otf", "ttf", "ttc", "dfont" }
        statistics  : TODO;
        version     : float;
    }
    and filemap = {
        base : {
            local  : (string, int) hash; // basename -> idx
            system : (string, int) hash;
            texmf  : (string, int) hash;
        };
        bare : {
            local  : (string, (string, int) hash) hash; // format -> (barename -> idx)
            system : (string, (string, int) hash) hash;
            texmf  : (string, (string, int) hash) hash;
        };
        full : (int, string) hash; // idx -> full path
    }
    and fontentry = {
        barename    : string;
        familyname  : string;
        filename    : string;
        fontname    : string; // <- metadata
        fullname    : string; // <- metadata
        sanitized   : {
            family         : string;
            fontstyle_name : string; // <- new in 2.4
            fontname       : string; // <- metadata
            fullname       : string; // <- namedata.names
            metafamily     : string;
            pfullname      : string;
            prefmodifiers  : string;
            psname         : string;
            subfamily      : string;
        };
        size         : int list;
        slant        : int;
        subfont      : int;
        location     : local | system | texmf;
        weight       : int;
        width        : int;
        units_per_em : int;         // mainly 1000, but also 2048 or 256
    }
    and filestatus = (string,       // fullname
                      { index       : int list; // pointer into mappings
                        timestamp   : int;      }) dict

beware that this is a reconstruction and may be incomplete.

mtx-fonts has in names.tma:

    type names = {
        cache_uuid    : uuid;
        cache_version : float;
        datastate     : uuid list;
        fallbacks     : (filetype, (basename, int) hash) hash;
        families      : (basename, int list) hash;
        files         : (filename, fullname) hash;
        indices       : (fullname, int) hash;
        mappings      : (filetype, (basename, int) hash) hash;
        names         : ? (empty hash) ?;
        rejected      : (basename, int) hash;
        specifications: fontentry list;
    }
    and fontentry = {
        designsize    : int;
        familyname    : string;
        filename      : string;
        fontname      : string;
        format        : string;
        fullname      : string;
        maxsize       : int;
        minsize       : int;
        modification  : int;
        rawname       : string;
        style         : string;
        subfamily     : string;
        variant       : string;
        weight        : string;
        width         : string;
    }

--doc]]--

local fontnames_init = function (formats) --- returns dbobj
    return {
        families        = {
            ["local"]  = { },
            system     = { },
            texmf      = { },
        },
        status          = { }, -- was: status; map abspath -> mapping
        mappings        = { }, -- TODO: check if still necessary after rewrite
        names           = { },
--      filenames       = { }, -- created later
        meta            = {
            formats    = formats,
            statistics = { },
            version    = names.version,
        },
    }
end

--- When loading a lua file we try its binary complement first, which
--- is assumed to be located at an identical path, carrying the suffix
--- .luc.

--- string -> (string * table)
local load_lua_file = function (path)
    local foundname = filereplacesuffix(path, "luc")

    local fh = ioopen(foundname, "rb") -- try bin first
    if fh then
        local chunk = fh:read"*all"
        fh:close()
        code = load(chunk, "b")
    end

    if not code then --- fall back to text file
        foundname = filereplacesuffix(path, "lua")
        fh = ioopen(foundname, "rb")
        if fh then
            local chunk = fh:read"*all"
            fh:close()
            code = load(chunk, "t")
        end
    end

    if not code then return nil, nil end
    return foundname, code()
end

--- define locals in scope
local crude_file_lookup
local crude_file_lookup_verbose
local find_closest
local flush_lookup_cache
local ot_fullinfo
local t1_fullinfo
local load_names
local load_lookups
local read_blacklist
local read_fonts_conf
local reload_db
local resolve
local resolve_cached
local resolve_fullpath
local save_names
local save_lookups
local update_names
local get_font_filter
local set_font_filter

--- state of the database
local fonts_loaded   = false
local fonts_reloaded = false

--- limit output when approximate font matching (luaotfload-tool -F)
local fuzzy_limit = 1 --- display closest only

--- bool? -> dbobj
load_names = function (dry_run)
    local starttime = os.gettimeofday ()
    local foundname, data = load_lua_file (names.path.index.lua)

    if data then
        report ("both", 2, "db",
                "Font names database loaded", "%s", foundname)
        report ("info", 3, "db", "Loading took %0.f ms",
                1000*(os.gettimeofday()-starttime))

        local db_version, nms_version = data.version, names.version
        if db_version ~= nms_version then
            report ("both", 0, "db",
                    [[Version mismatch; expected %4.3f, got %4.3f]],
                    nms_version, db_version)
            if not fonts_reloaded then
                report ("both", 0, "db", [[Force rebuild]])
                data = update_names ({ }, true, false)
                if not data then
                    report ("both", 0, "db",
                            "Database creation unsuccessful.")
                end
            end
        end
    else
        report ("both", 0, "db",
                [[Font names database not found, generating new one.]])
        report ("both", 0, "db",
                [[This can take several minutes; please be patient.]])
        data = update_names (fontnames_init (get_font_filter ()),
                             nil, dry_run)
        if not success then
            report ("both", 0, "db", "Database creation unsuccessful.")
        end
    end
    fonts_loaded = true
    return data
end

--- unit -> dbobj
load_lookups = function ( )
    local foundname, data = load_lua_file(names.path.lookups.lua)
    if data then
        report("both", 3, "cache",
               "Lookup cache loaded (%s)", foundname)
    else
        report("both", 1, "cache",
               "No lookup cache, creating empty.")
        data = { }
    end
    return data
end

local style_synonyms = { set = { } }
do
    local combine = function (ta, tb)
        local result = { }
        for i=1, #ta do
            for j=1, #tb do
                result[#result+1] = ta[i] .. tb[j]
            end
        end
        return result
    end

    --- read this: http://blogs.adobe.com/typblography/2008/05/indesign_font_conflicts.html
    --- tl;dr: font style synonyms are unreliable.
    ---
    --- Context matches font names against lists of known identifiers
    --- for weight, style, width, and variant, so that including
    --- the family name there are five dimensions for choosing a
    --- match. The sad thing is, while this is a decent heuristic it
    --- makes no sense to imitate it in luaotfload because the user
    --- interface must fit into the much more limited Xetex scheme that
    --- distinguishes between merely four style categories (variants):
    --- “regular”, “italic”, “bold”, and “bolditalic”. As a result,
    --- some of the styles are lumped together although they can differ
    --- significantly (like “medium” and “bold”).

    --- Xetex (XeTeXFontMgr.cpp) appears to recognize only “plain”,
    --- “normal”, and “roman” as synonyms for “regular”.
    local list = {
        regular    = { "normal",         "roman",
                       "plain",          "book",
                       "light",          "extralight",
                       "ultralight", },
        bold       = { "demi",           "demibold",
                       "semibold",       "boldregular",
                       "medium",         "mediumbold",
                       "ultrabold",      "extrabold",
                       "heavy",          "black",
                       "bold", },
        italic     = { "regularitalic",  "normalitalic",
                       "oblique",        "slanted",
                       "italic", },
    }

    list.bolditalic     = combine(list.bold, list.italic)
    style_synonyms.list = list

    for category, synonyms in next, style_synonyms.list do
        style_synonyms.set[category] = tabletohash(synonyms, true)
    end
end

local type1_formats = { "tfm", "ofm", }

local dummy_findfile = resolvers.findfile -- from basics-gen

--- filemap -> string -> string -> (string | bool)
local verbose_lookup = function (data, kind, filename)
    local found = data[kind][filename]
    if found ~= nil then
        found = data.full[found]
        if found == nil then --> texmf
            report("info", 0, "db",
                "Crude file lookup: req=%s; hit=%s => kpse",
                filename, kind)
            found = dummy_findfile(filename)
        else
            report("info", 0, "db",
                "Crude file lookup: req=%s; hit=%s; ret=%s",
                filename, kind, found)
        end
        return found
    end
    return false
end

--- string -> (string * string * bool)
crude_file_lookup_verbose = function (filename)
    if not names.data then names.data = load_names() end
    local data      = names.data
    local mappings  = data.mappings
    local filenames = data.filenames
    local found

    --- look up in db first ...
    found = verbose_lookup(filenames, "bare", filename)
    if found then
        return found, nil, true
    end
    found = verbose_lookup(filenames, "base", filename)
    if found then
        return found, nil, true
    end

    --- ofm and tfm, returns pair
    for i=1, #type1_formats do
        local format = type1_formats[i]
        if resolvers.findfile(filename, format) then
            return file.addsuffix(filename, format), format, true
        end
    end
    return filename, nil, false
end

--- string -> (string * string * bool)
crude_file_lookup = function (filename)
    if not names.data then names.data = load_names() end
    local data      = names.data
    local mappings  = data.mappings
    local filenames = data.filenames

    local found

    found = filenames.base[filename]
         or filenames.bare[filename]

    if found then
        found = filenames.full[found]
        if found == nil then
            found = dummy_findfile(filename)
        end
        return found or filename, nil, true
    end

    for i=1, #type1_formats do
        local format = type1_formats[i]
        if resolvers.findfile(filename, format) then
            return file.addsuffix(filename, format), format, true
        end
    end

    return filename, nil, false
end

--[[doc--
Existence of the resolved file name is verified differently depending
on whether the index entry has a texmf flag set.
--doc]]--

local get_font_file = function (fullnames, entry)
    local basename = entry.basename
    if entry.texmf == true then
        if kpselookup(basename) then
            return true, basename, entry.subfont
        end
    else
        local fullname = fullnames[entry.index]
        if lfsisfile(fullname) then
            return true, basename, entry.subfont
        end
    end
    return false
end

--[[doc--
We need to verify if the result of a cached lookup actually exists in
the texmf or filesystem.
--doc]]--

local verify_font_file = function (basename)
    if not names.data then names.data = load_names() end
    local filenames = names.data.filenames
    local idx = filenames.base[basename]
    if not idx then
        return false
    end

    --- firstly, check filesystem
    local fullname = filenames.full[idx]
    if fullname and lfsisfile(fullname) then
        return true
    end

    --- secondly, locate via kpathsea
    if kpsefind_file(basename) then
        return true
    end

    return false
end

--[[doc--
Lookups can be quite costly, more so the less specific they are.
Even if we find a matching font eventually, the next time the
user compiles Eir document E will have to stand through the delay
again.
Thus, some caching of results -- even between runs -- is in order.
We’ll just store successful name: lookups in a separate cache file.

type lookup_cache = (string, (string * num)) dict

Complete, needs testing:
 ×  1) add cache to dbobj
 ×  2) wrap lookups in cached versions
 ×  3) make caching optional (via the config table) for debugging
 ×  4) make names_update() cache aware (nil if “force”)
 ×  5) add logging
 ×  6) add cache control to luaotfload-tool
 ×  7) incr db version (now 2.203)
 ×  8) save cache only at the end of a run

The spec is modified in place (ugh), so we’ll have to catalogue what
fields actually influence its behavior.

Idk what the “spec” resolver is for.

        lookup      inspects            modifies
        file:       name                forced, name
        name:*      name, style, sub,   resolved, sub, name, forced
                    optsize, size
        spec:       name, sub           resolved, sub, name, forced

* name: contains both the name resolver from luatex-fonts and resolve()
  below

From my reading of font-def.lua, what a resolver does is
basically rewrite the “name” field of the specification record
with the resolution.
Also, the fields “resolved”, “sub”, “force” etc. influence the outcome.

--doc]]--

local concat_char = "#"
local hash_fields = {
    --- order is important
    "specification", "style", "sub", "optsize", "size",
}
local n_hash_fields = #hash_fields

--- spec -> string
local hash_request = function (specification)
    local key = { } --- segments of the hash
    for i=1, n_hash_fields do
        local field = specification[hash_fields[i]]
        if field then
            key[#key+1] = field
        end
    end
    return tableconcat(key, concat_char)
end

--- 'a -> 'a -> table -> (string * int|boolean * boolean)
resolve_cached = function (_, _, specification)
    if not names.lookups then names.lookups = load_lookups() end
    local request = hash_request(specification)
    report("both", 4, "cache", "Looking for %q in cache ...",
           request)

    local found = names.lookups[request]

    --- case 1) cache positive ----------------------------------------
    if found then --- replay fields from cache hit
        report("info", 4, "cache", "Found!")
        local basename = found[1]
        --- check the presence of the file in case it’s been removed
        local success = verify_font_file(basename)
        if success == true then
            return basename, found[2], true
        end
        report("both", 4, "cache", "Cached file not found; resolving again")
    else
        report("both", 4, "cache", "Not cached; resolving")
    end

    --- case 2) cache negative ----------------------------------------
    --- first we resolve normally ...
    local filename, subfont, success = resolve(nil, nil, specification)
    if not success then return filename, subfont, false end
    --- ... then we add the fields to the cache ... ...
    local entry = { filename, subfont }
    report("both", 4, "cache", "New entry: %s", request)
    names.lookups[request] = entry

    --- obviously, the updated cache needs to be stored.
    --- TODO this should trigger a save only once the
    ---      document is compiled (finish_pdffile callback?)
    report("both", 5, "cache", "Saving updated cache")
    local success = save_lookups()
    if not success then --- sad, but not critical
        report("both", 0, "cache", "Could not write to cache")
    end
    return filename, subfont, true
end

--- this used to be inlined; with the lookup cache we don’t
--- have to be parsimonious wrt function calls anymore
--- “found” is the match accumulator
local add_to_match = function (found, size, face)

    local continue = true

    local optsize = face.size

    if optsize and next (optsize) then
        local dsnsize, maxsize, minsize
        dsnsize = optsize[1]
        maxsize = optsize[2]
        minsize = optsize[3]

        if size ~= nil
        and (dsnsize == size or (size > minsize and size <= maxsize))
        then
            found[1] = face
            continue = false ---> break
        else
            found[#found+1] = face
        end
    else
        found[1] = face
        continue = false ---> break
    end

    return found, continue
end

--[[doc--

Luatex-fonts, the font-loader package luaotfload imports, comes with
basic file location facilities (see luatex-fonts-syn.lua).
However, not only does the builtin functionality rely on Context’s font
name database, it is also too limited to be of more than basic use.
For this reason, luaotfload supplies its own resolvers that accesses
the font database created by the luaotfload-tool script.

--doc]]--


---
--- the request specification has the fields:
---
---   · features: table
---     · normal: set of { ccmp clig itlc kern liga locl mark mkmk rlig }
---     · ???
---   · forced:   string
---   · lookup:   "name"
---   · method:   string
---   · name:     string
---   · resolved: string
---   · size:     int
---   · specification: string (== <lookup> ":" <name>)
---   · sub:      string
---
--- The “size” field deserves special attention: if its value is
--- negative, then it actually specifies a scalefactor of the
--- design size of the requested font. This happens e.g. if a font is
--- requested without an explicit “at size”. If the font is part of a
--- larger collection with different design sizes, this complicates
--- matters a bit: Normally, the resolver prefers fonts that have a
--- design size as close as possible to the requested size. If no
--- size specified, then the design size is implied. But which design
--- size should that be? Xetex appears to pick the “normal” (unmarked)
--- size: with Adobe fonts this would be the one that is neither
--- “caption” nor “subhead” nor “display” &c ... For fonts by Adobe this
--- seems to be the one that does not receive a “prefmodifiers” field.
--- (IOW Adobe uses the “prefmodifiers” field to encode the design size
--- in more or less human readable format.) However, this is not true
--- of LM and EB Garamond. As this matters only where there are
--- multiple design sizes to a given font/style combination, we put a
--- workaround in place that chooses that unmarked version.

---
--- the first return value of “resolve” is the file name of the
--- requested font (string)
--- the second is of type bool or string and indicates the subfont of a
--- ttc
---
--- 'a -> 'a -> table -> (string * string | bool * bool)
---

resolve = function (_, _, specification) -- the 1st two parameters are used by ConTeXt
    if not fonts_loaded then names.data = load_names() end
    local data = names.data

    local name  = sanitize_string(specification.name)
    local style = sanitize_string(specification.style) or "regular"

    local askedsize

    if specification.optsize then
        askedsize = tonumber(specification.optsize)
    else
        local specsize = specification.size
        if specsize and specsize >= 0 then
            askedsize = specsize / 65536
        end
    end

    if type(data) ~= "table" then
         --- this catches a case where load_names() doesn’t
         --- return a database object, which can happen only
         --- in case there is valid Lua code in the database,
         --- but it’s not a table, e.g. it contains an integer.
        if not fonts_reloaded then
            return reload_db("invalid database; not a table",
                             resolve, nil, nil, specification)
        end
        --- unsucessfully reloaded; bail
        return specification.name, false, false
    end

    if not data.mappings then
        if not fonts_reloaded then
            return reload_db("invalid database; missing font mapping",
                             resolve, nil, nil, specification)
        end
        return specification.name, false, false
    end

    local synonym_set       = style_synonyms.set
    local stylesynonyms     = synonym_set[style]
    local regularsynonyms   = synonym_set.regular

    local exact      = { } --> collect exact style matches
    local synonymous = { } --> collect matching style synonyms
    local fallback         --> e.g. non-matching style (fontspec is anal about this)
    local candidates = { } --> secondary results, incomplete matches

    for n, face in next, data.mappings do
        local family, metafamily
        local prefmodifiers, fontstyle_name, subfamily
        local psname, fullname, fontname, pfullname

        local facenames = face.sanitized
        if facenames then
            family          = facenames.family
            subfamily       = facenames.subfamily
            fontstyle_name  = facenames.fontstyle_name
            prefmodifiers   = facenames.prefmodifiers or fontstyle_name or subfamily
            fullname        = facenames.fullname
            psname          = facenames.psname
            fontname        = facenames.fontname
            pfullname       = facenames.pfullname
            metafamily      = facenames.metafamily
        end
        fontname    = fontname  or sanitize_string(face.fontname)
        pfullname   = pfullname or sanitize_string(face.fullname)

        if     name == family
            or name == metafamily
        then
            if     style == prefmodifiers
                or style == fontstyle_name
            then
                local continue
                exact, continue = add_to_match(exact, askedsize, face)
                if continue == false then break end
            elseif style == subfamily then
                exact = add_to_match(exact, askedsize, face)
            elseif stylesynonyms and stylesynonyms[prefmodifiers]
                or regularsynonyms[prefmodifiers]
            then
                --- treat synonyms for prefmodifiers as first-class
                --- (needed to prioritize DejaVu Book over Condensed)
                exact = add_to_match(exact, askedsize, face)
            elseif name == fullname
                or name == pfullname
                or name == fontname
                or name == psname
            then
                synonymous = add_to_match(synonymous, askedsize, face)
            elseif stylesynonyms and stylesynonyms[subfamily]
                or regularsynonyms[subfamily]
            then
                synonymous = add_to_match(synonymous, askedsize, face)
            elseif prefmodifiers == "regular"
                or subfamily     == "regular" then
                fallback = face
            else --- mark as last straw but continue
                candidates[#candidates+1] = face
            end
        else
            if name == fullname
            or name == pfullname
            or name == fontname
            or name == psname then
                local continue
                exact, continue = add_to_match(exact, askedsize, face)
                if continue == false then break end
            end
        end
    end

    local found
    if next(exact) then
        found = exact
    else
        found = synonymous
    end

    --- this is a monster
    if #found == 1 then
        --- “found” is really synonymous with “registered in the db”.
        local entry = found[1]
        local success, filename, subfont
            = get_font_file(data.filenames.full, entry)
        if success == true then
            report("log", 0, "resolve",
                "Font family='%s', subfamily='%s' found: %s",
                name, style, filename
            )
            return filename, subfont, true
        end

    elseif #found > 1 then
        -- we found matching font(s) but not in the requested optical
        -- sizes, so we loop through the matches to find the one with
        -- least difference from the requested size.
        local match

        if askedsize then  --- choose by design size
            local closest
            local least = math.huge -- initial value is infinity

            for i, face in next, found do
                local dsnsize = face.size and face.size [1] or 0
                local difference = mathabs (dsnsize - askedsize)
                if difference < least then
                    closest = face
                    least   = difference
                end
            end

            match = closest
        else --- choose “unmarked” match, for Adobe fonts this
             --- is the one without a “prefmodifiers” field.
            match = found [1] --- fallback
            for i, face in next, found do
                if not face.sanitized.prefmodifiers then
                    match = face
                    break
                end
            end
        end

        local success, filename, subfont
            = get_font_file(data.filenames.full, match)
        if success == true then
            report("log", 0, "resolve",
                "Font family='%s', subfamily='%s' found: %s",
                name, style, filename
            )
            return filename, subfont, true
        end

    elseif fallback then
        local success, filename, subfont
            = get_font_file(data.filenames.full, fallback)
        if success == true then
            report("log", 0, "resolve",
                "No exact match for request %s; using fallback",
                specification.specification
            )
            report("log", 0, "resolve",
                "Font family='%s', subfamily='%s' found: %s",
                name, style, filename
            )
            return filename, subfont, true
        end
    elseif next(candidates) then
        --- pick the first candidate encountered
        local entry = candidates[1]
        local success, filename, subfont
            = get_font_file(data.filenames.full, entry)
        if success == true then
            report("log", 0, "resolve",
                "Font family='%s', subfamily='%s' found: %s",
                name, style, filename
            )
            return filename, subfont, true
        end
    end

    --- no font found so far
    if not fonts_reloaded then
        --- last straw: try reloading the database
        return reload_db(
            "unresolved font name: '" .. name .. "'",
            resolve, nil, nil, specification
        )
    end

    --- else, default to requested name
    return specification.name, false, false
end --- resolve()

resolve_fullpath = function (fontname, ext) --- getfilename()
    if not fonts_loaded then
        names.data = load_names()
    end
    local filenames = names.data.filenames
    local idx = filenames.base[fontname]
             or filenames.bare[fontname]
    if idx then
        return filenames.full[idx]
    end
    return ""
end

--- when reload is triggered we update the database
--- and then re-run the caller with the arg list

--- string -> ('a -> 'a) -> 'a list -> 'a
reload_db = function (why, caller, ...)
    local namedata  = names.data
    local formats   = tableconcat (namedata.formats, ",")

    report ("both", 1, "db",
            "Reload initiated (formats: %s); reason: %q",
            formats, why)

    set_font_filter (formats)
    names.data = update_names (names.data, false, false)

    if names.data then
        fonts_reloaded = true
        return caller (...)
    end

    report ("both", 0, "db", "Database update unsuccessful.")
end

--- string -> string -> int
local iterative_levenshtein = function (s1, s2)

  local costs = { }
  local len1, len2 = #s1, #s2

  for i = 0, len1 do
    local last = i
    for j = 0, len2 do
      if i == 0 then
        costs[j] = j
      else
        if j > 0 then
          local current = costs[j-1]
          if stringsub(s1, i, i) ~= stringsub(s2, j, j) then
            current = mathmin(current, last, costs[j]) + 1
          end
          costs[j-1] = last
          last = current
        end
      end
    end
    if i > 0 then costs[len2] = last end
  end

  return costs[len2]--- lower right has the distance
end

--- string -> int -> bool
find_closest = function (name, limit)
    local name     = sanitize_string(name)
    limit          = limit or fuzzy_limit

    if not fonts_loaded then names.data = load_names() end

    local data = names.data

    if type(data) ~= "table" then
        if not fonts_reloaded then
            return reload_db("no database", find_closest, name)
        end
        return false
    end
    local by_distance   = { } --- (int, string list) dict
    local distances     = { } --- int list
    local cached        = { } --- (string, int) dict
    local mappings      = data.mappings
    local n_fonts       = #mappings

    for n = 1, n_fonts do
        local current    = mappings[n]
        local cnames     = current.sanitized
        --[[
            This is simplistic but surpisingly fast.
            Matching is performed against the “fullname” field
            of a db record in preprocessed form. We then store the
            raw “fullname” at its edit distance.
            We should probably do some weighting over all the
            font name categories as well as whatever agrep
            does.
        --]]
        if cnames then
            local fullname, sfullname = current.fullname, cnames.fullname

            local dist = cached[sfullname]--- maybe already calculated
            if not dist then
                dist = iterative_levenshtein(name, sfullname)
                cached[sfullname] = dist
            end
            local namelst = by_distance[dist]
            if not namelst then --- first entry
                namelst = { fullname }
                distances[#distances+1] = dist
            else --- append
                namelst[#namelst+1] = fullname
            end
            by_distance[dist] = namelst
        end
    end

    --- print the matches according to their distance
    local n_distances = #distances
    if n_distances > 0 then --- got some data
        tablesort(distances)
        limit = mathmin(n_distances, limit)
        report(false, 1, "query",
               "Displaying %d distance levels", limit)

        for i = 1, limit do
            local dist     = distances[i]
            local namelst  = by_distance[dist]
            report(false, 0, "query",
                   "Distance from \"" .. name .. "\": " .. dist
                .. "\n    " .. tableconcat(namelst, "\n    ")
            )
        end

        return true
    end
    return false
end --- find_closest()

local sanitize_names = function (names)
    local res = { }
    for idx, name in next, names do
        res[idx] = sanitize_string(name)
    end
    return res
end

local load_font_file = function (filename, subfont)
    local rawfont, _msg = fontloaderopen (filename, subfont)
    if not rawfont then
        report ("log", 1, "db", "ERROR: failed to open %s", filename)
        return
    end
    local metadata = fontloaderto_table (rawfont)
    fontloaderclose (rawfont)
    collectgarbage "collect"
    return metadata
end

--[[doc--
The data inside an Opentype font file can be quite heterogeneous.
Thus in order to get the relevant information, parts of the original
table as returned by the font file reader need to be relocated.
--doc]]--

--- string -> int -> bool -> string -> fontentry
ot_fullinfo = function (filename, subfont, texmf, basename)
    local namedata = { }

    local metadata = load_font_file (filename, subfont)
    if not metadata then
        return nil
    end

    local english_names

    if metadata.names then
        for _, raw_namedata in next, metadata.names do
            if raw_namedata.lang == "English (US)" then
                english_names = raw_namedata.names
            end
        end
    else
        -- no names table, propably a broken font
        report("log", 1, "db",
               "Broken font %s rejected due to missing names table.",
               basename)
        return
    end

    local fontnames = {
        --- see
        --- https://developer.apple.com/fonts/TTRefMan/RM06/Chap6name.html
        fullname      = english_names.compatfull
                     or english_names.fullname,
        family        = english_names.preffamilyname
                     or english_names.family,
        prefmodifiers = english_names.prefmodifiers,
        subfamily     = english_names.subfamily,
        psname        = english_names.postscriptname,
        pfullname     = metadata.fullname,
        fontname      = metadata.fontname,
        metafamily    = metadata.familyname,
    }

    -- see http://www.microsoft.com/typography/OTSPEC/features_pt.htm#size
    if metadata.fontstyle_name then
        for _, name in next, metadata.fontstyle_name do
            if name.lang == 1033 then --- I hate magic numbers
                fontnames.fontstyle_name = name.name
            end
        end
    end

    namedata.sanitized     = sanitize_names (fontnames)
    namedata.fontname      = metadata.fontname
    namedata.fullname      = metadata.fullname
    namedata.familyname    = metadata.familyname
    namedata.weight        = metadata.pfminfo.weight
    namedata.width         = metadata.pfminfo.width
    namedata.slant         = metadata.italicangle
    --- this is for querying, see www.ntg.nl/maps/40/07.pdf for details
    namedata.units_per_em  = metadata.units_per_em
    namedata.version       = metadata.version
    -- don't waste the space with zero values

    local design_size         = metadata.design_size
    local design_range_top    = metadata.design_range_top
    local design_range_bottom = metadata.design_range_bottom

    local fallback_size = design_size         ~= 0 and design_size
                       or design_range_bottom ~= 0 and design_range_bottom
                       or design_range_top    ~= 0 and design_range_top

    if fallback_size then
        design_size         = (design_size         or fallback_size) / 10
        design_range_top    = (design_range_top    or fallback_size) / 10
        design_range_bottom = (design_range_bottom or fallback_size) / 10
        namedata.size = {
            design_size, design_range_top, design_range_bottom,
        }
    else
        namedata.size = false
    end

    --- file location data (used to be filename field)
    namedata.filename      = filename --> sys
    namedata.basename      = basename --> texmf
    namedata.texmf         = texmf or false
    namedata.subfont       = subfont

    return namedata
end

--[[doc--

    Type1 font inspector. In comparison with OTF, PFB’s contain a good
    deal less name fields which makes it tricky in some parts to find a
    meaningful representation for the database.

    Good read: http://www.adobe.com/devnet/font/pdfs/5004.AFM_Spec.pdf

--doc]]--

--- string -> int -> bool -> string -> fontentry
t1_fullinfo = function (filename, _subfont, texmf, basename)
    local namedata = { }
    local metadata = load_font_file (filename)

    local fontname      = metadata.fontname
    local fullname      = metadata.fullname
    local familyname    = metadata.familyname
    local italicangle   = metadata.italicangle
    local weight        = metadata.weight --- string identifier

    --- we have to improvise and detect whether we deal with
    --- italics since pfb fonts don’t come with a “subfamily”
    --- field
    local style
    if italicangle == 0 then
        style = false
    else
        style = "italic"
    end

    local style_synonyms_set = style_synonyms.set
    if weight then
        weight = sanitize_string (weight)
        local tmp = ""
        if style_synonyms_set.bold[weight] then
            tmp = "bold"
        end
        if style then
            style = tmp .. style
        else
            if style_synonyms_set.regular[weight] then
                style = "regular"
            else
                style = tmp
            end
        end
    end

    if not style or style == "" then
        style = "regular"
        --- else italic
    end

    namedata.sanitized = sanitize_names ({
        fontname        = fontname,
        psname          = fullname,
        pfullname       = fullname,
        metafamily      = family,
        family          = familyname,
        subfamily       = weight,
        prefmodifiers   = style,
    })

    namedata.fontname      = fontname
    namedata.fullname      = fullname
    namedata.familyname    = familyname

    namedata.slant         = italicangle
    namedata.units_per_em  = 1000 --- ps fonts standard
    namedata.version       = metadata.version
    namedata.weight        = metadata.pfminfo.weight --- integer
    namedata.width         = metadata.pfminfo.width

    namedata.size          = false

    namedata.filename      = filename --> sys
    namedata.basename      = basename --> texmf
    namedata.texmf         = texmf or false
    namedata.subfont       = false
    return namedata
end

local loaders = {
    dfont   = ot_fullinfo,
    otf     = ot_fullinfo,
    ttc     = ot_fullinfo,
    ttf     = ot_fullinfo,

    pfb     = t1_fullinfo,
    pfa     = t1_fullinfo,
}

--- we return true if the font is new or re-indexed
--- string -> dbobj -> dbobj -> bool

local read_font_names = function (fullname,
                                  fontnames,
                                  newfontnames,
                                  texmf)

    local newmappings   = newfontnames.mappings
    local newstatus     = newfontnames.status --- by full path

    local mappings      = fontnames.mappings
    local status        = fontnames.status

    local basename      = filebasename (fullname)
    local barename      = filenameonly (fullname)

    local format        = stringlower (filesuffix (basename))

    local entryname     = fullname
    if texmf == true then
        entryname = basename
    end

    if names.blacklist[fullname] or names.blacklist[basename]
    then
        report("log", 2, "db",
               "Ignoring blacklisted font %q", fullname)
        return false
    end

    local new_timestamp, current_timestamp
    current_timestamp   = status[fullname]
                      and status[fullname].timestamp
    new_timestamp       = lfsattributes(fullname, "modification")

    local newentrystatus = newstatus[fullname]
    --- newentrystatus: nil | false | table
    if newentrystatus and newentrystatus.timestamp == new_timestamp then
        -- already statused this run
        return false
    end

    newstatus[fullname]      = newentrystatus or { }
    local newentrystatus     = newstatus[fullname]
    newentrystatus.timestamp = new_timestamp
    newentrystatus.index     = newentrystatus.index or { }

    if  current_timestamp == new_timestamp
    and not newentrystatus.index[1]
    then
        for _, v in next, status[fullname].index do
            local index      = #newentrystatus.index
            local fullinfo   = mappings[v]
            local location   = #newmappings + 1
            newmappings[location]          = fullinfo --- keep
            newentrystatus.index[index+1]  = location --- is this actually used anywhere?
        end
        report("log", 2, "db", "Font %q already indexed", basename)
        return false
    end

    local loader = loaders[format] --- ot_fullinfo, t1_fullinfo
    if not loader then
        report ("both", 0, "db",
                "Unknown format: %q, skipping.", format)
        return false
    end

    local info = fontloaderinfo(fullname)
    if info then
        if type(info) == "table" and #info > 1 then --- ttc
            for n_font = 1, #info do
                local fullinfo = loader (fullname, n_font-1, texmf, basename)
                if not fullinfo then
                    return false
                end
                local location = #newmappings+1
                local index    = newentrystatus.index[n_font]
                if not index then index = location end

                newmappings[index]            = fullinfo
                newentrystatus.index[n_font]  = index
            end
        else
            local fullinfo = loader (fullname, false, texmf, basename)
            if not fullinfo then
                return false
            end
            local location  = #newmappings+1
            local index     = newentrystatus.index[1]
            if not index then index = location end

            newmappings[index]       = fullinfo
            newentrystatus.index[1]  = index
        end

    else --- missing info
        report("log", 1, "db", "Failed to load %q", basename)
        return false
    end
    return true
end

local path_normalize
do
    --- os.type and os.name are constants so we
    --- choose a normalization function in advance
    --- instead of testing with every call
    local os_type, os_name = os.type, os.name
    local filecollapsepath = filecollapsepath
    local lfsreadlink      = lfs.readlink

    --- windows and dos
    if os_type == "windows" or os_type == "msdos" then
        --- ms platfom specific stuff
        path_normalize = function (path)
            path = stringgsub(path, '\\', '/')
            path = stringlower(path)
            path = filecollapsepath(path)
            return path
        end
--[[doc--
    The special treatment for cygwin was removed with a patch submitted
    by Ken Brown.
    Reference: http://cygwin.com/ml/cygwin/2013-05/msg00006.html
--doc]]--

    else -- posix
        path_normalize = function (path)
            local dest = lfsreadlink(path)
            if dest then
                if kpsereadable_file(dest) then
                    path = dest
                elseif kpsereadable_file(filejoin(filedirname(path), dest)) then
                    path = filejoin(file.dirname(path), dest)
                else
                    -- broken symlink?
                end
            end
            path = filecollapsepath(path)
            return path
        end
    end
end

fonts.path_normalize = path_normalize

names.blacklist = { }

local blacklist   = names.blacklist
local p_blacklist --- prefixes of dirs

--- string list -> string list
local collapse_prefixes = function (lst)
    --- avoid redundancies in blacklist
    if #lst < 2 then
        return lst
    end

    tablesort(lst)
    local cur = lst[1]
    local result = { cur }
    for i=2, #lst do
        local elm = lst[i]
        if stringsub(elm, 1, #cur) ~= cur then
            --- different prefix
            cur = elm
            result[#result+1] = cur
        end
    end
    return result
end

--- string list -> string list -> (string, bool) hash_t
local create_blacklist = function (blacklist, whitelist)
    local result = { }
    local dirs   = { }

    report("info", 2, "db", "Blacklisting %q files and directories",
           #blacklist)
    for i=1, #blacklist do
        local entry = blacklist[i]
        if lfsisdir(entry) then
            dirs[#dirs+1] = entry
        else
            result[blacklist[i]] = true
        end
    end

    report("info", 2, "db", "Whitelisting %q files", #whitelist)
    for i=1, #whitelist do
        result[whitelist[i]] = nil
    end

    dirs = collapse_prefixes(dirs)

    --- build the disjunction of the blacklisted directories
    for i=1, #dirs do
        local p_dir = P(dirs[i])
        if p_blacklist then
            p_blacklist = p_blacklist + p_dir
        else
            p_blacklist = p_dir
        end
    end

    if p_blacklist == nil then
        --- always return false
        p_blacklist = Cc(false)
    end

    return result
end

--- unit -> unit
read_blacklist = function ()
    local files = {
        kpselookup ("luaotfload-blacklist.cnf",
                    {all=true, format="tex"})
    }
    local blacklist = { }
    local whitelist = { }

    if files and type(files) == "table" then
        for _,v in next, files do
            for line in iolines(v) do
                line = stringstrip(line) -- to get rid of lines like " % foo"
                local first_chr = stringsub(line, 1, 1) --- faster than find
                if first_chr == "%" or stringis_empty(line) then
                    -- comment or empty line
                elseif first_chr == "-" then
                    whitelist[#whitelist+1] = stringsub(line, 2, -1)
                else
                    local cmt = stringfind(line, "%%")
                    if cmt then
                        line = stringsub(line, 1, cmt - 1)
                    end
                    line = stringstrip(line)
                    report("log", 2, "db", "Blacklisted file %q", line)
                    blacklist[#blacklist+1] = line
                end
            end
        end
    end
    names.blacklist = create_blacklist(blacklist, whitelist)
end

local p_font_filter

do
    local current_formats = { }

    local extension_pattern = function (list)
        local pat
        for i=#list, 1, -1 do
            local e = list[i]
            if not pat then
                pat = P(e)
            else
                pat = pat + P(e)
            end
        end
        pat = pat * P(-1)
        return (1 - pat)^1 * pat
    end

    --- small helper to adjust the font filter pattern (--formats
    --- option)

    set_font_filter = function (formats)

        if not formats or type (formats) ~= "string" then
            return
        end

        if stringsub (formats, 1, 1) == "+" then -- add
            formats = lpegmatch (splitcomma, stringsub (formats, 2))
            if formats then
                current_formats = tableappend (current_formats, formats)
            end
        elseif stringsub (formats, 1, 1) == "-" then -- add
            formats = lpegmatch (splitcomma, stringsub (formats, 2))
            if formats then
                local newformats = { }
                for i = 1, #current_formats do
                    local fmt     = current_formats[i]
                    local include = true
                    for j = 1, #formats do
                        if current_formats[i] == formats[j] then
                            include = false
                            goto skip
                        end
                    end
                    newformats[#newformats+1] = fmt
                    ::skip::
                end
                current_formats = newformats
            end
        else -- set
            formats = lpegmatch (splitcomma, formats)
            if formats then
                current_formats = formats
            end
        end

        p_font_filter = extension_pattern (current_formats)
    end

    get_font_filter = function (formats)
        return tablefastcopy (current_formats)
    end

    --- initialize
    set_font_filter (config.luaotfload.formats)
end

local process_dir_tree
process_dir_tree = function (acc, dirs)
    if not next (dirs) then --- done
        return acc
    end

    local pwd   = lfscurrentdir ()
    local dir   = dirs[#dirs]
    dirs[#dirs] = nil

    if lfschdir (dir) then
        lfschdir (pwd)

        local newfiles = { }
        local blacklist = names.blacklist
        for ent in lfsdir (dir) do
            --- filter right away
            if ent ~= "." and ent ~= ".." and not blacklist[ent] then
                local fullpath = dir .. "/" .. ent
                if lfsisdir (fullpath)
                and not lpegmatch (p_blacklist, fullpath)
                then
                    dirs[#dirs+1] = fullpath
                elseif lfsisfile (fullpath) then
                    ent = stringlower (ent)

                    if lpegmatch (p_font_filter, ent) then
                        if filesuffix (ent) == "afm" then
                            --- fontloader.open() will load the afm
                            --- iff both files are in the same directory
                            local pfbpath = filereplacesuffix
                                                    (fullpath, "pfb")
                            if lfsisfile (pfbpath) then
                                newfiles[#newfiles+1] = pfbpath
                            end
                        else
                            newfiles[#newfiles+1] = fullpath
                        end
                    end

                end
            end
        end
        return process_dir_tree (tableappend (acc, newfiles), dirs)
    end
    --- cannot cd; skip
    return process_dir_tree (acc, dirs)
end

local process_dir = function (dir)
    local pwd = lfscurrentdir ()
    if lfschdir (dir) then
        lfschdir (pwd)

        local files = { }
        local blacklist = names.blacklist
        for ent in lfsdir (dir) do
            if ent ~= "." and ent ~= ".." and not blacklist[ent] then
                local fullpath = dir .. "/" .. ent
                if lfsisfile (fullpath) then
                    ent = stringlower (ent)
                    if lpegmatch (p_font_filter, ent)
                    then
                        if filesuffix (ent) == "afm" then
                            --- fontloader.open() will load the afm
                            --- iff both files are in the same
                            --- directory
                            local pfbpath = filereplacesuffix
                                                    (fullpath, "pfb")
                            if lfsisfile (pfbpath) then
                                files[#files+1] = pfbpath
                            end
                        else
                            files[#files+1] = fullpath
                        end
                    end
                end
            end
        end
        return files
    end
    return { }
end

--- string -> bool -> string list
local find_font_files = function (root, recurse)
    if lfsisdir (root) then
        if recurse == true then
            return process_dir_tree ({}, { root })
        else --- kpathsea already delivered the necessary subdirs
            return process_dir (root)
        end
    end
end

--[[doc--

    scan_dir() scans a directory and populates the list of fonts
    with all the fonts it finds.

        · dirname   : name of the directory to scan
        · fontnames : current font db object
        · newnames  : font db object to fill
        · dry_run   : don’t touch anything

--doc]]--

--- string -> dbobj -> dbobj -> bool -> bool -> (int * int)

local scan_dir = function (dirname, fontnames, newfontnames,
                           dry_run, texmf)
    if lpegmatch (p_blacklist, dirname) then
        report ("both", 3, "db",
                "Skipping blacklisted directory %s", dirname)
        --- ignore
        return 0, 0
    end
    local found = find_font_files (dirname, texmf ~= true)
    if not found then
        report ("both", 3, "db",
                "No such directory: %q; skipping.", dirname)
        return 0, 0
    end
    report ("both", 3, "db", "Scanning directory %s", dirname)

    local n_new = 0   --- total of fonts collected
    local n_found = #found
    report ("both", 4, "db", "%d font files detected", n_found)
    for j=1, n_found do
        local fullname = found[j]
        fullname = path_normalize(fullname)
        local new
        if dry_run == true then
            report ("both", 1, "db",
                    "Would have been extracting metadata from %q",
                    fullname)
        else
            report ("both", 4, "db",
                    "Extracting metadata from font %q", fullname)
            local new = read_font_names (fullname, fontnames,
                                         newfontnames, texmf)
            if new == true then
                n_new = n_new + 1
            end
        end
    end

    report("both", 4, "db", "%d fonts found in '%s'", n_found, dirname)
    return n_found, n_new
end

--- string list -> string list
local filter_out_pwd = function (dirs)
    local result = { }
    local pwd = path_normalize (lpegmatch (stripslashes,
                                           lfscurrentdir ()))
    for i = 1, #dirs do
        --- better safe than sorry
        local dir = path_normalize (lpegmatch (stripslashes, dirs[i]))
        if not (dir == "." or dir == pwd) then
            result[#result+1] = dir
        end
    end
    return result
end

local path_separator = ostype == "windows" and ";" or ":"

--[[doc--
    scan_texmf_fonts() scans all fonts in the texmf tree through the
    kpathsea variables OPENTYPEFONTS and TTFONTS of texmf.cnf.
    The current working directory comes as “.” (texlive) or absolute
    path (miktex) and will always be filtered out.
--doc]]--

--- dbobj -> dbobj -> bool? -> (int * int)

local scan_texmf_fonts = function (fontnames, newfontnames, dry_run)

    local n_scanned, n_new, fontdirs = 0, 0
    local osfontdir = kpseexpand_path "$OSFONTDIR"

    if stringis_empty (osfontdir) then
        report ("info", 2, "db", "Scanning TEXMF fonts...")
    else
        report ("info", 2, "db", "Scanning TEXMF and OS fonts...")
        if logs.get_loglevel () > 3 then
            local osdirs = filesplitpath (osfontdir)
            report ("info", 0, "db",
                    "$OSFONTDIR has %d entries:", #osdirs)
            for i = 1, #osdirs do
                report ("info", 0, "db", "[%d] %s", i, osdirs[i])
            end
        end
    end

    fontdirs = kpseexpand_path "$OPENTYPEFONTS"
    fontdirs = fontdirs .. path_separator .. kpseexpand_path "$TTFONTS"
    fontdirs = fontdirs .. path_separator .. kpseexpand_path "$T1FONTS"

    if not stringis_empty (fontdirs) then
        local tasks = filter_out_pwd (filesplitpath (fontdirs))
        report ("info", 3, "db",
                "Initiating scan of %d directories.", #tasks)
        for _, d in next, tasks do
            local found, new = scan_dir (d, fontnames, newfontnames,
                                         dry_run, true)
            n_scanned = n_scanned + found
            n_new     = n_new     + new
        end
    end

    return n_scanned, n_new
end

--[[
  For the OS fonts, there are several options:
   - if OSFONTDIR is set (which is the case under windows by default but
     not on the other OSs), it scans it at the same time as the texmf tree,
     in the scan_texmf_fonts.
   - if not:
     - under Windows and Mac OSX, we take a look at some hardcoded directories
     - under Unix, we read /etc/fonts/fonts.conf and read the directories in it

  This means that if you have fonts in fancy directories, you need to set them
  in OSFONTDIR.
]]

local read_fonts_conf
do --- closure for read_fonts_conf()

    local alpha             = R("az", "AZ")
    local digit             = R"09"
    local tag_name          = C(alpha^1)
    local whitespace        = S" \n\r\t\v"
    local ws                = whitespace^1
    local comment           = P"<!--" * (1 - P"--")^0 * P"-->"

    ---> header specifica
    local xml_declaration   = P"<?xml" * (1 - P"?>")^0 * P"?>"
    local xml_doctype       = P"<!DOCTYPE" * ws
                            * "fontconfig" * (1 - P">")^0 * P">"
    local header            = xml_declaration^-1
                            * (xml_doctype + comment + ws)^0

    ---> enforce root node
    local root_start        = P"<"  * ws^-1 * P"fontconfig" * ws^-1 * P">"
    local root_stop         = P"</" * ws^-1 * P"fontconfig" * ws^-1 * P">"

    local dquote, squote    = P[["]], P"'"
    local xml_namestartchar = S":_" + alpha --- ascii only, funk the rest
    local xml_namechar      = S":._" + alpha + digit
    local xml_name          = ws^-1
                            * C(xml_namestartchar * xml_namechar^0)
    local xml_attvalue      = dquote * C((1 - S[[%&"]])^1) * dquote * ws^-1
                            + squote * C((1 - S[[%&']])^1) * squote * ws^-1
    local xml_attr          = Cg(xml_name * P"=" * xml_attvalue)
    local xml_attr_list     = Cf(Ct"" * xml_attr^1, rawset)

    --[[doc--
         scan_node creates a parser for a given xml tag.
    --doc]]--
    --- string -> bool -> lpeg_t
    local scan_node = function (tag)
        --- Node attributes go into a table with the index “attributes”
        --- (relevant for “prefix="xdg"” and the likes).
        local p_tag = P(tag)
        local with_attributes   = P"<" * p_tag
                                * Cg(xml_attr_list, "attributes")^-1
                                * ws^-1
                                * P">"
        local plain             = P"<" * p_tag * ws^-1 * P">"
        local node_start        = plain + with_attributes
        local node_stop         = P"</" * p_tag * ws^-1 * P">"
        --- there is no nesting, the earth is flat ...
        local node              = node_start
                                * Cc(tag) * C(comment + (1 - node_stop)^1)
                                * node_stop
        return Ct(node) -- returns {string, string [, attributes = { key = val }] }
    end

    --[[doc--
         At the moment, the interesting tags are “dir” for
         directory declarations, and “include” for including
         further configuration files.

         spec: http://freedesktop.org/software/fontconfig/fontconfig-user.html
    --doc]]--
    local include_node        = scan_node"include"
    local dir_node            = scan_node"dir"

    local element             = dir_node
                              + include_node
                              + comment         --> ignore
                              + P(1-root_stop)  --> skip byte

    local root                = root_start * Ct(element^0) * root_stop
    local p_cheapxml          = header * root

    --lpeg.print(p_cheapxml) ---> 757 rules with v0.10

    --[[doc--
         fonts_conf_scanner() handles configuration files.
         It is called on an abolute path to a config file (e.g.
         /home/luser/.config/fontconfig/fonts.conf) and returns a list
         of the nodes it managed to extract from the file.
    --doc]]--
    --- string -> path list
    local fonts_conf_scanner = function (path)
        local fh = ioopen(path, "r")
        if not fh then
            report("both", 3, "db", "Cannot open fontconfig file %s", path)
            return
        end
        local raw = fh:read"*all"
        fh:close()

        local confdata = lpegmatch(p_cheapxml, raw)
        if not confdata then
            report("both", 3, "db", "Cannot scan fontconfig file %s", path)
            return
        end
        return confdata
    end

    local p_conf   = P".conf" * P(-1)
    local p_filter = (1 - p_conf)^1 * p_conf

    local conf_filter = function (path)
        if lpegmatch (p_filter, path) then
            return true
        end
        return false
    end

    --[[doc--
         read_fonts_conf_indeed() is called with six arguments; the
         latter three are tables that represent the state and are
         always returned.
         The first three are
             · the path to the file
             · the expanded $HOME
             · the expanded $XDG_CONFIG_DIR
    --doc]]--
    --- string -> string -> string -> tab -> tab -> (tab * tab * tab)
    local read_fonts_conf_indeed
    read_fonts_conf_indeed = function (start, home, xdg_home,
                                       acc, done, dirs_done)

        local paths = fonts_conf_scanner(start)
        if not paths then --- nothing to do
            return acc, done, dirs_done
        end

        for i=1, #paths do
            local pathobj = paths[i]
            local kind, path = pathobj[1], pathobj[2]
            local attributes = pathobj.attributes
            if attributes and attributes.prefix == "xdg" then
                --- this prepends the xdg root (usually ~/.config)
                path = filejoin(xdg_home, path)
            end

            if kind == "dir" then
                if stringsub(path, 1, 1) == "~" then
                    path = filejoin(home, stringsub(path, 2))
                end
                --- We exclude paths with texmf in them, as they should be
                --- found anyway; also duplicates are ignored by checking
                --- if they are elements of dirs_done.
                if not (stringfind(path, "texmf") or dirs_done[path]) then
                    acc[#acc+1] = path
                    dirs_done[path] = true
                end

            elseif kind == "include" then
                --- here the path can be four things: a directory or a file,
                --- in absolute or relative path.
                if stringsub(path, 1, 1) == "~" then
                    path = filejoin(home, stringsub(path, 2))
                elseif --- if the path is relative, we make it absolute
                    not ( lfsisfile(path) or lfsisdir(path) )
                then
                    path = filejoin(filedirname(start), path)
                end
                if  lfsisfile(path)
                    and kpsereadable_file(path)
                    and not done[path]
                then
                    --- we exclude path with texmf in them, as they should
                    --- be found otherwise
                    acc = read_fonts_conf_indeed(
                                path, home, xdg_home,
                                acc,  done, dirs_done)
                elseif lfsisdir(path) then --- arrow code ahead
                    local config_files = find_files (path, conf_filter)
                    for _, filename in next, config_files do
                        if not done[filename] then
                            acc = read_fonts_conf_indeed(
                            filename, home, xdg_home,
                            acc,      done, dirs_done)
                        end
                    end
                end --- match “kind”
            end --- iterate paths
        end

        --inspect(acc)
        --inspect(done)
        return acc, done, dirs_done
    end --- read_fonts_conf_indeed()

    --[[doc--
         read_fonts_conf() sets up an accumulator and two sets
         for tracking what’s been done.

         Also, the environment variables HOME and XDG_CONFIG_HOME --
         which are constants anyways -- are expanded so don’t have to
         repeat that over and over again as with the old parser.
         Now they’re just passed on to every call of
         read_fonts_conf_indeed().

         read_fonts_conf() is also the only reference visible outside
         the closure.
    --doc]]--
    --- list -> list
    read_fonts_conf = function (path_list)
        local home      = kpseexpand_path"~" --- could be os.getenv"HOME"
        local xdg_home  = kpseexpand_path"$XDG_CONFIG_HOME"
        if xdg_home == "" then xdg_home = filejoin(home, ".config") end
        local acc       = { } ---> list: paths collected
        local done      = { } ---> set:  files inspected
        local dirs_done = { } ---> set:  dirs in list
        for i=1, #path_list do --- we keep the state between files
            acc, done, dirs_done = read_fonts_conf_indeed(
                                     path_list[i], home, xdg_home,
                                     acc, done, dirs_done)
        end
        return acc
    end
end --- read_fonts_conf closure

--- TODO stuff those paths into some writable table
--- unit -> string list
local function get_os_dirs ()
    if os.name == 'macosx' then
        return {
            filejoin(kpseexpand_path('~'), "Library/Fonts"),
            "/Library/Fonts",
            "/System/Library/Fonts",
            "/Network/Library/Fonts",
        }
    elseif os.type == "windows" or os.type == "msdos" then
        local windir = os.getenv("WINDIR")
        return { filejoin(windir, 'Fonts') }
    else
        local fonts_conves = { --- plural, much?
            "/usr/local/etc/fonts/fonts.conf",
            "/etc/fonts/fonts.conf",
        }
        local os_dirs = read_fonts_conf(fonts_conves)
        return os_dirs
    end
    return {}
end

--[[doc--

    scan_os_fonts() scans the OS fonts through
      - fontconfig for Unix (reads the fonts.conf file[s] and scans the
        directories)
      - a static set of directories for Windows and MacOSX

    **NB**: If $OSFONTDIR is nonempty, as it appears to be by default
            on Windows setups, the system fonts will have already been
            processed while scanning the TEXMF. Thus, this function is
            never called.

--doc]]--

--- dbobj -> dbobj -> bool? -> (int * int)
local scan_os_fonts = function (fontnames, newfontnames,
                                dry_run)

    local n_scanned, n_new = 0, 0
    report ("info", 2, "db", "Scanning OS fonts...")
    report ("info", 3, "db",
            "Searching in static system directories...")

    for _, d in next, get_os_dirs () do
        local found, new = scan_dir (d, fontnames,
                                     newfontnames, dry_run)
        n_scanned = n_scanned + found
        n_new     = n_new     + new
    end

    return n_scanned, n_new
end

--- unit -> (bool, lookup_cache)
flush_lookup_cache = function ()
    if not names.lookups then names.lookups = load_lookups() end
    names.lookups = { }
    collectgarbage "collect"
    return true, names.lookups
end

--- dbobj -> dbobj
local gen_fast_lookups = function (fontnames)
    report("both", 2, "db", "Creating filename map")
    local mappings   = fontnames.mappings
    local nmappings  = #mappings
    --- this is needlessly complicated due to texmf priorization
    local filenames  = {
        bare = {
            system = { }, --- mapped to mapping format -> index in full
            texmf  = { }, --- mapped to mapping format -> “true”
        },
        base = {
            system = { }, --- mapped to index in “full”
            texmf  = { }, --- set; all values are “true”
        },
        full = { }, --- non-texmf
    }

    local texmf, sys = { }, { } -- quintuple list

    for idx = 1, nmappings do
        local entry    = mappings[idx]
        local filename = entry.filename
        local basename = entry.basename
        local bare     = filenameonly(filename)
        local subfont  = entry.subfont

        entry.index    = idx
---     unfortunately, the sys/texmf schism prevents us from
---     doing away the full name, so we cannot avoid the
---     substantial duplication
--      entry.filename = nil

        if entry.texmf == true then
            texmf[#texmf+1] = { idx, basename, bare, true, nil }
        else
            sys[#sys+1] = { idx, basename, bare, false, filename }
        end
    end

    local addmap = function (lst)
        --- this will overwrite existing entries
        for i=1, #lst do
            local idx, base, bare, intexmf, full = unpack(lst[i])

            local known = filenames.base[base] or filenames.bare[bare]
            if known then --- known
                report("both", 3, "db",
                       "Font file %q already indexed (%d)",
                       base, idx)
                report("both", 3, "db", "> old location: %s",
                       (filenames.full[known] or "texmf"))
                report("both", 3, "db", "> new location: %s",
                       (intexmf and "texmf" or full))
            end

            filenames.bare[bare] = idx
            filenames.base[base] = idx
            if intexmf == true then
                filenames.full[idx] = nil
            else
                filenames.full[idx] = full
            end
        end
    end

    if config.luaotfload.prioritize == "texmf" then
        report("both", 2, "db", "Preferring texmf fonts")
        addmap(sys)
        addmap(texmf)
    else --- sys
        addmap(texmf)
        addmap(sys)
    end

    fontnames.filenames = filenames
    texmf, sys = nil, nil
    collectgarbage "collect"
    return fontnames
end

local retrieve_namedata = function (fontnames, newfontnames, dry_run)
    local n_rawnames, n_new = 0, 0

    local rawnames, new = scan_texmf_fonts (fontnames,
                                            newfontnames,
                                            dry_run)

    n_rawnames    = n_rawnames + rawnames
    n_new         = n_new + new

    rawnames, new = scan_os_fonts (fontnames, newfontnames, dry_run)

    n_rawnames    = n_rawnames + rawnames
    n_new         = n_new + new

    return n_rawnames, n_new
end

--- force:      dictate rebuild from scratch
--- dry_dun:    don’t write to the db, just scan dirs

--- dbobj? -> bool? -> bool? -> dbobj
update_names = function (fontnames, force, dry_run)

    if config.luaotfload.update_live == false then
        report("info", 2, "db",
               "Skipping database update")
        --- skip all db updates
        return fontnames or names.data
    end

    local starttime            = os.gettimeofday()
    local n_rawnames, n_new    = 0, 0

    --[[
    The main function, scans everything
    - “newfontnames” is the final table to return
    - force is whether we rebuild it from scratch or not
    ]]
    report("both", 2, "db", "Updating the font names database"
                         .. (force and " forcefully" or ""))

    if force then
        fontnames = fontnames_init (get_font_filter ())
    else
        if not fontnames then
            fontnames = load_names (dry_run)
        end
        if fontnames.version ~= names.version then
            report ("both", 1, "db", "No font names database or old "
                                  .. "one found; generating new one")
            fontnames = fontnames_init (get_font_filter ())
        end
    end
    local newfontnames = fontnames_init (get_font_filter ())
    read_blacklist ()

    local rawnames, new = retrieve_namedata (fontnames,
                                             newfontnames,
                                             dry_run)
    n_rawnames = n_rawnames + rawnames
    n_new      = n_new + new

    --- we always generate the file lookup tables because
    --- non-texmf entries are redirected there and the mapping
    --- needs to be 100% consistent
    newfontnames = gen_fast_lookups(newfontnames)

    --- stats:
    ---            before rewrite   | after rewrite
    ---   partial:         804 ms   |   701 ms
    ---   forced:        45384 ms   | 44714 ms
    report("info", 3, "db",
           "Scanned %d font files; %d new entries.", n_rawnames, n_new)
    report("info", 3, "db",
           "Rebuilt in %0.f ms", 1000*(os.gettimeofday()-starttime))
    names.data = newfontnames

    if dry_run ~= true then

        save_names ()

        local success, _lookups = flush_lookup_cache ()
        if success then
            local success = names.save_lookups ()
            if success then
                logs.names_report ("info", 2, "cache",
                                   "Lookup cache emptied")
                return newfontnames
            end
        end
    end
    return newfontnames
end

--- unit -> bool
save_lookups = function ( )
    local lookups = names.lookups
    local path    = names.path.lookups
    local luaname, lucname = path.lua, path.luc
    if fileiswritable (luaname) and fileiswritable (lucname) then
        tabletofile (luaname, lookups, true)
        osremove (lucname)
        caches.compile (lookups, luaname, lucname)
        --- double check ...
        if lfsisfile (luaname) and lfsisfile (lucname) then
            report ("both", 3, "cache", "Lookup cache saved")
            return true
        end
        report ("info", 0, "cache", "Could not compile lookup cache")
        return false
    end
    report ("info", 0, "cache", "Lookup cache file not writable")
    if not fileiswritable (luaname) then
        report ("info", 0, "cache", "Failed to write %s", luaname)
    end
    if not fileiswritable (lucname) then
        report ("info", 0, "cache", "Failed to write %s", lucname)
    end
    return false
end

--- save_names() is usually called without the argument
--- dbobj? -> bool
save_names = function (fontnames)
    if not fontnames then fontnames = names.data end
    local path = names.path.index
    local luaname, lucname = path.lua, path.luc
    if fileiswritable (luaname) and fileiswritable (lucname) then
        tabletofile (luaname, fontnames, true)
        osremove (lucname)
        caches.compile (fontnames, luaname, lucname)
        if lfsisfile (luaname) and lfsisfile (lucname) then
            report ("info", 1, "db", "Font index saved")
            report ("info", 3, "db", "Text: " .. luaname)
            report ("info", 3, "db", "Byte: " .. lucname)
            return true
        end
        report ("info", 0, "db", "Could not compile font index")
        return false
    end
    report ("info", 0, "db", "Index file not writable")
    if not fileiswritable (luaname) then
        report ("info", 0, "db", "Failed to write %s", luaname)
    end
    if not fileiswritable (lucname) then
        report ("info", 0, "db", "Failed to write %s", lucname)
    end
    return false
end

--[[doc--

    Below set of functions is modeled after mtx-cache.

--doc]]--

--- string -> string -> string list -> string list -> string list -> unit
local print_cache = function (category, path, luanames, lucnames, rest)
    local report_indeed = function (...)
        report("info", 0, "cache", ...)
    end
    report_indeed("Luaotfload cache: %s", category)
    report_indeed("location: %s", path)
    report_indeed("[raw]       %4i", #luanames)
    report_indeed("[compiled]  %4i", #lucnames)
    report_indeed("[other]     %4i", #rest)
    report_indeed("[total]     %4i", #luanames + #lucnames + #rest)
end

--- string -> string -> string list -> bool -> bool
local purge_from_cache = function (category, path, list, all)
    report("info", 2, "cache", "Luaotfload cache: %s %s",
        (all and "erase" or "purge"), category)
    report("info", 2, "cache", "location: %s",path)
    local n = 0
    for i=1,#list do
        local filename = list[i]
        if stringfind(filename,"luatex%-cache") then -- safeguard
            if all then
                report("info", 5, "cache", "removing %s", filename)
                osremove(filename)
                n = n + 1
            else
                local suffix = filesuffix(filename)
                if suffix == "lua" then
                    local checkname = file.replacesuffix(
                        filename, "lua", "luc")
                    if lfsisfile(checkname) then
                        report("info", 5, "cache", "Removing %s", filename)
                        osremove(filename)
                        n = n + 1
                    end
                end
            end
        end
    end
    report("info", 2, "cache", "Removed lua files : %i", n)
    return true
end

--- string -> string list -> int -> string list -> string list -> string list ->
---     (string list * string list * string list * string list)
local collect_cache collect_cache = function (path, all, n, luanames,
                                              lucnames, rest)
    if not all then
        local all = find_files (path)

        local luanames, lucnames, rest = { }, { }, { }
        return collect_cache(nil, all, 1, luanames, lucnames, rest)
    end

    local filename = all[n]
    if filename then
        local suffix = filesuffix(filename)
        if suffix == "lua" then
            luanames[#luanames+1] = filename
        elseif suffix == "luc" then
            lucnames[#lucnames+1] = filename
        else
            rest[#rest+1] = filename
        end
        return collect_cache(nil, all, n+1, luanames, lucnames, rest)
    end
    return luanames, lucnames, rest, all
end

local getwritablecachepath = function ( )
    --- fonts.handlers.otf doesn’t exist outside a Luatex run,
    --- so we have to improvise
    local writable = getwritablepath (config.luaotfload.cache_dir)
    if writable then
        return writable
    end
end

local getreadablecachepaths = function ( )
    local readables = caches.getreadablepaths
                        (config.luaotfload.cache_dir)
    local result    = { }
    if readables then
        for i=1, #readables do
            local readable = readables[i]
            if lfsisdir (readable) then
                result[#result+1] = readable
            end
        end
    end
    return result
end

--- unit -> unit
local purge_cache = function ( )
    local writable_path = getwritablecachepath ()
    local luanames, lucnames, rest = collect_cache(writable_path)
    if logs.get_loglevel() > 1 then
        print_cache("writable path", writable_path, luanames, lucnames, rest)
    end
    local success = purge_from_cache("writable path", writable_path, luanames, false)
    return success
end

--- unit -> unit
local erase_cache = function ( )
    local writable_path = getwritablecachepath ()
    local luanames, lucnames, rest, all = collect_cache(writable_path)
    if logs.get_loglevel() > 1 then
        print_cache("writable path", writable_path, luanames, lucnames, rest)
    end
    local success = purge_from_cache("writable path", writable_path, all, true)
    return success
end

local separator = function ( )
    report("info", 0, string.rep("-", 67))
end

--- unit -> unit
local show_cache = function ( )
    local readable_paths = getreadablecachepaths ()
    local writable_path  = getwritablecachepath ()
    local luanames, lucnames, rest = collect_cache(writable_path)

    separator ()
    print_cache ("writable path", writable_path,
                 luanames, lucnames, rest)
    texiowrite_nl""
    for i=1,#readable_paths do
        local readable_path = readable_paths[i]
        if readable_path ~= writable_path then
            local luanames, lucnames = collect_cache (readable_path)
            print_cache ("readable path",
                         readable_path, luanames, lucnames, rest)
        end
    end
    separator()
    return true
end

-----------------------------------------------------------------------
--- export functionality to the namespace “fonts.names”
-----------------------------------------------------------------------

names.scan_dir                    = scan_dir
names.set_font_filter             = set_font_filter
names.flush_lookup_cache          = flush_lookup_cache
names.save_lookups                = save_lookups
names.load                        = load_names
names.save                        = save_names
names.update                      = update_names
names.crude_file_lookup           = crude_file_lookup
names.crude_file_lookup_verbose   = crude_file_lookup_verbose
names.read_blacklist              = read_blacklist
names.sanitize_string             = sanitize_string
names.getfilename                 = resolve_fullpath

--- font cache
names.purge_cache    = purge_cache
names.erase_cache    = erase_cache
names.show_cache     = show_cache

--- replace the resolver from luatex-fonts
if config.luaotfload.resolver == "cached" then
    report("both", 2, "cache", "caching of name: lookups active")
    names.resolve     = resolve_cached
    names.resolvespec = resolve_cached
else
    names.resolve     = resolve
    names.resolvespec = resolve
end

names.find_closest = find_closest

-- for testing purpose
names.read_fonts_conf = read_fonts_conf

-- vim:tw=71:sw=4:ts=4:expandtab
