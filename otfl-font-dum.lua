if not modules then modules = { } end modules ['font-dum'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

fonts = fonts or { }

-- general

fonts.otf.pack       = false
fonts.tfm.resolve_vf = false -- no sure about this

-- readers

fonts.tfm.readers          = fonts.tfm.readers or { }
fonts.tfm.readers.sequence = { 'otf', 'ttf', 'tfm' }
fonts.tfm.readers.afm      = nil

-- define

fonts.define = fonts.define or { }

--~ fonts.define.method = "tfm"

fonts.define.specify.colonized_default_lookup = "name"

function fonts.define.get_specification(str)
    return "", str, "", ":", str
end

-- logger

fonts.logger = fonts.logger or { }

function fonts.logger.save()
end

-- names

fonts.names = fonts.names or { }

fonts.names.basename   = "luatex-fonts-names.lua"
fonts.names.new_to_old = { }
fonts.names.old_to_new = { }

local data, loaded = nil, false

function fonts.names.resolve(name,sub)
    if not loaded then
        local basename = fonts.names.basename
        if basename and basename ~= "" then
            for _, format in ipairs { "lua", "tex", "other text files" } do
                local foundname = input.find_file(basename,format) or ""
                if foundname ~= "" then
                    data = dofile(foundname)
                    if data then
                        local d = {  }
                        for k, v in pairs(data.mapping) do
                            local t = v[1]
                            if t == "ttf" or t == "otf" or t == "ttc" then
                                d[k] = v
                            end
                        end
                        data.mapping = d
                    end
                    break
                end
            end
        end
        loaded = true
    end
    if type(data) == "table" and data.version == 1.07 then
        local condensed = string.gsub(name,"[^%a%d]","")
        local found = data.mapping and data.mapping[condensed]
        if found then
            local filename, is_sub = found[3], found[4]
            return filename, is_sub
        else
            return name, false -- fallback to filename
        end
    end
end
