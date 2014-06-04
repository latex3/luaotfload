if not modules then modules = { } end modules ['luaotfload-database'] = {
    version   = "2.5",
    comment   = "companion to luaotfload-main.lua",
    author    = "Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2.0"
}

--[[doc--

    Some statistics:

        a) TL 2012,     mkluatexfontdb --force
        b) v2.4,        luaotfload-tool --update --force
        c) v2.4,        luaotfload-tool --update --force --formats=+afm,pfa,pfb
        d) Context,     mtxrun --script fonts --reload --force

    (Keep in mind that Context does index fewer fonts since it
    considers only the contents of the minimals tree, not the
    tex live one!)

                time (m:s)       peak VmSize (kB)
            a     1:19              386 018
            b     0:37              715 797
            c     2:27            1 017 674
            d     0:44            1 082 313

    Most of the increase in memory consumption from version 1.x to 2.2+
    can be attributed to the move from single-pass to a multi-pass
    approach to building the index: Information is first gathered from
    all reachable fonts and only afterwards processed, classified and
    discarded.  Also, there is a good deal of additional stuff kept in
    the database now: two extra tables for file names and font families
    have been added, making font lookups more efficient while improving
    maintainability of the code.

--doc]]--

local lpeg                     = require "lpeg"
local P, Cc, lpegmatch         = lpeg.P, lpeg.Cc, lpeg.match

local parsers                  = luaotfload.parsers
local read_fonts_conf          = parsers.read_fonts_conf
local stripslashes             = parsers.stripslashes
local splitcomma               = parsers.splitcomma

local log                      = luaotfload.log
local report                   = log.report
local report_status            = log.names_status
local report_status_start      = log.names_status_start
local report_status_stop       = log.names_status_stop


--- Luatex builtins
local load                     = load
local next                     = next
local require                  = require
local tonumber                 = tonumber
local unpack                   = table.unpack

local fontloaderinfo           = fontloader.info
local fontloaderclose          = fontloader.close
local fontloaderopen           = fontloader.open
----- fontloaderto_table       = fontloader.to_table
local gzipopen                 = gzip.open
local iolines                  = io.lines
local ioopen                   = io.open
local iopopen                  = io.popen
local kpseexpand_path          = kpse.expand_path
local kpsefind_file            = kpse.find_file
local kpselookup               = kpse.lookup
local kpsereadable_file        = kpse.readable_file
local lfsattributes            = lfs.attributes
local lfschdir                 = lfs.chdir
local lfscurrentdir            = lfs.currentdir
local lfsdir                   = lfs.dir
local mathabs                  = math.abs
local mathmin                  = math.min
local osgetenv                 = os.getenv
local osgettimeofday           = os.gettimeofday
local osremove                 = os.remove
local stringfind               = string.find
local stringformat             = string.format
local stringgmatch             = string.gmatch
local stringgsub               = string.gsub
local stringlower              = string.lower
local stringsub                = string.sub
local stringupper              = string.upper
local tableconcat              = table.concat
local tablesort                = table.sort
local utf8gsub                 = unicode.utf8.gsub
local utf8lower                = unicode.utf8.lower
local utf8len                  = unicode.utf8.len
local zlibcompress             = zlib.compress

--- these come from Lualibs/Context
local filebasename             = file.basename
local filecollapsepath         = file.collapsepath or file.collapse_path
local filedirname              = file.dirname
local fileextname              = file.extname
local fileiswritable           = file.iswritable
local filejoin                 = file.join
local filenameonly             = file.nameonly
local filereplacesuffix        = file.replacesuffix
local filesplitpath            = file.splitpath or file.split_path
local filesuffix               = file.suffix
local getwritablepath          = caches.getwritablepath
local lfsisdir                 = lfs.isdir
local lfsisfile                = lfs.isfile
local lfsmkdirs                = lfs.mkdirs
local lpegsplitat              = lpeg.splitat
local stringis_empty           = string.is_empty
local stringsplit              = string.split
local stringstrip              = string.strip
local tableappend              = table.append
local tablecontains            = table.contains
local tablecopy                = table.copy
local tablefastcopy            = table.fastcopy
local tabletofile              = table.tofile
local tabletohash              = table.tohash
local tableserialize           = table.serialize
--- the font loader namespace is “fonts”, same as in Context
--- we need to put some fallbacks into place for when running
--- as a script
fonts                          = fonts          or { }
fonts.names                    = fonts.names    or { }
fonts.definers                 = fonts.definers or { }

local names                    = fonts.names
local name_index               = nil --> upvalue for names.data
local lookup_cache             = nil --> for names.lookups
names.version                  = 2.51
names.data                     = nil      --- contains the loaded database
names.lookups                  = nil      --- contains the lookup cache

--- string -> (string * string)
local make_luanames = function (path)
    return filereplacesuffix(path, "lua"),
           filereplacesuffix(path, "luc")
end

local format_precedence = {
    "otf",   "ttc", "ttf",
    "dfont", "afm", "pfb",
    "pfa",
}

local location_precedence = {
    "local", "system", "texmf",
}

local set_location_precedence = function (precedence)
    location_precedence = precedence
end

--[[doc--

    Auxiliary functions

--doc]]--

--- fontnames contain all kinds of garbage; as a precaution we
--- lowercase and strip them of non alphanumerical characters

--- string -> string

local invalidchars = "[^%a%d]"

local sanitize_fontname = function (str)
    if str ~= nil then
        str = utf8gsub (utf8lower (str), invalidchars, "")
        return str
    end
    return nil
end

local sanitize_fontnames = function (rawnames)
    local result = { }
    for category, namedata in next, rawnames do

        if type (namedata) == "string" then
            result [category] = utf8gsub (utf8lower (namedata),
                                          invalidchars,
                                          "")
        else
            local target = { }
            for field, name in next, namedata do
                target [field] = utf8gsub (utf8lower (name),
                                        invalidchars,
                                        "")
            end
            result [category] = target
        end
    end
    return result
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
        files       : filemap;
        status      : filestatus;
        mappings    : fontentry list;
        meta        : metadata;
    }
    and familytable = {
        local  : (format, familyentry) hash; // specified with include dir
        texmf  : (format, familyentry) hash;
        system : (format, familyentry) hash;
    }
    and familyentry = {
        r  : sizes; // regular
        i  : sizes; // italic
        b  : sizes; // bold
        bi : sizes; // bold italic
    }
    and sizes = {
        default : int;              // points into mappings or names
        optical : (int, int) list;  // design size -> index entry
    }
    and metadata = {
        created     : string       // creation time
        formats     : string list; // { "otf", "ttf", "ttc", "dfont" }
        local       : bool;        (* set if local fonts were added to the db *)
        modified    : string       // modification time
        statistics  : TODO;        // created when built with "--stats"
        version     : float;       // index version
    }
    and filemap = { // created by generate_filedata()
        base : {
            local  : (string, int) hash; // basename -> idx
            system : (string, int) hash;
            texmf  : (string, int) hash;
        };
        bare : {
            local  : (string, (string, int) hash) hash; // location -> (barename -> idx)
            system : (string, (string, int) hash) hash;
            texmf  : (string, (string, int) hash) hash;
        };
        full : (int, string) hash; // idx -> full path
    }
    and fontentry = { // finalized by collect_families()
        basename        : string;   // file name without path "foo.otf"
        conflicts       : { barename : int; basename : int }; // filename conflict with font at index; happens with subfonts
        familyname      : string;   // sanitized name of the font family the font belongs to, usually from the names table
        fontname        : string;   // sanitized name of the font
        fontstyle_name  : string;   // the fontstyle_name field returned by fontloader.info()
        format          : string;   // "otf" | "ttf" | "dfont" | "pfa" | "pfb" | "afm"
        fullname        : string;   // sanitized full name of the font including style modifiers
        fullpath        : string;   // path to font in filesystem
        index           : int;      // index in the mappings table
        italicangle     : float;    // italic angle; non-zero with oblique faces
        location        : string;   // "texmf" | "system" | "local"
        metafamily      : string;   // alternative family identifier if appropriate, sanitized
        plainname       : string;   // unsanitized font name
        prefmodifiers   : string;   // sanitized preferred subfamily (names table 14)
        psname          : string;   // PostScript name
        size            : (false | float * float * float);  // if available, size info from the size table converted from decipoints
        splainname      : string;   // sanitized version of the “plainname” field
        splitstyle      : string;   // style information obtained by splitting the full name at the last dash
        subfamily       : string;   // sanitized subfamily (names table 2)
        subfont         : (int | bool);     // integer if font is part of a TrueType collection ("ttc")
        version         : string;   // font version string
        weight          : int;      // usWeightClass
    }
    and filestatus = (string,       // fullname
                      { index       : int list; // pointer into mappings
                        timestamp   : int;      }) dict

beware that this is a reconstruction and may be incomplete or out of
date. Last update: 2014-04-06, describing version 2.51.

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

--- string list -> string option -> dbobj

local initialize_namedata = function (formats, created)
    local now = os.date "%F %T"
    return {
        --families        = { },
        status          = { }, -- was: status; map abspath -> mapping
        mappings        = { }, -- TODO: check if still necessary after rewrite
        names           = { },
--      files           = { }, -- created later
        meta            = {
            created    = created or now,
            formats    = formats,
            ["local"]  = false,
            modified   = now,
            statistics = { },
            version    = names.version,
        },
    }
end

--[[doc--

    Since Luaotfload does not depend on the lualibs anymore we
    have to put our own small wrappers for the gzip library in
    place.

    load_gzipped -- Read and decompress and entire gzipped file.
    Returns the uncompressed content as a string.

--doc]]--

local load_gzipped = function (filename)
    local gh = gzipopen (filename,"rb")
    if gh then
        local data = gh:read "*all"
        gh:close ()
        return data
    end
end

--[[doc--

    save_gzipped -- Compress and write a string to file. The return
    value is the number of bytes written. Zlib parameters are: best
    compression and default strategy.

--doc]]--

local save_gzipped = function (filename, data)
    local gh = gzipopen (filename, "wb9")
    if gh then
        gh:write (data)
        local bytes = gh:seek ()
        gh:close ()
        return bytes
    end
end

--- When loading a lua file we try its binary complement first, which
--- is assumed to be located at an identical path, carrying the suffix
--- .luc.

--- string -> (string * table)
local load_lua_file = function (path)
    local foundname = filereplacesuffix (path, "luc")
    local code      = nil

    local fh = ioopen (foundname, "rb") -- try bin first
    if fh then
        local chunk = fh:read"*all"
        fh:close()
        code = load (chunk, "b")
    end

    if not code then --- fall back to text file
        foundname = filereplacesuffix (path, "lua")
        fh = ioopen(foundname, "rb")
        if fh then
            local chunk = fh:read"*all"
            fh:close()
            code = load (chunk, "t")
        end
    end

    if not code then --- probe gzipped file
        foundname = filereplacesuffix (path, "lua.gz")
        local chunk = load_gzipped (foundname)
        if chunk then
            code = load (chunk, "t")
        end
    end

    if not code then return nil, nil end
    return foundname, code ()
end

--- define locals in scope
local access_font_index
local collect_families
local crude_file_lookup
local crude_file_lookup_verbose
local find_closest
local flush_lookup_cache
local generate_filedata
local get_font_filter
local group_modifiers
local load_lookups
local load_names
local getmetadata
local order_design_sizes
local ot_fullinfo
local read_blacklist
local reload_db
local resolve_cached
local resolve_fullpath
local resolve_name
local save_lookups
local save_names
local set_font_filter
local t1_fullinfo
local update_names

--- state of the database
local fonts_reloaded = false

--- limit output when approximate font matching (luaotfload-tool -F)
local fuzzy_limit = 1 --- display closest only

--- bool? -> dbobj
load_names = function (dry_run)
    local starttime = osgettimeofday ()
    local foundname, data = load_lua_file (config.luaotfload.paths.index_path_lua)

    if data then
        report ("log", 0, "db",
                "Font names database loaded from %s", foundname)
        report ("term", 3, "db",
                "Font names database loaded from %s", foundname)
        report ("info", 3, "db", "Loading took %0.f ms.",
                1000 * (osgettimeofday () - starttime))

        local db_version, names_version
        if data.meta then
            db_version = data.meta.version
        else
            --- Compatibility branch; the version info used to be
            --- stored in the table root which is why updating from
            --- an earlier index version broke.
            db_version = data.version or -42 --- invalid
        end
        names_version = names.version
        if db_version ~= names_version then
            report ("both", 0, "db",
                    [[Version mismatch; expected %4.3f, got %4.3f.]],
                    names_version, db_version)
            if not fonts_reloaded then
                report ("both", 0, "db", [[Force rebuild.]])
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
        data = update_names (initialize_namedata (get_font_filter ()),
                             nil, dry_run)
        if not data then
            report ("both", 0, "db", "Database creation unsuccessful.")
        end
    end
    return data
end

--[[doc--

    access_font_index -- Provide a reference of the index table. Will
    cause the index to be loaded if not present.

--doc]]--

access_font_index = function ()
    if not name_index then name_index = load_names () end
    return name_index
end

getmetadata = function ()
    if not name_index then name_index = load_names() end
    return tablefastcopy (name_index.meta)
end

--- unit -> unit
load_lookups = function ( )
    local foundname, data = load_lua_file(config.luaotfload.paths.lookup_path_lua)
    if data then
        report("log", 0, "cache", "Lookup cache loaded from %s.", foundname)
        report("term", 3, "cache",
               "Lookup cache loaded from %s.", foundname)
    else
        report("both", 1, "cache",
               "No lookup cache, creating empty.")
        data = { }
    end
    lookup_cache = data
end

local regular_synonym = {
    book    = "r",
    normal  = "r",
    plain   = "r",
    regular = "r",
    roman   = "r",
}

local italic_synonym = {
    oblique = true,
    slanted = true,
    italic  = true,
}

local style_category = {
    regular     = "r",
    bold        = "b",
    bolditalic  = "bi",
    italic      = "i",
    r           = "regular",
    b           = "bold",
    bi          = "bolditalic",
    i           = "italic",
}

local type1_metrics = { "tfm", "ofm", }

local dummy_findfile = resolvers.findfile -- from basics-gen

--- filemap -> string -> string -> (string | bool)
local verbose_lookup = function (data, kind, filename)
    local found = data[kind][filename]
    if found ~= nil then
        found = data.full[found]
        if found == nil then --> texmf
            report("info", 0, "db",
                "Crude file lookup: req=%s; hit=%s => kpse.",
                filename, kind)
            found = dummy_findfile(filename)
        else
            report("info", 0, "db",
                "Crude file lookup: req=%s; hit=%s; ret=%s.",
                filename, kind, found)
        end
        return found
    end
    return false
end

--- string -> (string * string * bool)
crude_file_lookup_verbose = function (filename)
    if not name_index then name_index = load_names() end
    local mappings  = name_index.mappings
    local files     = name_index.files
    local found

    --- look up in db first ...
    found = verbose_lookup(files, "bare", filename)
    if found then
        return found, nil, true
    end
    found = verbose_lookup(files, "base", filename)
    if found then
        return found, nil, true
    end

    --- ofm and tfm, returns pair
    for i=1, #type1_metrics do
        local format = type1_metrics[i]
        if resolvers.findfile(filename, format) then
            return file.addsuffix(filename, format), format, true
        end
    end

    if not fonts_reloaded and config.luaotfload.db.update_live == true then
        return reload_db (stringformat ("File not found: %s.", filename),
                          crude_file_lookup_verbose,
                          filename)
    end
    return filename, nil, false
end

local lookup_filename = function (filename)
    if not name_index then name_index = load_names () end
    local files    = name_index.files
    local basedata = files.base
    local baredata = files.bare
    for i = 1, #location_precedence do
        local location = location_precedence [i]
        local basenames = basedata [location]
        local barenames = baredata [location]
        local idx
        if basenames ~= nil then
            idx = basenames [filename]
            if idx then
                goto done
            end
        end
        if barenames ~= nil then
            for j = 1, #format_precedence do
                local format  = format_precedence [j]
                local filemap = barenames [format]
                if filemap then
                    idx = barenames [format] [filename]
                    if idx then
                        break
                    end
                end
            end
        end
::done::
        if idx then
            return files.full [idx]
        end
    end
end

--- string -> (string * string * bool)
crude_file_lookup = function (filename)
    local found = lookup_filename (filename)

    if not found then
        found = dummy_findfile(filename)
    end

    if found then
        return found, nil, true
    end

    for i=1, #type1_metrics do
        local format = type1_metrics[i]
        if resolvers.findfile(filename, format) then
            return file.addsuffix(filename, format), format, true
        end
    end

    if not fonts_reloaded and config.luaotfload.db.update_live == true then
        return reload_db (stringformat ("File not found: %s.", filename),
                          crude_file_lookup_verbose,
                          filename)
    end
    return filename, nil, false
end

--[[doc--
Existence of the resolved file name is verified differently depending
on whether the index entry has a texmf flag set.
--doc]]--

local get_font_file = function (index)
    local entry = name_index.mappings [index]
    if not entry then
        return false
    end
    local basename = entry.basename
    if entry.location == "texmf" then
        if kpselookup(basename) then
            return true, basename, entry.subfont
        end
    else --- system, local
        local fullname = name_index.files.full [index]
        if lfsisfile (fullname) then
            return true, basename, entry.subfont
        end
    end
    return false
end

--[[doc--
We need to verify if the result of a cached lookup actually exists in
the texmf or filesystem. Again, due to the schizoprenic nature of the
font managment we have to check both the system path and the texmf.
--doc]]--

local verify_font_file = function (basename)
    local path = resolve_fullpath (basename)
    if path and lfsisfile(path) then
        return true
    end
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

The spec is expected to be modified in place (ugh), so we’ll have to
catalogue what fields actually influence its behavior.

Idk what the “spec” resolver is for.

        lookup      inspects            modifies
        ----------  -----------------   ---------------------------
        file:       name                forced, name
        name:[*]    name, style, sub,   resolved, sub, name, forced
                    optsize, size
        spec:       name, sub           resolved, sub, name, forced

[*] name: contains both the name resolver from luatex-fonts and
    resolve_name() below

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
resolve_cached = function (specification)
    if not lookup_cache then load_lookups () end
    local request = hash_request(specification)
    report("both", 4, "cache", "Looking for %q in cache ...",
           request)

    local found = lookup_cache [request]

    --- case 1) cache positive ----------------------------------------
    if found then --- replay fields from cache hit
        report("info", 4, "cache", "Found!")
        local basename = found[1]
        --- check the presence of the file in case it’s been removed
        local success = verify_font_file (basename)
        if success == true then
            return basename, found[2], true
        end
        report("both", 4, "cache", "Cached file not found; resolving again.")
    else
        report("both", 4, "cache", "Not cached; resolving.")
    end

    --- case 2) cache negative ----------------------------------------
    --- first we resolve normally ...
    local filename, subfont = resolve_name (specification)
    if not filename then
        return nil, nil
    end
    --- ... then we add the fields to the cache ... ...
    local entry = { filename, subfont }
    report("both", 4, "cache", "New entry: %s.", request)
    lookup_cache [request] = entry

    --- obviously, the updated cache needs to be stored.
    --- TODO this should trigger a save only once the
    ---      document is compiled (finish_pdffile callback?)
    report("both", 5, "cache", "Saving updated cache.")
    local success = save_lookups ()
    if not success then --- sad, but not critical
        report("both", 0, "cache", "Error writing cache.")
    end
    return filename, subfont
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

local choose_closest = function (distances)
    local closest = 2^51
    local match
    for i = 1, #distances do
        local d, index = unpack (distances [i])
        if d < closest then
            closest = d
            match   = index
        end
    end
    return match
end

--[[doc--

    choose_size -- Pick a font face of appropriate size from the list
    of family members with matching style. There are three categories:

        1. exact matches: if there is a face whose design size equals
           the asked size, it is returned immediately and no further
           candidates are inspected.

        2. range matches: of all faces in whose design range the
           requested size falls the one whose center the requested
           size is closest to is returned.

        3. out-of-range matches: of all other faces (i. e. whose range
           is above or below the asked size) the one is chosen whose
           boundary (upper or lower) is closest to the requested size.

        4. default matches: if no design size or a design size of zero
           is requested, the face with the default size is returned.

--doc]]--

--- int * int * int * int list -> int -> int
local choose_size = function (sizes, askedsize)
    local mappings = name_index.mappings
    local match    = sizes.default
    local exact
    local inrange  = { } --- distance * index list
    local norange  = { } --- distance * index list
    local fontname, subfont
    if askedsize ~= 0 then
        --- firstly, look for an exactly matching design size or
        --- matching range
        for i = 1, #sizes do
            local dsnsize, high, low, index = unpack (sizes [i])
            if dsnsize == askedsize then
                --- exact match, this is what we were looking for
                exact = index
                goto skip
            elseif askedsize < low then
                --- below range, add to the norange table
                local d = low - askedsize
                norange [#norange + 1] = { d, index }
            elseif askedsize > high then
                --- beyond range, add to the norange table
                local d = askedsize - high
                norange [#norange + 1] = { d, index }
            else
                --- range match
                local d = ((low + high) / 2) - askedsize
                if d < 0 then
                    d = -d
                end
                inrange [#inrange + 1] = { d, index }
            end
        end
    end
::skip::
    if exact then
        match = exact
    elseif #inrange > 0 then
        match = choose_closest (inrange)
    elseif #norange > 0 then
        match = choose_closest (norange)
    end
    return match
end

--[[doc--

    resolve_familyname -- Query the families table for an entry
    matching the specification.
    The parameters “name” and “style” are pre-sanitized.

--doc]]--
--- spec -> string -> string -> int -> string * int
local resolve_familyname = function (specification, name, style, askedsize)
    local families   = name_index.families
    local mappings   = name_index.mappings
    local candidates = nil
    --- arrow code alert
    for i = 1, #location_precedence do
        local location = location_precedence [i]
        local locgroup = families [location]
        for j = 1, #format_precedence do
            local format       = format_precedence [j]
            local fmtgroup     = locgroup [format]
            if fmtgroup then
                local familygroup  = fmtgroup [name]
                if familygroup then
                    local stylegroup = familygroup [style]
                    if stylegroup then --- suitable match
                        candidates = stylegroup
                        goto done
                    end
                end
            end
        end
    end
    if true then
        return nil, nil
    end
::done::
    index = choose_size (candidates, askedsize)
    local success, resolved, subfont = get_font_file (index)
    if not success then
        return nil, nil
    end
    report ("info", 2, "db", "Match found: %s(%d).",
            resolved, subfont or 0)
    return resolved, subfont
end

local resolve_fontname = function (specification, name, style)
    local mappings    = name_index.mappings
    local fallback    = nil
    local lastresort  = nil
    style = style_category [style]
    for i = 1, #mappings do
        local face = mappings [i]
        local prefmodifiers = face.prefmodifiers
        local subfamily     = face.subfamily
        if     face.fontname   == name
            or face.splainname == name
            or face.fullname   == name
            or face.psname     == name
        then
            return face.basename, face.subfont
        elseif face.familyname == name then
            if prefmodifiers == style
                or subfamily == style
            then
                fallback = face
            elseif regular_synonym [prefmodifiers]
                or regular_synonym [subfamily]
            then
                lastresort = face
            end
        elseif face.metafamily == name
            and (regular_synonym [prefmodifiers]
                 or regular_synonym [subfamily])
        then
            lastresort = face
        end
    end
    if fallback then
        return fallback.basename, fallback.subfont
    end
    if lastresort then
        return lastresort.basename, lastresort.subfont
    end
    return nil, nil
end

--[[doc--

    resolve_name -- Perform a name: lookup. This first queries the
    font families table and, if there is no match for the spec, the
    font names table.
    The return value is a pair consisting of the file name and the
    subfont index if appropriate..

    the request specification has the fields:

      · features: table
        · normal: set of { ccmp clig itlc kern liga locl mark mkmk rlig }
        · ???
      · forced:   string
      · lookup:   "name"
      · method:   string
      · name:     string
      · resolved: string
      · size:     int
      · specification: string (== <lookup> ":" <name>)
      · sub:      string

    The “size” field deserves special attention: if its value is
    negative, then it actually specifies a scalefactor of the
    design size of the requested font. This happens e.g. if a font is
    requested without an explicit “at size”. If the font is part of a
    larger collection with different design sizes, this complicates
    matters a bit: Normally, the resolver prefers fonts that have a
    design size as close as possible to the requested size. If no
    size specified, then the design size is implied. But which design
    size should that be? Xetex appears to pick the “normal” (unmarked)
    size: with Adobe fonts this would be the one that is neither
    “caption” nor “subhead” nor “display” &c ... For fonts by Adobe this
    seems to be the one that does not receive a “prefmodifiers” field.
    (IOW Adobe uses the “prefmodifiers” field to encode the design size
    in more or less human readable format.) However, this is not true
    of LM and EB Garamond. As this matters only where there are
    multiple design sizes to a given font/style combination, we put a
    workaround in place that chooses that unmarked version.

    The first return value of “resolve_name” is the file name of the
    requested font (string). It can be passed to the fullname resolver
    get_font_file().
    The second value is either “false” or an integer indicating the
    subfont index in a TTC.

--doc]]--

--- table -> string * (int | bool)
resolve_name = function (specification)
    local resolved, subfont
    if not name_index then name_index = load_names () end
    local name      = sanitize_fontname (specification.name)
    local style     = sanitize_fontname (specification.style) or "r"
    local askedsize = specification.optsize

    if askedsize then
        askedsize = tonumber (askedsize)
    else
        askedsize = specification.size
        if askedsize and askedsize >= 0 then
            askedsize = askedsize / 65536
        else
            askedsize = 0
        end
    end

    resolved, subfont = resolve_familyname (specification,
                                            name,
                                            style,
                                            askedsize)
    if not resolved then
        resolved, subfont = resolve_fontname (specification,
                                              name,
                                              style)
    end

    if not resolved then
        if not fonts_reloaded and config.luaotfload.db.update_live == true then
            return reload_db (stringformat ("Font %s not found.",
                                            specification.name or "<?>"),
                              resolve_name,
                              specification)
        end
    end
    return resolved, subfont
end

resolve_fullpath = function (fontname, ext) --- getfilename()
    if not name_index then name_index = load_names () end
    local files = name_index.files
    local basedata = files.base
    local baredata = files.bare
    for i = 1, #location_precedence do
        local location = location_precedence [i]
        local basenames = basedata [location]
        local idx
        if basenames ~= nil then
            idx = basenames [fontname]
        end
        if ext then
            local barenames = baredata [location] [ext]
            if not idx and barenames ~= nil then
                idx = barenames [fontname]
            end
        end
        if idx then
            return files.full [idx]
        end
    end
    return ""
end

--- when reload is triggered we update the database
--- and then re-run the caller with the arg list

--- string -> ('a -> 'a) -> 'a list -> 'a
reload_db = function (why, caller, ...)
    local namedata  = name_index
    local formats   = tableconcat (namedata.meta.formats, ",")

    report ("both", 0, "db",
            "Reload initiated (formats: %s); reason: %q.",
            formats, why)

    set_font_filter (formats)
    namedata = update_names (namedata, false, false)

    if namedata then
        fonts_reloaded = true
        name_index = namedata
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
    local name     = sanitize_fontname (name)
    limit          = limit or fuzzy_limit

    if not name_index then name_index = load_names () end
    if not name_index or type (name_index) ~= "table" then
        if not fonts_reloaded then
            return reload_db("Font index missing.", find_closest, name)
        end
        return false
    end

    local by_distance   = { } --- (int, string list) dict
    local distances     = { } --- int list
    local cached        = { } --- (string, int) dict
    local mappings      = name_index.mappings
    local n_fonts       = #mappings

    for n = 1, n_fonts do
        local current    = mappings[n]
        --[[
            This is simplistic but surpisingly fast.
            Matching is performed against the “fullname” field
            of a db record in preprocessed form. We then store the
            raw “fullname” at its edit distance.
            We should probably do some weighting over all the
            font name categories as well as whatever agrep
            does.
        --]]
        local fullname  = current.plainname
        local sfullname = current.fullname
        local dist      = cached[sfullname]--- maybe already calculated

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

    --- print the matches according to their distance
    local n_distances = #distances
    if n_distances > 0 then --- got some data
        tablesort(distances)
        limit = mathmin(n_distances, limit)
        report(false, 1, "query",
               "Displaying %d distance levels.", limit)

        for i = 1, limit do
            local dist     = distances[i]
            local namelst  = by_distance[dist]
            report(false, 0, "query",
                   "Distance from \"%s\": %s\n    "
                   .. tableconcat (namelst, "\n    "),
                   name, dist)
        end

        return true
    end
    return false
end --- find_closest()

--[[doc--

    load_font_file -- Safely open a font file. See
    <http://www.ntg.nl/pipermail/ntg-context/2013/075885.html>
    regarding the omission of ``fontloader.close()``.

    TODO --   check if fontloader.info() is ready for prime in 0.78+
         --   fields /tables needed:
                    -- names
                    -- postscriptname
                    -- validation_state
                    -- ..

--doc]]--

local load_font_file = function (filename, subfont)
    local rawfont, _msg = fontloaderopen (filename, subfont)
    --local rawfont, _msg = fontloaderinfo (filename, subfont)
    if not rawfont then
        report ("log", 1, "db", "ERROR: failed to open %s.", filename)
        return
    end
    return rawfont
end

--- rawdata -> (int * int * int | bool)

local get_size_info = function (metadata)
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
        return {
            design_size, design_range_top, design_range_bottom,
        }
    end

    return false
end

local get_english_names = function (metadata)
    local names = metadata.names
    local english_names

    if names then
        --inspect(names)
        for _, raw_namedata in next, names do
            if raw_namedata.lang == "English (US)" then
                return raw_namedata.names
            end
        end
    end

    -- no (English) names table, probably a broken font
    report("both", 3, "db",
            "%s: missing or broken English names table.", basename)
    return { fontname = metadata.fontname,
             fullname = metadata.fullname, }
end

--[[--
    In case of broken PS names we set some dummies. However, we cannot
    directly modify the font data as returned by fontloader.open() because
    it is a userdata object.

    For this reason we copy what is necessary whilst keeping the table
    structure the same as in the tfmdata.
--]]--
local get_raw_info = function (metadata, basename)
    local fullname
    local fontname = metadata.fontname
    local fullname = metadata.fullname
    local psname

    local validation_state = metadata.validation_state
    if (validation_state and tablecontains (validation_state, "bad_ps_fontname"))
        or not fontname
    then
        --- Broken names table, e.g. avkv.ttf with UTF-16 strings;
        --- we put some dummies in place like the fontloader
        --- (font-otf.lua) does.
        report("both", 3, "db",
               "%s has invalid postscript font names, using dummies.",
               basename)
        fontname = "bad-fontname-" .. basename
        fullname = "bad-fullname-" .. basename
    end

    return {
        familyname          = metadata.familyname,
        fontname            = fontname,
        fontstyle_name      = metadata.fontstyle_name,
        fullname            = fullname,
        italicangle         = metadata.italicangle,
        names               = metadata.names,
        pfminfo             = metadata.pfminfo,
        units_per_em        = metadata.units_per_em,
        version             = metadata.version,
        design_size         = metadata.design_size,
        design_range_top    = metadata.design_range_top,
        design_range_bottom = metadata.design_range_bottom,
    }
end

local organize_namedata = function (rawinfo,
                                    english_names,
                                    basename,
                                    info)
    local default_name = english_names.compatfull
                      or english_names.fullname
                      or english_names.postscriptname
                      or rawinfo.fullname
                      or rawinfo.fontname
                      or info.fullname
                      or info.fontname
    local default_family = english_names.preffamily
                        or english_names.family
                        or rawinfo.familyname
                        or info.familyname
--    local default_modifier = english_names.prefmodifiers
--                          or english_names.subfamily
    local fontnames = {
        --- see
        --- https://developer.apple.com/fonts/TTRefMan/RM06/Chap6name.html
        --- http://www.microsoft.com/typography/OTSPEC/name.htm#NameIDs
        english = {
            --- where a “compatfull” field is given, the value of “fullname” is
            --- either identical or differs by separating the style
            --- with a hyphen and omitting spaces. (According to the
            --- spec, “compatfull” is “Macintosh only”.)
            --- Of the three “fullname” fields, this one appears to be the one
            --- with the entire name given in a legible,
            --- non-abbreviated fashion, for most fonts at any rate.
            --- However, in some fonts (e.g. CMU) all three fields are
            --- identical.
            fullname      = --[[ 18 ]] english_names.compatfull
                         or --[[  4 ]] english_names.fullname
                         or default_name,
            --- we keep both the “preferred family” and the “family”
            --- values around since both are valid but can turn out
            --- quite differently, e.g. with Latin Modern:
            ---     preffamily: “Latin Modern Sans”,
            ---     family:     “LM Sans 10”
            preffamily    = --[[ 16 ]] english_names.preffamilyname,
            family        = --[[  1 ]] english_names.family or default_family,
            prefmodifiers = --[[ 17 ]] english_names.prefmodifiers,
            subfamily     = --[[  2 ]] english_names.subfamily,
            psname        = --[[  6 ]] english_names.postscriptname,
        },

        metadata = {
            fullname      = rawinfo.fullname,
            fontname      = rawinfo.fontname,
            familyname    = rawinfo.familyname,
        },

        info = {
            fullname      = info.fullname,
            familyname    = info.familyname,
            fontname      = info.fontname,
        },
    }

    -- see http://www.microsoft.com/typography/OTSPEC/features_pt.htm#size
    if rawinfo.fontstyle_name then
        --- not present in all fonts, often differs from the preferred
        --- subfamily as well as subfamily fields, e.g. with
        --- LMSans10-BoldOblique:
        ---     subfamily:      “Bold Italic”
        ---     prefmodifiers:  “10 Bold Oblique”
        ---     fontstyle_name: “Bold Oblique”
        for _, name in next, rawinfo.fontstyle_name do
            if name.lang == 1033 then --- I hate magic numbers
                fontnames.fontstyle_name = name.name
            end
        end
    end

    return {
        sanitized     = sanitize_fontnames (fontnames),
        fontname      = rawinfo.fontname,
        fullname      = rawinfo.fullname,
        familyname    = rawinfo.familyname,
    }
end


local dashsplitter = lpegsplitat "-"

local split_fontname = function (fontname)
    --- sometimes the style hides in the latter part of the
    --- fontname, separated by a dash, e.g. “Iwona-Regular”,
    --- “GFSSolomos-Regular”
    local splitted = { lpegmatch (dashsplitter, fontname) }
    if next (splitted) then
        return sanitize_fontname (splitted [#splitted])
    end
end

local organize_styledata = function (fontname,
                                     metadata,
                                     english_names,
                                     info)
    local pfminfo   = metadata.pfminfo or { }
    local names     = metadata.names

    return {
    --- see http://www.microsoft.com/typography/OTSPEC/features_pt.htm#size
        size            = get_size_info (metadata),
        weight          = pfminfo.weight or 400,
        split           = split_fontname (fontname),
        width           = pfminfo.width,
        italicangle     = metadata.italicangle,
    --- this is for querying, see www.ntg.nl/maps/40/07.pdf for details
        units_per_em    = metadata.units_per_em,
        version         = metadata.version,
    }
end

--[[doc--
The data inside an Opentype font file can be quite heterogeneous.
Thus in order to get the relevant information, parts of the original
table as returned by the font file reader need to be relocated.
--doc]]--

--- string -> int -> bool -> string -> fontentry

ot_fullinfo = function (filename,
                        subfont,
                        location,
                        basename,
                        format,
                        info)

    local metadata = load_font_file (filename, subfont)
    if not metadata then
        return nil
    end

    local rawinfo = get_raw_info (metadata, basename)
    --- Closing the file manually is a tad faster and more memory
    --- efficient than having it closed by the gc
    fontloaderclose (metadata)

    local english_names = get_english_names (rawinfo)
    local namedata      = organize_namedata (rawinfo,
                                             english_names,
                                             basename,
                                             info)
    local style         = organize_styledata (namedata.fontname,
                                              rawinfo,
                                              english_names,
                                              info)

    local res = {
        file            = { base        = basename,
                            full        = filename,
                            subfont     = subfont,
                            location    = location or "system" },
        format          = format,
        names           = namedata,
        style           = style,
        version         = rawinfo.version,
    }
    return res
end

--[[doc--

    Type1 font inspector. In comparison with OTF, PFB’s contain a good
    deal less name fields which makes it tricky in some parts to find a
    meaningful representation for the database.

    Good read: http://www.adobe.com/devnet/font/pdfs/5004.AFM_Spec.pdf

--doc]]--

--- string -> int -> bool -> string -> fontentry

t1_fullinfo = function (filename, _subfont, location, basename, format)
    local sanitized
    local metadata      = load_font_file (filename)
    local fontname      = metadata.fontname
    local fullname      = metadata.fullname
    local familyname    = metadata.familyname
    local italicangle   = metadata.italicangle
    local splitstyle    = split_fontname (fontname)
    local style         = ""
    local weight

    sanitized = sanitize_fontnames ({
        fontname        = fontname,
        psname          = fullname,
        pfullname       = fullname,
        metafamily      = family,
        familyname      = familyname,
        weight          = metadata.weight, --- string identifier
        prefmodifiers   = style,
    })

    weight = sanitized.weight

    if weight == "bold" then
        style = weight
    end

    if italicangle ~= 0 then
        style = style .. "italic"
    end

    return {
        basename         = basename,
        fullpath         = filename,
        subfont          = false,
        location         = location or "system",
        format           = format,
        fullname         = sanitized.fullname,
        fontname         = sanitized.fontname,
        familyname       = sanitized.familyname,
        plainname        = fullname,
        splainname       = sanitized.fullname,
        psname           = sanitized.fontname,
        version          = metadata.version,
        size             = false,
        splitstyle       = splitstyle,
        fontstyle_name   = style ~= "" and style or weight,
        weight           = metadata.pfminfo.weight or 400,
        italicangle      = italicangle,
    }
end

local loaders = {
    dfont   = ot_fullinfo,
    otf     = ot_fullinfo,
    ttc     = ot_fullinfo,
    ttf     = ot_fullinfo,

    pfb     = t1_fullinfo,
    pfa     = t1_fullinfo,
}

--- not side-effect free!

local compare_timestamps = function (fullname,
                                     currentstatus,
                                     currententrystatus,
                                     currentmappings,
                                     targetstatus,
                                     targetentrystatus,
                                     targetmappings)

    local currenttimestamp = currententrystatus
                         and currententrystatus.timestamp
    local targettimestamp  = lfsattributes (fullname, "modification")

    if targetentrystatus ~= nil
    and targetentrystatus.timestamp == targettimestamp then
        report ("log", 3, "db", "Font %q already read.", fullname)
        return false
    end

    targetentrystatus.timestamp = targettimestamp
    targetentrystatus.index     = targetentrystatus.index or { }

    if  currenttimestamp == targettimestamp
    and not targetentrystatus.index [1]
    then
        --- copy old namedata into new

        for _, currentindex in next, currententrystatus.index do

            local targetindex   = #targetentrystatus.index
            local fullinfo      = currentmappings [currentindex]
            local location      = #targetmappings + 1

            targetmappings [location]                 = fullinfo
            targetentrystatus.index [targetindex + 1] = location
        end

        report ("log", 3, "db", "Font %q already indexed.", fullname)

        return false
    end

    return true
end

local insert_fullinfo = function (fullname,
                                  basename,
                                  n_font,
                                  loader,
                                  format,
                                  location,
                                  targetmappings,
                                  targetentrystatus,
                                  info)

    local subfont
    if n_font ~= false then
        subfont = n_font - 1
    else
        subfont = false
        n_font  = 1
    end

    local fullinfo = loader (fullname, subfont,
                             location, basename,
                             format, info)

    if not fullinfo then
        return false
    end

    local index = targetentrystatus.index [n_font]

    if not index then
        index = #targetmappings + 1
    end

    targetmappings [index]            = fullinfo
    targetentrystatus.index [n_font]  = index

    return true
end



--- we return true if the font is new or re-indexed
--- string -> dbobj -> dbobj -> bool

local read_font_names = function (fullname,
                                  currentnames,
                                  targetnames,
                                  location)

    local targetmappings        = targetnames.mappings
    local targetstatus          = targetnames.status --- by full path
    local targetentrystatus     = targetstatus [fullname]

    if targetentrystatus == nil then
        targetentrystatus        = { }
        targetstatus [fullname]  = targetentrystatus
    end

    local currentmappings       = currentnames.mappings
    local currentstatus         = currentnames.status
    local currententrystatus    = currentstatus [fullname]

    local basename              = filebasename (fullname)
    local barename              = filenameonly (fullname)
    local entryname             = fullname

    if location == "texmf" then
        entryname = basename
    end

    --- 1) skip if blacklisted

    if names.blacklist[fullname] or names.blacklist[basename] then
        report("log", 2, "db",
               "Ignoring blacklisted font %q.", fullname)
        return false
    end

    --- 2) skip if known with same timestamp

    if not compare_timestamps (fullname,
                               currentstatus,
                               currententrystatus,
                               currentmappings,
                               targetstatus,
                               targetentrystatus,
                               targetmappings)
    then
        return false
    end

    --- 3) new font; choose a loader, abort if unknown

    local format    = stringlower (filesuffix (basename))
    local loader    = loaders [format] --- ot_fullinfo, t1_fullinfo

    if not loader then
        report ("both", 0, "db",
                "Unknown format: %q, skipping.", format)
        return false
    end

    --- 4) get basic info, abort if fontloader can’t read it

    local info = fontloaderinfo (fullname)

    if not info then
        report ("log", 1, "db",
                "Failed to read basic information from %q", basename)
        return false
    end


    --- 5) check for subfonts and process each of them

    if type (info) == "table" and #info > 1 then --- ttc

        local success = false --- true if at least one subfont got read

        for n_font = 1, #info do
            if insert_fullinfo (fullname, basename, n_font,
                                loader, format, location,
                                targetmappings, targetentrystatus,
                                info)
            then
                success = true
            end
        end

        return success
    end

    return insert_fullinfo (fullname, basename, false,
                            loader, format, location,
                            targetmappings, targetentrystatus,
                            info)
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

    report("info", 2, "db", "Blacklisting %d files and directories.",
           #blacklist)
    for i=1, #blacklist do
        local entry = blacklist[i]
        if lfsisdir(entry) then
            dirs[#dirs+1] = entry
        else
            result[blacklist[i]] = true
        end
    end

    report("info", 2, "db", "Whitelisting %d files.", #whitelist)
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
        for _, path in next, files do
            for line in iolines (path) do
                line = stringstrip(line) -- to get rid of lines like " % foo"
                local first_chr = stringsub(line, 1, 1)
                if first_chr == "%" or stringis_empty(line) then
                    -- comment or empty line
                elseif first_chr == "-" then
                    report ("both", 3, "db",
                            "Whitelisted file %q via %q.",
                            line, path)
                    whitelist[#whitelist+1] = stringsub(line, 2, -1)
                else
                    local cmt = stringfind(line, "%%")
                    if cmt then
                        line = stringsub(line, 1, cmt - 1)
                    end
                    line = stringstrip(line)
                    report ("both", 3, "db",
                            "Blacklisted file %q via %q.",
                            line, path)
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

--- truncate_string -- Cut the first part of a string to fit it
--- into a given terminal width. The parameter “restrict” (int)
--- indicates the number of characters already consumed on the
--- line.
local truncate_string = function (str, restrict)
    local tw  = config.luaotfload.misc.termwidth
    local wd  = tw - restrict
    local len = utf8len (str)
    if wd - len < 0 then
        --- combined length exceeds terminal,
        str = ".." .. stringsub(str, len - wd + 2)
    end
    return str
end


--[[doc--

    collect_font_filenames_dir -- Traverse the directory root at
    ``dirname`` looking for font files. Returns a list of {*filename*;
    *location*} pairs.

--doc]]--

--- string -> string -> string * string list
local collect_font_filenames_dir = function (dirname, location)
    if lpegmatch (p_blacklist, dirname) then
        report ("both", 4, "db",
                "Skipping blacklisted directory %s.", dirname)
        --- ignore
        return { }
    end
    local found = find_font_files (dirname, location ~= "texmf" and location ~= "local")
    if not found then
        report ("both", 4, "db",
                "No such directory: %q; skipping.", dirname)
        return { }
    end

    local nfound = #found
    local files  = { }

    report ("both", 4, "db",
            "%d font files detected in %s.",
            nfound, dirname)
    for j = 1, nfound do
        local fullname = found[j]
        files[#files + 1] = { path_normalize (fullname), location }
    end
    return files
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

    collect_font_filenames_texmf -- Scan texmf tree for font files
    relying on the kpathsea variables $OPENTYPEFONTS and $TTFONTS of
    texmf.cnf.
    The current working directory comes as “.” (texlive) or absolute
    path (miktex) and will always be filtered out.

    Returns a list of { *filename*; *location* } pairs.

--doc]]--

--- unit -> string * string list
local collect_font_filenames_texmf = function ()

    local osfontdir = kpseexpand_path "$OSFONTDIR"

    if stringis_empty (osfontdir) then
        report ("info", 1, "db", "Scanning TEXMF for fonts...")
    else
        report ("info", 1, "db", "Scanning TEXMF and $OSFONTDIR for fonts...")
        if log.get_loglevel () > 3 then
            local osdirs = filesplitpath (osfontdir)
            report ("info", 0, "db", "$OSFONTDIR has %d entries:", #osdirs)
            for i = 1, #osdirs do
                report ("info", 0, "db", "[%d] %s", i, osdirs[i])
            end
        end
    end

    fontdirs = kpseexpand_path "$OPENTYPEFONTS"
    fontdirs = fontdirs .. path_separator .. kpseexpand_path "$TTFONTS"
    fontdirs = fontdirs .. path_separator .. kpseexpand_path "$T1FONTS"

    if stringis_empty (fontdirs) then
        return { }
    end

    local tasks = filter_out_pwd (filesplitpath (fontdirs))
    report ("info", 3, "db",
            "Initiating scan of %d directories.", #tasks)

    local files = { }
    for _, dir in next, tasks do
        files = tableappend (files, collect_font_filenames_dir (dir, "texmf"))
    end
    report ("term", 3, "db", "Collected %d files.", #files)
    return files
end

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
        local windir = osgetenv("WINDIR")
        return { filejoin(windir, 'Fonts') }
    else
        local fonts_conves = { --- plural, much?
            "/usr/local/etc/fonts/fonts.conf",
            "/etc/fonts/fonts.conf",
        }
        local os_dirs = read_fonts_conf(fonts_conves, find_files)
        return os_dirs
    end
    return {}
end

--[[doc--

    retrieve_namedata -- Scan the list of collected fonts and populate
    the list of namedata.

        · dirname       : name of the directory to scan
        · currentnames  : current font db object
        · targetnames   : font db object to fill
        · dry_run       : don’t touch anything

    Returns the number of fonts that were actually added to the index.

--doc]]--

--- string * string list -> dbobj -> dbobj -> bool? -> int
local retrieve_namedata = function (files, currentnames, targetnames, dry_run)

    local nfiles    = #files
    local nnew      = 0

    report ("info", 1, "db", "Scanning %d collected font files ...", nfiles)

    local bylocation = { texmf     = { 0, 0 }
                       , ["local"] = { 0, 0 }
                       , system    = { 0, 0 }
                       }
    report_status_start (2, 4)
    for i = 1, nfiles do
        local fullname, location   = unpack (files[i])
        local count                = bylocation[location]
        count[1]                   = count[1] + 1
        if dry_run == true then
            local truncated = truncate_string (fullname, 43)
            report ("log", 2, "db", "Would have been loading %s.", fullname)
            report_status ("term", "db", "Would have been loading %s", truncated)
            --- skip the read_font_names part
        else
            local truncated = truncate_string (fullname, 32)
            report ("log", 2, "db", "Loading font %s.", fullname)
            report_status ("term", "db", "Loading font %s", truncated)
            local new = read_font_names (fullname, currentnames,
                                         targetnames, location)
            if new == true then
                nnew     = nnew + 1
                count[2] = count[2] + 1
            end
        end
    end
    report_status_stop ("term", "db", "Scanned %d files, %d new.", nfiles, nnew)
    for location, count in next, bylocation do
        report ("term", 4, "db", "   * %s: %d files, %d new",
                location, count[1], count[2])
    end
    return nnew
end

--- unit -> string * string list
local collect_font_filenames_system = function ()

    local n_scanned, n_new = 0, 0
    report ("info", 1, "db", "Scanning system fonts...")
    report ("info", 2, "db",
            "Searching in static system directories...")

    local files = { }
    for _, dir in next, get_os_dirs () do
        tableappend (files, collect_font_filenames_dir (dir, "system"))
    end
    report ("term", 3, "db", "Collected %d files.", #files)
    return files
end

--- unit -> bool
flush_lookup_cache = function ()
    lookup_cache = { }
    collectgarbage "collect"
    return true
end

--[[doc--

    collect_font_filenames_local -- Scan $PWD (during a TeX run)
    for font files.

    Side effect: This sets the “local” flag in the subtable “meta” to
    prevent the merged table from being saved to disk.

    TODO the local tree could be cached in $PWD.

--doc]]--

--- unit -> string * string list
local collect_font_filenames_local = function ()
    local pwd = lfscurrentdir ()
    report ("both", 1, "db", "Scanning for fonts in $PWD (%q) ...", pwd)

    local files  = collect_font_filenames_dir (pwd, "local")
    local nfiles = #files
    if nfiles > 0 then
        targetnames.meta["local"] = true --- prevent saving to disk
        report ("term", 1, "db", "Found %d files.", pwd)
    else
        report ("term", 1, "db",
                "Couldn’t find a thing here. What a waste.", pwd)
    end
    report ("term", 3, "db", "Collected %d files.", #files)
    return files
end

--- dbobj -> dbobj -> int * int

--- fontentry list -> filemap

generate_filedata = function (mappings)

    report ("both", 2, "db", "Creating filename map.")

    local nmappings  = #mappings

    local files  = {
        bare = {
            ["local"]   = { },
            system      = { }, --- mapped to mapping format -> index in full
            texmf       = { }, --- mapped to mapping format -> “true”
        },
        base = {
            ["local"]   = { },
            system      = { }, --- mapped to index in “full”
            texmf       = { }, --- set; all values are “true”
        },
        full = { }, --- non-texmf
    }

    local base = files.base
    local bare = files.bare
    local full = files.full

    local conflicts = {
        basenames = 0,
        barenames = 0,
    }

    for index = 1, nmappings do
        local entry    = mappings [index]

        local filedata = entry.file
        local format
        local location
        local fullpath
        local basename
        local barename
        local subfont

        if filedata then --- new entry
            format   = entry.format   --- otf, afm, ...
            location = filedata.location --- texmf, system, ...
            fullpath = filedata.full
            basename = filedata.base
            barename = filenameonly (fullpath)
            subfont  = filedata.subfont
        else
            format   = entry.format   --- otf, afm, ...
            location = entry.location --- texmf, system, ...
            fullpath = entry.fullpath
            basename = entry.basename
            barename = filenameonly (fullpath)
            subfont  = entry.subfont
        end

        entry.index    = index

        --- 1) add to basename table

        local inbase = base [location] --- no format since the suffix is known

        if inbase then
            local present = inbase [basename]
            if present then
                report ("both", 4, "db",
                        "Conflicting basename: %q already indexed \z
                         in category %s, ignoring.",
                        barename, location)
                conflicts.basenames = conflicts.basenames + 1

                --- track conflicts per font
                local conflictdata = entry.conflicts

                if not conflictdata then
                    entry.conflicts = { basename = present }
                else -- some conflicts already detected
                    conflictdata.basename = present
                end

            else
                inbase [basename] = index
            end
        else
            inbase = { basename = index }
            base [location] = inbase
        end

        --- 2) add to barename table

        local inbare = bare [location] [format]

        if inbare then
            local present = inbare [barename]
            if present then
                report ("both", 4, "db",
                        "Conflicting barename: %q already indexed \z
                         in category %s/%s, ignoring.",
                        barename, location, format)
                conflicts.barenames = conflicts.barenames + 1

                --- track conflicts per font
                local conflictdata = entry.conflicts

                if not conflictdata then
                    entry.conflicts = { barename = present }
                else -- some conflicts already detected
                    conflictdata.barename = present
                end

            else
                inbare [barename] = index
            end
        else
            inbare = { [barename] = index }
            bare [location] [format] = inbare
        end

        --- 3) add to fullpath map

        full [index] = fullpath
    end

    return files
end

local pick_style
local check_regular

do
    local splitfontname = lpeg.splitat "-"

    local choose_exact = function (field)
        --- only clean matches, without guessing
        if italic_synonym [field] then
            return "i"
        end

        if field == "bold" then
            return "b"
        end

        if field == "bolditalic" or field == "boldoblique" then
            return "bi"
        end

        return false
    end

    pick_style = function (fontstyle_name,
                           prefmodifiers,
                           subfamily,
                           splitstyle)
        local style
        if fontstyle_name then
            style = choose_exact (fontstyle_name)
        end
        if not style then
            if prefmodifiers then
                style = choose_exact (prefmodifiers)
            elseif subfamily then
                style = choose_exact (subfamily)
            end
        end
        return style
    end

    pick_fallback_style = function (italicangle, weight)
        --- more aggressive, but only to determine bold faces
        if weight > 500 then --- bold spectrum matches
            if italicangle == 0 then
                return tostring (weight)
            else
                return tostring (weight) .. "i"
            end
        end
        return false
    end

    --- we use only exact matches here since there are constructs
    --- like “regularitalic” (Cabin, Bodoni Old Fashion)

    check_regular = function (fontstyle_name,
                              prefmodifiers,
                              subfamily,
                              splitstyle,
                              italicangle,
                              weight)

        if fontstyle_name then
            return regular_synonym [fontstyle_name]
        elseif prefmodifiers then
            return regular_synonym [prefmodifiers]
        elseif subfamily then
            return regular_synonym [subfamily]
        elseif splitstyle then
            return regular_synonym [splitstyle]
        elseif italicangle == 0 and weight == 400 then
            return true
        end

        return nil
    end
end

local pull_values = function (entry)
    local file              = entry.file
    local names             = entry.names
    local style             = entry.style
    local sanitized         = names.sanitized
    local english           = sanitized.english
    local info              = sanitized.info
    local metadata          = sanitized.metadata

    --- pull file info ...
    entry.basename          = file.base
    entry.fullpath          = file.full
    entry.location          = file.location
    entry.subfont           = file.subfont

    --- pull name info ...
    entry.psname            = english.psname
    entry.fontname          = info.fontname or metadata.fontname
    entry.fullname          = english.fullname or info.fullname
    entry.splainname        = metadata.fullname
    entry.prefmodifiers     = english.prefmodifiers
    local metafamily        = metadata.familyname
    local familyname        = english.preffamily or english.family
    entry.familyname        = familyname
    if familyname ~= metafamily then
        entry.metafamily    = metadata.familyname
    end
    entry.fontstyle_name    = sanitized.fontstyle_name
    entry.plainname         = names.fullname
    entry.subfamily         = english.subfamily

    --- pull style info ...
    entry.italicangle       = style.italicangle
    entry.size              = style.size
    entry.splitstyle        = style.split
    entry.weight            = style.weight

    if config.luaotfload.db.strip == true then
        entry.file  = nil
        entry.names = nil
        entry.style = nil
    end
end

local add_family = function (name, subtable, modifier, entry)
    if not name then --- probably borked font
        return
    end
    local familytable = subtable [name]
    if not familytable then
        familytable = { }
        subtable [name] = familytable
    end

    local size = entry.size

    familytable [#familytable + 1] = {
        index    = entry.index,
        modifier = modifier,
    }
end

local get_subtable = function (families, entry)
    local location  = entry.location
    local format    = entry.format
    local subtable  = families [location] [format]
    if not subtable then
        subtable  = { }
        families [location] [format] = subtable
    end
    return subtable
end

collect_families = function (mappings)

    report ("info", 2, "db", "Analyzing families.")

    local families = {
        ["local"]  = { },
        system     = { },
        texmf      = { },
    }

    for i = 1, #mappings do

        local entry = mappings [i]

        if entry.file then
            pull_values (entry)
        end

        local subtable          = get_subtable (families, entry)

        local familyname        = entry.familyname
        local metafamily        = entry.metafamily
        local fontstyle_name    = entry.fontstyle_name
        local prefmodifiers     = entry.prefmodifiers
        local subfamily         = entry.subfamily

        local weight            = entry.weight
        local italicangle       = entry.italicangle
        local splitstyle        = entry.splitstyle

        local modifier          = pick_style (fontstyle_name,
                                              prefmodifiers,
                                              subfamily,
                                              splitstyle)

        if not modifier then --- regular, exact only
            modifier = check_regular (fontstyle_name,
                                      prefmodifiers,
                                      subfamily,
                                      splitstyle,
                                      italicangle,
                                      weight)
        end

        if modifier then
            add_family (familyname, subtable, modifier, entry)
            --- registering the metafamilies is unreliable within the
            --- same table as identifiers might interfere with an
            --- unmarked style that lacks a metafamily, e.g.
            ---
            ---         iwona condensed regular ->
            ---                     family:     iwonacond
            ---                     metafamily: iwona
            ---         iwona regular ->
            ---                     family:     iwona
            ---                     metafamily: ø
            ---
            --- Both would be registered as under the same family,
            --- i.e. “iwona”, and depending on the loading order
            --- the query “name:iwona” can resolve to the condensed
            --- version instead of the actual unmarked one. The only
            --- way around this would be to introduce a separate
            --- table for metafamilies and do fallback queries on it.
            --- At the moment this is not pressing enough to justify
            --- further increasing the index size, maybe if need
            --- arises from the user side.
--            if metafamily and metafamily ~= familyname then
--                add_family (metafamily, subtable, modifier, entry)
--            end
        elseif weight > 500 then -- in bold spectrum
            modifier = pick_fallback_style (italicangle, weight)
            if modifier then
                add_family (familyname, subtable, modifier, entry)
            end
        end
    end

    collectgarbage "collect"
    return families
end

--[[doc--

    group_modifiers -- For not-quite-bold faces, determine whether
    they can fill in for a missing bold face slot in a matching family.

    Some families like Lucida do not contain real bold / bold italic
    members. Instead, they have semibold variants at weight 600 which
    we must add in a separate pass.

--doc]]--

local bold_spectrum_low  = 501 --- 500 is medium, 900 heavy/black
local bold_weight        = 700
local style_categories   = { "r", "b", "i", "bi" }
local bold_categories    = {      "b",      "bi" }

group_modifiers = function (mappings, families)
    report ("info", 2, "db", "Analyzing shapes, weights, and styles.")
    for location, location_data in next, families do
        for format, format_data in next, location_data do
            for familyname, collected in next, format_data do
                local styledata = { } --- will replace the “collected” table
                --- First, fill in the ordinary style data that
                --- fits neatly into the four relevant modifier
                --- categories.
                for _, modifier in next, style_categories do
                    local entries
                    for key, info in next, collected do
                        if info.modifier == modifier then
                            if not entries then
                                entries = { }
                            end
                            local index = info.index
                            local entry = mappings [index]
                            local size  = entry.size
                            if size then
                                entries [#entries + 1] = {
                                    size [1],
                                    size [2],
                                    size [3],
                                    index,
                                }
                            else
                                entries.default = index
                            end
                            collected [key] = nil
                        end
                        styledata [modifier] = entries
                    end
                end

                --- At this point the family set may still lack
                --- entries for bold or bold italic. We will fill
                --- those in using the modifier with the numeric
                --- weight that is closest to bold (700).
                if next (collected) then --- there are uncategorized entries
                    for _, modifier in next, bold_categories do
                        if not styledata [modifier] then
                            local closest
                            local minimum = 2^51
                            for key, info in next, collected do
                                local info_modifier = tonumber (info.modifier) and "b" or "bi"
                                if modifier == info_modifier then
                                    local index  = info.index
                                    local entry  = mappings [index]
                                    local weight = entry.weight
                                    local diff   = weight < 700 and 700 - weight or weight - 700
                                    if diff < minimum then
                                        minimum = diff
                                        closest = weight
                                    end
                                end
                            end
                            if closest then
                                --- We know there is a substitute face for the modifier.
                                --- Now we scan the list again to extract the size data
                                --- in case the shape is available at multiple sizes.
                                local entries = { }
                                for key, info in next, collected do
                                    local info_modifier = tonumber (info.modifier) and "b" or "bi"
                                    if modifier == info_modifier then
                                        local index  = info.index
                                        local entry  = mappings [index]
                                        local size   = entry.size
                                        if entry.weight == closest then
                                            if size then
                                                entries [#entries + 1] =  {
                                                    size [1],
                                                    size [2],
                                                    size [3],
                                                    index,
                                                }
                                            else
                                                entries.default = index
                                            end
                                        end
                                    end
                                end
                                styledata [modifier] = entries
                            end
                        end
                    end
                end
                format_data [familyname] = styledata
            end
        end
    end
    return families
end

local cmp_sizes = function (a, b)
    return a [1] < b [1]
end

order_design_sizes = function (families)

    report ("info", 2, "db", "Ordering design sizes.")

    for location, data in next, families do
        for format, data in next, data do
            for familyname, data in next, data do
                for style, data in next, data do
                    tablesort (data, cmp_sizes)
                end
            end
        end
    end

    return families
end

--[[doc--

    collect_font_filenames -- Scan the three search path categories for
    font files. This constitutes the first pass of the update mode.

--doc]]--

--- unit -> string * bool list
local collect_font_filenames = function ()

    report ("info", 4, "db", "Scanning the filesystem for font files.")

    local filenames = { }
    local bisect    = config.luaotfload.misc.bisect
    local max_fonts = config.luaotfload.db.max_fonts --- XXX revisit for lua 5.3 wrt integers

    tableappend (filenames, collect_font_filenames_texmf  ())
    tableappend (filenames, collect_font_filenames_system ())
    if config.luaotfload.db.scan_local == true then
        tableappend (filenames, collect_font_filenames_local  ())
    end
    --- Now drop everything above max_fonts.
    if max_fonts < #filenames then
        filenames = { unpack (filenames, 1, max_fonts) }
    end
    --- And choose the requested slice if in bisect mode.
    if bisect then
        return { unpack (filenames, bisect[1], bisect[2]) }
    end
    return filenames
end

--[[doc--

    nth_font_file -- Return the filename of the nth font.

--doc]]--

--- int -> string
local nth_font_filename = function (n)
    report ("info", 4, "db", "Picking font file no. %d.", n)
    if not p_blacklist then
        read_blacklist ()
    end
    local filenames = collect_font_filenames ()
    return filenames[n] and filenames[n][1] or "<error>"
end

--[[doc--

    font_slice -- Return the fonts in the range from lo to hi.

--doc]]--

local font_slice = function (lo, hi)
    report ("info", 4, "db", "Retrieving font files nos. %d--%d.", lo, hi)
    if not p_blacklist then
        read_blacklist ()
    end
    local filenames = collect_font_filenames ()
    local result    = { }
    for i = lo, hi do
        result[#result + 1] = filenames[i][1]
    end
    return result
end

--[[doc

    count_font_files -- Return the number of files found by
    collect_font_filenames. This function is exported primarily
    for use with luaotfload-tool.lua in bisect mode.

--doc]]--

--- unit -> int
local count_font_files = function ()
    report ("info", 4, "db", "Counting font files.")
    if not p_blacklist then
        read_blacklist ()
    end
    return #collect_font_filenames ()
end

--- dbobj -> stats

local collect_statistics = function (mappings)
    local sum_dsnsize, n_dsnsize = 0, 0

    local fullname, family, families = { }, { }, { }
    local subfamily, prefmodifiers, fontstyle_name = { }, { }, { }

    local addtohash = function (hash, item)
        if item then
            local times = hash [item]
            if times then
                hash [item] = times + 1
            else
                hash [item] = 1
            end
        end
    end

    local appendtohash = function (hash, key, value)
        if key and value then
            local entry = hash [key]
            if entry then
                entry [#entry + 1] = value
            else
                hash [key] = { value }
            end
        end
    end

    local addtoset = function (hash, key, value)
        if key and value then
            local set = hash [key]
            if set then
                set [value] = true
            else
                hash [key] = { [value] = true }
            end
        end
    end

    local setsize = function (set)
        local n = 0
        for _, _ in next, set do
            n = n + 1
        end
        return n
    end

    local hashsum = function (hash)
        local n = 0
        for _, m in next, hash do
            n = n + m
        end
        return n
    end

    for _, entry in next, mappings do
        local style        = entry.style
        local names        = entry.names.sanitized
        local englishnames = names.english

        addtohash (fullname,        englishnames.fullname)
        addtohash (family,          englishnames.family)
        addtohash (subfamily,       englishnames.subfamily)
        addtohash (prefmodifiers,   englishnames.prefmodifiers)
        addtohash (fontstyle_name,  names.fontstyle_name)

        addtoset (families, englishnames.family, englishnames.fullname)

        local sizeinfo = entry.style.size
        if sizeinfo then
            sum_dsnsize = sum_dsnsize + sizeinfo [1]
            n_dsnsize = n_dsnsize + 1
        end
    end

    --inspect (families)

    local n_fullname = setsize (fullname)
    local n_family   = setsize (family)

    if log.get_loglevel () > 1 then
        local pprint_top = function (hash, n, set)

            local freqs = { }
            local items = { }

            for item, value in next, hash do
                if set then
                    freq = setsize (value)
                else
                    freq = value
                end
                local ifreq = items [freq]
                if ifreq then
                    ifreq [#ifreq + 1] = item
                else
                    items [freq] = { item }
                    freqs [#freqs + 1] = freq
                end
            end

            tablesort (freqs)

            local from = #freqs
            local to   = from - (n - 1)
            if to < 1 then
                to = 1
            end

            for i = from, to, -1 do
                local freq     = freqs [i]
                local itemlist = items [freq]

                if type (itemlist) == "table" then
                    itemlist = tableconcat (itemlist, ", ")
                end

                report ("both", 0, "db",
                        "       · %4d × %s.",
                        freq, itemlist)
            end
        end

        report ("both", 0, "", "~~~~ font index statistics ~~~~")
        report ("both", 0, "db",
                "   · Collected %d fonts (%d names) in %d families.",
                #mappings, n_fullname, n_family)
        pprint_top (families, 4, true)

        report ("both", 0, "db",
                "   · %d different “subfamily” kinds.",
                setsize (subfamily))
        pprint_top (subfamily, 4)

        report ("both", 0, "db",
                "   · %d different “prefmodifiers” kinds.",
                setsize (prefmodifiers))
        pprint_top (prefmodifiers, 4)

        report ("both", 0, "db",
                "   · %d different “fontstyle_name” kinds.",
                setsize (fontstyle_name))
        pprint_top (fontstyle_name, 4)
    end

    local mean_dsnsize = 0
    if n_dsnsize > 0 then
        mean_dsnsize = sum_dsnsize / n_dsnsize
    end

    return {
        mean_dsnsize = mean_dsnsize,
        names = {
            fullname = n_fullname,
            families = n_family,
        },
--        style = {
--            subfamily = subfamily,
--            prefmodifiers = prefmodifiers,
--            fontstyle_name = fontstyle_name,
--        },
    }
end

--- force:      dictate rebuild from scratch
--- dry_dun:    don’t write to the db, just scan dirs

--- dbobj? -> bool? -> bool? -> dbobj
update_names = function (currentnames, force, dry_run)
    local targetnames

    if config.luaotfload.db.update_live == false then
        report ("info", 2, "db",
                "Skipping database update.")
        --- skip all db updates
        return currentnames or name_index
    end

    local starttime = osgettimeofday ()

    --[[
    The main function, scans everything
    - “targetnames” is the final table to return
    - force is whether we rebuild it from scratch or not
    ]]
    report("both", 1, "db", "Updating the font names database"
                         .. (force and " forcefully." or "."))

    if config.luaotfload.db.skip_read == true then
        --- the difference to a “dry run” is that we don’t search
        --- for font files entirely. we also ignore the “force”
        --- parameter since it concerns only the font files.
        report ("info", 2, "db",
                "Ignoring font files, reusing old data.")
        currentnames = load_names (false)
        targetnames  = currentnames
    else
        if force then
            currentnames = initialize_namedata (get_font_filter ())
        else
            if not currentnames then
                currentnames = load_names (dry_run)
            end
            if currentnames.meta.version ~= names.version then
                report ("both", 1, "db", "No font names database or old "
                                    .. "one found; generating new one.")
                currentnames = initialize_namedata (get_font_filter ())
            end
        end

        targetnames = initialize_namedata (get_font_filter (),
                                           currentnames.meta and currentnames.meta.created)

        read_blacklist ()

        --- pass 1: Collect the names of all fonts we are going to process.
        local font_filenames = collect_font_filenames ()

        --- pass 2: read font files (normal case) or reuse information
        --- present in index

        n_new = retrieve_namedata (font_filenames,
                                   currentnames,
                                   targetnames,
                                   dry_run)
        report ("info", 3, "db",
                "Found %d font files; %d new entries.",
                #font_filenames, n_new)
    end

    --- pass 3 (optional): collect some stats about the raw font info
    if config.luaotfload.misc.statistics == true then
        targetnames.meta.statistics = collect_statistics
                                            (targetnames.mappings)
    end

    --- we always generate the file lookup tables because
    --- non-texmf entries are redirected there and the mapping
    --- needs to be 100% consistent

    --- pass 4: build filename table
    targetnames.files       = generate_filedata (targetnames.mappings)

    --- pass 5: build family lookup table
    targetnames.families    = collect_families  (targetnames.mappings)

    --- pass 6: arrange style and size info
    targetnames.families    = group_modifiers (targetnames.mappings,
                                               targetnames.families)

    --- pass 7: order design size tables
    targetnames.families    = order_design_sizes (targetnames.families)


    report ("info", 3, "db",
            "Rebuilt in %0.f ms.",
            1000 * (osgettimeofday () - starttime))
    name_index = targetnames

    if dry_run ~= true then

        if n_new == 0 then
            report ("info", 2, "db", "No new fonts found, skip saving to disk.")
        else
            local success, reason = save_names ()
            if not success then
                report ("both", 0, "db",
                        "Failed to save database to disk: %s",
                        reason)
            end
        end

        if flush_lookup_cache () and save_lookups () then
            report ("both", 2, "cache", "Lookup cache emptied.")
            return targetnames
        end
    end
    return targetnames
end

--- unit -> bool
save_lookups = function ( )
    local paths = config.luaotfload.paths
    local luaname, lucname = paths.lookup_path_lua, paths.lookup_path_luc
    if fileiswritable (luaname) and fileiswritable (lucname) then
        tabletofile (luaname, lookup_cache, true)
        osremove (lucname)
        caches.compile (lookup_cache, luaname, lucname)
        --- double check ...
        if lfsisfile (luaname) and lfsisfile (lucname) then
            report ("both", 3, "cache", "Lookup cache saved.")
            return true
        end
        report ("info", 0, "cache", "Could not compile lookup cache.")
        return false
    end
    report ("info", 0, "cache", "Lookup cache file not writable.")
    if not fileiswritable (luaname) then
        report ("info", 0, "cache", "Failed to write %s.", luaname)
    end
    if not fileiswritable (lucname) then
        report ("info", 0, "cache", "Failed to write %s.", lucname)
    end
    return false
end

--- save_names() is usually called without the argument
--- dbobj? -> bool * string option
save_names = function (currentnames)
    if not currentnames then
        currentnames = name_index
    end
    if not currentnames or type (currentnames) ~= "table" then
        return false, "invalid names table"
    elseif currentnames.meta and currentnames.meta["local"] then
        return false, "table contains local entries"
    end
    local paths = config.luaotfload.paths
    local luaname, lucname = paths.index_path_lua, paths.index_path_luc
    if fileiswritable (luaname) and fileiswritable (lucname) then
        osremove (lucname)
        local gzname = luaname .. ".gz"
        if config.luaotfload.db.compress then
            local serialized = tableserialize (currentnames, true)
            save_gzipped (gzname, serialized)
            caches.compile (currentnames, "", lucname)
        else
            tabletofile (luaname, currentnames, true)
            caches.compile (currentnames, luaname, lucname)
        end
        report ("info", 2, "db", "Font index saved at ...")
        local success = false
        if lfsisfile (luaname) then
            report ("info", 2, "db", "Text: " .. luaname)
            success = true
        end
        if lfsisfile (gzname) then
            report ("info", 2, "db", "Gzip: " .. gzname)
            success = true
        end
        if lfsisfile (lucname) then
            report ("info", 2, "db", "Byte: " .. lucname)
            success = true
        end
        if success then
            return true
        else
            report ("info", 0, "db", "Could not compile font index.")
            return false
        end
    end
    report ("info", 0, "db", "Index file not writable")
    if not fileiswritable (luaname) then
        report ("info", 0, "db", "Failed to write %s.", luaname)
    end
    if not fileiswritable (lucname) then
        report ("info", 0, "db", "Failed to write %s.", lucname)
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
    report("info", 1, "cache", "Luaotfload cache: %s %s",
        (all and "erase" or "purge"), category)
    report("info", 1, "cache", "location: %s",path)
    local n = 0
    for i=1,#list do
        local filename = list[i]
        if stringfind(filename,"luatex%-cache") then -- safeguard
            if all then
                report("info", 5, "cache", "Removing %s.", filename)
                osremove(filename)
                n = n + 1
            else
                local suffix = filesuffix(filename)
                if suffix == "lua" then
                    local checkname = file.replacesuffix(
                        filename, "lua", "luc")
                    if lfsisfile(checkname) then
                        report("info", 5, "cache", "Removing %s.", filename)
                        osremove(filename)
                        n = n + 1
                    end
                end
            end
        end
    end
    report("info", 1, "cache", "Removed lua files : %i", n)
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
    local writable = getwritablepath (config.luaotfload.paths.cache_dir)
    if writable then
        return writable
    end
end

local getreadablecachepaths = function ( )
    local readables = caches.getreadablepaths
                        (config.luaotfload.paths.cache_dir)
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
    if log.get_loglevel() > 1 then
        print_cache("writable path", writable_path, luanames, lucnames, rest)
    end
    local success = purge_from_cache("writable path", writable_path, luanames, false)
    return success
end

--- unit -> unit
local erase_cache = function ( )
    local writable_path = getwritablecachepath ()
    local luanames, lucnames, rest, all = collect_cache(writable_path)
    if log.get_loglevel() > 1 then
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
    texio.write_nl""
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

names.set_font_filter             = set_font_filter
names.flush_lookup_cache          = flush_lookup_cache
names.save_lookups                = save_lookups
names.load                        = load_names
names.access_font_index           = access_font_index
names.data                        = function () return name_index end
names.save                        = save_names
names.update                      = update_names
names.crude_file_lookup           = crude_file_lookup
names.crude_file_lookup_verbose   = crude_file_lookup_verbose
names.read_blacklist              = read_blacklist
names.sanitize_fontname           = sanitize_fontname
names.getfilename                 = resolve_fullpath
names.getmetadata                 = getmetadata
names.set_location_precedence     = set_location_precedence
names.count_font_files            = count_font_files
names.nth_font_filename           = nth_font_filename
names.font_slice                  = font_slice
names.resolve_cached              = resolve_cached
names.resolve_name                = resolve_name

--- font cache
names.purge_cache    = purge_cache
names.erase_cache    = erase_cache
names.show_cache     = show_cache

names.find_closest = find_closest

-- for testing purpose
names.read_fonts_conf = read_fonts_conf

-- vim:tw=71:sw=4:ts=4:expandtab
