if not modules then modules = { } end modules ['luaotfload-database'] = {
    version   = 2.2,
    comment   = "companion to luaotfload.lua",
    author    = "Khaled Hosny and Elie Roux",
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

local fontloaderinfo          = fontloader.info
local iolines                 = io.lines
local ioopen                  = io.open
local kpseexpand_path         = kpse.expand_path
local kpseexpand_var          = kpse.expand_var
local kpselookup              = kpse.lookup
local kpsereadable_file       = kpse.readable_file
local lfsisdir                = lfs.isdir
local lfsisfile               = lfs.isfile
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

names.version        = 2.202
names.data           = nil
names.path           = {
    basename = "luaotfload-names.lua",
    dir      = "",
    path     = "",
}

config                      = config or { }
config.luaotfload           = config.luaotfload or { }
config.luaotfload.resolver  = config.luaotfload.resolver or "normal"

-- We use the cache.* of ConTeXt (see luat-basics-gen), we can
-- use it safely (all checks and directory creations are already done). It
-- uses TEXMFCACHE or TEXMFVAR as starting points.
local writable_path
if caches then
    writable_path = caches.getwritablepath("names","")
    if not writable_path then
        error("Impossible to find a suitable writeable cache...")
    end
    names.path.dir   = writable_path
    names.path.path  = filejoin(writable_path, names.path.basename)
else --- running as script, inject some dummies
    caches = { }
    logs   = { report = function () end }
end


--[[doc--
Auxiliary functions
--doc]]--


local report = logs.names_report

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
        // preliminary additions of v2.2:
        basenames       : (string, int) hash;    // where int is the index in mappings
        barenames       : (string, int) hash;    // where int is the index in mappings
        request_cache   : lookup_cache;          // see below
    }
    and fontentry = {
        familyname  : string;
        filename    : (string * bool);
        fontname    : string;
        fullname    : string;
        names       : {
            family     : string;
            fullname   : string;
            psname     : string;
            subfamily  : string;
        }
        size        : int list;
        slant       : int;
        weight      : int;
        width       : int;
    }
    and filestatus = (fullname, { index : int list; timestamp : int }) dict

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
    local request_cache
    if keep_cache and names.data and names.data.request_cache then
        request_cache = names.data.request_cache
    else
        request_cache = { }
    end
    return {
        mappings        = { },
        status          = { },
        --- adding filename mapping increases the
        --- size of the serialized db on my system
        --- (5840 font files) by a factor of 1.09
        --- if we store only the indices in the
        --- mappings table
        barenames       = { },
        basenames       = { },
--      fullnames       = { },
        version         = names.version,
        request_cache   = request_cache,
    }
end

local make_name = function (path)
    return filereplacesuffix(path, "lua"), filereplacesuffix(path, "luc")
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
local flush_cache
local font_fullinfo
local load_names
local read_fonts_conf
local reload_db
local resolve
local resolve_cached
local save_names
local scan_external_dir
local update_names

--- state of the database
local fonts_loaded   = false
local fonts_reloaded = false

--- unit -> dbobj
load_names = function ( )
    local starttime = os.gettimeofday()
    local foundname, data = load_lua_file(names.path.path)

    if data then
        report("info", 1, "db",
            "Font names database loaded", "%s", foundname)
        report("info", 3, "db", "Loading took %0.f ms",
                                1000*(os.gettimeofday()-starttime))
    else
        report("info", 1, "db",
            [[Font names database not found, generating new one.
             This can take several minutes; please be patient.]])
        data = update_names(fontnames_init(false))
        save_names(data)
    end
    fonts_loaded = true
    return data
end

local fuzzy_limit = 1 --- display closest only

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

--- string -> (string * bool | int)
crude_file_lookup_verbose = function (filename)
    if not names.data then names.data = load_names() end
    local data      = names.data
    local mappings  = data.mappings
    local found

    --- look up in db first ...
    found = data.barenames[filename]
    if found and mappings[found] then
        found = mappings[found].filename
        report("info", 0, "db",
            "crude file lookup: req=%s; hit=bare; ret=%s",
            filename, found[1])
        return found
    end
--  found = data.fullnames[filename]
--  if found and mappings[found] then
--      found = mappings[found].filename[1]
--          "crude file lookup: req=%s; hit=bare; ret=%s",
--          filename, found[1])
--      return found
--  end
    found = data.basenames[filename]
    if found and mappings[found] then
        found = mappings[found].filename
        report("info", 0, "db",
            "crude file lookup: req=%s; hit=base; ret=%s",
            filename, found[1])
        return found
    end

    --- ofm and tfm
    for i=1, #type1_formats do
        local format = type1_formats[i]
        if resolvers.findfile(filename, format) then
            return { file.addsuffix(filename, format), false }, format
        end
    end
    return { filename, false }, nil
end

--- string -> (string * bool | int)
crude_file_lookup = function (filename)
    if not names.data then names.data = load_names() end
    local data      = names.data
    local mappings  = data.mappings
    local found = data.barenames[filename]
--             or data.fullnames[filename]
               or data.basenames[filename]
    if found then
        found = data.mappings[found]
        if found then return found.filename end
    end
    for i=1, #type1_formats do
        local format = type1_formats[i]
        if resolvers.findfile(filename, format) then
            return { file.addsuffix(filename, format), false }, format
        end
    end
    return { filename, false }, nil
end

--[[doc--
Lookups can be quite costly, more so the less specific they are.
Even if we find a matching font eventually, the next time the
user compiles Eir document E will have to stand through the delay
again.
Thus, some caching of results -- even between runs -- is in order.
We’ll just store successful lookups in the database in a record of
the respective lookup type.

type lookup_cache = (string, (string * num)) dict

TODO:
 ×  1) add cache to dbobj
 ×  2) wrap lookups in cached versions
 ×  3) make caching optional (via the config table) for debugging
 ×  4) make names_update() cache aware (nil if “force”)
 ×  5) add logging
 ×  6) add cache control to fontdbutil
 ×  7) incr db version
    8) wishlist: save cache only at the end of a run
    9) ???
    n) PROFIT!!!

The name lookup requires both the “name” and some other
keys, so we’ll concatenate them.
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

The following fields of a resolved spec need to be cached:
--doc]]--
local cache_fields = {
    "forced", "hash", "lookup", "name", "resolved", "sub",
}

--[[doc--
From my reading of font-def.lua, what a resolver does is
basically rewrite the “name” field of the specification record
with the resolution.
Also, the fields “resolved”, “sub”, “force” etc. influence the outcome.

We’ll just cache a deep copy of the entire spec as it leaves the
resolver, lest we want to worry if we caught all the details.
--doc]]--

--- 'a -> 'a -> table -> (string * int|boolean * boolean)
resolve_cached = function (_, _, specification)
    if not names.data then names.data = load_names() end
    local request_cache = names.data.request_cache
    local request = specification.specification
    report("log", 4, "cache", "looking for “%s” in cache ...",
           request)

    local found = names.data.request_cache[request]

    --- case 1) cache positive ----------------------------------------
    if found then --- replay fields from cache hit
        report("info", 4, "cache", "found!")
        return found[1], found[2], true
    end
    report("log", 4, "cache", "not cached; resolving")

    --- case 2) cache negative ----------------------------------------
    --- first we resolve normally ...
    local filename, subfont, success = resolve(nil, nil, specification)
    if not success then return filename, subfont, false end
    --- ... then we add the fields to the cache ... ...
    local entry = { filename, subfont }
    report("log", 4, "cache", "new entry: %s", request)
    names.data.request_cache[request] = entry

    --- obviously, the updated cache needs to be stored.
    --- for the moment, we write the entire db to disk
    --- whenever the cache is updated.
    --- TODO this should trigger a save only once the
    ---      document is compiled (finish_pdffile callback?)
    --- TODO we should speed up writing by separating
    ---      the cache from the db
    report("log", 5, "cache", "saving updated cache")
    save_names()
    return filename, subfont, true
end

--[[doc--

Luatex-fonts, the font-loader package luaotfload imports, comes with
basic file location facilities (see luatex-fonts-syn.lua).
However, the builtin functionality is too limited to be of more than
basic use, which is why we supply our own resolver that accesses the
font database created by the mkluatexfontdb script.

--doc]]--


---
--- the request specification has the fields:
---
---   · features: table
---     · normal: set of { ccmp clig itlc kern liga locl mark mkmk rlig }
---     · ???
---   · forced:   string
---   · lookup:   "name" | "file"
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
            nms_version, db_version
        )
        return reload_db("version mismatch", resolve, nil, nil, specification)
    end

    if not data.mappings then
        return reload_db("invalid database; missing font mapping",
                         resolve, nil, nil, specification
               )
    end

    local found = { }
    local synonym_set = style_synonyms.set
    for _, face in next, data.mappings do
        local family, subfamily, fullname, psname, fontname, pfullname

        local facenames = face.sanitized
        if facenames then
            family      = facenames.family
            subfamily   = facenames.subfamily
            fullname    = facenames.fullname
            psname      = facenames.psname
        end
        fontname  = facenames.fontname  or sanitize_string(face.fontname)
        pfullname = facenames.pfullname or sanitize_string(face.fullname)

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
                if optsize then
                    if dsnsize == size
                    or (size > minsize and size <= maxsize) then
                        found[1] = face
                        break
                    else
                        found[#found+1] = face
                    end
                else
                    found[1] = face
                    break
                end
            elseif synonym_set[style] and
                   synonym_set[style][subfamily]
            then
                if optsize then
                    if dsnsize == size
                    or (size > minsize and size <= maxsize) then
                        found[1] = face
                        break
                    else
                        found[#found+1] = face
                    end
                else
                    found[1] = face
                    break
                end
            elseif subfamily == "regular" or
                    synonym_set.regular[subfamily] then
                found.fallback = face
            end
        end

        if name == fullname
        or name == pfullname
        or name == fontname
        or name == psname then
            if optsize then
                if dsnsize == size
                or (size > minsize and size <= maxsize) then
                    found[1] = face
                    break
                else
                    found[#found+1] = face
                end
            else
                found[1] = face
                break
            end
        end
    end

    if #found == 1 then
        --- “found” is really synonymous with “registered in the db”.
        local filename = found[1].filename[1]
        if lfsisfile(filename) or kpselookup(filename) then
            report("log", 0, "resolve",
                "font family='%s', subfamily='%s' found: %s",
                name, style, filename
            )
            return filename, found[1].filename[2], true
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
        local filename = closest.filename[1]
        if lfsisfile(filename) or kpselookup(filename) then
            report("log", 0, "resolve",
                "font family='%s', subfamily='%s' found: %s",
                name, style, filename
            )
            return filename, closest.filename[2], true
        end
    elseif found.fallback then
        return found.fallback.filename[1],
               found.fallback.filename[2],
               true
    end

    --- no font found so far
    if not fonts_reloaded then
        --- last straw: try reloading the database
        return reload_db(
            "unresolved font name: “" .. name .. "”",
            resolve, nil, nil, specification
        )
    end

    --- else, fallback to requested name
    --- specification.name is empty with absolute paths, looks
    --- like a bug in the specification parser <TODO< is it still
    --- relevant? looks not...
    return specification.name, false, false
end --- resolve()

--- when reload is triggered we update the database
--- and then re-run the caller with the arg list

--- string -> ('a -> 'a) -> 'a list -> 'a
reload_db = function (why, caller, ...)
    report("log", 1, "db", "reload initiated; reason: “%s”", why)
    names.data = update_names()
    save_names(names.data)
    fonts_reloaded = true
    return caller(...)
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
        return reload_db("no database", find_closest, name)
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
font_fullinfo = function (filename, subfont)
    local tfmdata = { }
    local rawfont = fontloader.open(filename, subfont)
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
    tfmdata.fontname    = metadata.fontname
    tfmdata.fullname    = metadata.fullname
    tfmdata.familyname  = metadata.familyname
    tfmdata.filename    = { filename, subfont } -- always store full path
    tfmdata.weight      = metadata.pfminfo.weight
    tfmdata.width       = metadata.pfminfo.width
    tfmdata.slant       = metadata.italicangle
    -- don't waste the space with zero values
    tfmdata.size = {
        metadata.design_size         ~= 0 and metadata.design_size         or nil,
        metadata.design_range_top    ~= 0 and metadata.design_range_top    or nil,
        metadata.design_range_bottom ~= 0 and metadata.design_range_bottom or nil,
    }
    return tfmdata
end

--- we return true if the fond is new or re-indexed
--- string -> dbobj -> dbobj -> bool -> bool
local load_font = function (fullname, fontnames, newfontnames)
    local newmappings   = newfontnames.mappings
    local newstatus     = newfontnames.status

--  local newfullnames  = newfontnames.fullnames
    local newbasenames  = newfontnames.basenames
    local newbarenames  = newfontnames.barenames

    local mappings      = fontnames.mappings
    local status        = fontnames.status
--  local fullnames     = fontnames.fullnames
    local basenames     = fontnames.basenames
    local barenames     = fontnames.barenames

    local basename      = filebasename(fullname)
    local barename      = filenameonly(fullname)

    local entryname     = basename

    if not fullname then return false end

    if names.blacklist[fullname]
    or names.blacklist[basename]
    then
        report("log", 2, "db",
            "ignoring blacklisted font “%s”", fullname)
        return false
    end
    local timestamp, db_timestamp
    db_timestamp        = status[entryname]
                        and status[entryname].timestamp
    timestamp           = lfs.attributes(fullname, "modification")

    local index_status = newstatus[entryname] or newstatus[basename]
    local teststat = newstatus[entryname]
    --- index_status: nil | false | table
    if index_status and index_status.timestamp == timestamp then
        -- already indexed this run
        return false
    end

    newstatus[entryname]           = newstatus[entryname] or { }
    newstatus[entryname].timestamp = timestamp
    newstatus[entryname].index     = newstatus[entryname].index or { }

    if  db_timestamp == timestamp
    and not newstatus[entryname].index[1] then
        for _,v in next, status[entryname].index do
            local index      = #newstatus[entryname].index
            local fullinfo   = mappings[v]
            local location   = #newmappings + 1
            newmappings[location]               = fullinfo --- keep
            newstatus[entryname].index[index+1] = location --- is this actually used anywhere?
--          newfullnames[fullname]              = location
            newbasenames[basename]              = location
            newbarenames[barename]              = location
        end
        report("log", 2, "db", "font “%s” already indexed", entryname)
        return false
    end

    local info = fontloaderinfo(fullname)
    if info then
        if type(info) == "table" and #info > 1 then --- ttc
            for n_font = 1, #info do
                local fullinfo = font_fullinfo(fullname, n_font-1)
                if not fullinfo then
                    return false
                end
                local location = #newmappings+1
                local index    = newstatus[entryname].index[n_font]
                if not index then index = location end

                newmappings[index]                  = fullinfo
--              newfullnames[fullname]              = location
                newbasenames[basename]              = location
                newbarenames[barename]              = location
                newstatus[entryname].index[n_font]  = index
            end
        else
            local fullinfo = font_fullinfo(fullname, false)
            if not fullinfo then
                return false
            end
            local location  = #newmappings+1
            local index     = newstatus[entryname].index[1]
            if not index then index = location end

            newmappings[index]            = fullinfo
--          newfullnames[fullname]        = location
            newbasenames[basename]        = location
            newbarenames[barename]        = location
            newstatus[entryname].index[1] = index
        end

    else --- missing info
        report("log", 1, "db", "failed to load “%s”", entryname)
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
            path = stringgsub(path, '^/cygdrive/(%a)/', '%1:/')
            path = filecollapsepath(path)
            return path
        end

    elseif os_name == "cygwin" then -- union of ms + unix
        path_normalize = function (path)
            path = stringgsub(path, '\\', '/')
            path = stringlower(path)
            path = stringgsub(path, '^/cygdrive/(%a)/', '%1:/')
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

--- string -> dbobj -> dbobj -> bool -> (int * int)
local scan_dir = function (dirname, fontnames, newfontnames)
    --[[
    This function scans a directory and populates the list of fonts
    with all the fonts it finds.
    - dirname is the name of the directory to scan
    - names is the font database to fill -> no such term!!!
    - texmf used to be a boolean saying if we are scanning a texmf directory
    ]]
    local n_scanned, n_new = 0, 0   --- total of fonts collected
    report("log", 2, "db", "scanning", "%s", dirname)
    for _,i in next, font_extensions do
        for _,ext in next, { i, stringupper(i) } do
            local found = dirglob(stringformat("%s/**.%s$", dirname, ext))
            local n_found = #found
            --- note that glob fails silently on broken symlinks, which
            --- happens sometimes in TeX Live.
            report("log", 2, "db", "%s '%s' fonts found", n_found, ext)
            n_scanned = n_scanned + n_found
            for j=1, n_found do
                local fullname = found[j]
                fullname = path_normalize(fullname)
                report("log", 2, "db", "loading font “%s”", fullname)
                local new = load_font(fullname, fontnames, newfontnames)
                if new then n_new = n_new + 1 end
            end
        end
    end
    report("log", 2, "db", "%d fonts found in '%s'", n_scanned, dirname)
    return n_scanned, n_new
end

local function scan_texmf_fonts(fontnames, newfontnames)
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
            local found, new = scan_dir(d, fontnames, newfontnames, true)
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
local function get_os_dirs()
    if os.name == 'macosx' then
        return {
            filejoin(kpseexpand_path('~'), "Library/Fonts"),
            "/Library/Fonts",
            "/System/Library/Fonts",
            "/Network/Library/Fonts",
        }
    elseif os.type == "windows" or os.type == "msdos" or os.name == "cygwin" then
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

local function scan_os_fonts(fontnames, newfontnames)
    local n_scanned, n_new = 0, 0
    --[[
    This function scans the OS fonts through
      - fontcache for Unix (reads the fonts.conf file and scans the
        directories)
      - a static set of directories for Windows and MacOSX
    ]]
    report("info", 2, "db", "Scanning OS fonts...")
    report("info", 3, "db", "Searching in static system directories...")
    print"~~~~"
    for _,d in next, get_os_dirs() do
        local found, new = scan_dir(d, fontnames, newfontnames)
        n_scanned = n_scanned + found
        n_new     = n_new     + new
    end
    return n_scanned, n_new
end

flush_cache = function ()
    if not names.data then names.data = load_names() end
    names.data.request_cache = { }
    collectgarbage"collect"
    return true, names.data
end

--- dbobj -> bool -> dbobj
update_names = function (fontnames, force)
    local starttime = os.gettimeofday()
    local n_scanned, n_new = 0, 0
    --[[
    The main function, scans everything
    - “newfontnames” is the final table to return
    - force is whether we rebuild it from scratch or not
    ]]
    report("info", 2, "db", "Updating the font names database"
                         .. (force and " forcefully" or ""))

    if force then
        fontnames = fontnames_init(false)
    else
        if not fontnames then
            fontnames = load_names()
        end
        if fontnames.version ~= names.version then
            fontnames = fontnames_init(true)
            report("log", 1, "db", "No font names database or old "
                                .. "one found; generating new one")
        end
    end
    local newfontnames = fontnames_init(true)
    read_blacklist()

    local scanned, new
    scanned, new = scan_texmf_fonts(fontnames, newfontnames)
    n_scanned = n_scanned + scanned
    n_new     = n_new     + new

    scanned, new = scan_os_fonts(fontnames, newfontnames)
    n_scanned = n_scanned + scanned
    n_new     = n_new     + new

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

--- dbobj -> unit
save_names = function (fontnames)
    if not fontnames then fontnames = names.data end
    local path  = names.path.dir
    if not lfs.isdir(path) then
        dirmkdirs(path)
    end
    if fileiswritable(path) then
        local luaname, lucname = make_name(names.path.path)
        if luaname then
            --tabletofile(luaname, fontnames, true, { reduce=true })
            tabletofile(luaname, fontnames, true)
            if lucname and type(caches.compile) == "function" then
                os.remove(lucname)
                caches.compile(fontnames, luaname, lucname)
                report("info", 0, "db", "Font names database saved")
                return names.path.path
            end
        end
    end
    report("info", 0, "db", "Failed to save names database")
    return nil
end

scan_external_dir = function (dir)
    local old_names, new_names
    if fonts_loaded then
        old_names = names.data
    else
        old_names = load_names()
    end
    new_names = tablecopy(old_names)
    local n_scanned, n_new = scan_dir(dir, old_names, new_names)
    names.data = new_names
    return n_scanned, n_new
end

--- export functionality to the namespace “fonts.names”
names.flush_cache                 = flush_cache
names.load                        = load_names
names.save                        = save_names
names.scan                        = scan_external_dir
names.update                      = update_names
names.crude_file_lookup           = crude_file_lookup
names.crude_file_lookup_verbose   = crude_file_lookup_verbose

--- replace the resolver from luatex-fonts
if config.luaotfload.resolver == "cached" then
    report("info", 0, "cache", "caching of name: lookups active")
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
