if not modules then modules = { } end modules ['luatex-fonts-syn'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if context then
    texio.write_nl("fatal error: this module is not for context")
    os.exit()
end

-- Generic font names support.
--
-- Watch out, the version number is the same as the one used in
-- the mtx-fonts.lua function scripts.fonts.names as we use a
-- simplified font database in the plain solution and by using
-- a different number we're less dependent on context.
--
-- mtxrun --script font --reload --simple
--
-- The format of the file is as follows:
--
-- return {
--     ["version"]  = 1.001,
--     ["mappings"] = {
--         ["somettcfontone"] = { "Some TTC Font One", "SomeFontA.ttc", 1 },
--         ["somettcfonttwo"] = { "Some TTC Font Two", "SomeFontA.ttc", 2 },
--         ["somettffont"]    = { "Some TTF Font",     "SomeFontB.ttf"    },
--         ["someotffont"]    = { "Some OTF Font",     "SomeFontC.otf"    },
--     },
-- }

local fonts = fonts
fonts.names = fonts.names or { }

fonts.names.version    = 1.001 -- not the same as in context
fonts.names.basename   = "luatex-fonts-names.lua"
fonts.names.new_to_old = { }
fonts.names.old_to_new = { }

local data, loaded = nil, false

local fileformats = { "lua", "tex", "other text files" }

function fonts.names.resolve(name,sub)
    if not loaded then
        local basename = fonts.names.basename
        if basename and basename ~= "" then
            for i=1,#fileformats do
                local format = fileformats[i]
                local foundname = resolvers.findfile(basename,format) or ""
                if foundname ~= "" then
                    data = dofile(foundname)
                    texio.write("<font database loaded: ",foundname,">")
                    break
                end
            end
        end
        loaded = true
    end
    if type(data) == "table" and data.version == fonts.names.version then
        local condensed = string.gsub(string.lower(name),"[^%a%d]","")
        local found = data.mappings and data.mappings[condensed]
        if found then
            local fontname, filename, subfont = found[1], found[2], found[3]
            if subfont then
                return filename, fontname
            else
                return filename, false
            end
        else
            return name, false -- fallback to filename
        end
    end
end

fonts.names.resolvespec = fonts.names.resolve -- only supported in mkiv

function fonts.names.getfilename(askedname,suffix)  -- only supported in mkiv
    return ""
end
