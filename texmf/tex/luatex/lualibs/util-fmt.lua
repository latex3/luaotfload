if not modules then modules = { } end modules ['util-fmt'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

utilities            = utilities or { }
utilities.formatters = utilities.formatters or { }
local formatters     = utilities.formatters

local concat, format = table.concat, string.format
local tostring, type = tostring, type
local strip = string.strip

local lpegmatch = lpeg.match
local stripper  = lpeg.patterns.stripzeros

function formatters.stripzeros(str)
    return lpegmatch(stripper,str)
end

function formatters.formatcolumns(result,between)
    if result and #result > 0 then
        between = between or "   "
        local widths, numbers = { }, { }
        local first = result[1]
        local n = #first
        for i=1,n do
            widths[i] = 0
        end
        for i=1,#result do
            local r = result[i]
            for j=1,n do
                local rj = r[j]
                local tj = type(rj)
                if tj == "number" then
                    numbers[j] = true
                end
                if tj ~= "string" then
                    rj = tostring(rj)
                    r[j] = rj
                end
                local w = #rj
                if w > widths[j] then
                    widths[j] = w
                end
            end
        end
        for i=1,n do
            local w = widths[i]
            if numbers[i] then
                if w > 80 then
                    widths[i] = "%s" .. between
                 else
                    widths[i] = "%0" .. w .. "i" .. between
                end
            else
                if w > 80 then
                    widths[i] = "%s" .. between
                 elseif w > 0 then
                    widths[i] = "%-" .. w .. "s" .. between
                else
                    widths[i] = "%s"
                end
            end
        end
        local template = strip(concat(widths))
        for i=1,#result do
            local str = format(template,unpack(result[i]))
            result[i] = strip(str)
        end
    end
    return result
end
