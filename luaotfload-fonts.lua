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

local splitpath, expandpath, glob, basename = file.split_path, kpse.expand_path, dir.glob, file.basename
local upper, format, rep = string.upper, string.format, string.rep

luaotfload.fonts.basename   = "otfl-names.lua"
luaotfload.fonts.version    = 2.002
luaotfload.fonts.log_level  = 1

local lastislog = 0

local function log(lvl, fmt, ...)
    if lvl <= luaotfload.fonts.log_level then
        lastislog = 1
        texio.write_nl(format("luaotfload | %s", format(fmt,...)))
    end
end

local function progress(current, total)
    if luaotfload.fonts.log_level == 1 then
--      local width   = os.getenv("COLUMNS") -2 --doesn't work
        local width   = 78
        local percent = current/total
        local gauge   = format("[%s]", rep(" ", width))
        if percent > 0 then
            done  = (width * percent) >= 1 and (width * percent) or 1
            gauge = format("[%s>%s]", rep("=", done - 1), rep(" ", width - done))
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

local function scan_dir(dirname, names, recursive, texmf)
    log(2, "Scanning directory %s", dirname)
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

local function scan_texmf_tree(names)
    log(1, "Scanning TEXMF fonts:")
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
                scan_dir(d, names, false, true)
                explored_dirs[d] = true
            end
        end
    end
end

local function read_fcdata(data)
    local list = { }
    for line in data:lines() do
        line = line:gsub(": ", "")
        local ext = string.lower(string.match(line,"^.+%.([^/\\]-)$"))
        if ext == "otf" or ext == "ttf" or ext == "ttc" or ext == "dfont" then
            list[#list+1] = line:gsub(": ", "")
        end
    end
    return list
end

local function scan_os_fonts(names)
    if expandpath("$OSFONTDIR"):is_empty() then 
        log(1, "Scanning system fonts:")
        log(2, "Executing 'fc-list : file'")
        local data = io.popen("fc-list : file", 'r')
        local list = read_fcdata(data)
        data:close()
        count = 0
        for _,fnt in ipairs(list) do
            count = count + 1
            progress(count, #list)
            load_font(fnt, names, texmf)
        end
    end
end

local function generate()
    texio.write("luaotfload | Generating font names database.")
    local fnames = {
        mappings = { },
        families = { },
        version  = luaotfload.fonts.version,
    }
    local savepath
    scan_texmf_tree(fnames)
    scan_os_fonts  (fnames)
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

