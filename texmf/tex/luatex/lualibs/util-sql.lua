if not modules then modules = { } end modules ['util-sql'] = {
    version   = 1.001,
    comment   = "companion to m-sql.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: templates as table (saves splitting)

-- Of course we could use a library but we don't want another depedency and there is
-- a bit of flux in these libraries. Also, we want the data back in a way that we
-- like.
--
-- This is the first of set of sql related modules that are providing functionality
-- for a web based framework that we use for typesetting (related) services. We're
-- talking of session management, job ticket processing, storage, (xml) file processing
-- and dealing with data from databases (often ambitiously called database publishing).
--
-- There is no generic solution for such services, but from our perspective, as we use
-- context in a regular tds tree (the standard distribution) it makes sense to put shared
-- code in the context distribution. That way we don't need to reinvent wheels every time.

-- We use the template mechanism from util-tpl which inturn is just using the dos cq
-- windows convention of %whatever% variables that I've used for ages.

-- util-sql-imp-client.lua
-- util-sql-imp-library.lua
-- util-sql-imp-swiglib.lua
-- util-sql-imp-lmxsql.lua

-- local sql = require("util-sql")
--
-- local converter = sql.makeconverter {
--     { name = "id",  type = "number" },
--     { name = "data",type = "string" },
-- }
--
-- local execute = sql.methods.swiglib.execute
-- -- local execute = sql.methods.library.execute
-- -- local execute = sql.methods.client.execute
-- -- local execute = sql.methods.lmxsql.execute
--
-- result = execute {
--     presets = {
--         host      = "localhost",
--         username  = "root",
--         password  = "test",
--         database  = "test",
--         id        = "test", -- forces persistent session
--     },
--     template  = "select * from `test` where `id` > %criterium% ;",
--     variables = {
--         criterium = 2,
--     },
--     converter = converter
-- }
--
-- inspect(result)

local format, match = string.format, string.match
local random = math.random
local rawset, setmetatable, getmetatable, load, type = rawset, setmetatable, getmetatable, load, type
local P, S, V, C, Cs, Ct, Cc, Cg, Cf, patterns, lpegmatch = lpeg.P, lpeg.S, lpeg.V, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cc, lpeg.Cg, lpeg.Cf, lpeg.patterns, lpeg.match
local concat = table.concat

local osuuid            = os.uuid
local setmetatableindex = table.setmetatableindex

local trace_sql     = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries = false  trackers.register("sql.queries",function(v) trace_queries = v end)
local report_state  = logs.reporter("sql")

-- trace_sql     = true
-- trace_queries = true

utilities.sql         = utilities.sql or { }
local sql             = utilities.sql

local replacetemplate = utilities.templates.replace
local loadtemplate    = utilities.templates.load

local methods         = { }
sql.methods           = methods

local helpers         = { }
sql.helpers           = helpers

local serialize       = table.fastserialize
local deserialize     = table.deserialize

sql.serialize         = serialize
sql.deserialize       = deserialize

helpers.serialize     = serialize   -- bonus
helpers.deserialize   = deserialize -- bonus

local defaults     = { __index =
    {
        resultfile     = "result.dat",
        templatefile   = "template.sql",
        queryfile      = "query.sql",
        variables      = { },
        username       = "default",
        password       = "default",
        host           = "localhost", -- 127.0.0.1 is sometimes more reliable
        port           = 3306,
        database       = "default",
    },
}

setmetatableindex(sql.methods,function(t,k)
    if type(k) == "string" then
        report_state("start loading method %a",k)
        require("util-sql-imp-"..k)
        report_state("loading method %a done",k)
        return rawget(t,k)
    else
        report_state("invalid method %a",tostring(k))
    end
end)

-- converters

local converters = { }
sql.converters   = converters

local function makeconverter(entries,celltemplate,wraptemplate)
    local shortcuts   = { }
    local assignments = { }
    local key         = false
    for i=1,#entries do
        local entry = entries[i]
        local name  = entry.name
        local kind  = entry.type or entry.kind
        local value = format(celltemplate,i,i)
        if kind == "boolean" then
            assignments[#assignments+1] = format("[%q] = booleanstring(%s),",name,value)
        elseif kind == "number" then
            assignments[#assignments+1] = format("[%q] = tonumber(%s),",name,value)
        elseif type(kind) == "function" then
            local c = #converters + 1
            converters[c] = kind
            shortcuts[#shortcuts+1] = format("local fun_%s = converters[%s]",c,c)
            assignments[#assignments+1] = format("[%q] = fun_%s(%s),",name,c,value)
        elseif type(kind) == "table" then
            local c = #converters + 1
            converters[c] = kind
            shortcuts[#shortcuts+1] = format("local tab_%s = converters[%s]",c,c)
            assignments[#assignments+1] = format("[%q] = tab_%s[%s],",name,#converters,value)
        elseif kind == "deserialize" then
            assignments[#assignments+1] = format("[%q] = deserialize(%s),",name,value)
        elseif kind == "key" then
            -- hashed instead of indexed
            key = value
        elseif kind == "entry" then
            -- so we can (efficiently) extend the hashed table
            local default = entry.default or ""
            if type(default) == "string" then
                assignments[#assignments+1] = format("[%q] = %q,",name,default)
            else
                assignments[#assignments+1] = format("[%q] = %s,",name,tostring(default))
            end
        else
            assignments[#assignments+1] = format("[%q] = %s,",name,value)
        end
    end
    local code = format(wraptemplate,concat(shortcuts,"\n"),key and "{ }" or "data",key or "i",concat(assignments,"\n            "))
 -- print(code)
    local func = load(code)
    return func and func()
end

function sql.makeconverter(entries)
    local fields = { }
    for i=1,#entries do
        fields[i] = format("`%s`",entries[i].name)
    end
    fields = concat(fields, ", ")
    local converter = {
        fields = fields
    }
    setmetatableindex(converter, function(t,k)
        local sqlmethod = methods[k]
        local v = makeconverter(entries,sqlmethod.celltemplate,sqlmethod.wraptemplate)
        t[k] = v
        return v
    end)
    return converter, fields
end

-- helper for libraries:

local function validspecification(specification)
    local presets = specification.presets
    if type(presets) == "string" then
        presets = dofile(presets)
    end
    if type(presets) == "table" then
        setmetatable(presets,defaults)
        setmetatable(specification,{ __index = presets })
    else
        setmetatable(specification,defaults)
    end
    return true
end

helpers.validspecification = validspecification

local whitespace = patterns.whitespace^0
local eol        = patterns.eol
local separator  = P(";")
local escaped    = patterns.escaped
local dquote     = patterns.dquote
local squote     = patterns.squote
local dsquote    = squote * squote
----  quoted     = patterns.quoted
local quoted     = dquote * (escaped + (1-dquote))^0 * dquote
                 + squote * (escaped + dsquote + (1-squote))^0 * squote
local comment    = P("--") * (1-eol) / ""
local query      = whitespace
                 * Cs((quoted + comment + 1 - separator)^1 * Cc(";"))
                 * whitespace
local splitter   = Ct(query * (separator * query)^0)

helpers.querysplitter = splitter

-- I will add a bit more checking.

local function validspecification(specification)
    local presets = specification.presets
    if type(presets) == "string" then
        presets = dofile(presets)
    end
    if type(presets) == "table" then
        local m = getmetatable(presets)
        if m then
            setmetatable(m,defaults)
        else
            setmetatable(presets,defaults)
        end
        setmetatable(specification,{ __index = presets })
    else
        setmetatable(specification,defaults)
    end
    local templatefile = specification.templatefile or "query"
    local name         = file.nameonly(templatefile)
    local queryfile    = specification.queryfile  or presets.queryfile  or format("%s-temp.sql",name)
    local resultfile   = specification.resultfile or presets.resultfile or format("%s-temp.dat",name)
    specification.queryfile  = queryfile
    specification.resultfile = resultfile
    if trace_sql then
        report_state("template file: %s",templatefile or "<none>")
        report_state("query file: %s",queryfile)
        report_state("result file: %s",resultfile)
    end
    return true
end

local function preparetemplate(specification)
    local template = specification.template
    if template then
        local query = replacetemplate(template,specification.variables,'sql')
        if not query then
            report_state("error in template: %s",template)
        elseif trace_queries then
            report_state("query from template: %s",query)
        end
        return query
    end
    local templatefile = specification.templatefile
    if templatefile then
        local query = loadtemplate(templatefile,specification.variables,'sql')
        if not query then
            report_state("error in template file %a",templatefile)
        elseif trace_queries then
            report_state("query from template file %a: %s",templatefile,query)
        end
        return query
    end
    report_state("no query template or templatefile")
end

helpers.preparetemplate = preparetemplate

-- -- -- we delay setting this -- -- --

local currentmethod
local currentserver

local function firstexecute(...)
    local method = methods[currentmethod]
    if not method then
        report_state("invalid sql method")
        sql.execute = function() end
        return nil
    end
    local execute = method.execute
    sql.execute = execute
    return execute(...)
end

function sql.setmethod(method)
    currentmethod = method
    sql.execute = firstexecute
end

function sql.setserver(server)
    currentserver = server
end

function sql.getmethod()
    return currentmethod
end

function sql.getserver()
    return currentserver
end

sql.setmethod("library")
sql.setserver("mysql")

-- helper:

local sqlmethods = sql.methods

function sql.usedatabase(presets,datatable)
    local name = datatable or presets.datatable
    if name then
        local usedmethod = presets.method
        local method     = usedmethod and sqlmethods[usedmethod]
        if not method then
            usedmethod = currentmethod
            method     = usedmethod and sqlmethods[usedmethod]
        end
        if not method then
            usedmethod = sql.methods.client
            method     = usedmethod and sqlmethods[usedmethod]
            if not method then
                report_state("invalid method")
                return
            end
        end
        local base      = presets.database or "test"
        local basename  = format("`%s`.`%s`",base,name)
        local execute   = nil
        local m_execute = method.execute
        if not m_execute then
            execute = function()
                report_state("no valid execute handler")
            end
        elseif method.usesfiles then
            local queryfile   = presets.queryfile  or format("%s-temp.sql",name)
            local resultfile  = presets.resultfile or format("%s-temp.dat",name)
            execute = function(specification) -- variables template
                if not specification.presets    then specification.presets    = presets    end
                if not specification.queryfile  then specification.queryfile  = queryfile  end
                if not specification.resultfile then specification.resultfile = resultfile end
                return m_execute(specification)
            end
        else
            execute = function(specification) -- variables template
                if not specification.presets then specification.presets = presets end
                return m_execute(specification)
            end
        end
        local function unpackdata(records,name)
            if records then
                name = name or "data"
                for i=1,#records do
                    local record = records[i]
                    local data = record[name]
                    if data then
                        record[name] = deserialize(data)
                    end
                end
            end
        end
        return {
            usedmethod  = usedmethod,
            presets     = preset,
            base        = base,
            name        = name,
            basename    = basename,
            execute     = execute,
            serialize   = serialize,
            deserialize = deserialize,
            unpackdata  = unpackdata,
        }
    else
        report_state("missing name in usedatabase specification")
    end
end

-- local data = utilities.sql.prepare {
--     templatefile = "test.sql",
--     variables    = { },
--     host         = "...",
--     username     = "...",
--     password     = "...",
--     database     = "...",
-- }

-- local presets = {
--     host     = "...",
--     username = "...",
--     password = "...",
--     database = "...",
-- }
--
-- local data = utilities.sql.prepare {
--     templatefile = "test.sql",
--     variables    = { },
--     presets      = presets,
-- }

-- local data = utilities.sql.prepare {
--     templatefile = "test.sql",
--     variables    = { },
--     presets      = dofile(...),
-- }

-- local data = utilities.sql.prepare {
--     templatefile = "test.sql",
--     variables    = { },
--     presets      = "...",
-- }

-- for i=1,10 do
--     local dummy = uuid() -- else same every time, don't ask
-- end

sql.tokens = {
    length = 42, -- but in practice we will reserve some 50 characters
    new    = function()
        return format("%s-%x06",osuuid(),random(0xFFFFF)) -- 36 + 1 + 6 = 42
    end,
}

-- -- --

-- local func, code = sql.makeconverter {
--     { name = "a", type = "number" },
--     { name = "b", type = "string" },
--     { name = "c", type = "boolean" },
--     { name = "d", type = { x = "1" } },
--     { name = "e", type = os.fulltime },
-- }
--
-- print(code)

-- -- --

if tex and tex.systemmodes then

    local droptable = table.drop
    local threshold = 16 * 1024 -- use slower but less memory hungry variant

    function sql.prepare(specification,tag)
        -- could go into tuc if needed
        -- todo: serialize per column
        local tag = tag or specification.tag or "last"
        local filename = format("%s-sql-result-%s.tuc",tex.jobname,tag)
        if tex.systemmodes["first"] then
            local data, keys = sql.execute(specification)
            if not data then
                data = { }
            end
            if not keys then
                keys = { }
            end
            io.savedata(filename,droptable({ data = data, keys = keys },#keys*#data>threshold))
            return data, keys
        else
            local result = table.load(filename)
            return result.data, result.keys
        end
    end

else

    sql.prepare = sql.execute

end

return sql
