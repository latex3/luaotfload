otfl              = otfl or { }
otfl.fonts        = { }

otfl.fonts.module = {
    name          = "otfl.fonts",
    version       = 1.001,
    date          = "2010/01/10",
    description   = "luaotfload font database.",
    author        = "Khaled Hosny",
    copyright     = "Khaled Hosny",
    license       = "CC0"
}

otfl.fonts.basename = "otfl-names.lua"

kpse.set_program_name("luatex")

require("luaextra.lua")
require("otfl-luat-dum.lua")

local fnames    = fnames or { }
fnames.mappings = fnames.mappings or { }
fnames.version  = 1.001

local function clean(str)
    if str then
        return string.gsub(string.lower(str),"[^%a%d]","")
    end
end

function otfl.fonts.load(filename,names,force)
    local mappings = names.mappings
    local key
    if filename then
        local i = fontloader.info(filename)
        if i then
            if type(i) == "table" and #i > 1 then
                for k,v in ipairs(i) do
                    key = clean(v.fullname)
                    if not mappings[key] or force then
                        mappings[key] = { v.fullname, filename, k }
                    end
                end

            else
                key = clean(i.fullname)
                if not mappings[key] or force then
                    mappings[key] = { i.fullname, filename }
                end
            end
        else
            logs.simple("Failed to load %s", filename)
        end
    end
end

function otfl.fonts.reload(list,names)
    for _,v in ipairs(list) do
        otfl.fonts.load(v,names,force)
    end
end

function otfl.fonts.fontlist()
    local fc = io.popen("fc-list : file")
    local l  = {}
    string.gsub(fc:read("*a"), "(.-): \n", function(h) table.insert(l, h) return "" end)
    fc:close()
    return l
end

local function main()
    local flist = otfl.fonts.fontlist()
    otfl.fonts.reload(flist,fnames)
    logs.simple("%s fonts found, %s saved in the database", #flist, #table.keys(fnames.mappings))
    io.savedata(otfl.fonts.basename, table.serialize(fnames, true))
    logs.simple("Saved names database in %s\n", otfl.fonts.basename)
end

main()
