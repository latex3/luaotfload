if not modules then modules = { } end modules ['luatex-font-enc'] = {
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

local fonts           = fonts
fonts.encodings       = { }
fonts.encodings.agl   = { }
fonts.encodings.known = { }

setmetatable(fonts.encodings.agl, { __index = function(t,k)
    if k == "unicodes" then
        texio.write(" <loading (extended) adobe glyph list>")
        local unicodes = dofile(resolvers.findfile("font-age.lua"))
        fonts.encodings.agl = { unicodes = unicodes }
        return unicodes
    else
        return nil
    end
end })

