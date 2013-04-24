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
fonts                = fonts       or { }
fonts.names          = fonts.names or { }

local names          = fonts.names

names.version        = 2.2
names.data           = nil
names.path           = {
    basename = "luaotfload-names.lua",
    dir      = "",
    path     = "",
}

-- We use the cache.* of ConTeXt (see luat-basics-gen), we can
-- use it safely (all checks and directory creations are already done). It
-- uses TEXMFCACHE or TEXMFVAR as starting points.
local writable_path = caches.getwritablepath("names","")
if not writable_path then
  error("Impossible to find a suitable writeable cache...")
end
names.path.dir = writable_path
names.path.path = filejoin(writable_path, names.path.basename)

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
This is a sketch of the db:

    type dbobj = {
        mappings : fontentry list;
        status   : filestatus;
        version  : float;
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

--doc]]--

local fontnames_init = function ( )
    return {
        mappings  = { },
        status    = { },
        --- adding filename mapping increases the
        --- size of the serialized db on my system
        --- (5840 font files) by a factor of ...
        barenames = { },--- incr. by 1.11
        basenames = { },--- incr. by 1.22
--      fullnames = { },--- incr. by 1.48
        version   = names.version,
    }
end

local make_name = function (path)
    return filereplacesuffix(path, "lua"), filereplacesuffix(path, "luc")
end

--- When loading a lua file we try its binary complement first, which
--- is assumed to be located at an identical path, carrying the suffix
--- .luc.

local code_cache = { }

--- string -> (string * table)
local load_lua_file = function (path)
    local code = code_cache[path]
    if code then return path, code() end

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

    code_cache[path] = code --- insert into memo
    return foundname, code()
end

--- define locals in scope
local find_closest
local font_fullinfo
local load_names
local read_fonts_conf
local reload_db
local resolve
local save_names
local scan_external_dir
local update_names

--- unit -> dbobj
load_names = function ( )
    local starttime = os.gettimeofday()
    local foundname, data = load_lua_file(names.path.path)

    if data then
        report("info", 1, "db",
            "Font names database loaded", "%s", foundname)
        report("info", 1, "db", "Loading took %0.f ms",
                                1000*(os.gettimeofday()-starttime))
    else
        report("info", 0, "db",
            [[Font names database not found, generating new one.
             This can take several minutes; please be patient.]])
        data = update_names(fontnames_init())
        save_names(data)
    end
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

--- state of the database
local fonts_loaded   = false
local fonts_reloaded = false

local crude_file_lookup_verbose = function (data, filename)
    local found = data.barenames[filename]
    if found then
        report("info", 0, "db",
            "crude file lookup: req=%s; hit=bare; ret=%s",
            filename, found[1])
        return found
    end
--  found = data.fullnames[filename]
--  if found then
--      report("info", 0, "db",
--          "crude file lookup: req=%s; hit=bare; ret=%s",
--          filename, found[1])
--      return found
--  end
    found = data.basenames[filename]
    if found then
        report("info", 0, "db",
            "crude file lookup: req=%s; hit=bare; ret=%s",
            filename, found[1])
        return found
    end
    found = resolvers.findfile(filename, "tfm")
    if found then
        report("info", 0, "db",
            "crude file lookup: req=tfm; hit=bare; ret=%s", found)
        return { found, false }
    end
    found = resolvers.findfile(filename, "ofm")
    if found then
        report("info", 0, "db",
            "crude file lookup: req=ofm; hit=bare; ret=%s", found)
        return { found, false }
    end
    return false
end

local crude_file_lookup = function (data, filename)
    local found = data.barenames[filename]
--             or data.fullnames[filename]
               or data.basenames[filename]
    if found then return found end
    found = resolvers.findfile(filename, "tfm")
    if found then return { found, false } end
    found = resolvers.findfile(filename, "ofm")
    if found then return { found, false } end
    return false
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
--- 
resolve = function (_,_,specification) -- the 1st two parameters are used by ConTeXt
    if not fonts_loaded then
        names.data   = load_names()
        fonts_loaded = true
    end
    local data = names.data

    if specification.lookup == "file" then
        local found = crude_file_lookup(data, specification.name)
        --local found = crude_file_lookup_verbose(data, specification.name)
        if found then return found[1], found[2], true end
    end

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
    for _,face in next, data.mappings do
        --- TODO we really should store those in dedicated
        --- .sanitized field
        local family    = sanitize_string(face.names and face.names.family)
        local subfamily = sanitize_string(face.names and face.names.subfamily)
        local fullname  = sanitize_string(face.names and face.names.fullname)
        local psname    = sanitize_string(face.names and face.names.psname)
        local fontname  = sanitize_string(face.fontname)
        local pfullname = sanitize_string(face.fullname)
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
                    synonym_set[style][subfamily] then
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
        else
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
    end

    if #found == 1 then
        if kpselookup(found[1].filename[1]) then
            report("log", 0, "resolve",
                "font family='%s', subfamily='%s' found: %s",
                name, style, found[1].filename[1]
            )
            return found[1].filename[1], found[1].filename[2], true
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
        if kpselookup(closest.filename[1]) then
            report("log", 0, "resolve",
                "font family='%s', subfamily='%s' found: %s",
                name, style, closest.filename[1]
            )
            return closest.filename[1], closest.filename[2], true
        end
    elseif found.fallback then
        return found.fallback.filename[1], found.fallback.filename[2], true
    end

    --- no font found so far
    if not fonts_reloaded then
        --- last straw: try reloading the database
        return reload_db(
            "unresoled font name: “" .. name .. "”",
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

    if not fonts_loaded then
        names.data = load_names()
        fonts_loaded     = true
    end

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
        local cnames     = current.names
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

--[[doc--
The data inside an Opentype font file can be quite heterogeneous.
Thus in order to get the relevant information, parts of the original
table as returned by the font file reader need to be relocated.
--doc]]--
font_fullinfo = function (filename, subfont, texmf)
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
                tfmdata.names = {
                    --- see
                    --- https://developer.apple.com/fonts/TTRefMan/RM06/Chap6name.html
                    fullname = namedata.names.compatfull
                            or namedata.names.fullname,
                    family   = namedata.names.preffamilyname
                            or namedata.names.family,
                    subfamily= tfmdata.fontstyle_name
                            or namedata.names.prefmodifiers
                            or namedata.names.subfamily,
                    psname   = namedata.names.postscriptname
                }
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
    tfmdata.filename    = {
        texmf and filebasename(filename) or filename,
        subfont
    }
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
local load_font = function (fullname, fontnames, newfontnames, texmf)
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

    --- entryname is apparently the identifier a font is
    --- loaded by; it is different for files in the texmf
    --- (due to kpse? idk.)
    --- entryname = texmf : true -> basename | false -> fullname
    local entryname     = texmf and basename or fullname

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

    local index_status = newstatus[entryname]
                        or (not texmf and newstatus[basename])
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
            local index    = #newstatus[entryname].index
            local fullinfo = mappings[v]
            newmappings[#newmappings+1]         = fullinfo --- keep
            newstatus[entryname].index[index+1] = #newmappings
--          newfullnames[fullname] = fullinfo.filename
            newbasenames[basename] = fullinfo.filename
            newbarenames[barename] = fullinfo.filename
        end
        report("log", 2, "db", "font “%s” already indexed", entryname)
        return false
    end

    local info = fontloaderinfo(fullname)
    if info then
        if type(info) == "table" and #info > 1 then --- ttc
            for i in next, info do
                local fullinfo = font_fullinfo(fullname, i-1, texmf)
                if not fullinfo then
                    return false
                end
                local index = newstatus[entryname].index[i]
                if newstatus[entryname].index[i] then
                    index = newstatus[entryname].index[i]
                else
                    index = #newmappings+1
                end
                newmappings[index]            = fullinfo
--              newfullnames[fullname]        = fullinfo.filename
                newbasenames[basename]        = fullinfo.filename
                newbarenames[barename]        = fullinfo.filename
                newstatus[entryname].index[i] = index
            end
        else
            local fullinfo = font_fullinfo(fullname, false, texmf)
            if not fullinfo then
                return false
            end
            local index
            if newstatus[entryname].index[1] then
                index = newstatus[entryname].index[1]
            else
                index = #newmappings+1
            end
            newmappings[index]            = fullinfo
--          newfullnames[fullname]        = { fullinfo.filename[1], fullinfo.filename[2] }
            newbasenames[basename]        = { fullinfo.filename[1], fullinfo.filename[2] }
            newbarenames[barename]        = { fullinfo.filename[1], fullinfo.filename[2] }
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
local scan_dir = function (dirname, fontnames, newfontnames, texmf)
    --[[
    This function scans a directory and populates the list of fonts
    with all the fonts it finds.
    - dirname is the name of the directory to scan
    - names is the font database to fill -> no such term!!!
    - texmf is a boolean saying if we are scanning a texmf directory
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
                local new = load_font(fullname, fontnames, newfontnames, texmf)
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
        report("info", 1, "db", "Scanning TEXMF fonts...")
    else
        report("info", 1, "db", "Scanning TEXMF and OS fonts...")
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

--- (string -> tab -> tab -> tab)
read_fonts_conf = function (path, results, passed_paths)
    --[[
    This function parses /etc/fonts/fonts.conf and returns all the dir
    it finds.  The code is minimal, please report any error it may
    generate.

    TODO    fonts.conf are some kind of XML so in theory the following
            is totally inappropriate. Maybe a future version of the
            lualibs will include the lxml-* files from Context so we
            can write something presentable instead.
    ]]
    local fh = ioopen(path)
    passed_paths[#passed_paths+1] = path
    passed_paths_set = tabletohash(passed_paths, true)
    if not fh then
        report("log", 2, "db", "cannot open file %s", path)
        return results
    end
    local incomments = false
    for line in fh:lines() do
        while line and line ~= "" do
            -- spaghetti code... hmmm...
            if incomments then
                local tmp = stringfind(line, '-->') --- wtf?
                if tmp then
                    incomments = false
                    line = stringsub(line, tmp+3)
                else
                    line = nil
                end
            else
                local tmp = stringfind(line, '<!--')
                local newline = line
                if tmp then
                    -- for the analysis, we take everything that is before the
                    -- comment sign
                    newline = stringsub(line, 1, tmp-1)
                    -- and we loop again with the comment
                    incomments = true
                    line = stringsub(line, tmp+4)
                else
                    -- if there is no comment start, the block after that will
                    -- end the analysis, we exit the while loop
                    line = nil
                end
                for dir in stringgmatch(newline, '<dir>([^<]+)</dir>') do
                    -- now we need to replace ~ by kpse.expand_path('~')
                    if stringsub(dir, 1, 1) == '~' then
                        dir = filejoin(kpseexpand_path('~'), stringsub(dir, 2))
                    end
                    -- we exclude paths with texmf in them, as they should be
                    -- found anyway
                    if not stringfind(dir, 'texmf') then
                        results[#results+1] = dir
                    end
                end
                for include in stringgmatch(newline, '<include[^<]*>([^<]+)</include>') do
                    -- include here can be four things: a directory or a file,
                    -- in absolute or relative path.
                    if stringsub(include, 1, 1) == '~' then
                        include = filejoin(kpseexpand_path('~'),stringsub(include, 2))
                        -- First if the path is relative, we make it absolute:
                    elseif not lfs.isfile(include) and not lfs.isdir(include) then
                        include = filejoin(file.dirname(path), include)
                    end
                    if      lfs.isfile(include)
                    and     kpsereadable_file(include)
                    and not passed_paths_set[include]
                    then
                        -- maybe we should prevent loops here?
                        -- we exclude path with texmf in them, as they should
                        -- be found otherwise
                        read_fonts_conf(include, results, passed_paths)
                    elseif lfs.isdir(include) then
                        for _,f in next, dirglob(filejoin(include, "*.conf")) do
                            if not passed_paths_set[f] then
                                read_fonts_conf(f, results, passed_paths)
                            end
                        end
                    end
                end
            end
        end
    end
    fh:close()
    return results
end

-- for testing purpose
names.read_fonts_conf = read_fonts_conf

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
        local passed_paths = {}
        local os_dirs = {}
        for _,p in next, {"/usr/local/etc/fonts/fonts.conf", "/etc/fonts/fonts.conf"} do
            if lfs.isfile(p) then
                read_fonts_conf(p, os_dirs, passed_paths)
            end
        end
        return os_dirs
    end
    return {}
end

local function scan_os_fonts(fontnames, newfontnames)
    local n_scanned, n_new = 0, 0
    --[[
    This function scans the OS fonts through
      - fontcache for Unix (reads the fonts.conf file and scans the directories)
      - a static set of directories for Windows and MacOSX
    ]]
    report("info", 1, "db", "Scanning OS fonts...")
    report("info", 2, "db", "Searching in static system directories...")
    for _,d in next, get_os_dirs() do
        local found, new = scan_dir(d, fontnames, newfontnames, false)
        n_scanned = n_scanned + found
        n_new     = n_new     + new
    end
    return n_scanned, n_new
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
    report("info", 1, "db", "Updating the font names database"
                         .. (force and " forcefully" or ""))

    if force then
        fontnames = fontnames_init()
    else
        if not fontnames then
            fontnames = load_names()
        end
        if fontnames.version ~= names.version then
            fontnames = fontnames_init()
            report("log", 1, "db", "No font names database or old "
                                .. "one found; generating new one")
        end
    end
    local newfontnames = fontnames_init()
    read_blacklist()
    --installed_fonts_scanned = false
    --scan_installed_fonts(fontnames, newfontnames) --- see fixme above
    local scanned, new = scan_texmf_fonts(fontnames, newfontnames)
    n_scanned = n_scanned + scanned
    n_new     = n_new     + new
    --if  not installed_fonts_scanned
    --and stringis_empty(kpseexpand_path("$OSFONTDIR"))
    if stringis_empty(kpseexpand_path("$OSFONTDIR"))
    then
        local scanned, new = scan_os_fonts(fontnames, newfontnames)
        n_scanned = n_scanned + scanned
        n_new     = n_new     + new
    end
    --- stats:
    ---            before rewrite   | after rewrite
    ---   partial:         804 ms   |   701 ms
    ---   forced:        45384 ms   | 44714 ms
    report("info", 1, "db",
           "Scanned %d font files; %d new entries.", n_scanned, n_new)
    report("info", 1, "db",
           "Rebuilt in %0.f ms", 1000*(os.gettimeofday()-starttime))
    return newfontnames
end

--- dbobj -> unit
save_names = function (fontnames)
    local path  = names.path.dir
    if not lfs.isdir(path) then
        dirmkdirs(path)
    end
    path = filejoin(path, names.path.basename)
    if fileiswritable(path) then
        local luaname, lucname = make_name(path)
        tabletofile(luaname, fontnames, true)
        caches.compile(fontnames,luaname,lucname)
        report("info", 0, "db", "Font names database saved")
        return path
    else
        report("info", 0, "db", "Failed to save names database")
        return nil
    end
end

scan_external_dir = function (dir)
    local old_names, new_names
    if fonts_loaded then
        old_names = names.data
    else
        old_names = load_names()
        fonts_loaded    = true
    end
    new_names = tablecopy(old_names)
    local n_scanned, n_new = scan_dir(dir, old_names, new_names)
    names.data = new_names
    return n_scanned, n_new
end

--- export functionality to the namespace “fonts.names”
names.scan   = scan_external_dir
names.load   = load_names
names.update = update_names
names.save   = save_names

names.resolve      = resolve --- replace the resolver from luatex-fonts
names.resolvespec  = resolve
names.find_closest = find_closest

--- dummy required by luatex-fonts (cf. luatex-fonts-syn.lua)

fonts.names.getfilename = function (askedname,suffix) return "" end

-- vim:tw=71:sw=4:ts=4:expandtab
