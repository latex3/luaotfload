if not modules then modules = { } end modules ['luat-ovr'] = {
    version   = 2.2,
    comment   = "companion to luatex-*.tex",
    author    = "Khaled Hosny, Elie Roux, Philipp Gesang",
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

--- int -> bool
local set_loglevel = function (n)
    if type(n) == "number" then
        loglevel = n
    end
    return true
end
logs.setloglevel    = set_loglevel
logs.set_loglevel   = set_loglevel
logs.set_log_level  = set_loglevel --- accomodating lazy typists

--- unit -> int
local get_loglevel = function ( )
    return loglevel
end
logs.getloglevel    = get_loglevel
logs.get_loglevel   = get_loglevel
logs.get_log_level  = get_loglevel

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

--- at default (zero), we aim to be quiet
local level_ids = { common  = 1, loading = 2, search  = 3 }

local names_report = function (mode, lvl, ...)
    if type(lvl) == "string" then
        lvl = level_ids[lvl]
    end
    if not lvl then lvl = 0 end

    if loglevel >= lvl then
        if mode == "log" then
            log (...)
        elseif mode == "both" then
            log (...)
            stdout (...)
        else
            stdout (...)
        end
    end
end

logs.names_report = names_report

--[[doc--

    The fontloader comes with the Context logging mechanisms
    inaccessible. Instead, it provides dumb fallbacks based
    on the functions in texio.write*() that can be overridden
    by providing a function texio.reporter().

    The fontloader output can be quite verbose, so we disable
    it entirely by default.

--doc]]--

local texioreporter = function (message)
    names_report("log", 2, message)
end

texio.reporter = texioreporter

--[[doc--

    Adobe Glyph List.
    -------------------------------------------------------------------

    Context provides a somewhat different font-age.lua from an unclear
    origin. Unfortunately, the file name it reads from is hard-coded
    in font-enc.lua, so we have to replace the entire table.

    This shouldn’t cause any complications. Due to its implementation
    the glyph list will be loaded upon loading a OTF or TTF for the
    first time during a TeX run. (If one sticks to TFM/OFM then it is
    never read at all.) For this reason we can install a metatable that
    looks up the file of our choosing and only falls back to the
    Context one in case it cannot be found.

--doc]]--

if fonts then --- need to be running TeX
    if next(fonts.encodings.agl) then
        print(next, fonts.encodings.agl)
        --- unnecessary because the file shouldn’t be loaded at this time
        --- but we’re just making sure
        fonts.encodings.agl = nil
        collectgarbage"collect"
    end


    fonts.encodings.agl = { }

    setmetatable(fonts.encodings.agl, { __index = function (t, k)
        if k == "unicodes" then
            local glyphlist = resolvers.findfile"luaotfload-glyphlist.lua"
            if glyphlist then
                names_report("both", 0, "load", "loading the Adobe glyph list")
            else
                glyphlist = resolvers.findfile"font-age.lua"
                names_report("both", 0, "load", "loading the extended glyph list from ConTeXt")
            end
            local unicodes      = dofile(glyphlist)
            fonts.encodings.agl = { unicodes = unicodes }
            return unicodes
        else
            return nil
        end
    end })
end

-- vim:tw=71:sw=4:ts=4:expandtab
