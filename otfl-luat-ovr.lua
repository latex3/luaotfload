if not modules then modules = { } end modules ['luat-ovr'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Khaled Hosny and Elie Roux",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2"
}


local module_name = "luaotfload"

local texiowrite_nl = texio.write_nl
local stringformat  = string.format
local ioflush       = io.flush
local dummyfunction = function() end

function logs.report(category,fmt,...)
    if fmt then
        texiowrite_nl('log', stringformat("%s | %s: %s",module_name,category,stringformat(fmt,...)))
    elseif category then
        texiowrite_nl('log', stringformat("%s | %s",module_name,category))
    else
        texiowrite_nl('log', stringformat("%s |",module_name))
    end
end

function logs.info(category,fmt,...)
    if fmt then
        texiowrite_nl(stringformat("%s | %s: %s",module_name,category,stringformat(fmt,...)))
    elseif category then
        texiowrite_nl(stringformat("%s | %s",module_name,category))
    else
        texiowrite_nl(stringformat("%s |",module_name))
    end
    ioflush()
end

