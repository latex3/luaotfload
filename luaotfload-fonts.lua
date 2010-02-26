-- This lua script is made to generate the font database for LuaTeX, in order
-- for it to be able to load a font according to its name, like XeTeX does.
--
-- It is part of the luaotfload bundle, see luaotfload's README for legal
-- notice.

-- some usual initializations
luaotfload              = luaotfload or { }
luaotfload.fonts        = { }

luaotfload.fonts.module = {
    name          = "luaotfload.fonts",
    version       = 1.001,
    date          = "2010/01/12",
    description   = "luaotfload font database.",
    author        = "Khaled Hosny and Elie Roux",
    copyright     = "Luaotfload Development Team",
    license       = "CC0"
}

kpse.set_program_name("luatex")

local luaextra_file = kpse.find_file("luaextra.lua")
if not luaextra_file then
    texio.write_nl("Error: cannot find 'luaextra.lua', exiting.")
    os.exit(1)
end
dofile(luaextra_file)

local splitpath, expandpath, glob, basename = file.split_path, kpse.expand_path, dir.glob, file.basename
local upper, format, rep = string.upper, string.format, string.rep

-- the file name of the font database
luaotfload.fonts.basename   = "otfl-names.lua"

-- the directory in which the database will be saved, can be overwritten
luaotfload.fonts.directory = kpse.expand_var("$TEXMFVAR") .. "/tex/"

-- the version of the database, to be checked by the lookup function of
-- luaotfload
luaotfload.fonts.version    = 2.002

-- Log facilities:
-- - level 0 is quiet
-- - level 1 is the progress bar
-- - level 2 prints the searched directories
-- - level 3 prints all the loaded fonts
-- - level 4 prints all informations when searching directories (debug only)
luaotfload.fonts.log_level  = 1

local lastislog = 0

local function log(lvl, fmt, ...)
    if lvl <= luaotfload.fonts.log_level then
        lastislog = 1
        texio.write_nl(format("luaotfload | %s", format(fmt,...)))
    end
end

-- The progress bar
local function progress(current, total)
    if luaotfload.fonts.log_level == 1 then
--      local width   = os.getenv("COLUMNS") -2 --doesn't work
        local width   = 78
        local percent = current/total
        local gauge   = format("[%s]", string.rpadd(" ", width, " "))
        if percent > 0 then
            local done = string.rpadd("=", (width * percent) - 1, "=") .. ">"
            gauge = format("[%s]", string.rpadd(done, width, " ") )
        end
        if percent == 1 then
            gauge = gauge .. "\n"
        end
        if lastislog == 1 then
            texio.write_nl("")
            lastislog = 0
        end
        io.stderr:write("\r"..gauge)
        io.stderr:flush()
    end
end

function fontloader.fullinfo(...)
    local t = { }
    local f = fontloader.open(...)
    local m = f and fontloader.to_table(f)
    fontloader.close(f)
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
                    -- see http://developer.apple.com/textfonts/TTRefMan/RM06/Chap6name.html
                    fullname       = v.names.compatfull     or v.names.fullname, -- 18, 4
                    family         = v.names.preffamilyname or v.names.family,   -- 17, 1
                    subfamily      = t.fontstyle_name       or v.names.prefmodifiers  or v.names.subfamily, -- opt. style, 16, 2
                    psname         = v.names.postscriptname --or t.fontname
                }
            end
        end
    end
    t.fontname    = m.fontname
    t.fullname    = m.fullname
    t.familyname  = m.familyname
    t.filename    = m.origname
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

local function load_font(filename, names, texmf)
    log(3, "Loading font %s", filename)
    local mappings = names.mappings
    local families = names.families
    if filename then
        local info = fontloader.info(filename)
        if info then
            if type(info) == "table" and #info > 1 then
                for index,_ in ipairs(info) do
                    local fullinfo = fontloader.fullinfo(filename, index-1)
                    if texmf then
                        fullinfo.filename = basename(filename)
                    end
                    mappings[#mappings+1] = fullinfo
                    if fullinfo.names.family then
                        if not families[fullinfo.names.family] then
                            families[fullinfo.names.family] = { }
                        end
                        table.insert(families[fullinfo.names.family], #mappings)
                    else
                        log(3, "Warning: font with broken names table: %s, ignored", filename)
                    end
                end
            else
                local fullinfo = fontloader.fullinfo(filename)
                if texmf then
                    fullinfo.filename = basename(filename)
                end
                mappings[#mappings+1] = fullinfo
                if fullinfo.names.family then
                    if not families[fullinfo.names.family] then
                        families[fullinfo.names.family] = { }
                    end
                    table.insert(families[fullinfo.names.family], #mappings)
                else
                    log(3, "Warning: font with broken names table: %s, ignored", filename)
                end
            end
        else
            log(1, "Failed to load %s", filename)
        end
    end
end

-- We need to detect the OS (especially cygwin) to convert paths.
local system = LUAROCKS_UNAME_S or io.popen("uname -s"):read("*l")
if system then
    if system:match("^CYGWIN") then
        system = 'cygwin'
    elseif system:match("^Windows") then
        system = 'windows'
    else
        system = 'unix'
    end
else
    system = 'unix' -- ?
end
log(2, "Detecting system: %s", system)

-- path normalization:
-- - a\b\c  -> a/b/c
-- - a/../b -> b
-- - /cygdrive/a/b -> a:/b
local function path_normalize(path)
    if system ~= 'unix' then
        path = path:gsub('\\', '/')
        path = path:lower()
    end
    path = file.collapse_path(path)
    if system == "cygwin" then
        path = path:gsub('^/cygdrive/(%a)/', '%1:/')
    end
    return path
end

-- this function scans a directory and populates the list of fonts
-- with all the fonts it finds.
-- - dirname is the name of the directory to scan
-- - names is the font database to fill
-- - recursive is whether we scan all directories recursively (always false
--       in this script)
-- - texmf is a boolean saying if we are scanning a texmf directory (always
--       true in this script)
-- - scanned_fonts contains the list of alread scanned fonts, in order for them
--       not to be scanned twice. The function populates this list with the
--       fonts it scans.
local function scan_dir(dirname, names, recursive, texmf, scanned_fonts)
    local list, found = { }, { }
    local nbfound = 0
    for _,ext in ipairs { "otf", "ttf", "ttc", "dfont" } do
        if recursive then pat = "/**." else pat = "/*." end
        log(4, "Scanning '%s' for '%s' fonts", dirname, ext)
        found = glob(dirname .. pat .. ext)
        -- note that glob fails silently on broken symlinks, which happens
        -- sometimes in TeX Live.
        log(4, "%s fonts found", #found)
        nbfound = nbfound + #found
        table.append(list, found)
        log(4, "Scanning '%s' for '%s' fonts", dirname, upper(ext))
        found = glob(dirname .. pat .. upper(ext))
        table.append(list, found)
        nbfound = nbfound + #found
    end
    log(2, "%d fonts found in '%s'", nbfound, dirname)
    for _,fnt in ipairs(list) do
        fnt = path_normalize(fnt)
        if not scanned_fonts[fnt] then
            load_font(fnt, names, texmf)
            scanned_fonts[fnt] = true
        end
    end
end

-- The function that scans all fonts in the texmf tree, through kpathsea
-- variables OPENTYPEFONTS and TTFONTS of texmf.cnf
local function scan_texmf_tree(names)
    if expandpath("$OSFONTDIR"):is_empty() then
        log(1, "Scanning TEXMF fonts:")
    else
        log(1, "Scanning TEXMF and OS fonts:")
    end
    local scanned_fonts = {}
    local fontdirs = expandpath("$OPENTYPEFONTS")
    fontdirs = fontdirs .. string.gsub(expandpath("$TTFONTS"), "^\.", "")
    if not fontdirs:is_empty() then
        local explored_dirs = {}
        fontdirs = splitpath(fontdirs)
        -- hack, don't scan current dir
        table.remove(fontdirs, 1)
        count = 0
        for _,d in ipairs(fontdirs) do
            if not explored_dirs[d] then
                count = count + 1
                progress(count, #fontdirs)
                scan_dir(d, names, false, true, scanned_fonts)
                explored_dirs[d] = true
            end
        end
    end
    return scanned_fonts
end

-- this function takes raw data returned by fc-list, parses it, normalizes the
-- paths and makes a list out of it.
local function read_fcdata(data)
    local list = { }
    for line in data:lines() do
        line = line:gsub(": ", "")
        local ext = string.lower(string.match(line,"^.+%.([^/\\]-)$"))
        if ext == "otf" or ext == "ttf" or ext == "ttc" or ext == "dfont" then
            list[#list+1] = path_normalize(line:gsub(": ", ""))
        end
    end
    return list
end

-- This function scans the OS fonts through fontcache (fc-list), it executes
-- only if OSFONTDIR is empty (which is the case under most Unix by default).
-- If OSFONTDIR is non-empty, this means that the system fonts it contains have
-- already been scanned, and thus we don't scan them again.
local function scan_os_fonts(names, scanned_fonts)
    if expandpath("$OSFONTDIR"):is_empty() then 
        log(1, "Scanning system fonts:")
        log(2, "Executing 'fc-list : file'")
        local data = io.popen("fc-list : file", 'r')
        log(2, "Parsing the result...")
        local list = read_fcdata(data)
        data:close()
        log(2, "%d fonts found", #list)
        log(2, "Scanning...", #list)
        count = 0
        for _,fnt in ipairs(list) do
            count = count + 1
            progress(count, #list)
            if not scanned_fonts[fnt] then
                load_font(fnt, names, false)
                scanned_fonts[fnt] = true
            end
        end
    end
end

-- The main function, scans everything and writes the file.
local function generate()
    texio.write("luaotfload | Generating font names database.")
    local fnames = {
        mappings = { },
        families = { },
        version  = luaotfload.fonts.version,
    }
    local savepath = luaotfload.fonts.directory
    savepath = path_normalize(savepath)
    if not lfs.isdir(savepath) then
        log(1, "Creating directory %s", savepath)
        lfs.mkdir(savepath)
        if not lfs.isdir(savepath) then
            texio.write_nl(string.format("Error: cannot create directory '%s', exiting.\n", savepath))
            os.exit(1)
        end
    end
    savepath = savepath .. '/' .. luaotfload.fonts.basename
    local fh = io.open(savepath, 'wb')
    if not fh then
        texio.write_nl(string.format("Error: cannot write file '%s', exiting.\n", savepath))
        os.exit(1)
    end
    fh:close()
    -- we save the scanned fonts in a variable in order for scan_os_fonts 
    -- not to rescan them
    local scanned_fonts = scan_texmf_tree(fnames)
    scan_os_fonts  (fnames, scanned_fonts)
    log(1, "%s fonts in %s families saved in the database", 
        #fnames.mappings, #table.keys(fnames.families))
    io.savedata(savepath, table.serialize(fnames, true))
    log(1, "Saved font names database in %s\n", savepath)
end

luaotfload.fonts.scan     = scan_dir
luaotfload.fonts.generate = generate

if arg[0] == "luaotfload-fonts.lua" then
    generate()
end
