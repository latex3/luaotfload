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
local tableconcat   = table.concat
local type          = type

--[[doc--
We recreate the verbosity levels previously implemented in font-nms:

    ==========================================================
    lvl      arg  trace_loading  trace_search  suppress_output
    ----------------------------------------------------------
    (0)  ->  -q         ⊥              ⊥            ⊤
    (1)  ->  ∅          ⊥              ⊥            ⊥
    (2)  ->  -v         ⊤              ⊥            ⊥
    (>2) ->  -vv        ⊤              ⊤            ⊥
    ==========================================================

--doc]]--
local loglevel = 1 --- default
local logout   = "log"

local set_loglevel = function (n)
    if type(n) == "number" then
        loglevel = n
    end
end
logs.set_loglevel = set_loglevel

local set_logout = function (s)
    if s == "stdout" then
        logout = "term"
    --else --- remains “log”
    end
end

logs.set_logout = set_logout

local log = function (category, fmt, ...)
    local res = { module_name, " |" }
    if category then res[#res+1] = " " .. category end
    if fmt      then res[#res+1] = ": " .. stringformat(fmt, ...) end
    texiowrite_nl(logout, tableconcat(res))
end

local stdout = function (category, fmt, ...)
    local res = { module_name, " |" }
    if category then res[#res+1] = " " .. category end
    if fmt      then res[#res+1] = ": " .. stringformat(fmt, ...) end
    texiowrite_nl(tableconcat(res))
end

local level_ids = { common  = 0, loading = 1, search  = 2 }

logs.names_report = function (mode, lvl, ...)
    if type(lvl) == "string" then
        lvl = level_ids[lvl]
    end
    if not lvl then lvl = 0 end

    if loglevel > lvl then
        if mode == "log" then
            log (...)
        else
            stdout (...)
        end
    end
end

-- vim:tw=71:sw=4:ts=4:expandtab
