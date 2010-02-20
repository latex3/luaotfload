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
directives = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}
trackers = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}
experiments = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}
storage = {
    register      = dummyfunction,
    shared        = { },
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
callbacks = {
    register      = dummyfunction,
}

-- we need to cheat a bit here

texconfig.kpse_init = true

resolvers = resolvers or { } -- no fancy file helpers used

local remapper = {
    otf   = "opentype fonts",
    ttf   = "truetype fonts",
    ttc   = "truetype fonts",
    dfont = "truetype dictionary",
    cid   = "other text files", -- will become "cid files"
}

function resolvers.find_file(name,kind)
    name = string.gsub(name,"\\","\/")
    kind = string.lower(kind)
    return kpse.find_file(name,(kind and kind ~= "" and (remapper[kind] or kind)) or "tex")
end

function resolvers.findbinfile(name,kind)
    if not kind or kind == "" then
        kind = file.extname(name) -- string.match(name,"%.([^%.]-)$")
    end
    return resolvers.find_file(name,(kind and remapper[kind]) or kind)
end

local write_nl, format, name = texio.write_nl, string.format, "luaotfload"

function logs.report(category,fmt,...)
    if fmt then
        write_nl('log', format("%s | %s: %s",name,category,format(fmt,...)))
    elseif category then
        write_nl('log', format("%s | %s",name,category))
    else
        write_nl('log', format("%s |",name))
    end
end

function logs.simple(fmt,...)
    if fmt then
        write_nl('log', format("%s | %s",name,format(fmt,...)))
    else
        write_nl('log', format("%s |",name))
    end
end

tex.ctxcatcodes = luatextra.catcodetables.latex
