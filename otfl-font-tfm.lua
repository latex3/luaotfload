if not modules then modules = { } end modules ['luatex-fonts-tfm'] = {
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

local fonts        = fonts
local tfm          = { }
fonts.handlers.tfm = tfm
fonts.formats.tfm  = "type1" -- we need to have at least a value here

function fonts.readers.tfm(specification)
    local fullname = specification.filename or ""
    if fullname == "" then
        local forced = specification.forced or ""
        if forced ~= "" then
            fullname = specification.name .. "." .. forced
        else
            fullname = specification.name
        end
    end
    local foundname = resolvers.findbinfile(fullname, 'tfm') or ""
    if foundname == "" then
        foundname = resolvers.findbinfile(fullname, 'ofm') or ""
    end
    if foundname ~= "" then
        specification.filename = foundname
        specification.format   = "ofm"
        return font.read_tfm(specification.filename,specification.size)
    end
end
