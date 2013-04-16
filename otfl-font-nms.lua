if not modules then modules = { } end modules ['font-nms'] = {
    version   = 1.002,
    comment   = "companion to luaotfload.lua",
    author    = "Khaled Hosny and Elie Roux",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2"
}

--- Luatex builtins
local dofile                  = dofile
local load                    = load
local next                    = next
local pcall                   = pcall
local require                 = require
local tonumber                = tonumber

local iolines                 = io.lines
local ioopen                  = io.open
local kpseexpand_path         = kpse.expand_path
local mathabs                 = math.abs
local stringfind              = string.find
local stringformat            = string.format
local stringgmatch            = string.gmatch
local stringgsub              = string.gsub
local stringlower             = string.lower
local stringsub               = string.sub
local stringupper             = string.upper
local tableinsert             = table.insert
local texiowrite_nl           = texio.write_nl
local utf8gsub                = unicode.utf8.gsub
local utf8lower               = unicode.utf8.lower

--- these come from Lualibs/Context
local dirglob                 = dir.glob
local filebasename            = file.basename
local filecollapsepath        = file.collapsepath
local fileextname             = file.extname
local filejoin                = file.join
local filereplacesuffix       = file.replacesuffix
local filesplitpath           = file.splitpath
local stringis_empty          = string.is_empty
local stringsplit             = string.split
local stringstrip             = string.strip

--- the font loader namespace is “fonts”, same as in Context
fonts                = fonts       or { }
fonts.names          = fonts.names or { }

local names          = fonts.names
local names_dir      = "luatex-cache/generic/names"
names.version        = 2.2 -- not the same as in context
names.data           = nil
names.path           = {
    basename = "otfl-names.lua",
    dir      = filejoin(kpse.expand_var("$TEXMFVAR"), names_dir),
}

local success = pcall(require, "luatexbase.modutils")
if success then
   success = pcall(luatexbase.require_module,
                   "lualatex-platform", "2011/03/30")
end
local get_installed_fonts
if success then
   get_installed_fonts = lualatex.platform.get_installed_fonts
else
   function get_installed_fonts()
   end
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
--- Furthermore, we memoize loaded files along the way to avoid
--- duplication.

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
local load_names
local save_names
local scan_external_dir
local update_names
local read_fonts_conf
local resolve


load_names = function ( )
    local path            = filejoin(names.path.dir, names.path.basename)
    local foundname, data = load_lua_file(path)

    if data then
        report("info", 0, "Font names database loaded", "%s", foundname)
    else
        report("info", 0,
            [[Font names database not found, generating new one.
             This can take several minutes; please be patient.]])
        data = names.update(fontnames_init())
        names.save(data)
    end
    texiowrite_nl("")
    return data
end

local synonyms = {
    regular    = { "normal",        "roman",
                   "plain",         "book",
                   "medium"                             },
    --- TODO note from Élie Roux
    --- boldregular was for old versions of Linux Libertine, is it still useful?
    --- semibold is in new versions of Linux Libertine, but there is also a bold,
    --- not sure it's useful here...
    bold       = { "demi",           "demibold",
                   "semibold",       "boldregular",     },
    italic     = { "regularitalic",  "normalitalic",
                   "oblique",        "slanted",         },
    bolditalic = {
                   "boldoblique",    "boldslanted",
                   "demiitalic",     "demioblique",
                   "demislanted",    "demibolditalic",
                   "semibolditalic",                   },
}

local loaded   = false
local reloaded = false

--[[doc--

Luatex-fonts, the font-loader package luaotfload imports, comes with
basic file location facilities (see luatex-fonts-syn.lua).
However, the builtin functionality is too limited to be of more than
basic use, which is why we supply our own resolver that accesses the
font database created by the mkluatexfontdb script.

--doc]]--

resolve = function (_,_,specification) -- the 1st two parameters are used by ConTeXt
    local name  = sanitize_string(specification.name)
    local style = sanitize_string(specification.style) or "regular"

    local size
    if specification.optsize then
        size = tonumber(specification.optsize)
    elseif specification.size then
        size = specification.size / 65536
    end


    if not loaded then
        names.data = load_names()
        loaded     = true
    end

    local data = names.data
    if type(data) == "table" and data.version == names.version then
        if data.mappings then
            local found = { }
            for _,face in next, data.mappings do
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
                    elseif synonyms[style] and
                           table.contains(synonyms[style], subfamily) then
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
                           table.contains(synonyms.regular, subfamily) then
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
                if kpse.lookup(found[1].filename[1]) then
                    report("log", 0, "load font",
                        "font family='%s', subfamily='%s' found: %s",
                        name, style, found[1].filename[1]
                    )
                    return found[1].filename[1], found[1].filename[2]
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
                if kpse.lookup(closest.filename[1]) then
                    report("log", 0, "load font",
                        "font family='%s', subfamily='%s' found: %s",
                        name, style, closest.filename[1]
                    )
                    return closest.filename[1], closest.filename[2]
                end
            elseif found.fallback then
                return found.fallback.filename[1], found.fallback.filename[2]
            end
            -- no font found so far
            if not reloaded then
                -- try reloading the database
                names.data = names.update(names.data)
                names.save(names.data)
                reloaded   = true
                return resolve(_,_,specification)
            else
                -- else, fallback to filename
                -- XXX: specification.name is empty with absolute paths, looks
                -- like a bug in the specification parser
                return specification.name, false
            end
        end
    else
        if not reloaded then
            names.data = names.update()
            names.save(names.data)
            reloaded   = true
            return resolve(_,_,specification)
        else
            return specification.name, false
        end
    end
end

local function font_fullinfo(filename, subfont, texmf)
    local t = { }
    local f = fontloader.open(filename, subfont)
    if not f then
        report("log", 1, "error", "failed to open %s", filename)
        return
    end
    local m = fontloader.to_table(f)
    fontloader.close(f)
    collectgarbage('collect')
    -- see http://www.microsoft.com/typography/OTSPEC/features_pt.htm#size
    if m.fontstyle_name then
        for _,v in next, m.fontstyle_name do
            if v.lang == 1033 then
                t.fontstyle_name = v.name
            end
        end
    end
    if m.names then
        for _,v in next, m.names do
            if v.lang == "English (US)" then
                t.names = {
                    -- see
                    -- http://developer.apple.com/textfonts/
                    -- TTRefMan/RM06/Chap6name.html
                    fullname = v.names.compatfull     or v.names.fullname,
                    family   = v.names.preffamilyname or v.names.family,
                    subfamily= t.fontstyle_name       or v.names.prefmodifiers  or v.names.subfamily,
                    psname   = v.names.postscriptname
                }
            end
        end
    else
        -- no names table, propably a broken font
        report("log", 1, "broken font rejected", "%s", basefile)
        return
    end
    t.fontname    = m.fontname
    t.fullname    = m.fullname
    t.familyname  = m.familyname
    t.filename    = { texmf and filebasename(filename) or filename, subfont }
    t.weight      = m.pfminfo.weight
    t.width       = m.pfminfo.width
    t.slant       = m.italicangle
    -- don't waste the space with zero values
    t.size = {
        m.design_size         ~= 0 and m.design_size         or nil,
        m.design_range_top    ~= 0 and m.design_range_top    or nil,
        m.design_range_bottom ~= 0 and m.design_range_bottom or nil,
    }
    return t
end

local function load_font(filename, fontnames, newfontnames, texmf)
    local newmappings = newfontnames.mappings
    local newstatus   = newfontnames.status
    local mappings    = fontnames.mappings
    local status      = fontnames.status
    local basename    = filebasename(filename)
    local basefile    = texmf and basename or filename
    if filename then
        if names.blacklist[filename] or
           names.blacklist[basename] then
            report("log", 2, "ignoring font", "%s", filename)
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
            report("log", 1, "font already indexed", "%s", basefile)
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
            report("log", 1, "failed to load", "%s", basefile)
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
            if kpse.readable_file(dest) then
                path = dest
            elseif kpse.readable_file(filejoin(file.dirname(path), dest)) then
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
        kpse.lookup("otfl-blacklist.cnf", {all=true, format="tex"})
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
                    line = stringsplit(line, "%")[1]
                    line = stringstrip(line)
                    if stringsub(line, 1, 1) == "-" then
                        whitelist[stringsub(line, 2, -1)] = true
                    else
                        report("log", 2, "blacklisted file", "%s", line)
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

local installed_fonts_scanned = false

local function scan_installed_fonts(fontnames, newfontnames)
    -- Try to query and add font list from operating system.
    -- This uses the lualatex-platform module.
    report("info", 0, "Scanning fonts known to operating system...")
    local fonts = get_installed_fonts()
    if fonts and #fonts > 0 then
        installed_fonts_scanned = true
        report("log", 2, "operating system fonts found", "%d", #fonts)
        for key, value in next, fonts do
            local file = value.path
            if file then
                local ext = fileextname(file)
                if ext and font_extensions_set[ext] then
                file = path_normalize(file)
                    report("log", 1, "loading font", "%s", file)
                load_font(file, fontnames, newfontnames, false)
                end
            end
        end
    else
        report("log", 2, "Could not retrieve list of installed fonts")
    end
end

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
    report("log", 2, "scanning", "%s", dirname)
    for _,i in next, font_extensions do
        for _,ext in next, { i, stringupper(i) } do
            found = dirglob(stringformat("%s/**.%s$", dirname, ext))
            -- note that glob fails silently on broken symlinks, which happens
            -- sometimes in TeX Live.
            report("log", 2, "fonts found", "%s '%s' fonts found", #found, ext)
            nbfound = nbfound + #found
            table.append(list, found)
        end
    end
    report("log", 2, "fonts found", "%d fonts found in '%s'", nbfound, dirname)

    for _,file in next, list do
        file = path_normalize(file)
        report("log", 1, "loading font", "%s", file)
        load_font(file, fontnames, newfontnames, texmf)
    end
end

local function scan_texmf_fonts(fontnames, newfontnames)
    --[[
    This function scans all fonts in the texmf tree, through kpathsea
    variables OPENTYPEFONTS and TTFONTS of texmf.cnf
    ]]
    if stringis_empty(kpseexpand_path("$OSFONTDIR")) then
        report("info", 0, "Scanning TEXMF fonts...")
    else
        report("info", 0, "Scanning TEXMF and OS fonts...")
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
    ]]
    local fh = ioopen(path)
    tableinsert(passed_paths, path)
    if not fh then
        report("log", 2, "cannot open file", "%s", path)
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
                    and     kpse.readable_file(include)
                    and not table.contains(passed_paths, include)
                    then
                        -- maybe we should prevent loops here?
                        -- we exclude path with texmf in them, as they should
                        -- be found otherwise
                        read_fonts_conf(include, results, passed_paths)
                    elseif lfs.isdir(include) then
                        for _,f in next, dirglob(filejoin(include, "*.conf")) do
                            read_fonts_conf(f, results, passed_paths)
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
        for _,p in next, {"/usr/local/etc/fonts/fonts.conf", "/etc/fonts/fonts.conf"} do
            if lfs.isfile(p) then
                return read_fonts_conf("/etc/fonts/fonts.conf", {}, {})
            end
        end
    end
    return {}
end

local function scan_os_fonts(fontnames, newfontnames)
    --[[
    This function scans the OS fonts through
      - fontcache for Unix (reads the fonts.conf file and scans the directories)
      - a static set of directories for Windows and MacOSX
    ]]
    report("info", 0, "Scanning OS fonts...")
    report("info", 2, "Searching in static system directories...")
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
    report("info", 0, "Updating the font names database")

    if force then
        fontnames = fontnames_init()
    else
        if not fontnames then
            fontnames = load_names()
        end
        if fontnames.version ~= names.version then
            fontnames = fontnames_init()
            report("log", 0, "No font names database or old one found; "
                           .."generating new one")
        end
    end
    local newfontnames = fontnames_init()
    read_blacklist()
    installed_font_scanned = false
    scan_installed_fonts(fontnames, newfontnames)
    scan_texmf_fonts(fontnames, newfontnames)
    if not installed_fonts_scanned and stringis_empty(kpseexpand_path("$OSFONTDIR")) then
        scan_os_fonts(fontnames, newfontnames)
    end
    return newfontnames
end

save_names = function (fontnames)
    local path  = names.path.dir
    if not lfs.isdir(path) then
        dir.mkdirs(path)
    end
    path = filejoin(path, names.path.basename)
    if file.iswritable(path) then
        local luaname, lucname = make_name(path)
        table.tofile(luaname, fontnames, true)
        caches.compile(fontnames,luaname,lucname)
        report("info", 0, "Font names database saved")
        return path
    else
        report("info", 0, "Failed to save names database")
        return nil
    end
end

scan_external_dir = function (dir)
    local old_names, new_names
    if loaded then
        old_names = names.data
    else
        old_names = load_names()
        loaded    = true
    end
    new_names = table.copy(old_names)
    scan_dir(dir, old_names, new_names)
    names.data = new_names
end

--- export functionality to the namespace “fonts.names”
names.scan   = scan_external_dir
names.load   = load_names
names.update = update_names
names.save   = save_names

names.resolve     = resolve --- replace the resolver from luatex-fonts
names.resolvespec = resolve

--- dummy required by luatex-fonts (cf. luatex-fonts-syn.lua)

fonts.names.getfilename = function (askedname,suffix) return "" end

-- vim:tw=71:sw=4:ts=4:expandtab
