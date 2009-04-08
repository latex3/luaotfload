if not modules then modules = { } end modules ['luat-dum'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local dummyfunction = function() end

statistics = {
    register      = dummyfunction,
    starttiming   = dummyfunction,
    stoptiming    = dummyfunction,
}
trackers = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}
storage = {
    register      = dummyfunction,
}
logs = {
    report        = dummyfunction,
    simple        = dummyfunction,
}
tasks = {
    new           = dummyfunction,
    actions       = dummyfunction,
    appendaction  = dummyfunction,
    prependaction = dummyfunction,
}


-- we need to cheat a bit here

texconfig.kpse_init = true

input = { } -- no fancy file helpers used

local remapper = {
    otf = "opentype fonts",
    ttf = "truetype fonts",
    ttc = "truetype fonts"
}

function input.find_file(name,kind)
    name = name:gsub("\\","\/")
    return kpse.find_file(name,(kind ~= "" and kind) or "tex")
end

function input.findbinfile(name,kind)
    if not kind or kind == "" then
        kind = string.match(name,"%.(.-)$")
    end
    return input.find_file(name,kind and remapper[kind])
end
