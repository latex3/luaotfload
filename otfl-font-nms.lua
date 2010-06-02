if not modules then modules = { } end modules ['font-nms'] = {
    version   = 1.002,
    comment   = "companion to luaotfload.lua",
    author    = "Khaled Hosny and Elie Roux",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2"
}

-- This is a patch for otfl-font-def.lua, that defines a reader for ofm fonts,
-- this is necessary if we set the forced field of the specification to 'ofm'
-- we use it only when using luaotfload, not mkluatexfontdb.
if fonts and fonts.tfm and fonts.tfm.readers then
    fonts.tfm.readers.ofm = fonts.tfm.readers.tfm
end

-- This is a necessary initalization in order not to rebuild an existing font.
-- Maybe 600 should be replaced by \pdfpkresolution
-- or texconfig.pk_dpi (and it should be replaced dynamically), but we don't
-- have access (yet) to the texconfig table, so we let it be 600. Anyway, it
-- does still work fine even if \pdfpkresolution is changed.
kpse.init_prog('', 600, '/')

fonts                = fonts       or { }
fonts.names          = fonts.names or { }

local names          = fonts.names
local names_dir      = "/luatex/generic/luaotfload/names/"
names.version        = 2.009 -- not the same as in context
names.data           = nil
names.path           = {
    basename  = "otfl-names.lua",
    localdir  = kpse.expand_var("$TEXMFVAR")    .. names_dir,
    systemdir = kpse.expand_var("$TEXMFSYSVAR") .. names_dir,
}


local splitpath, expandpath = file.split_path, kpse.expand_path
local glob, basename        = dir.glob, file.basename
local upper, lower, format  = string.upper, string.lower, string.format
local gsub, match, rpadd    = string.gsub, string.match, string.rpadd
local gmatch, sub, find     = string.gmatch, string.sub, string.find
local utfgsub               = unicode.utf8.gsub

local trace_short    = false --tracing adapted to rebuilding of the database inside a document
local trace_progress = true  --trackers.register("names.progress", function(v) trace_progress = v end)
local trace_search   = false --trackers.register("names.search",   function(v) trace_search   = v end)
local trace_loading  = false --trackers.register("names.loading",  function(v) trace_loading  = v end)


-- Basic function from <http://stackoverflow.com/questions/2282444/how-to-check-if-a-table-contains-an-element-in-lua>
function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end


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
    -- this sets the output of the database building accordingly.
    names.set_log_level(-1)
    local localpath  = names.path.localdir  .. names.path.basename
    local systempath = names.path.systemdir .. names.path.basename
    local kpsefound  = kpse.find_file(names.path.basename)
    local foundname
    local data
    if kpsefound and file.isreadable(kpsefound) then
        data = dofile(kpsefound)
	foundname = kpsefound
    elseif file.isreadable(localpath)  then
        data = dofile(localpath)
	foundname = localpath
    elseif file.isreadable(systempath) then
        data = dofile(systempath)
	foundname = systempath
    end
    if data then
        logs.info("load font",
            "loaded font names database: %s", foundname)
    else
        logs.info("load font",
            "no font names database found, generating new one")
        data = names.update()
        names.save(data)
    end
    return data
end

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

local loaded   = false
local reloaded = false

function names.resolve(specification)
    local name  = sanitize(specification.name)
    local style = sanitize(specification.style) or "regular"

    local size
    if specification.optsize then
        size = tonumber(specification.optsize)
    elseif specification.size then
        size = specification.size / 65536
    end


    if not loaded then
        names.data = names.load()
        loaded     = true
    end

    local data = names.data
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
            -- no font found so far
            if not reloaded then
                -- try reloading the database
                names.data = names.update(names.data)
                names.save(names.data)
                reloaded   = true
                return names.resolve(specification)
            else
                -- else, fallback to filename
                return specification.name, false
            end
        end
    else
        if not reloaded then
            names.data = names.update()
            names.save(names.data)
            reloaded   = true
            return names.resolve(specification)
        else
            return specification.name, false
        end
    end
end

names.resolvespec = names.resolve

function names.set_log_level(level)
    if level == -1 then
        trace_progress = false
        trace_short = true
    elseif level == 2 then
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
logs.info   = logs.info or log

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
	    if trace_loading then
        	logs.report("error: failed to open %s", filename)
	    end
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
    local basefile    = texmf and basename(filename) or filename
    if filename then
        local timestamp, db_timestamp
        db_timestamp        = status[basefile] and status[basefile].timestamp
        timestamp           = lfs.attributes(filename, "modification")

        local index_status = newstatus[basefile] or (not texmf and newstatus[basename(filename)])
        if index_status and index_status.timestamp == timestamp then
            -- already indexed this run
            return
        end

        newstatus[basefile] = newstatus[basefile] or { }
        newstatus[basefile].timestamp = timestamp
        newstatus[basefile].index     = newstatus[basefile].index or { }

        if db_timestamp == timestamp and not newstatus[basefile].index[1] then
            for _,v in ipairs(status[basefile].index) do
                local index = #newstatus[basefile].index
                newmappings[#newmappings+1]        = mappings[v]
                newstatus[basefile].index[index+1] = #newmappings
            end
            if trace_loading then
                logs.report("font already indexed: %s", basefile)
            end
            return
        end
        if trace_loading then
            logs.report("loading font: %s", basefile)
        end
        local info = fontloader.info(filename)
        if info then
            if type(info) == "table" and #info > 1 then
                for i in ipairs(info) do
                    local fullinfo = font_fullinfo(filename, i-1, texmf)
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
            if trace_loading then
               logs.report("failed to load %s", basefile)
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
        - reading symlinks under non-Win32
        - using kpse.readable_file on Win32
    --]]
    if os.type == "windows" or os.type == "msdos" or os.name == "cygwin" then
--      path = kpse.readable_file(path)
        path = path:gsub('\\', '/')
        path = path:lower()
        path = path:gsub('^/cygdrive/(%a)/', '%1:/')
    end
    if os.type ~= "windows" and os.type ~= "msdos" then
        local dest = lfs.readlink(path)
        if dest then
            if kpse.readable_file(dest) then
                path = dest
            elseif kpse.readable_file(file.join(file.dirname(path), dest)) then
                path = file.join(file.dirname(path), dest)
            else
                -- broken symlink?
            end
        end
    end
    path = file.collapse_path(path)
    return path
end

fonts.path_normalize = path_normalize

if os.name == "macosx" then
    -- While Mac OS X 10.6 has a problem with TTC files, ignore them globally:
    font_extensions = { "otf", "ttf", "dfont" }
else
    font_extensions = { "otf", "ttf", "ttc", "dfont" }
end

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
    if trace_search then
        logs.report("scanning '%s'", dirname)
    end
    for _,i in next, font_extensions do
        for _,ext in next, { i, upper(i) } do
            found = glob(format("%s/**.%s$", dirname, ext))
            -- note that glob fails silently on broken symlinks, which happens
            -- sometimes in TeX Live.
            if trace_search then
                logs.report("%s '%s' fonts found", #found, ext)
            end
            nbfound = nbfound + #found
            table.append(list, found)
        end
    end
    if trace_search then
        logs.report("%d fonts found in '%s'", nbfound, dirname)
    end
    list = remove_ignore_fonts(list) -- fixme: general solution required
    for _,fnt in ipairs(list) do
        fnt = path_normalize(fnt)
        load_font(fnt, fontnames, newfontnames, texmf)
    end
end

-- Temporary until a general solution is implemented:
if os.name == "macosx" then
    ignore_fonts = {
      -- this font kills the indexer:
      "/System/Library/Fonts/LastResort.ttf"
    }
    function remove_ignore_fonts(fonts)
        for N,fnt in ipairs(fonts) do
            if table.contains(ignore_fonts,fnt) then
                if trace_search then
                	logs.report("ignoring font '%s'", fnt)
                end
                table.remove(fonts,N)
            end
        end
        return fonts
    end
-- This function is only necessary, for now, on Mac OS X.
else
    function remove_ignore_fonts(fonts)
        return fonts
    end
end

local function scan_texmf_fonts(fontnames, newfontnames)
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
    elseif trace_short then
        if expandpath("$OSFONTDIR"):is_empty() then
            logs.info("scanning TEXMF fonts...")
        else
            logs.info("scanning TEXMF and OS fonts...")
        end
    end
    local fontdirs = expandpath("$OPENTYPEFONTS"):gsub("^\.", "")
    fontdirs = fontdirs .. expandpath("$TTFONTS"):gsub("^\.", "")
    if not fontdirs:is_empty() then
        fontdirs = splitpath(fontdirs)
        count = 0
        for _,d in ipairs(fontdirs) do
            count = count + 1
            progress(count, #fontdirs)
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

--[[
  This function parses /etc/fonts/fonts.conf and returns all the dir it finds.
  The code is minimal, please report any error it may generate.
]]

local function read_fonts_conf(path, results)
    local f = io.open(path)
    if not f then
        error("Cannot open the file "..path)
    end
    local incomments = false
    for line in f:lines() do
        while line and line ~= "" do
            -- spaghetti code... hmmm...
            if incomments then
                local tmp = find(line, '-->')
                if tmp then
                    incomments = false
                    line = sub(line, tmp+3)
                else
                    line = nil
                end
            else
                local tmp = find(line, '<!--')
                local newline = line
                if tmp then
                    -- for the analysis, we take everything that is before the
                    -- comment sign
                    newline = sub(line, 1, tmp-1)
                    -- and we loop again with the comment
                    incomments = true
                    line = sub(line, tmp+4)
                else
                    -- if there is no comment start, the block after that will
                    -- end the analysis, we exit the while loop
                    line = nil
                end
                for dir in gmatch(newline, '<dir>([^<]+)</dir>') do
                    -- now we need to replace ~ by kpse.expand_path('~')
                    if sub(dir, 1, 1) == '~' then
                        dir = kpse.expand_path('~') .. sub(dir, 2)
                    end
                    -- we exclude paths with texmf in them, as they should be
                    -- found anyway
                    if not find(dir, 'texmf') then
                        results[#results+1] = dir
                    end
                end
                for include in gmatch(newline, '<include[^<]*>([^<]+)</include>') do
                    -- include here can be four things: a directory or a file,
                    -- in absolute or relative path.
                    if sub(include, 1, 1) == '~' then
                        include = kpse.expand_path('~') .. sub(include, 2)
                        -- First if the path is relative, we make it absolute:
                    elseif not lfs.isfile(include) and not lfs.isdir(include) then
                        include = file.join(file.dirname(path), include)
                    end
                    if lfs.isfile(include) then
                        -- maybe we should prevent loops here?
                        -- we exclude path with texmf in them, as they should
                        -- be found otherwise
                        read_fonts_conf(include, results)
                    elseif lfs.isdir(include) then
                        if sub(include, -1, 0) ~= "/" then
                            include = include.."/"
                        end
                        found = glob(include.."*.conf")
                        for _, f in ipairs(found) do
                            read_fonts_conf(f, results)
                        end
                    end
                end
            end
        end
    end
    f:close()
    return results
end

-- for testing purpose
names.read_fonts_conf = read_fonts_conf

local function get_os_dirs()
    if os.name == 'macosx' then
        return {
            kpse.expand_path('~') .. "/Library/Fonts",
            "/Library/Fonts",
            "/System/Library/Fonts",
            "/Network/Library/Fonts",
        }
    elseif os.type == "windows" or os.type == "msdos" or os.name == "cygwin" then
        local windir = os.getenv("WINDIR")
        return {windir..'\\Fonts',}
    else
        return read_fonts_conf("/etc/fonts/fonts.conf", {})
    end
end

local function scan_os_fonts(fontnames, newfontnames)
    --[[
    This function scans the OS fonts through
      - fontcache for Unix (reads the fonts.conf file and scans the directories)
      - a static set of directories for Windows and MacOSX
    --]]
    if trace_progress then
        logs.report("scanning OS fonts:")
    elseif trace_short then
        logs.info("scanning OS fonts...")
    end
    if trace_search then
        logs.info("searching in static system directories...")
    end
    count = 0
    local os_dirs = get_os_dirs()
    for _,d in ipairs(os_dirs) do
        count = count + 1
        progress(count, #os_dirs)
        scan_dir(d, fontnames, newfontnames, false)
    end
end

local function update_names(fontnames, force)
    --[[
    The main function, scans everything
    - fontnames is the final table to return
    - force is whether we rebuild it from scratch or not
    --]]
    if trace_short then
        logs.info("Updating the font names database:")
    end
    if force then
        fontnames = fontnames_init()
    else
        if not fontnames
        or not fontnames.version
        or fontnames.version ~= names.version then
            fontnames = fontnames_init()
            if trace_search then
                logs.report("no font names database or old one found, "
                          .."generating new one")
            end
        end
    end
    local newfontnames = fontnames_init()
    scan_texmf_fonts(fontnames, newfontnames)
    if expandpath("$OSFONTDIR"):is_empty() then
        scan_os_fonts(fontnames, newfontnames)
    end
    return newfontnames
end

local function save_names(fontnames)
    local savepath  = names.path.localdir
    if not lfs.isdir(savepath) then
        dir.mkdirs(savepath)
    end
    io.savedata(savepath .. names.path.basename,
                table.serialize(fontnames, true))
end

names.scan   = scan_dir
names.update = update_names
names.save   = save_names
