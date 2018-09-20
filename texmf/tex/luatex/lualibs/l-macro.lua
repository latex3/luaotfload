if not modules then modules = { } end modules ['l-macros'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is actually rather old code that I made as a demo for Luigi but that
-- now comes in handy when we switch to Lua 5.3. The reason for using it (in
-- in transition) is that we cannot mix 5.3 bit operators in files that get
-- loaded in 5.2 (parsing happens before conditional testing).

local S, P, R, V, C, Cs, Cc, Ct, Carg = lpeg.S, lpeg.P, lpeg.R, lpeg.V, lpeg.C, lpeg.Cs, lpeg.Cc, lpeg.Ct, lpeg.Carg
local lpegmatch = lpeg.match
local concat = table.concat
local format, sub, match = string.format, string.sub, string.match
local next, load, type = next, load, type

local newline       = S("\n\r")^1
local continue      = P("\\") * newline
local spaces        = S(" \t") + continue
local name          = R("az","AZ","__","09")^1
local body          = ((continue/"" + 1) - newline)^1
local lparent       = P("(")
local rparent       = P(")")
local noparent      = 1 - (lparent  + rparent)
local nested        = P { lparent  * (noparent  + V(1))^0 * rparent }
local escaped       = P("\\") * P(1)
local squote        = P("'")
local dquote        = P('"')
local quoted        = dquote * (escaped + (1-dquote))^0 * dquote
                    + squote * (escaped + (1-squote))^0 * squote

local arguments     = lparent * Ct((Cs((nested+(quoted + 1 - S("),")))^1) + S(", "))^0) * rparent

local macros        = lua.macros or { }
lua.macros          = macros

local patterns      = { }
local definitions   = { }
local resolve
local subparser

local report_lua = function(...)
    if logs and logs.reporter then
        report_lua = logs.reporter("system","lua")
        report_lua(...)
    else
        print(format(...))
    end
end

-- todo: zero case

resolve = C(C(name) * arguments^-1) / function(raw,s,a)
    local d = definitions[s]
    if d then
        if a then
            local n = #a
            local p = patterns[s][n]
            if p then
                local d = d[n]
                for i=1,n do
                    a[i] = lpegmatch(subparser,a[i]) or a[i]
                end
                return lpegmatch(p,d,1,a) or d
            else
                return raw
            end
        else
            return d[0] or raw
        end
    elseif a then
        for i=1,#a do
            a[i] = lpegmatch(subparser,a[i]) or a[i]
        end
        return s .. "(" .. concat(a,",") .. ")"
    else
        return raw
    end
end

subparser = Cs((resolve + P(1))^1)

local enddefine   = P("#enddefine") / ""

local beginregister = (C(name) * (arguments + Cc(false)) * C((1-enddefine)^1) * enddefine) / function(k,a,v)
    local n = 0
    if a then
        n = #a
        local pattern = P(false)
        for i=1,n do
            pattern = pattern + (P(a[i]) * Carg(1)) / function(t) return t[i] end
        end
        pattern = Cs((pattern + P(1))^1)
        local p = patterns[k]
        if not p then
            p = { [0] = false, false, false, false, false, false, false, false, false }
            patterns[k] = p
        end
        p[n] = pattern
    end
    local d = definitions[k]
    if not d then
        d = { a = a, [0] = false, false, false, false, false, false, false, false, false }
        definitions[k] = d
    end
    d[n] = lpegmatch(subparser,v) or v
    return ""
end

local register = (Cs(name) * (arguments + Cc(false)) * spaces^0 * Cs(body)) / function(k,a,v)
    local n = 0
    if a then
        n = #a
        local pattern = P(false)
        for i=1,n do
            pattern = pattern + (P(a[i]) * Carg(1)) / function(t) return t[i] end
        end
        pattern = Cs((pattern + P(1))^1)
        local p = patterns[k]
        if not p then
            p = { [0] = false, false, false, false, false, false, false, false, false }
            patterns[k] = p
        end
        p[n] = pattern
    end
    local d = definitions[k]
    if not d then
        d = { a = a, [0] = false, false, false, false, false, false, false, false, false }
        definitions[k] = d
    end
    d[n] = lpegmatch(subparser,v) or v
    return ""
end

local unregister = (C(name) * spaces^0 * (arguments + Cc(false))) / function(k,a)
    local n = 0
    if a then
        n = #a
        local p = patterns[k]
        if p then
            p[n] = false
        end
    end
    local d = definitions[k]
    if d then
        d[n] = false
    end
    return ""
end

local begindefine = (P("begindefine") * spaces^0 / "") * beginregister
local define      = (P("define"     ) * spaces^0 / "") * register
local undefine    = (P("undefine"   ) * spaces^0 / "") * unregister

local parser = Cs( ( ( (P("#")/"") * (define + begindefine + undefine) * (newline^0/"") ) + resolve + P(1) )^0 )

function macros.reset()
    definitions = { }
    patterns    = { }
end

function macros.showdefinitions()
    -- no helpers loaded but not called early
    for name, list in table.sortedhash(definitions) do
        local arguments = list.a
        if arguments then
            arguments = "(" .. concat(arguments,",") .. ")"
        else
            arguments = ""
        end
        print("macro: " .. name .. arguments)
        for i=0,#list do
            local l = list[i]
            if l then
                print("  " .. l)
            end
        end
    end
end

function macros.resolvestring(str)
    return lpegmatch(parser,str) or str
end

function macros.resolving()
    return next(patterns)
end

local function reload(path,name,data)
    local only = match(name,".-([^/]+)%.lua")
    if only and only ~= "" then
        local name = path .. "/" .. only
        local f = io.open(name,"wb")
        f:write(data)
        f:close()
        local f = loadfile(name)
        os.remove(name)
        return f
    end
end

-- local function reload(path,name,data)
--     if path and path ~= "" then
--         local only = file.nameonly(name) .. "-macro.lua"
--         local name = file.join(path,only)
--         io.savedata(name,data)
--         local l = loadfile(name)
--         os.remove(name)
--         return l
--     end
--     return load(data,name)
-- end
--
-- assumes no helpers

local function reload(path,name,data)
    if path and path ~= "" then
        local only = string.match(name,".-([^/]+)%.lua")
        if only and only ~= "" then
            local name = path .. "/" .. only .. "-macro.lua"
            local f = io.open(name,"wb")
            if f then
                f:write(data)
                f:close()
                local l = loadfile(name)
                os.remove(name)
                return l
            end
        end
    end
    return load(data,name)
end

local function loaded(name,trace,detail)
 -- local c = io.loaddata(fullname) -- not yet available
    local f = io.open(name,"rb")
    if not f then
        return false, format("file '%s' not found",name)
    end
    local c = f:read("*a")
    if not c then
        return false, format("file '%s' is invalid",name)
    end
    f:close()
    local n = lpegmatch(parser,c)
    if trace then
        if #n ~= #c then
            report_lua("macros expanded in '%s' (%i => %i bytes)",name,#c,#n)
            if detail then
                report_lua()
                report_lua(n)
                report_lua()
            end
        elseif detail then
            report_lua("no macros expanded in '%s'",name)
        end
    end
 -- if #name > 30 then
 --     name = sub(name,-30)
 -- end
 -- n = "--[[" .. name .. "]]\n" .. n
    return reload(lfs and lfs.currentdir(),name,n)
end

macros.loaded = loaded

function required(name,trace)
    local filename = file.addsuffix(name,"lua")
    local fullname = resolvers and resolvers.find_file(filename) or filename
    if not fullname or fullname == "" then
        return false
    end
    local codeblob = package.loaded[fullname]
    if codeblob then
        return codeblob
    end
    local code, message = loaded(fullname,macros,trace,trace)
    if type(code) == "function" then
        code = code()
    else
        report_lua("error when loading '%s'",fullname)
        return false, message
    end
    if code == nil then
        code = false
    end
    package.loaded[fullname] = code
    return code
end

macros.required = required

-- local str = [[
-- #define check(p,q) (p ~= 0) and (p > q)
--
-- #define oeps a > 10
--
-- #define whatever oeps
--
-- if whatever and check(1,2) then print("!") end
-- if whatever and check(1,3) then print("!") end
-- if whatever and check(1,4) then print("!") end
-- if whatever and check(1,5) then print("!") end
-- if whatever and check(1,6) then print("!") end
-- if whatever and check(1,7) then print("!") end
-- ]]
--
-- print(macros.resolvestring(str))
--
-- macros.resolvestring(io.loaddata("mymacros.lua"))
-- loadstring(macros.resolvestring(io.loaddata("mytestcode.lua")))

-- local luamacros = [[
-- #begindefine setnodecodes
-- local nodecodes  = nodes.codes
-- local hlist_code = nodecodes.hlist
-- local vlist_code = nodecodes.vlist
-- local glyph_code = nodecodes.glyph
-- #enddefine
--
-- #define hlist(id) id == hlist_code
-- #define vlist(id) id == vlist_code
-- #define glyph(id) id == glyph_code
-- ]]
--
-- local luacode = [[
-- setnodecodes
--
-- if hlist(id) or vlist(id) then
--     print("we have a list")
-- elseif glyph(id) then
--     print("we have a glyph")
-- else
--     print("i'm stymied")
-- end
--
-- local z = band(0x23,x)
-- local z = btest(0x23,x)
-- local z = rshift(0x23,x)
-- local z = lshift(0x23,x)
-- ]]
--
-- require("l-macros-test-001")
--
-- macros.resolvestring(luamacros)
--
-- local newcode = macros.resolvestring(luacode)
--
-- print(newcode)
--
-- macros.reset()

-- local d = io.loaddata("t:/sources/font-otr.lua")
-- local n = macros.resolvestring(d)
-- io.savedata("r:/tmp/o.lua",n)
