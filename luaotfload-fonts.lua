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

require("luaextra.lua")
require("otfl-luat-dum.lua")

local upper, splitpath, expandpath, glob, basename = string.upper, file.split_path, kpse.expand_path, dir.glob, file.basename

luaotfload.fonts.basename = "otfl-names.lua"
luaotfload.fonts.version  = 1.001
luaotfload.fonts.log      = false

local function log(...)
    if luaotfload.fonts.log then
        logs.simple(...)
    end
end

local function info(...)
    logs.simple(...)
end

local function clean(str)
    return string.gsub(string.lower(str), "[^%a%d]", "")
end

local function load_font(filename, names, texmf)
    local mappings = names.mappings
    local key
    if filename then
        local info = fontloader.info(filename)
        if texmf == true then filename = basename(filename) end
        if info then
            if type(info) == "table" and #info > 1 then
                for index,sub in ipairs(info) do
                    key = clean(sub.fullname)
                    if not mappings[key] then
                        mappings[key] = { sub.fullname, filename, index }
                    else
                        log("Font '%s' already exists.", key)
                    end
                end
            else
                key = clean(info.fullname)
                if not mappings[key] then
                    mappings[key] = { info.fullname, filename }
                else
                    log("Font '%s' already exists.", key)
                end
            end
        else
            log("Failed to load %s", filename)
        end
    end
end

local function scan_dir(dirname, names, recursive, texmf)
    local list, found = { }, { }
    for _,ext in ipairs { "otf", "ttf", "ttc", "dfont" } do
        if recursive then pat = "/**." else pat = "/*." end
        log("Scanning '%s' for '%s' fonts", dirname, ext)
        found = glob(dirname .. pat .. ext)
        log("%s fonts found", #found)
        table.append(list, found)

        log("Scanning '%s' for '%s' fonts", dirname, upper(ext))
        found = glob(dirname .. pat .. upper(ext))
        log("%s fonts found", #found)
        table.append(list, found)
    end
    for _,fnt in ipairs(list) do
        load_font(fnt, names, texmf)
    end
end

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

local function scan_txmf_tree(names)
    local fontdirs = expandpath("$OPENTYPEFONTS")
    fontdirs = fontdirs .. expandpath("$TTFONTS")
    if not fontdirs:is_empty() then
        fontdirs = splitpath(fontdirs, ":")
        for _,d in ipairs(fontdirs) do
            scan_dir(d, names, false, true)
        end
    end
end

local function generate()
    local fnames = {
        mappings = { },
        version  = luaotfload.fonts.version
    }
    local savepath
    scan_os_fonts(fnames)
    scan_txmf_tree(fnames)
    logs.simple("%s fonts saved in the database", #table.keys(fnames.mappings))
    savepath = kpse.expand_var("$TEXMFVAR") .. "/tex/"
    lfs.mkdir(savepath)
    savepath = savepath .. luaotfload.fonts.basename
    io.savedata(savepath, table.serialize(fnames, true))
    logs.simple("Saved font names database in %s\n", savepath)
end

luaotfload.fonts.scan     = scan_dir
luaotfload.fonts.generate = generate

if arg[0] == "luaotfload-fonts.lua" then
    generate()
end
