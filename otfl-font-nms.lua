if not modules then modules = { } end modules ['font-nms'] = {
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
    basename = "otfl-names.lua",
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


---- <FIXME>
---
--- these lines load some binary module called “lualatex-platform”
--- that doesn’t appear to build with Lua 5.2. I’m going ahead and
--- disable it for the time being until someone clarifies what it
--- is supposed to do and whether we should care to fix it.
---
--local success = pcall(require, "luatexbase.modutils")
--if success then
--   success = pcall(luatexbase.require_module,
--                   "lualatex-platform", "2011/03/30")
--    print(success)
--end

--local get_installed_fonts
--if success then
--   get_installed_fonts = lualatex.platform.get_installed_fonts
--else
--   function get_installed_fonts()
--   end
--end
---- </FIXME>

local get_installed_fonts = nil

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

local fontnames_init = function ( )
    return {
        mappings  = { },
        status    = { },
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

load_names = function ( )
    local foundname, data = load_lua_file(names.path.path)

    if data then
        report("info", 1, "db",
            "Font names database loaded", "%s", foundname)
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
        --- TODO note from Élie Roux
        --- boldregular was for old versions of Linux Libertine, is it still useful?
        --- semibold is in new versions of Linux Libertine, but there is also a bold,
        --- not sure it's useful here...
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
--- the return value of “resolve” is the file name of the requested
--- font
---
--- 'a -> 'a -> table -> (string * string | bool * bool)
---
---     note by phg: I added a third return value that indicates a
---     successful lookup as this cannot be inferred from the other
---     values.
---
--- 
resolve = function (_,_,specification) -- the 1st two parameters are used by ConTeXt
    local name  = sanitize_string(specification.name)
    local style = sanitize_string(specification.style) or "regular"

    local size
    if specification.optsize then
        size = tonumber(specification.optsize)
    elseif specification.size then
        size = specification.size / 65536
    end

    if not fonts_loaded then
        names.data   = load_names()
        fonts_loaded = true
    end

    local data = names.data
    if type(data) == "table" then
        local db_version, nms_version = data.version, names.version
        if data.version ~= names.version then
            report("log", 0, "db",
                [[version mismatch; expected %4.3f, got %4.3f]],
                nms_version, db_version
            )
            return reload_db(resolve, nil, nil, specification)
        end
        if data.mappings then
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
                return reload_db(resolve, nil, nil, specification)
            else
                --- else, fallback to requested name
                --- specification.name is empty with absolute paths, looks
                --- like a bug in the specification parser <TODO< is it still
                --- relevant? looks not...
                return specification.name, false, false
            end
        end
    else --- no db or outdated; reload names and retry
        if not fonts_reloaded then
            return reload_db(resolve, nil, nil, specification)
        else --- unsucessfully reloaded; bail
            return specification.name, false, false
        end
    end
end --- resolve()

--- when reload is triggered we update the database
--- and then re-run the caller with the arg list

--- ('a -> 'a) -> 'a list -> 'a
reload_db = function (caller, ...)
    report("log", 1, "db", "reload initiated")
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

    if type(data) == "table" then
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
    else --- need reload
        return reload_db(find_closest, name)
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

local load_font = function (filename, fontnames, newfontnames, texmf)
    local newmappings = newfontnames.mappings
    local newstatus   = newfontnames.status
    local mappings    = fontnames.mappings
    local status      = fontnames.status
    local basename    = filebasename(filename)
    local basefile    = texmf and basename or filename
    if filename then
        if names.blacklist[filename] or
           names.blacklist[basename] then
            report("log", 2, "db", "ignoring font", "%s", filename)
            return
        end
        local timestamp, db_timestamp
        db_timestamp        = status[basefile] and status[basefile].timestamp
        timestamp           = lfs.attributes(filename, "modification")

        local index_status = newstatus[basefile] or (not texmf and newstatus[basename])
        if index_status and index_status.timestamp == timestamp then
            -- already indexed this run
            return
        end

        newstatus[basefile] = newstatus[basefile] or { }
        newstatus[basefile].timestamp = timestamp
        newstatus[basefile].index     = newstatus[basefile].index or { }

        if db_timestamp == timestamp and not newstatus[basefile].index[1] then
            for _,v in next, status[basefile].index do
                local index = #newstatus[basefile].index
                newmappings[#newmappings+1]        = mappings[v]
                newstatus[basefile].index[index+1] = #newmappings
            end
            report("log", 1, "db", "font already indexed", "%s", basefile)
            return
        end
        local info = fontloader.info(filename)
        if info then
            if type(info) == "table" and #info > 1 then
                for i in next, info do
                    local fullinfo = font_fullinfo(filename, i-1, texmf)
                    if not fullinfo then
                        return
                    end
                    local index = newstatus[basefile].index[i]
                    if newstatus[basefile].index[i] then
                        index = newstatus[basefile].index[i]
                    else
                        index = #newmappings+1
                    end
                    newmappings[index]           = fullinfo
                    newstatus[basefile].index[i] = index
                end
            else
                local fullinfo = font_fullinfo(filename, false, texmf)
                if not fullinfo then
                    return
                end
                local index
                if newstatus[basefile].index[1] then
                    index = newstatus[basefile].index[1]
                else
                    index = #newmappings+1
                end
                newmappings[index]           = fullinfo
                newstatus[basefile].index[1] = index
            end
        else
            report("log", 1, "db", "failed to load", "%s", basefile)
        end
    end
end

local function path_normalize(path)
    --[[
        path normalization:
        - a\b\c  -> a/b/c
        - a/../b -> b
        - /cygdrive/a/b -> a:/b
        - reading symlinks under non-Win32
        - using kpse.readable_file on Win32
    ]]
    if os.type == "windows" or os.type == "msdos" or os.name == "cygwin" then
        path = stringgsub(path, '\\', '/')
        path = stringlower(path)
        path = stringgsub(path, '^/cygdrive/(%a)/', '%1:/')
    end
    if os.type ~= "windows" and os.type ~= "msdos" then
        local dest = lfs.readlink(path)
        if dest then
            if kpsereadable_file(dest) then
                path = dest
            elseif kpsereadable_file(filejoin(file.dirname(path), dest)) then
                path = filejoin(file.dirname(path), dest)
            else
                -- broken symlink?
            end
        end
    end
    path = filecollapsepath(path)
    return path
end

fonts.path_normalize = path_normalize

names.blacklist = { }

local function read_blacklist()
    local files = {
        kpselookup("otfl-blacklist.cnf", {all=true, format="tex"})
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
                        report("log", 2, "db", "blacklisted file", "%s", line)
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

--local installed_fonts_scanned = false --- ugh

--- we already have scan_os_fonts don’t we?

--local function scan_installed_fonts(fontnames, newfontnames)
--    --- Try to query and add font list from operating system.
--    --- This uses the lualatex-platform module.
--    --- <phg>what for? why can’t we do this in Lua?</phg>
--    report("info", 0, "Scanning fonts known to operating system...")
--    local fonts = get_installed_fonts()
--    if fonts and #fonts > 0 then
--        installed_fonts_scanned = true
--        report("log", 2, "operating system fonts found", "%d", #fonts)
--        for key, value in next, fonts do
--            local file = value.path
--            if file then
--                local ext = fileextname(file)
--                if ext and font_extensions_set[ext] then
--                file = path_normalize(file)
--                    report("log", 1, "loading font", "%s", file)
--                load_font(file, fontnames, newfontnames, false)
--                end
--            end
--        end
--    else
--        report("log", 2, "Could not retrieve list of installed fonts")
--    end
--end

local function scan_dir(dirname, fontnames, newfontnames, texmf)
    --[[
    This function scans a directory and populates the list of fonts
    with all the fonts it finds.
    - dirname is the name of the directory to scan
    - names is the font database to fill
    - texmf is a boolean saying if we are scanning a texmf directory
    ]]
    local list, found = { }, { }
    local nbfound = 0
    report("log", 2, "db", "scanning", "%s", dirname)
    for _,i in next, font_extensions do
        for _,ext in next, { i, stringupper(i) } do
            found = dirglob(stringformat("%s/**.%s$", dirname, ext))
            -- note that glob fails silently on broken symlinks, which happens
            -- sometimes in TeX Live.
            report("log", 2, "db",
                "fonts found", "%s '%s' fonts found", #found, ext)
            nbfound = nbfound + #found
            tableappend(list, found)
        end
    end
    report("log", 2, "db",
        "fonts found", "%d fonts found in '%s'", nbfound, dirname)

    for _,file in next, list do
        file = path_normalize(file)
        report("log", 1, "db",
            "loading font", "%s", file)
        load_font(file, fontnames, newfontnames, texmf)
    end
end

local function scan_texmf_fonts(fontnames, newfontnames)
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
            scan_dir(d, fontnames, newfontnames, true)
        end
    end
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
        report("log", 2, "db", "cannot open file", "%s", path)
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
        -- what about ~/config/fontconfig/fonts.conf etc? 
        -- Answer: they should be included by the others, please report if it's not
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
    --[[
    This function scans the OS fonts through
      - fontcache for Unix (reads the fonts.conf file and scans the directories)
      - a static set of directories for Windows and MacOSX
    ]]
    report("info", 1, "db", "Scanning OS fonts...")
    report("info", 2, "db", "Searching in static system directories...")
    for _,d in next, get_os_dirs() do
        scan_dir(d, fontnames, newfontnames, false)
    end
end

update_names = function (fontnames, force)
    --[[
    The main function, scans everything
    - fontnames is the final table to return
    - force is whether we rebuild it from scratch or not
    ]]
    report("info", 1, "db", "Updating the font names database")

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
    scan_texmf_fonts(fontnames, newfontnames)
    --if  not installed_fonts_scanned
    --and stringis_empty(kpseexpand_path("$OSFONTDIR"))
    if stringis_empty(kpseexpand_path("$OSFONTDIR"))
    then
        scan_os_fonts(fontnames, newfontnames)
    end
    return newfontnames
end

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
    scan_dir(dir, old_names, new_names)
    names.data = new_names
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
