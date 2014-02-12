if not modules then modules = { } end modules ['luatex-fonts-lua'] = {
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

local fonts       = fonts
fonts.formats.lua = "lua"

function fonts.readers.lua(specification)
    local fullname = specification.filename or ""
    if fullname == "" then
        local forced = specification.forced or ""
        if forced ~= "" then
            fullname = specification.name .. "." .. forced
        else
            fullname = specification.name
        end
    end
    local fullname = resolvers.findfile(fullname) or ""
    if fullname ~= "" then
        local loader = loadfile(fullname)
        loader = loader and loader()
        return loader and loader(specification)
    end
end
