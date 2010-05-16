if not modules then modules = { } end modules ['font-nms'] = {
    version   = 1.002,
    comment   = "companion to luaotfload.lua",
    author    = "Khaled Hosny and Elie Roux",
    copyright = "Luaotfload Development Team",
    license   = "GPL"
}

fonts                = fonts       or { }
fonts.names          = fonts.names or { }

local names          = fonts.names
local names_dir      = "/luatex/generic/luaotfload/names/"
names.version        = 2.008 -- not the same as in context
names.data           = nil
names.path           = {
    basename  = "otfl-names.lua",
    localdir  = kpse.expand_var("$TEXMFVAR")    .. names_dir,
    systemdir = kpse.expand_var("$TEXMFSYSVAR") .. names_dir,
}


local splitpath, expandpath, glob, basename = file.split_path, kpse.expand_path, dir.glob, file.basename
local upper, lower, format, gsub, match  = string.upper, string.lower, string.format, string.gsub, string.match
local rpadd = string.rpadd
local utfgsub = unicode.utf8.gsub

local trace_progress = true  --trackers.register("names.progress", function(v) trace_progress = v end)
local trace_search   = false --trackers.register("names.search",   function(v) trace_search   = v end)
local trace_loading  = false --trackers.register("names.loading",  function(v) trace_loading  = v end)

local function sanitize(str)
    if str then
        return utfgsub(lower(str), "[^%a%d]", "")
    else
        return str -- nil
    end
end

local function fontnames_init()
    return {
        mappings  = { },
        status    = { },
        version   = names.version,
    }
end

function names.load()
    local localpath  = names.path.localdir  .. names.path.basename
    local systempath = names.path.systemdir .. names.path.basename
    local kpsefound  = kpse.find_file(names.path.basename)
    local data
    if kpsefound and file.isreadable(kpsefound) then
        data = dofile(kpsefound)
    elseif file.isreadable(localpath)  then
        data = dofile(localpath)
    elseif file.isreadable(systempath) then
        data = dofile(systempath)
    end
    if data then
        if trace_loading then
            logs.report("load font",
                "loaded font names database: %s",
                foundname)
        end
    else
        logs.report("load font",
            "no font names database found, generating new one")
        local savepath  = names.path.localdir  .. names.path.basename
        data = names.update()
        io.savedata(savepath, table.serialize(data, true))
    end
    return data
end

local loaded    = false

local synonyms  = {
    regular = {
        normal = true,
        roman  = true,
        plain  = true,
        book   = true,
        medium = true,
    },
    italic = {
        regularitalic = true,
        normalitalic  = true,
        oblique       = true,
        slant         = true,
    },
    bolditalic = {
        boldoblique   = true,
        boldslant     = true,
    },
}

function names.resolve(specification)
    local tfm   = resolvers.find_file(specification.name, "ofm")
    local name  = sanitize(specification.name)
    local style = sanitize(specification.style) or "regular"
    local size  = tonumber(specification.optsize) or specification.size and specification.size / 65536
    if tfm then
        -- is a tfm font, skip names database
        return specification.name, false
    end
    if not loaded then
        names.data   = names.load()
        loaded = true
    end
    local data  = names.data
    if type(data) == "table" and data.version == names.version then
        if data.mappings then
            local found = { }
            for _,face in ipairs(data.mappings) do
                local family    = sanitize(face.names.family)
                local subfamily = sanitize(face.names.subfamily)
                local fullname  = sanitize(face.names.fullname)
                local psname    = sanitize(face.names.psname)
                local fontname  = sanitize(face.fontname)
                local pfullname = sanitize(face.fullname)
                local optsize, dsnsize, maxsize, minsize
                if #face.size > 0 then
                    optsize = face.size
                    dsnsize = optsize[1] and optsize[1] / 10
                    maxsize = optsize[2] and optsize[2] / 10 or dsnsize -- can be nil
                    minsize = optsize[3] and optsize[3] / 10 or dsnsize -- can be nil
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
                    elseif synonyms[style] and synonyms[style][subfamily] then
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
                    else
                        found[1] = face
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
                    logs.report("load font",
                                "font family='%s', subfamily='%s' found: %s",
                                name, style, found[1].filename[1])
                    return found[1].filename[1], found[1].filename[2]
                end
            elseif #found > 1 then
                -- we found matching font(s) but not in the requested optical
                -- sizes, so we loop through the matches to find the one with
                -- least difference from the requested size.
                local closest
                local least = math.huge -- initial value is infinity
                for i,face in ipairs(found) do
                    local dsnsize    = face.size[1]/10
                    local difference = math.abs(dsnsize-size)
                    if difference < least then
                        closest = face
                        least   = difference
                    end
                end
                if kpse.lookup(closest.filename[1]) then
                    logs.report("load font",
                                "font family='%s', subfamily='%s' found: %s",
                                name, style, closest.filename[1])
                    return closest.filename[1], closest.filename[2]
                end
            end
            -- no font found so far, fallback to filename
            return specification.name, false
        end
    end
end

names.resolvespec = names.resolve -- only supported in mkiv

function names.set_log_level(level)
    if level == 2 then
        trace_progress = false
        trace_loading = true
    elseif level >= 3 then
        trace_progress = false
        trace_loading = true
        trace_search = true
    end
end
    
local lastislog = 0

function log(fmt, ...)
    lastislog = 1
    texio.write_nl(format("luaotfload | %s", format(fmt,...)))
end

logs        = logs or { }
logs.report = logs.report or log

local log = names.log

-- The progress bar
local function progress(current, total)
    if trace_progress then
--      local width   = os.getenv("COLUMNS") -2 --doesn't work
        local width   = 78
        local percent = current/total
        local gauge   = format("[%s]", rpadd(" ", width, " "))
        if percent > 0 then
            local done = rpadd("=", (width * percent) - 1, "=") .. ">"
            gauge = format("[%s]", rpadd(done, width, " ") )
        end
        if lastislog == 1 then
            texio.write_nl("")
            lastislog = 0
        end
        io.stderr:write("\r"..gauge)
        io.stderr:flush()
    end
end

local function font_fullinfo(filename, subfont, texmf)
    local t = { }
    local f = fontloader.open(filename, subfont)
    if not f then
        logs.report("error: failed to open %s", filename)
        return nil
    end
    local m = fontloader.to_table(f)
    fontloader.close(f)
    collectgarbage('collect')
    -- see http://www.microsoft.com/typography/OTSPEC/features_pt.htm#size
    if m.fontstyle_name then
        for _,v in pairs(m.fontstyle_name) do
            if v.lang == 1033 then
                t.fontstyle_name = v.name
            end
        end
    end
    if m.names then
        for _,v in pairs(m.names) do
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
    end
    t.fontname    = m.fontname
    t.fullname    = m.fullname
    t.familyname  = m.familyname
    t.filename    = { texmf and basename(filename) or filename, subfont }
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
    if filename then
        local timestamp, db_timestamp
        db_timestamp        = status[filename] and status[filename].timestamp
        timestamp           = lfs.attributes(filename, "modification")
        newstatus[filename] = { }
        newstatus[filename].timestamp = timestamp
        newstatus[filename].index     = {}
        if db_timestamp == timestamp then
            for _,v in ipairs(status[filename].index) do
                newmappings[#newmappings+1] = mappings[v]
                newstatus[filename].index[#newstatus[filename].index+1] = #newmappings
            end
            if trace_loading then
                logs.report("font already indexed: %s", filename)
            end
            return
        end
        if trace_loading then
            logs.report("loading font: %s", filename)
        end
        local info = fontloader.info(filename)
        if info then
            if type(info) == "table" and #info > 1 then
                for i in ipairs(info) do
                    local fullinfo = font_fullinfo(filename, i-1, texmf)
                    newmappings[#newmappings+1] = fullinfo
                    newstatus[filename].index[#newstatus[filename].index+1] = #newmappings
                end
            else
                local fullinfo = font_fullinfo(filename, false, texmf)
                newmappings[#newmappings+1] = fullinfo
                newstatus[filename].index[1] = #newmappings
            end
        else
            if trace_loading then
               logs.report("failed to load %s", filename)
            end
        end
    end
end

local function path_normalize(path)
    --[[
    path normalization:
    - a\b\c  -> a/b/c
    - a/../b -> b
    - /cygdrive/a/b -> a:/b
    --]]
    if os.type == "windows" or os.type == "msdos" or os.name == "cygwin" then
        path = path:gsub('\\', '/')
        path = path:lower()
        -- for cygwin cases...
        path = path:gsub('^/cygdrive/(%a)/', '%1:/')
    end
    path = file.collapse_path(path)
    return path
end

fonts.path_normalize = path_normalize

local function scan_dir(dirname, fontnames, newfontnames, texmf)
    --[[
    this function scans a directory and populates the list of fonts
    with all the fonts it finds.
    - dirname is the name of the directory to scan
    - names is the font database to fill
    - texmf is a boolean saying if we are scanning a texmf directory
    --]]
    local list, found = { }, { }
    local nbfound = 0
    for _,ext in ipairs { "otf", "ttf", "ttc", "dfont" } do
        if trace_search then
            logs.report("scanning '%s' for '%s' fonts", dirname, ext)
        end
        found = glob(dirname .. "/**." .. ext)
        -- note that glob fails silently on broken symlinks, which happens
        -- sometimes in TeX Live.
        if trace_search then
            logs.report("%s fonts found", #found)
        end
        nbfound = nbfound + #found
        table.append(list, found)
        if trace_search then
            logs.report("scanning '%s' for '%s' fonts", dirname, upper(ext))
        end
        found = glob(dirname .. "/**." .. upper(ext))
        table.append(list, found)
        nbfound = nbfound + #found
    end
    if trace_search then
        logs.report("%d fonts found in '%s'", nbfound, dirname)
    end
    for _,fnt in ipairs(list) do
        fnt = path_normalize(fnt)
        load_font(fnt, fontnames, newfontnames, texmf)
    end
end

local function scan_texmf_tree(fontnames, newfontnames)
    --[[
    The function that scans all fonts in the texmf tree, through kpathsea
    variables OPENTYPEFONTS and TTFONTS of texmf.cnf
    --]]
    if trace_progress then
        if expandpath("$OSFONTDIR"):is_empty() then
            logs.report("scanning TEXMF fonts:")
        else
            logs.report("scanning TEXMF and OS fonts:")
        end
    end
    local explored_dirs = {}
    local osdirs = expandpath("$OSFONTDIR")
    -- OPENTYPEFONTS and TTFONTS contain OSFONTDIR
    local fontdirs = expandpath("$OPENTYPEFONTS")
    fontdirs = fontdirs .. gsub(expandpath("$TTFONTS"), "^\.", "")
    if not fontdirs:is_empty() then
        fontdirs = splitpath(fontdirs)
        -- hack, don't scan current dir
        table.remove(fontdirs, 1)
        count = 0
        if osdirs and osdirs ~= '' then
            osdirs = splitpath(osdirs)
            -- we first scan the os dirs and have texmf=0 for scan_dir, and then
            -- we scan the true texmf dirs, with texmf=1. With explored_dirs, we
            -- won't explore a directory two times.
            for _,d in ipairs(osdirs) do
                if not explored_dirs[d] then
                    count = count + 1
                    progress(count, #fontdirs)
                    scan_dir(d, fontnames, newfontnames, false)
                    explored_dirs[d] = true
                end
            end
        end
        for _,d in ipairs(fontdirs) do
            if not explored_dirs[d] then
                count = count + 1
                progress(count, #fontdirs)
                scan_dir(d, fontnames, newfontnames, true)
                explored_dirs[d] = true
            end
        end
    end
end

local function read_fcdata(data)
    --[[
    this function takes raw data returned by fc-list, parses it, normalizes the
    paths and makes a list out of it.
    --]]
    local list = { }
    for line in data:lines() do
        line = line:gsub(": ", "")
        local ext = lower(match(line,"^.+%.([^/\\]-)$"))
        if ext == "otf" or ext == "ttf" or ext == "ttc" or ext == "dfont" then
            list[#list+1] = path_normalize(line:gsub(": ", ""))
        end
    end
    return list
end

--[[
  Under Mac OSX, fc-list does not exist and there is no guaranty that OSFONTDIR
  is correctly filled, so for now we use static paths.
]]

local static_osx_dirs = {
 "~/Library/Fonts",
 "/Library/Fonts",
 "/System/Library/Fonts",
 }

local function scan_os_fonts(fontnames, newfontnames)
    --[[
    This function scans the OS fonts through fontcache (fc-list), it executes
    only if OSFONTDIR is empty (which is the case under most Unix by default).
    If OSFONTDIR is non-empty, this means that the system fonts it contains have
    already been scanned, and thus we don't scan them again.
    --]]
    if expandpath("$OSFONTDIR"):is_empty() then 
        if trace_progress then
            logs.report("scanning OS fonts:")
        end
        -- under OSX, we don't rely on fc-list, we rely on some static
        -- directories instead
        if os.name == "macosx" then
            if trace_search then
                logs.report("searching in static system directories")
            end
            count = 0
            for _,d in ipairs(static_osx_dirs) do
                count = count + 1
                progress(count, #static_osx_dirs)
                scan_dir(d, fontnames, newfontnames, false)
            end
        else
            if trace_search then
                logs.report("executing 'fc-list : file' and parsing its result...")
            end
            local data = io.popen("fc-list : file", 'r')
            if data then
                local list = read_fcdata(data)
                data:close()
                if trace_search then
                    logs.report("%d fonts found", #list)
                end
                count = 0
                for _,fnt in ipairs(list) do
                    count = count + 1
                    progress(count, #list)
                    load_font(fnt, fontnames, newfontnames, false)
                end
            end
        end
    end
end

local function update(fontnames, force)
    --[[
    The main function, scans everything
    - fontnames is the final table to return
    - force is whether we rebuild it from scratch or not
    --]]
    if force then
        fontnames = fontnames_init()
    else
        if not fontnames or not fontnames.version or fontnames.version ~= names.version then
            fontnames = fontnames_init()
            if trace_search then
                logs.report("no font names database or old one found, generating new one")
            end
        end
    end
    local newfontnames = fontnames_init()
    scan_texmf_tree(fontnames, newfontnames)
    scan_os_fonts  (fontnames, newfontnames)
    return newfontnames
end

names.scan   = scan_dir
names.update = update

