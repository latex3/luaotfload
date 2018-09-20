if not modules then modules = { } end modules ['util-sql-imp-library'] = {
    version   = 1.001,
    comment   = "companion to util-sql.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- local function pcall(f,...) return true, f(...) end

-- For some reason the sql lib partially fails in luatex when creating hashed row. So far
-- we couldn't figure it out (some issue with adapting the table that is passes as first
-- argument in the fetch routine. Apart from this it looks like the mysql binding has some
-- efficiency issues (like creating a keys and types table for each row) but that could be
-- optimized. Anyhow, fetching results can be done as follows:

-- local function collect_1(r)
--     local t = { }
--     for i=1,r:numrows() do
--         t[#t+1] = r:fetch({},"a")
--     end
--     return t
-- end
--
-- local function collect_2(r)
--     local keys   = r:getcolnames()
--     local n      = #keys
--     local t      = { }
--     for i=1,r:numrows() do
--         local v = { r:fetch() }
--         local r = { }
--         for i=1,n do
--             r[keys[i]] = v[i]
--         end
--         t[#t+1] = r
--     end
--     return t
-- end
--
-- local function collect_3(r)
--     local keys   = r:getcolnames()
--     local n      = #keys
--     local t      = { }
--     for i=1,r:numrows() do
--         local v = r:fetch({},"n")
--         local r = { }
--         for i=1,n do
--             r[keys[i]] = v[i]
--         end
--         t[#t+1] = r
--     end
--     return t
-- end
--
-- On a large table with some 8 columns (mixed text and numbers) we get the following
-- timings (the 'a' alternative is already using the more efficient variant in the
-- binding).
--
-- collect_1 : 1.31
-- collect_2 : 1.39
-- collect_3 : 1.75
--
-- Some, as a workaround for this 'bug' the second alternative can be used.

local format = string.format
local lpegmatch = lpeg.match
local setmetatable, type = setmetatable, type

local trace_sql          = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries      = false  trackers.register("sql.queries",function(v) trace_queries = v end)
local report_state       = logs.reporter("sql","library")

local sql                = utilities.sql
local mysql              = require("luasql.mysql")
local cache              = { }
local helpers            = sql.helpers
local methods            = sql.methods
local validspecification = helpers.validspecification
local querysplitter      = helpers.querysplitter
local dataprepared       = helpers.preparetemplate
local serialize          = sql.serialize
local deserialize        = sql.deserialize
local formatters         = string.formatters

local initialize         = mysql.mysql

local function connect(session,specification)
    return session:connect(
        specification.database or "",
        specification.username or "",
        specification.password or "",
        specification.host     or "",
        specification.port
    )
end

local function fetched(specification,query,converter)
    if not query or query == "" then
        report_state("no valid query")
        return false
    end
    local id = specification.id
    local session, connection
    if id then
        local c = cache[id]
        if c then
            session    = c.session
            connection = c.connection
        end
        if not connection then
            session = initialize()
            if not session then
                return formatters["no session for %a"](id)
            end
            connection = connect(session,specification)
            if not connection then
                return formatters["no connection for %a"](id)
            end
            cache[id] = { session = session, connection = connection }
        end
    else
        session = initialize()
        if not session then
            return "no session"
        end
        connection = connect(session,specification)
        if not connection then
            return "no connection"
        end
    end
    if not connection then
        report_state("error in connection: %s@%s to %s:%s",
            specification.database or "no database",
            specification.username or "no username",
            specification.host     or "no host",
            specification.port     or "no port"
        )
        return "no connection"
    end
    query = lpegmatch(querysplitter,query)
    local result, okay
    for i=1,#query do
        local q = query[i]
        local r, m = connection:execute(q)
        if m then
            report_state("error in query to host %a: %s",specification.host,string.collapsespaces(q or "?"))
            if m then
                report_state("message: %s",m)
            end
        end
        local t = type(r)
        if t == "userdata" then
            result = r
            okay = true
        elseif t == "number" then
            okay = true
        end
    end
    if not okay then
        if connection then
            connection:close()
        end
        if session then
            session:close()
        end
        if id then
            cache[id] = nil
        end
        return "execution error"
    end
    local data, keys
    if result then
        if converter then
            data = converter.library(result)
        else
            keys = result:getcolnames()
            if keys then
                data = { }
                local n = result:numrows() or 0
                if n > 0 then
                    local k = #keys
                    for i=1,n do
                        local v = { result:fetch() }
                        local d = { }
                        for i=1,k do
                            d[keys[i]] = v[i]
                        end
                        data[#data+1] = d
                    end
                end
            end
        end
        result:close()
    end
    if not id then
        if connection then
            connection:close()
        end
        if session then
            session:close()
        end
    end
    return false, data, keys
end

local function datafetched(specification,query,converter)
    local callokay, connectionerror, data, keys = pcall(fetched,specification,query,converter)
    if not callokay then
        report_state("call error, retrying")
        callokay, connectionerror, data, keys = pcall(fetched,specification,query,converter)
    elseif connectionerror then
        report_state("error: %s, retrying",connectionerror)
        callokay, connectionerror, data, keys = pcall(fetched,specification,query,converter)
    end
    if not callokay then
        report_state("persistent call error")
    elseif connectionerror then
        report_state("persistent error: %s",connectionerror)
    end
    return data or { }, keys or { }
end

local function execute(specification)
    if trace_sql then
        report_state("executing library")
    end
    if not validspecification(specification) then
        report_state("error in specification")
        return
    end
    local query = dataprepared(specification)
    if not query then
        report_state("error in preparation")
        return
    end
    local data, keys = datafetched(specification,query,specification.converter)
    if not data then
        report_state("error in fetching")
        return
    end
    local one = data[1]
    if one then
        setmetatable(data,{ __index = one } )
    end
    return data, keys
end

-- Here we build the dataset stepwise so we don't use the data hack that
-- is used in the client variant.

local wraptemplate = [[
local converters    = utilities.sql.converters
local deserialize   = utilities.sql.deserialize

local tostring      = tostring
local tonumber      = tonumber
local booleanstring = string.booleanstring

%s

return function(result)
    if not result then
        return { }
    end
    local nofrows = result:numrows() or 0
    if nofrows == 0 then
        return { }
    end
    local target = { } -- no %s needed here
    for i=1,nofrows do
        local cells = { result:fetch() }
        target[%s] = {
            %s
        }
    end
    return target
end
]]

local celltemplate = "cells[%s]"

methods.library = {
    runner       = function() end, -- never called
    execute      = execute,
    initialize   = initialize,     -- returns session
    usesfiles    = false,
    wraptemplate = wraptemplate,
    celltemplate = celltemplate,
}
