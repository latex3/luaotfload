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

if status and status.luatex_version and status.luatex_version > 44 then
    require("luaextra.lua")
else
    dofile(kpse.find_file("luaextra.lua"))
end

local upper, splitpath, expandpath, glob, basename = string.upper, file.split_path, kpse.expand_path, dir.glob, file.basename

luaotfload.fonts.basename   = "otfl-names.lua"
luaotfload.fonts.version    = 2.000
luaotfload.fonts.log_level  = 1

local function info(fmt,...)
    texio.write_nl(string.format("luaotfload | %s", string.format(fmt,...)))
end

local function log(lvl, ...)
    if lvl <= luaotfload.fonts.log_level then
        info(...)
    end
end

local function sanitize(str)
    return string.gsub(string.lower(str), "[^%a%d]", "")
end

function fontloader.fullinfo(...)
    local t, n = { }, { }
    local f = fontloader.open(...)
    local m = f and fontloader.to_table(f)
    fontloader.close(f)
    if m.names then
        for _,v in pairs(m.names) do
            if v.lang == "English (US)" then
                n.name   = v.names.compatfull     or v.names.fullname
                n.family = v.names.preffamilyname or v.names.family
                n.style  = v.names.prefmodifiers  or v.names.subfamily
            end
        end
    end
    if m.fontstyle_name then
        for _,v in pairs(m.fontstyle_name) do
            if v.lang == 1033 then
                m.style = v.name
            end
        end
    end
    t.psname   = m.fontname
    t.fullname = n.name   or m.fullname
    t.family   = n.family or m.familyname
    t.style    = n.style  or m.style
    for k,v in pairs(t) do
        t[k] = sanitize(v)
    end
    m, n = nil, nil
    return t
end

-- table containing hard to guess styles
local styles = {
    calibrii = "italic",
    bookosi = "italic",
    bookosb = "bold",
    lsansi = "italic",
    antquab = "bold",
    antquai = "italic",
    }

-- euristics to normalize the style
local function normalize_style(style, family)
    local s = {}
    if style:find("semibold") or style:find("demibold") or style:find("medium")
            or style:find("lightbold") or style:match("lb$") then
        s.weight = "demibold"
    elseif style:find("bold") or style:find("heavy") or style:match("xb$")
            or style:match("bd$") or style:match("bb$") then
        s.weight = "bold"
    elseif style:find("light") or style:find("narrow") then
        s.weight = "narrow" -- ?
    end
    if style:find("italic") or style:find("oblique")  or style:match("it$") then
        s.italic = true
    end
    if style:find("regular") or style:match("rg$") then
        s.regular = true
    end
    local size = tonumber(string.match(style, "%d+"))
    if size and size > 4 and size < 25 then 
        s.size = size
    end
    if not next(s) then -- more aggressive guessing
        local truncated = style:sub(1,-2)
        local endletter = style:sub(-1, -1)
        if family:find(truncated) and family:sub(-1,-1) ~= endletter then 
            if endletter =='b' then
                s.weight = "bold"
            elseif endletter == 'i' then
                s.italic = true
            end
        end
    end
    if not next(s) and styles[style] then
        return styles[style]
    end
    if not next(s) then
        return style -- or "regular ?"
    else
        local result = ""
        if s.weight then
            result = s.weight
        end
        if s.italic then
            result = result.."italic"
        end
        if not s.italic and not s.weight then
            result = "regular"
        end
        if s.size then
            result = result.."-"..s.size
        end
        return result
    end
end

local function load_font(filename, names, texmf)
    log(3, "Loading font %s", filename)
    local psnames, families = names.mappings.psnames, names.mappings.families
    if filename then
        local info = fontloader.info(filename)
        if info then
            if type(info) == "table" and #info > 1 then
                for index,_ in ipairs(info) do
                    local fullinfo = fontloader.fullinfo(filename, index-1)
                    if not families[fullinfo.family] then
                        families[fullinfo.family] = { }
                    end
                    families[fullinfo.family][fullinfo.style] = {texmf and basename(filename) or filename, index-1}
                    psnames[fullinfo.psname] = {texmf and basename(filename) or filename, index-1}
                end
            else
                local fullinfo = fontloader.fullinfo(filename)
                if texmf == true then
                    filename = basename(filename)
                end
                if not families[fullinfo.family] then
                    families[fullinfo.family] = { }
                end
                if not fullinfo.style then
                    fullinfo.style = sanitize(file.nameonly(filename))
                end
                fullinfo.style = normalize_style(fullinfo.style, fullinfo.family)
                families[fullinfo.family][fullinfo.style] = {texmf and basename(filename) or filename}
                psnames[fullinfo.psname] = {texmf and basename(filename) or filename}
            end
        else
            log("Failed to load %s", filename)
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

--[[
local function scan_os_fonts(names)
    local fontdirs
    fontdirs = expandpath("$OSFONTDIR")
    if not fontdirs:is_empty() then
        fontdirs = splitpath(fontdirs, ":")
        for _,d in ipairs(fontdirs) do
            scan_dir(d, names, true)
        end
    end
end
--]]

local function scan_txmf_tree(names)
    local fontdirs = expandpath("$OPENTYPEFONTS")
    fontdirs = fontdirs .. string.gsub(expandpath("$TTFONTS"), "^\.", "")
    if not fontdirs:is_empty() then
        local explored_dirs = {}
        fontdirs = splitpath(fontdirs)
        for _,d in ipairs(fontdirs) do
            if not explored_dirs[d] then
                scan_dir(d, names, false, true)
                explored_dirs[d] = true
            end
        end
    end
end

local function generate()
    local fnames = {
        mappings = {
            families = { },
            psnames  = { },
        },
        version  = luaotfload.fonts.version
    }
    local savepath
    scan_txmf_tree(fnames)
    info("%s fonts saved in the database", #table.keys(fnames.mappings.psnames))
    savepath = kpse.expand_var("$TEXMFVAR") .. "/tex/"
    if not file.isreadable(savepath) then
        log(1, "Creating directory %s", savepath)
        lfs.mkdir(savepath)
    end
    if not file.iswritable(savepath) then
        info("Error: cannot write in directory %s\n", savepath)
    else
        savepath = savepath .. luaotfload.fonts.basename
        io.savedata(savepath, table.serialize(fnames, true))
        info("Saved font names database in %s\n", savepath)
    end
end

luaotfload.fonts.scan     = scan_dir
luaotfload.fonts.generate = generate

if arg[0] == "luaotfload-fonts.lua" then
    generate()
end
