if not modules then modules = { } end modules ['luaotfload-database'] = {
    version   = 2.3,
    comment   = "companion to luaotfload.lua",
    author    = "Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2"
}

--- TODO: if the specification is an absolute filename with a font not in the
--- database, add the font to the database and load it. There is a small
--- difficulty with the filenames of the TEXMF tree that are referenced as
--- relative paths...

--- Luatex builtins
local load                    = load
local next                    = next
local pcall                   = pcall
local require                 = require
local tonumber                = tonumber
local unpack                  = table.unpack

local fontloaderinfo          = fontloader.info
local fontloaderopen          = fontloader.open
local iolines                 = io.lines
local ioopen                  = io.open
local kpseexpand_path         = kpse.expand_path
local kpseexpand_var          = kpse.expand_var
local kpselookup              = kpse.lookup
local kpsereadable_file       = kpse.readable_file
local lfsisdir                = lfs.isdir
local lfsisfile               = lfs.isfile
local lfsattributes           = lfs.attributes
local mathabs                 = math.abs
local mathmin                 = math.min
local stringfind              = string.find
local stringformat            = string.format
local stringgmatch            = string.gmatch
local stringgsub              = string.gsub
local stringlower             = string.lower
local stringsub               = string.sub
local stringupper             = string.upper
local tableconcat             = table.concat
local tablecopy               = table.copy
local tablesort               = table.sort
local tabletofile             = table.tofile
local texiowrite_nl           = texio.write_nl
local utf8gsub                = unicode.utf8.gsub
local utf8lower               = unicode.utf8.lower

--- these come from Lualibs/Context
local dirglob                 = dir.glob
local dirmkdirs               = dir.mkdirs
local filebasename            = file.basename
local filenameonly            = file.nameonly
local filedirname             = file.dirname
local filecollapsepath        = file.collapsepath or file.collapse_path
local fileextname             = file.extname
local fileiswritable          = file.iswritable
local filejoin                = file.join
local filereplacesuffix       = file.replacesuffix
local filesplitpath           = file.splitpath or file.split_path
local stringis_empty          = string.is_empty
local stringsplit             = string.split
local stringstrip             = string.strip
local tableappend             = table.append
local tabletohash             = table.tohash

--- the font loader namespace is “fonts”, same as in Context
--- we need to put some fallbacks into place for when running
--- as a script
fonts                = fonts          or { }
fonts.names          = fonts.names    or { }
fonts.definers       = fonts.definers or { }

local names          = fonts.names

names.version        = 2.206
names.data           = nil      --- contains the loaded database
names.lookups        = nil      --- contains the lookup cache
names.path           = {
    dir              = "",                      --- db and cache directory
    basename         = "luaotfload-names.lua",  --- db file name
    path             = "",                      --- full path to db file
    lookup_basename  = "luaotfload-lookup-cache.lua", --- cache file name
    lookup_path      = "",                            --- cache full path
}

config                         = config or { }
config.luaotfload              = config.luaotfload or { }
config.luaotfload.resolver     = config.luaotfload.resolver or "normal"
if config.luaotfload.update_live ~= false then
    --- this option allows for disabling updates
    --- during a TeX run
    config.luaotfload.update_live = true
end

-- We use the cache.* of ConTeXt (see luat-basics-gen), we can
-- use it safely (all checks and directory creations are already done). It
-- uses TEXMFCACHE or TEXMFVAR as starting points.
local writable_path
if caches then
    writable_path = caches.getwritablepath("names","")
    if not writable_path then
        luaotfload.error("Impossible to find a suitable writeable cache...")
    end
    names.path.dir          = writable_path
    names.path.path         = filejoin(writable_path, names.path.basename)
    names.path.lookup_path  = filejoin(writable_path, names.path.lookup_basename)
else --- running as script, inject some dummies
    caches = { }
    logs   = { report = function () end }
end


--[[doc--
Auxiliary functions
--doc]]--


local report = logs.names_report

--- string -> string
local sanitize_string = function (str)
    if str ~= nil then
        return utf8gsub(utf8lower(str), "[^%a%d]", "")
    end
    return nil
end

--[[doc--
This is a sketch of the luaotfload db:

    type dbobj = {
        mappings        : fontentry list;
        status          : filestatus;
        version         : float;
        // new in v2.3; these supersede the basenames / barenames
        // hashes from v2.2
        filenames       : filemap;
    }
    and filemap = {
        base : (string, int) hash; // basename -> idx
        bare : (string, int) hash; // barename -> idx
        full : (int, string) hash; // idx -> full path
    }
    and fontentry = {
        barename    : string;
        familyname  : string;
        filename    : string;
        fontname    : string;
        fullname    : string;
        names       : {
            family     : string;
            fullname   : string;
            psname     : string;
            subfamily  : string;
        };
        sanitized   : {
            family     : string;
            fullname   : string;
            psname     : string;
            subfamily  : string;
        };
        size         : int list;
        slant        : int;
        subfont     : int;
        texmf        : bool;
        weight       : int;
        width        : int;
        units_per_em : int;        // mainly 1000, but also 2048 or 256
    }
    and filestatus = (fullname,
                      { index : int list; timestamp : int }) dict

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

local fontnames_init = function (keep_cache) --- returns dbobj
    return {
        mappings        = { },
        status          = { },
--      filenames       = { }, -- created later
        version         = names.version,
    }
end

--- string -> (string * string)
local make_savenames = function (path)
    return filereplacesuffix(path, "lua"),
           filereplacesuffix(path, "luc")
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
local font_fullinfo
local load_names
local load_lookups
local read_fonts_conf
local reload_db
local resolve
local resolve_cached
local save_names
local save_lookups
local update_names

--- state of the database
local fonts_loaded   = false
local fonts_reloaded = false

--- limit output when approximate font matching (luaotfload-tool -F)
local fuzzy_limit = 1 --- display closest only

--- bool? -> dbobj
load_names = function (dry_run)
    local starttime = os.gettimeofday()
    local foundname, data = load_lua_file(names.path.path)

    if data then
        report("both", 2, "db",
            "Font names database loaded", "%s", foundname)
        report("info", 3, "db", "Loading took %0.f ms",
                                1000*(os.gettimeofday()-starttime))
    else
        report("both", 0, "db",
            [[Font names database not found, generating new one.]])
        report("both", 0, "db",
             [[This can take several minutes; please be patient.]])
        data = update_names(fontnames_init(false), nil, dry_run)
        local success = save_names(data)
        if not success then
            report("both", 0, "db", "Database creation unsuccessful.")
        end
    end
    fonts_loaded = true
    return data
end

--- unit -> dbobj
load_lookups = function ( )
    local foundname, data = load_lua_file(names.path.lookup_path)
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
    style_synonyms.list = {
        regular    = { "normal",        "roman",
                       "plain",         "book",
                       "medium", },
        bold       = { "demi",           "demibold",
                       "semibold",       "boldregular",},
        italic     = { "regularitalic",  "normalitalic",
                       "oblique",        "slanted", },
        bolditalic = { "boldoblique",    "boldslanted",
                       "demiitalic",     "demioblique",
                       "demislanted",    "demibolditalic",
                       "semibolditalic", },
    }

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
                "crude file lookup: req=%s; hit=%s => kpse",
                filename, kind)
            found = dummy_findfile(filename)
        else
            report("info", 0, "db",
                "crude file lookup: req=%s; hit=%s; ret=%s",
                filename, kind, found)
        end
        return found
    end
    return false
end

--- string -> (string | string * string)
crude_file_lookup_verbose = function (filename)
    if not names.data then names.data = load_names() end
    local data      = names.data
    local mappings  = data.mappings
    local filenames = data.filenames
    local found

    --- look up in db first ...
    found = verbose_lookup(filenames, "bare", filename)
    if found then
        return found
    end
    found = verbose_lookup(filenames, "base", filename)
    if found then
        return found
    end

    --- ofm and tfm, returns pair
    for i=1, #type1_formats do
        local format = type1_formats[i]
        if resolvers.findfile(filename, format) then
            return file.addsuffix(filename, format), format
        end
    end
    return filename, nil
end

--- string -> (string | string * string)
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
        return found or filename
    end
    for i=1, #type1_formats do
        local format = type1_formats[i]
        if resolvers.findfile(filename, format) then
            return file.addsuffix(filename, format), format
        end
    end
    return filename, nil
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

--- 'a -> 'a -> table -> (string * int|boolean * boolean)
resolve_cached = function (_, _, specification)
    --if not names.data then names.data = load_names() end
    if not names.lookups then names.lookups = load_lookups() end
    local request = specification.specification
    report("both", 4, "cache", "looking for “%s” in cache ...",
           request)

    local found = names.lookups[request]

    --- case 1) cache positive ----------------------------------------
    if found then --- replay fields from cache hit
        report("info", 4, "cache", "found!")
        return found[1], found[2], true
    end
    report("both", 4, "cache", "not cached; resolving")

    --- case 2) cache negative ----------------------------------------
    --- first we resolve normally ...
    local filename, subfont, success = resolve(nil, nil, specification)
    if not success then return filename, subfont, false end
    --- ... then we add the fields to the cache ... ...
    local entry = { filename, subfont }
    report("both", 4, "cache", "new entry: %s", request)
    names.lookups[request] = entry

    --- obviously, the updated cache needs to be stored.
    --- TODO this should trigger a save only once the
    ---      document is compiled (finish_pdffile callback?)
    report("both", 5, "cache", "saving updated cache")
    local success = save_lookups()
    if not success then --- sad, but not critical
        report("both", 0, "cache", "could not write to cache")
    end
    return filename, subfont, true
end

--- this used to be inlined; with the lookup cache we don’t
--- have to be parsimonious wrt function calls anymore
--- “found” is the match accumulator
local add_to_match = function (
    found,   optsize, dsnsize, size,
    minsize, maxsize, face)
    local continue = true
    if optsize then
        if dsnsize == size or (size > minsize and size <= maxsize) then
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
Existence of the resolved file name is verified differently depending
on whether the index entry has a texmf flag set.
--doc]]--

local get_font_file = function (fullnames, entry)
    if entry.texmf == true then
        local basename = entry.basename
        if kpselookup(basename) then
            return true, basename, entry.subfont
        end
    else
        local fullname = fullnames[entry.index]
        if lfsisfile(fullname) then
            return true, fullname, entry.subfont
        end
    end
    return false
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
--- the first return value of “resolve” is the file name of the
--- requested font (string)
--- the second is of type bool or string and indicates the subfont of a
--- ttc
---
--- 'a -> 'a -> table -> (string * string | bool * bool)
---
---     note by phg: I added a third return value that indicates a
---     successful lookup as this cannot be inferred from the other
---     values.
---

resolve = function (_,_,specification) -- the 1st two parameters are used by ConTeXt
    if not fonts_loaded then names.data = load_names() end
    local data = names.data

    local name  = sanitize_string(specification.name)
    local style = sanitize_string(specification.style) or "regular"

    local size
    if specification.optsize then
        size = tonumber(specification.optsize)
    elseif specification.size then
        size = specification.size / 65536
    end

    if type(data) ~= "table" then
         --- this catches a case where load_names() doesn’t
         --- return a database object, which can happen only
         --- in case there is valid Lua code in the database,
         --- but it’s not a table, e.g. it contains an integer.
        if not fonts_reloaded then
            return reload_db("invalid database; not a table",
                             resolve, nil, nil, specification
                   )
        end
        --- unsucessfully reloaded; bail
        return specification.name, false, false
    end

    local db_version, nms_version = data.version, names.version
    if db_version ~= nms_version then
        report("log", 0, "db",
            [[version mismatch; expected %4.3f, got %4.3f]],
            nms_version, db_version)
        if not fonts_reloaded then
            return reload_db("version mismatch",
                             resolve, nil, nil, specification)
        end
        return specification.name, false, false
    end

    if not data.mappings then
        if not fonts_reloaded then
            return reload_db("invalid database; missing font mapping",
                             resolve, nil, nil, specification)
        end
        return specification.name, false, false
    end

    local found      = { } --> collect results
    local fallback         --> e.g. non-matching style (fontspec is anal about this)
    local candidates = { } --> secondary results, incomplete matches

    local synonym_set = style_synonyms.set
    for n, face in next, data.mappings do
        local family, subfamily, fullname, psname, fontname, pfullname

        local facenames = face.sanitized
        if facenames then
            family      = facenames.family
            subfamily   = facenames.subfamily
            fullname    = facenames.fullname
            psname      = facenames.psname
            fontname    = facenames.fontname
            pfullname   = facenames.pfullname
        end
        fontname    = fontname  or sanitize_string(face.fontname)
        pfullname   = pfullname or sanitize_string(face.fullname)

        local optsize, dsnsize, maxsize, minsize
        if #face.size > 0 then
            optsize = face.size
            dsnsize = optsize[1] and optsize[1] / 10
            -- can be nil
            maxsize = optsize[2] and optsize[2] / 10 or dsnsize
            minsize = optsize[3] and optsize[3] / 10 or dsnsize
        end

        if name == family then
            if subfamily == style then
                local continue
                found, continue = add_to_match(
                    found,   optsize, dsnsize, size,
                    minsize, maxsize, face)
                if continue == false then break end
            elseif synonym_set[style] and
                   synonym_set[style][subfamily]
            then
                local continue
                found, continue = add_to_match(
                    found,   optsize, dsnsize, size,
                    minsize, maxsize, face)
                if continue == false then break end
            elseif subfamily == "regular" or
                --- TODO this match should be performed when building the db
                   synonym_set.regular[subfamily] then
                fallback = face
            elseif name == fullname
                or name == pfullname
                or name == fontname
                or name == psname
            then
                local continue
                found, continue = add_to_match(
                    found,   optsize, dsnsize, size,
                    minsize, maxsize, face)
                if continue == false then break end
            else --- mark as last straw but continue
                candidates[#candidates+1] = face
            end
        else
            if name == fullname
            or name == pfullname
            or name == fontname
            or name == psname then
                local continue
                found, continue = add_to_match(
                    found,   optsize, dsnsize, size,
                    minsize, maxsize, face)
                if continue == false then break end
            end
        end
    end

    if #found == 1 then
        --- “found” is really synonymous with “registered in the db”.
        local entry = found[1]
        local success, filename, subfont
            = get_font_file(data.filenames.full, entry)
        if success == true then
            report("log", 0, "resolve",
                "font family='%s', subfamily='%s' found: %s",
                name, style, filename
            )
            return filename, subfont, true
        end
    elseif #found > 1 then
        -- we found matching font(s) but not in the requested optical
        -- sizes, so we loop through the matches to find the one with
        -- least difference from the requested size.
        local closest
        local least = math.huge -- initial value is infinity
        for i,face in next, found do
            local dsnsize    = face.size[1]/10
            local difference = mathabs(dsnsize-size)
            if difference < least then
                closest = face
                least   = difference
            end
        end
        local success, filename, subfont
            = get_font_file(data.filenames.full, closest)
        if success == true then
            report("log", 0, "resolve",
                "font family='%s', subfamily='%s' found: %s",
                name, style, filename
            )
            return filename, subfont, true
        end
    elseif fallback then
        local success, filename, subfont
            = get_font_file(data.filenames.full, fallback)
        if success == true then
            report("log", 0, "resolve",
                "no exact match for request %s; using fallback",
                specification.specification
            )
            report("log", 0, "resolve",
                "font family='%s', subfamily='%s' found: %s",
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
                "font family='%s', subfamily='%s' found: %s",
                name, style, filename
            )
            return filename, subfont, true
        end
    end

    --- no font found so far
    if not fonts_reloaded then
        --- last straw: try reloading the database
        return reload_db(
            "unresolved font name: ‘" .. name .. "’",
            resolve, nil, nil, specification
        )
    end

    --- else, default to requested name
    return specification.name, false, false
end --- resolve()

--- when reload is triggered we update the database
--- and then re-run the caller with the arg list

--- string -> ('a -> 'a) -> 'a list -> 'a
reload_db = function (why, caller, ...)
    report("both", 1, "db", "reload initiated; reason: “%s”", why)
    names.data = update_names(names.data, false, false)
    local success = save_names()
    if success then
        fonts_reloaded = true
        return caller(...)
    end
    report("both", 0, "db", "Database update unsuccessful.")
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
            Matching is performed against the “family” name
            of a db record. We then store its “fullname” at
            it edit distance.
            We should probably do some weighting over all the
            font name categories as well as whatever agrep
            does.
        --]]
        if cnames then
            local fullname, family = cnames.fullname, cnames.family
            family = sanitize_string(family)

            local dist = cached[family]--- maybe already calculated
            if not dist then
                dist = iterative_levenshtein(name, family)
                cached[family] = dist
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
                "displaying %d distance levels", limit)

        for i = 1, limit do
            local dist     = distances[i]
            local namelst  = by_distance[dist]
            report(false, 0, "query",
                "distance from “" .. name .. "”: " .. dist
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

--[[doc--
The data inside an Opentype font file can be quite heterogeneous.
Thus in order to get the relevant information, parts of the original
table as returned by the font file reader need to be relocated.
--doc]]--
--- string -> int -> bool -> string -> fontentry
font_fullinfo = function (filename, subfont, texmf, basename)
    local tfmdata = { }
    local rawfont = fontloaderopen(filename, subfont)
    if not rawfont then
        report("log", 1, "error", "failed to open %s", filename)
        return
    end
    local metadata = fontloader.to_table(rawfont)
    fontloader.close(rawfont)
    collectgarbage("collect")
    -- see http://www.microsoft.com/typography/OTSPEC/features_pt.htm#size
    if metadata.fontstyle_name then
        for _, name in next, metadata.fontstyle_name do
            if name.lang == 1033 then --- I hate magic numbers
                tfmdata.fontstyle_name = name.name
            end
        end
    end
    if metadata.names then
        for _, namedata in next, metadata.names do
            if namedata.lang == "English (US)" then
                local names = {
                    --- see
                    --- https://developer.apple.com/fonts/TTRefMan/RM06/Chap6name.html
                    fullname  = namedata.names.compatfull
                             or namedata.names.fullname,
                    family    = namedata.names.preffamilyname
                             or namedata.names.family,
                    subfamily = tfmdata.fontstyle_name
                             or namedata.names.prefmodifiers
                             or namedata.names.subfamily,
                    psname    = namedata.names.postscriptname,
                    pfullname = metadata.fullname,
                    fontname  = metadata.fontname,
                }
                tfmdata.names     = names
                tfmdata.sanitized = sanitize_names(names)
            end
        end
    else
        -- no names table, propably a broken font
        report("log", 1, "db", "broken font rejected", "%s", basefile)
        return
    end
    tfmdata.fontname      = metadata.fontname
    tfmdata.fullname      = metadata.fullname
    tfmdata.familyname    = metadata.familyname
    tfmdata.weight        = metadata.pfminfo.weight
    tfmdata.width         = metadata.pfminfo.width
    tfmdata.slant         = metadata.italicangle
    --- this is for querying
    tfmdata.units_per_em  = metadata.units_per_em
    tfmdata.version       = metadata.version
    -- don't waste the space with zero values
    tfmdata.size = {
        metadata.design_size         ~= 0 and metadata.design_size         or nil,
        metadata.design_range_top    ~= 0 and metadata.design_range_top    or nil,
        metadata.design_range_bottom ~= 0 and metadata.design_range_bottom or nil,
    }

    --- file location data (used to be filename field)
    tfmdata.filename      = filename --> sys
    tfmdata.basename      = basename --> texmf
    tfmdata.texmf         = texmf or false
    tfmdata.subfont       = subfont

    return tfmdata
end

--- we return true if the fond is new or re-indexed
--- string -> dbobj -> dbobj -> bool
local load_font = function (fullname, fontnames, newfontnames, texmf)
    if not fullname then
        return false
    end

    local newmappings   = newfontnames.mappings
    local newstatus     = newfontnames.status --- by full path

    local mappings      = fontnames.mappings
    local status        = fontnames.status

    local basename      = filebasename(fullname)
    local barename      = filenameonly(fullname)

    local entryname     = fullname
    if texmf == true then
        entryname = basename
    end

    if names.blacklist[fullname] or names.blacklist[basename]
    then
        report("log", 2, "db",
            "ignoring blacklisted font “%s”", fullname)
        return false
    end

    local new_timestamp, current_timestamp
    current_timestamp   = status[fullname]
                      and status[fullname].timestamp
    new_timestamp       = lfsattributes(fullname, "modification")

    local newentrystatus = newstatus[fullname]
    --- newentrystatus: nil | false | table
    if newentrystatus and newentrystatus.timestamp == new_timestamp then
        -- already indexed this run
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
        report("log", 2, "db", "font “%s” already indexed", basename)
        return false
    end

    local info = fontloaderinfo(fullname)
    if info then
        if type(info) == "table" and #info > 1 then --- ttc
            for n_font = 1, #info do
                local fullinfo = font_fullinfo(fullname, n_font-1, texmf, basename)
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
            local fullinfo = font_fullinfo(fullname, false, texmf, basename)
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
        report("log", 1, "db", "failed to load “%s”", basename)
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
    Cygwin used to be treated different from windows and dos.  This
    special treatment was removed with a patch submitted by Ken Brown.
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

local function read_blacklist()
    local files = {
        kpselookup("luaotfload-blacklist.cnf", {all=true, format="tex"})
    }
    local blacklist = names.blacklist
    local whitelist = { }

    if files and type(files) == "table" then
        for _,v in next, files do
            for line in iolines(v) do
                line = stringstrip(line) -- to get rid of lines like " % foo"
                local first_chr = stringsub(line, 1, 1) --- faster than find
                if first_chr == "%" or stringis_empty(line) then
                    -- comment or empty line
                else
                    --- this is highly inefficient
                    line = stringsplit(line, "%")[1]
                    line = stringstrip(line)
                    if stringsub(line, 1, 1) == "-" then
                        whitelist[stringsub(line, 2, -1)] = true
                    else
                        report("log", 2, "db", "blacklisted file “%s”", line)
                        blacklist[line] = true
                    end
                end
            end
        end
    end
    for _,fontname in next, whitelist do
      blacklist[fontname] = nil
    end
end

local font_extensions = { "otf", "ttf", "ttc", "dfont" }
local font_extensions_set = {}
for key, value in next, font_extensions do
   font_extensions_set[value] = true
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
local scan_dir = function (dirname, fontnames, newfontnames, dry_run, texmf)
    local n_scanned, n_new = 0, 0   --- total of fonts collected
    report("both", 2, "db", "scanning directory %s", dirname)
    for _,i in next, font_extensions do
        for _,ext in next, { i, stringupper(i) } do
            local found = dirglob(stringformat("%s/**.%s$", dirname, ext))
            local n_found = #found
            --- note that glob fails silently on broken symlinks, which
            --- happens sometimes in TeX Live.
            report("both", 4, "db", "%s '%s' fonts found", n_found, ext)
            n_scanned = n_scanned + n_found
            for j=1, n_found do
                local fullname = found[j]
                fullname = path_normalize(fullname)
                local new
                if dry_run == true then
                    report("both", 1, "db", "would have been loading “%s”", fullname)
                else
                    report("both", 4, "db", "loading font “%s”", fullname)
                    local new = load_font(fullname, fontnames, newfontnames, texmf)
                    if new == true then
                        n_new = n_new + 1
                    end
                end
            end
        end
    end
    report("both", 4, "db", "%d fonts found in '%s'", n_scanned, dirname)
    return n_scanned, n_new
end

--- dbobj -> dbobj -> bool? -> (int * int)
local scan_texmf_fonts = function (fontnames, newfontnames, dry_run)
    local n_scanned, n_new = 0, 0
    --[[
    This function scans all fonts in the texmf tree, through kpathsea
    variables OPENTYPEFONTS and TTFONTS of texmf.cnf
    ]]
    if stringis_empty(kpseexpand_path("$OSFONTDIR")) then
        report("info", 2, "db", "Scanning TEXMF fonts...")
    else
        report("info", 2, "db", "Scanning TEXMF and OS fonts...")
    end
    local fontdirs = stringgsub(kpseexpand_path("$OPENTYPEFONTS"), "^%.", "")
    fontdirs       = fontdirs .. stringgsub(kpseexpand_path("$TTFONTS"), "^%.", "")
    if not stringis_empty(fontdirs) then
        for _,d in next, filesplitpath(fontdirs) do
            report("info", 4, "db", "Entering directory %s", d)
            local found, new = scan_dir(d, fontnames, newfontnames, dry_run, true)
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

    local lpeg = require "lpeg"

    local C, Cc, Cf, Cg, Ct
        = lpeg.C, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Ct

    local P, R, S, lpegmatch
        = lpeg.P, lpeg.R, lpeg.S, lpeg.match

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
            report("both", 3, "db", "cannot open fontconfig file %s", path)
            return
        end
        local raw = fh:read"*all"
        fh:close()

        local confdata = lpegmatch(p_cheapxml, raw)
        if not confdata then
            report("both", 3, "db", "cannot scan fontconfig file %s", path)
            return
        end
        return confdata
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
                    local config_files = dirglob(filejoin(path, "*.conf"))
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

--- dbobj -> dbobj -> bool? -> (int * int)
local scan_os_fonts = function (fontnames, newfontnames, dry_run)
    local n_scanned, n_new = 0, 0
    --[[
    This function scans the OS fonts through
      - fontcache for Unix (reads the fonts.conf file and scans the
        directories)
      - a static set of directories for Windows and MacOSX
    ]]
    report("info", 2, "db", "Scanning OS fonts...")
    report("info", 3, "db", "Searching in static system directories...")
    for _, d in next, get_os_dirs() do
        local found, new = scan_dir(d, fontnames, newfontnames, dry_run)
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
    report("both", 2, "db", "creating filename map")
    local mappings   = fontnames.mappings
    local nmappings  = #mappings
    --- this is needlessly complicated due to texmf priorization
    local filenames  = {
        bare = { },
        base = { },
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
                report("both", 1, "db",
                       "font file “%s” already indexed (%d)",
                       base, idx)
                report("both", 2, "db", "> old location: %s",
                       (filenames.full[known] or "texmf"))
                report("both", 2, "db", "> new location: %s",
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
        report("both", 2, "db", "preferring texmf fonts")
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

--- force:      dictate rebuild from scratch
--- dry_dun:    don’t write to the db, just scan dirs

--- dbobj? -> bool? -> bool? -> dbobj
update_names = function (fontnames, force, dry_run)
    if config.luaotfload.update_live == false then
        report("info", 2, "db",
               "skipping database update")
        --- skip all db updates
        return fontnames or names.data
    end
    local starttime = os.gettimeofday()
    local n_scanned, n_new = 0, 0
    --[[
    The main function, scans everything
    - “newfontnames” is the final table to return
    - force is whether we rebuild it from scratch or not
    ]]
    report("both", 2, "db", "Updating the font names database"
                         .. (force and " forcefully" or ""))

    if force then
        fontnames = fontnames_init(false)
    else
        if not fontnames then
            fontnames = load_names(dry_run)
        end
        if fontnames.version ~= names.version then
            report("both", 1, "db", "No font names database or old "
                                 .. "one found; generating new one")
            fontnames = fontnames_init(true)
        end
    end
    local newfontnames = fontnames_init(true)
    read_blacklist()

    local scanned, new
    scanned, new = scan_texmf_fonts(fontnames, newfontnames, dry_run)
    n_scanned = n_scanned + scanned
    n_new     = n_new     + new

    scanned, new = scan_os_fonts(fontnames, newfontnames, dry_run)
    n_scanned = n_scanned + scanned
    n_new     = n_new     + new

    --- we always generate the file lookup tables because
    --- non-texmf entries are redirected there and the mapping
    --- needs to be 100% consistent
    newfontnames = gen_fast_lookups(newfontnames)

    --- stats:
    ---            before rewrite   | after rewrite
    ---   partial:         804 ms   |   701 ms
    ---   forced:        45384 ms   | 44714 ms
    report("info", 3, "db",
           "Scanned %d font files; %d new entries.", n_scanned, n_new)
    report("info", 3, "db",
           "Rebuilt in %0.f ms", 1000*(os.gettimeofday()-starttime))
    return newfontnames
end

--- unit -> string
local ensure_names_path = function ( )
    local path = names.path.dir
    if not lfsisdir(path) then
        dirmkdirs(path)
    end
    return path
end

--- The lookup cache is an experimental feature of version 2.2;
--- instead of incorporating it into the database it gets its own
--- file. As we update it after every single addition this saves us
--- quite some time.

--- unit -> bool
save_lookups = function ( )
    ---- this is boilerplate and should be refactored into something
    ---- usable by both the db and the cache writers
    local lookups  = names.lookups
    local path     = ensure_names_path()
    if fileiswritable(path) then
        local luaname, lucname = make_savenames(names.path.lookup_path)
        if luaname then
            tabletofile(luaname, lookups, true)
            if lucname and type(caches.compile) == "function" then
                os.remove(lucname)
                caches.compile(lookups, luaname, lucname)
                report("both", 3, "cache", "Lookup cache saved")
                return true
            end
        end
    end
    report("info", 0, "cache", "Could not write lookup cache")
    return false
end

--- save_names() is usually called without the argument
--- dbobj? -> bool
save_names = function (fontnames)
    if not fontnames then fontnames = names.data end
    local path = ensure_names_path()
    if fileiswritable(path) then
        local luaname, lucname = make_savenames(names.path.path)
        if luaname then
            --tabletofile(luaname, fontnames, true, { reduce=true })
            tabletofile(luaname, fontnames, true)
            if lucname and type(caches.compile) == "function" then
                os.remove(lucname)
                caches.compile(fontnames, luaname, lucname)
                report("info", 1, "db", "Font names database saved")
                return true
            end
        end
    end
    report("both", 0, "db", "Failed to save names database")
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
        if string.find(filename,"luatex%-cache") then -- safeguard
            if all then
                report("info", 5, "cache", "removing %s", filename)
                os.remove(filename)
                n = n + 1
            else
                local suffix = file.suffix(filename)
                if suffix == "lua" then
                    local checkname = file.replacesuffix(
                        filename, "lua", "luc")
                    if lfs.isfile(checkname) then
                        report("info", 5, "cache", "removing %s", filename)
                        os.remove(filename)
                        n = n + 1
                    end
                end
            end
        end
    end
    report("info", 2, "cache", "removed lua files : %i", n)
    return true
end
--- string -> string list -> int -> string list -> string list -> string list ->
---     (string list * string list * string list * string list)
local collect_cache collect_cache = function (path, all, n, luanames,
                                              lucnames, rest)
    if not all then
        local all = dirglob(path .. "/**/*")
        local luanames, lucnames, rest = { }, { }, { }
        return collect_cache(nil, all, 1, luanames, lucnames, rest)
    end

    local filename = all[n]
    if filename then
        local suffix = file.suffix(filename)
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

--- unit -> unit
local purge_cache = function ( )
    local writable_path = caches.getwritablepath()
    local luanames, lucnames, rest = collect_cache(writable_path)
    if logs.get_loglevel() > 1 then
        print_cache("writable path", writable_path, luanames, lucnames, rest)
    end
    local success = purge_from_cache("writable path", writable_path, luanames, false)
    return success
end

--- unit -> unit
local erase_cache = function ( )
    local writable_path = caches.getwritablepath()
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
    local readable_paths = caches.getreadablepaths()
    local writable_path  = caches.getwritablepath()
    local luanames, lucnames, rest = collect_cache(writable_path)

    separator()
    print_cache("writable path", writable_path, luanames, lucnames, rest)
    texiowrite_nl""
    for i=1,#readable_paths do
        local readable_path = readable_paths[i]
        if readable_path ~= writable_path then
            local luanames, lucnames = collect_cache(readable_path)
            print_cache("readable path",
                readable_path,luanames,lucnames,rest)
        end
    end
    separator()
    return true
end

-----------------------------------------------------------------------
--- export functionality to the namespace “fonts.names”
-----------------------------------------------------------------------

names.scan_dir                    = scan_dir
names.flush_lookup_cache          = flush_lookup_cache
names.save_lookups                = save_lookups
names.load                        = load_names
names.save                        = save_names
names.update                      = update_names
names.crude_file_lookup           = crude_file_lookup
names.crude_file_lookup_verbose   = crude_file_lookup_verbose

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
names.find_closest      = find_closest

-- for testing purpose
names.read_fonts_conf = read_fonts_conf

--- dummy required by luatex-fonts (cf. luatex-fonts-syn.lua)

fonts.names.getfilename = function (askedname,suffix) return "" end

-- vim:tw=71:sw=4:ts=4:expandtab
