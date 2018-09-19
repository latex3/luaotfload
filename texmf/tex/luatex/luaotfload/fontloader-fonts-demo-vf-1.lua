if not modules then modules = { } end modules ['luatex-fonts-demo-vf-1'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local identifiers = fonts.hashes.identifiers

local defaults = { [0] =
    { "pdf", "origin", "0 g" },
    { "pdf", "origin", "1 0 0 rg" },
    { "pdf", "origin", "0 1 0 rg" },
    { "pdf", "origin", "0 0 1 rg" },
    { "pdf", "origin", "0 0 1 rg" },
}

return function(specification)
    local f1, id1 = fonts.constructors.readanddefine('lmroman10-regular',     specification.size)
    local f2, id2 = fonts.constructors.readanddefine('lmsans10-regular',      specification.size)
    local f3, id3 = fonts.constructors.readanddefine('lmtypewriter10-regular',specification.size)
    if f1 and f2 and f3 then
        f1.properties.name = specification.name
        f1.properties.virtualized = true
        f1.fonts = {
            { id = id1 },
            { id = id2 },
            { id = id3 },
        }
        local chars = {
            identifiers[id1].characters,
            identifiers[id2].characters,
            identifiers[id3].characters,
        }
        for u, v in next, f1.characters do
            local n = math.floor(math.random(1,3)+0.5)
            local c = chars[n][u] or v
            v.commands = {
                defaults[n] or defaults[0],
                { 'slot', n, u },
                defaults[0],
                { 'nop' }
            }
            v.kerns    = nil
            v.width    = c.width
            v.height   = c.height
            v.depth    = c.depth
            v.italic   = nil
        end
    end
    return f1
end
