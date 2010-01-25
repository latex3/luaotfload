luaotfload              = luaotfload or { }
luaotfload.fonts        = { }

luaotfload.fonts.module = {
    name          = "luaotfload.fonts",
    version       = 1.001,
    date          = "2010/01/12",
    description   = "luaotfload font database.",
    author        = "Khaled Hosny",
    copyright     = "Khaled Hosny",
    license       = "CC0"
}

kpse.set_program_name("luatex")

dofile(kpse.find_file("luaextra.lua"))

local upper, splitpath, expandpath, glob, basename = string.upper, file.split_path, kpse.expand_path, dir.glob, file.basename

luaotfload.fonts.basename   = "otfl-names.lua"
luaotfload.fonts.version    = 2.001
luaotfload.fonts.log_level  = 1

local function log(lvl, fmt, ...)
    if lvl <= luaotfload.fonts.log_level then
        texio.write_nl(string.format("luaotfload | %s", string.format(fmt,...)))
    end
end

function fontloader.fullinfo(...)
    local t = { }
    local f = fontloader.open(...)
    local m = f and fontloader.to_table(f)
    fontloader.close(f)
    if m.names then
        for _,v in pairs(m.names) do
            if v.lang == "English (US)" then
                t.names = {
                    -- see http://developer.apple.com/textfonts/TTRefMan/RM06/Chap6name.html
                    fullname       = v.names.compatfull     or v.names.fullname, -- 18, 4
                    family         = v.names.preffamilyname or v.names.family,   -- 17, 1
                    subfamily      = v.names.prefmodifiers  or v.names.subfamily,-- 16, 2
                    psname         = v.names.postscriptname --or t.fontname
                }
            end
        end
    end
    if m.fontstyle_name then
        for _,v in pairs(m.fontstyle_name) do
            if v.lang == 1033 then
                t.fontstyle_name = v.name
            end
        end
    end
    if m.pfminfo then
        t.pfminfo = {
            weight = m.pfminfo.weight,
            width  = m.pfminfo.width,
        }
    end
    t.fontname    = m.fontname
    t.fullname    = m.fullname
    t.familyname  = m.familyname
    t.filename    = m.origname
    t.weight      = m.weight
    t.italicangle = m.italicangle
    -- don't waste the space with zero values
    t.design_size         = m.design_size         ~= 0 and m.design_size         or nil
    t.design_range_bottom = m.design_range_bottom ~= 0 and m.design_range_bottom or nil
    t.design_range_top    = m.design_range_top    ~= 0 and m.design_range_top    or nil
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
                    if not families[fullinfo.names.family] then
                        families[fullinfo.names.family] = { }
                    end
                    table.insert(families[fullinfo.names.family], #mappings)
                end
            else
                local fullinfo = fontloader.fullinfo(filename)
                if texmf then
                    fullinfo.filename = basename(filename)
                end
                mappings[#mappings+1] = fullinfo
                if not families[fullinfo.names.family] then
                    families[fullinfo.names.family] = { }
                end
                table.insert(families[fullinfo.names.family], #mappings)
            end
        else
            log(1, "Failed to load %s", filename)
        end
    end
end

local function scan_dir(dirname, names, recursive, texmf)
    log(1, "Scanning directory %s", dirname)
    local list, found = { }, { }
    for _,ext in ipairs { "otf", "ttf", "ttc", "dfont" } do
        if recursive then pat = "/**." else pat = "/*." end
        log(2, "Scanning '%s' for '%s' fonts", dirname, ext)
        found = glob(dirname .. pat .. ext)
        log(2, "%s fonts found", #found)
        table.append(list, found)
        log(2, "Scanning '%s' for '%s' fonts", dirname, upper(ext))
        found = glob(dirname .. pat .. upper(ext))
        log(2, "%s fonts found", #found)
        table.append(list, found)
    end
    for _,fnt in ipairs(list) do
        load_font(fnt, names, texmf)
    end
end

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
log(1, "detecting system: %s", system)

local texmfdist = kpse.expand_var("$TEXMFDIST")
local texmfmain = kpse.expand_var("$TEXMFMAIN")
local texmflocal = kpse.expand_var("$TEXMFLOCAL")
-- We lowercase everything under Windows, in order to get a bit of consistency
if system == 'windows' or system == 'cygwin' then
    texmfdist = string.lower(texmfdist)
    texmfmain = string.lower(texmfmain)
    texmflocal = string.lower(texmflocal)
end


local function is_texmf(dir)
    if dir:find(texmfdist) or dir:find(texmfmain) or dir:find(texmflocal) then
        return true
    end
    return false
end

local function read_fcdata(fontdirs, data, translate)
    local to_add = nil
    local done = nil
    for line in data:lines() do
        if not done then done = true end
        local match = line:match("^Directory: (.+)")
        if match then
            if match:find("ype1") then
                to_add = nil
            else
                to_add = translate(match)
            end
        elseif to_add then
            match = line:match('^"[^"]+%.[^"]+"')
            if match then
                if to_add then
                    fontdirs[to_add] = true
                    to_add = nil
                end
            end
        end
    end
    if not done then
        return nil
    else
        return fontdirs
    end
end

local function cygwin_translate(name)
    local res = string.lower(io.popen(string.format("cygpath.exe --mixed %s", name)):read("*all"))
    -- a very strange thing: spaces are replaced by \n and there is a trailing \n at the end
    res = res:gsub("\n$", '')
    res = res:gsub("\n", ' ')
    return res
end

local function windows_translate(name)
    return string.lower(name)
end

local function no_translate(name)
    return name
end

local function append_fccatdirs(fontdirs)
    -- under cygwin we have the choice between the
    -- fc-cat of cygwin and the fc-cat of TeXLive.
    -- we try the fc-cat from TeXLive.
    local translate = no_translate
    if system == 'cygwin' then
        local path = kpse.expand_var("$TEXMFMAIN")..'/../bin/win32/fc-cat.exe'
        if lfs.isfile(path) then
            log(1, "executing `%s' -v\n", path)
            -- dirty hack...
            path = io.popen(string.format('cygpath.exe -C ANSI -w -s "%s"', path)):read("*all")
            local data = io.popen('"'..path..' -v"', 'r')
            local result = read_fcdata(fontdirs, data, windows_translate)
            data:close()
            if result then
                return result
            else
                log(1, "fail")
            end
        else
            log(1, "unable to find TeXLive's fc-cat.exe")
        end
        translate = cygwin_translate
    elseif system == 'windows' then
        translate = windows_translate
    end
    log(1, "executing `fc-cat -v'\n")
    local data = io.popen("fc-cat -v", 'r')
    local result = read_fcdata(fontdirs, data, translate)
    data:close()
    -- this part may be removed (needs further tests though, under non-cygwin Windows systems)
    if not result then
        log(1, "fail, now trying `fc-cat.exe -v'\n")
        data = io.popen("fc-cat.exe -v", 'r')
        result = read_fcdata(fontdirs, data, translate)
        data:close()
        if not result then
            log(1, "Unable to execute fc-cat nor fc-cat.exe, system fonts will not be available")
            return fontdirs
        end
    end
    return result
end

local function scan_all(names)
    local fontdirs = string.gsub(expandpath("$OPENTYPEFONTS"), "^\.[;:]", "")
    fontdirs = fontdirs .. string.gsub(expandpath("$TTFONTS"), "^\.", "")
    if system == 'windows' or system == 'cygwin' then
        fontdirs = string.lower(fontdirs)
    end
    if not fontdirs:is_empty() then
        fontdirs = splitpath(fontdirs)
        fontdirs = table.tohash(fontdirs)
        fontdirs = append_fccatdirs(fontdirs)
        for d,_ in pairs(fontdirs) do
            scan_dir(d, names, false, is_texmf(d))
        end
    end
end

local function generate()
    local fnames = {
        mappings = { },
        families = { },
        version  = luaotfload.fonts.version,
    }
    local savepath
    scan_all(fnames)
    log(1, "%s fonts in %s families saved in the database", #fnames.mappings, #table.keys(fnames.families))
    savepath = kpse.expand_var("$TEXMFVAR") .. "/tex/"
    if not file.isreadable(savepath) then
        log(1, "Creating directory %s", savepath)
        lfs.mkdir(savepath)
    end
    if not file.iswritable(savepath) then
        log(1, "Error: cannot write in directory %s\n", savepath)
    else
        savepath = savepath .. luaotfload.fonts.basename
        io.savedata(savepath, table.serialize(fnames, true))
        log(1, "Saved font names database in %s\n", savepath)
    end
end

luaotfload.fonts.scan     = scan_dir
luaotfload.fonts.generate = generate

if arg[0] == "luaotfload-fonts.lua" then
    generate()
end

