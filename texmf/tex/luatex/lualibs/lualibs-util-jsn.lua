if not modules then modules = { } end modules ['util-jsn'] = {
    version   = 1.001,
    comment   = "companion to m-json.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Of course we could make a nice complete parser with proper error messages but
-- as json is generated programmatically errors are systematic and we can assume
-- a correct stream. If not, we have some fatal error anyway. So, we can just rely
-- on strings being strings (apart from the unicode escape which is not in 5.1) and
-- as we first catch known types we just assume that anything else is a number.
--
-- Reminder for me: check usage in framework and extend when needed. Also document
-- it in the cld lib documentation.
--
-- Upgraded for handling the somewhat more fax server templates.

local P, V, R, S, C, Cc, Cs, Ct, Cf, Cg = lpeg.P, lpeg.V, lpeg.R, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Cf, lpeg.Cg
local lpegmatch = lpeg.match
local format, gsub = string.format, string.gsub
local utfchar = utf.char
local concat = table.concat

local tonumber, tostring, rawset, type, next = tonumber, tostring, rawset, type, next

local json      = utilities.json or { }
utilities.json  = json

-- \\ \/ \b \f \n \r \t \uHHHH

local lbrace     = P("{")
local rbrace     = P("}")
local lparent    = P("[")
local rparent    = P("]")
local comma      = P(",")
local colon      = P(":")
local dquote     = P('"')

local whitespace = lpeg.patterns.whitespace
local optionalws = whitespace^0

local escapes    = {
    ["b"] = "\010",
    ["f"] = "\014",
    ["n"] = "\n",
    ["r"] = "\r",
    ["t"] = "\t",
}

-- todo: also handle larger utf16

local escape_un  = P("\\u")/"" * (C(R("09","AF","af")^-4) / function(s)
    return utfchar(tonumber(s,16))
end)

local escape_bs  = P([[\]]) / "" * (P(1) / escapes) -- if not found then P(1) is returned i.e. the to be escaped char

local jstring    = dquote * Cs((escape_un + escape_bs + (1-dquote))^0) * dquote
local jtrue      = P("true")  * Cc(true)
local jfalse     = P("false") * Cc(false)
local jnull      = P("null")  * Cc(nil)
local jnumber    = (1-whitespace-rparent-rbrace-comma)^1 / tonumber

local key        = jstring

local jsonconverter = { "value",
    hash  = lbrace * Cf(Ct("") * (V("pair") * (comma * V("pair"))^0 + optionalws),rawset) * rbrace,
    pair  = Cg(optionalws * key * optionalws * colon * V("value")),
    array = Ct(lparent * (V("value") * (comma * V("value"))^0 + optionalws) * rparent),
--  value = optionalws * (jstring + V("hash") + V("array") + jtrue + jfalse + jnull + jnumber + #rparent) * optionalws,
    value = optionalws * (jstring + V("hash") + V("array") + jtrue + jfalse + jnull + jnumber) * optionalws,
}

-- local jsonconverter = { "value",
--     hash   = lbrace * Cf(Ct("") * (V("pair") * (comma * V("pair"))^0 + optionalws),rawset) * rbrace,
--     pair   = Cg(optionalws * V("string") * optionalws * colon * V("value")),
--     array  = Ct(lparent * (V("value") * (comma * V("value"))^0 + optionalws) * rparent),
--     string = jstring,
--     value  = optionalws * (V("string") + V("hash") + V("array") + jtrue + jfalse + jnull + jnumber) * optionalws,
-- }

-- lpeg.print(jsonconverter) -- size 181

function json.tolua(str)
    return lpegmatch(jsonconverter,str)
end

local escaper

local function tojson(value,t,n) -- we could optimize #t
    local kind = type(value)
    if kind == "table" then
        local done = false
        local size = #value
        if size == 0 then
            for k, v in next, value do
                if done then
                    n = n + 1 ; t[n] = ","
                else
                    n = n + 1 ; t[n] = "{"
                    done = true
                end
                n = n + 1 ; t[n] = format("%q:",k)
                t, n = tojson(v,t,n)
            end
            if done then
                n = n + 1 ; t[n] = "}"
            else
                n = n + 1 ; t[n] = "{}"
            end
        elseif size == 1 then
            -- we can optimize for non tables
            n = n + 1 ; t[n] = "["
            t, n = tojson(value[1],t,n)
            n = n + 1 ; t[n] = "]"
        else
            for i=1,size do
                if done then
                    n = n + 1 ; t[n] = ","
                else
                    n = n + 1 ; t[n] = "["
                    done = true
                end
                t, n = tojson(value[i],t,n)
            end
            n = n + 1 ; t[n] = "]"
        end
    elseif kind == "string"  then
        n = n + 1 ; t[n] = '"'
        n = n + 1 ; t[n] = lpegmatch(escaper,value) or value
        n = n + 1 ; t[n] = '"'
    elseif kind == "number" then
        n = n + 1 ; t[n] = value
    elseif kind == "boolean" then
        n = n + 1 ; t[n] = tostring(value)
    end
    return t, n
end

function json.tostring(value)
    -- todo optimize for non table
    local kind = type(value)
    if kind == "table" then
        if not escaper then
            local escapes = {
                ["\\"] = "\\u005C",
                ["\""] = "\\u0022",
            }
            for i=0,0x20 do
                escapes[utfchar(i)] = format("\\u%04X",i)
            end
            escaper = Cs( (
                (R('\0\x20') + S('\"\\')) / escapes
              + P(1)
            )^1 )

        end
        return concat((tojson(value,{},0)))
    elseif kind == "string" or kind == "number" then
        return lpegmatch(escaper,value) or value
    else
        return tostring(value)
    end
end

-- local tmp = [[ { "t" : "foobar", "a" : true, "b" : [ 123 , 456E-10, { "a" : true, "b" : [ 123 , 456 ] } ] } ]]
-- tmp = json.tolua(tmp)
-- inspect(tmp)
-- tmp = json.tostring(tmp)
-- inspect(tmp)
-- tmp = json.tolua(tmp)
-- inspect(tmp)
-- tmp = json.tostring(tmp)
-- inspect(tmp)
-- inspect(json.tostring(true))

function json.load(filename)
    local data = io.loaddata(filename)
    if data then
        return lpegmatch(jsonconverter,data)
    end
end

-- local s = [[\foo"bar"]]
-- local j = json.tostring { s = s }
-- local l = json.tolua(j)
-- inspect(j)
-- inspect(l)
-- print(s==l.s)

return json
