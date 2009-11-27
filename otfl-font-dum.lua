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
--
-- Watch out, the version number is the same as the one used in
-- the mtx-fonts.lua function scripts.fonts.names as we use a
-- simplified font database in the plain solution and by using
-- a different number we're less dependent on context.

fonts.names = fonts.names or { }

fonts.names.version    = 1.001 -- not the same as in context
fonts.names.basename   = "luatex-fonts-names.lua"
fonts.names.new_to_old = { }
fonts.names.old_to_new = { }

local data, loaded = nil, false

function fonts.names.resolve(name,sub)
    if not loaded then
        local basename = fonts.names.basename
        if basename and basename ~= "" then
            for _, format in ipairs { "lua", "tex", "other text files" } do
                local foundname = resolvers.find_file(basename,format) or ""
                if foundname ~= "" then
                    data = dofile(foundname)
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

-- For the moment we put this (adapted) pseudo feature here.

table.insert(fonts.triggers,"itlc")

local function itlc(tfmdata,value)
    if value then
        -- the magic 40 and it formula come from Dohyun Kim
        local metadata = tfmdata.shared.otfdata.metadata
        if metadata then
            local italicangle = metadata.italicangle
            if italicangle and italicangle ~= 0 then
                local uwidth = (metadata.uwidth or 40)/2
                for unicode, d in next, tfmdata.descriptions do
                    local it = d.boundingbox[3] - d.width + uwidth
                    if it ~= 0 then
                        d.italic = it
                    end
                end
                tfmdata.has_italic = true
            end
        end
    end
end

fonts.initializers.base.otf.itlc = itlc
fonts.initializers.node.otf.itlc = itlc

function fonts.register_message()
end
