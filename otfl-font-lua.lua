if not modules then modules = { } end modules ['font-lua'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local trace_defining = false  trackers.register("fonts.defining", function(v) trace_defining = v end)

local report_lua = logs.reporter("fonts","lua loading")

fonts.formats.lua = "lua"

local readers = fonts.tfm.readers

local function check_lua(specification,fullname)
    -- standard tex file lookup
    local fullname = resolvers.findfile(fullname) or ""
    if fullname ~= "" then
        local loader = loadfile(fullname)
        loader = loader and loader()
        return loader and loader(specification)
    end
end

function readers.lua(specification)
    local original = specification.specification
    if trace_defining then
        report_lua("using lua reader for '%s'",original)
    end
    local fullname, tfmtable = specification.filename or "", nil
    if fullname == "" then
        local forced = specification.forced or ""
        if forced ~= "" then
            tfmtable = check_lua(specification,specification.name .. "." .. forced)
        end
        if not tfmtable then
            tfmtable = check_lua(specification,specification.name)
        end
    else
        tfmtable = check_lua(specification,fullname)
    end
    return tfmtable
end
