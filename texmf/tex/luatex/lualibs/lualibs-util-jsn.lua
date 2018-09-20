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

local P, V, R, S, C, Cc, Cs, Ct, Cf, Cg = lpeg.P, lpeg.V, lpeg.R, lpeg.S, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Cf, lpeg.Cg
local lpegmatch = lpeg.match
local format = string.format
local utfchar = utf.char
local concat = table.concat

local tonumber, tostring, rawset, type, next = tonumber, tostring, rawset, type, next

local json      = utilities.json or { }
utilities.json  = json

-- moduledata      = moduledata or { }
-- moduledata.json = json

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
 -- ["\\"] = "\\",  -- lua will escape these
 -- ["/"]  = "/",   -- no need to escape this one
    ["b"]  = "\010",
    ["f"]  = "\014",
    ["n"]  = "\n",
    ["r"]  = "\r",
    ["t"]  = "\t",
}

local escape_un  = C(P("\\u") / "0x" * S("09","AF","af")) / function(s) return utfchar(tonumber(s)) end
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

local function tojson(value,t) -- we could optimize #t
    local kind = type(value)
    if kind == "table" then
        local done = false
        local size = #value
        if size == 0 then
            for k, v in next, value do
                if done then
                    t[#t+1] = ","
                else
                    t[#t+1] = "{"
                    done = true
                end
                t[#t+1] = format("%q:",k)
                tojson(v,t)
            end
            if done then
                t[#t+1] = "}"
            else
                t[#t+1] = "{}"
            end
        elseif size == 1 then
            -- we can optimize for non tables
            t[#t+1] = "["
            tojson(value[1],t)
            t[#t+1] = "]"
        else
            for i=1,size do
                if done then
                    t[#t+1] = ","
                else
                    t[#t+1] = "["
                    done = true
                end
                tojson(value[i],t)
            end
            t[#t+1] = "]"
        end
    elseif kind == "string"  then
        t[#t+1] = format("%q",value)
    elseif kind == "number" then
        t[#t+1] = value
    elseif kind == "boolean" then
        t[#t+1] = tostring(value)
    end
    return t
end

function json.tostring(value)
    -- todo optimize for non table
    local kind = type(value)
    if kind == "table" then
        return concat(tojson(value,{}),"")
    elseif kind == "string" or kind == "number" then
        return value
    else
        return tostring(value)
    end
end

-- local tmp = [[ { "a" : true, "b" : [ 123 , 456E-10, { "a" : true, "b" : [ 123 , 456 ] } ] } ]]

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

return json
