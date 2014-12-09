if not modules then modules = { } end modules ['luatex-math'] = {
    version   = 1.001,
    comment   = "companion to luatex-math.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gaps = {
    [0x1D455] = 0x0210E,
    [0x1D49D] = 0x0212C,
    [0x1D4A0] = 0x02130,
    [0x1D4A1] = 0x02131,
    [0x1D4A3] = 0x0210B,
    [0x1D4A4] = 0x02110,
    [0x1D4A7] = 0x02112,
    [0x1D4A8] = 0x02133,
    [0x1D4AD] = 0x0211B,
    [0x1D4BA] = 0x0212F,
    [0x1D4BC] = 0x0210A,
    [0x1D4C4] = 0x02134,
    [0x1D506] = 0x0212D,
    [0x1D50B] = 0x0210C,
    [0x1D50C] = 0x02111,
    [0x1D515] = 0x0211C,
    [0x1D51D] = 0x02128,
    [0x1D53A] = 0x02102,
    [0x1D53F] = 0x0210D,
    [0x1D545] = 0x02115,
    [0x1D547] = 0x02119,
    [0x1D548] = 0x0211A,
    [0x1D549] = 0x0211D,
    [0x1D551] = 0x02124,
}


local function fixmath(tfmdata,key,value)
    if value then
        local characters = tfmdata.characters
        for gap, mess in pairs(gaps) do
            characters[gap] = characters[mess]
        end
    end
end

fonts.handlers.otf.features.register {
    name         = "fixmath",
    description  = "math font fixing",
    manipulators = {
        base = fixmath,
        node = fixmath,
    }
}
