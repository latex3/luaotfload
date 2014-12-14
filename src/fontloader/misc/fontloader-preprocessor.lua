if not modules then modules = { } end modules ['luatex-preprocessor'] = {
    version   = 1.001,
    comment   = "companion to luatex-preprocessor.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx
<p>This is a stripped down version of the preprocessor. In
<l n='context'/> we have a bit more, use a different logger, and
use a few optimizations. A few examples are shown at the end.</p>
--ldx]]

local rep, sub, gmatch = string.rep, string.sub, string.gmatch
local insert, remove = table.insert, table.remove
local setmetatable = setmetatable

local stack, top, n, hashes = { }, nil, 0, { }

local function set(s)
    if top then
        n = n + 1
        if n > 9 then
            texio.write_nl("number of arguments > 9, ignoring: " .. s)
        else
            local ns = #stack
            local h = hashes[ns]
            if not h then
                h = rep("#",ns)
                hashes[ns] = h
            end
            m = h .. n
            top[s] = m
            return m
        end
    end
end

local function get(s)
    local m = top and top[s] or s
    return m
end

local function push()
    top = { }
    n = 0
    local s = stack[#stack]
    if s then
        setmetatable(top,{ __index = s })
    end
    insert(stack,top)
end

local function pop()
    top = remove(stack)
end

local leftbrace   = lpeg.P("{")
local rightbrace  = lpeg.P("}")
local escape      = lpeg.P("\\")

local space       = lpeg.P(" ")
local spaces      = space^1
local newline     = lpeg.S("\r\n")
local nobrace     = 1 - leftbrace - rightbrace

local name        = lpeg.R("AZ","az")^1
local longname    = (leftbrace/"") * (nobrace^1) * (rightbrace/"")
local variable    = lpeg.P("#") * lpeg.Cs(name + longname)
local escapedname = escape * name
local definer     = escape * (lpeg.P("def") + lpeg.P("egdx") * lpeg.P("def"))
local anything    = lpeg.P(1)
local always      = lpeg.P(true)

local pushlocal   = always   / push
local poplocal    = always   / pop
local declaration = variable / set
local identifier  = variable / get

local function matcherror(str,pos)
    texio.write_nl("runaway definition at: " .. sub(str,pos-30,pos))
end

local parser = lpeg.Cs { "converter",
    definition  = pushlocal
                * definer
                * escapedname
                * (declaration + (1-leftbrace))^0
                * lpeg.V("braced")
                * poplocal,
    braced      = leftbrace
                * (   lpeg.V("definition")
                    + identifier
                    + lpeg.V("braced")
                    + nobrace
                  )^0
                * (rightbrace + lpeg.Cmt(always,matcherror)),
    converter   = (lpeg.V("definition") + anything)^1,
}

--[[ldx
<p>We provide a few commands.</p>
--ldx]]

-- local texkpse

local function find_file(...)
 -- texkpse = texkpse or kpse.new("luatex","tex")
 -- return texkpse:find_file(...) or ""
    return kpse.find_file(...) or ""
end

commands = commands or { }

function commands.preprocessed(str)
    return lpeg.match(parser,str)
end

function commands.inputpreprocessed(name)
    local name = find_file(name) or ""
    if name ~= "" then
     -- we could use io.loaddata as it's loaded in luatex-plain
        local f = io.open(name,'rb')
        if f then
            texio.write("("..name)
            local d = commands.preprocessed(f:read("*a"))
            if d and d ~= "" then
                texio.write("processed: " .. name)
                for s in gmatch(d,"[^\n\r]+") do
                    tex.print(s) -- we do a dumb feedback
                end
            end
            f:close()
            texio.write(")")
        else
            tex.error("preprocessor error, invalid file: " .. name)
        end
    else
        tex.error("preprocessor error, unknown file: " .. name)
    end
end

function commands.preprocessfile(oldfile,newfile) -- no checking
    if oldfile and oldfile ~= newfile then
        local f = io.open(oldfile,'rb')
        if f then
            local g = io.open(newfile,'wb')
            if g then
                g:write(lpeg.match(parser,f:read("*a") or ""))
                g:close()
            end
            f:close()
        end
    end
end

--~ print(preprocessed([[\def\test#oeps{test:#oeps}]]))
--~ print(preprocessed([[\def\test#oeps{test:#{oeps}}]]))
--~ print(preprocessed([[\def\test#{oeps:1}{test:#{oeps:1}}]]))
--~ print(preprocessed([[\def\test#{oeps}{test:#oeps}]]))
--~ preprocessed([[\def\test#{oeps}{test:#oeps \halign{##\cr #oeps\cr}]])
--~ print(preprocessed([[\def\test#{oeps}{test:#oeps \halign{##\cr #oeps\cr}}]]))
