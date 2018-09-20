if not modules then modules = { } end modules ['util-sql-imp-client'] = {
    version   = 1.001,
    comment   = "companion to util-sql.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: make a converter

local rawset, setmetatable = rawset, setmetatable
local P, S, V, C, Cs, Ct, Cc, Cg, Cf, patterns, lpegmatch = lpeg.P, lpeg.S, lpeg.V, lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cc, lpeg.Cg, lpeg.Cf, lpeg.patterns, lpeg.match

local trace_sql          = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries      = false  trackers.register("sql.queries",function(v) trace_queries = v end)
local report_state       = logs.reporter("sql","client")

local sql                = utilities.sql
local helpers            = sql.helpers
local methods            = sql.methods
local validspecification = helpers.validspecification
local preparetemplate    = helpers.preparetemplate
local splitdata          = helpers.splitdata
local replacetemplate    = utilities.templates.replace
local serialize          = sql.serialize
local deserialize        = sql.deserialize
local getserver          = sql.getserver

local osclock            = os.gettimeofday

-- Experiments with an p/action demonstrated that there is not much gain. We could do a runtime
-- capture but creating all the small tables is not faster and it doesn't work well anyway.

local separator    = P("\t")
local newline      = patterns.newline
local empty        = Cc("")

local entry        = C((1-separator-newline)^0) -- C 10% faster than Cs

local unescaped    = P("\\n")  / "\n"
                   + P("\\t")  / "\t"
                   + P("\\0")  / "\000"
                   + P("\\\\") / "\\"

local entry        = Cs((unescaped + (1-separator-newline))^0) -- C 10% faster than Cs but Cs needed due to nesting

local getfirst     = Ct( entry * (separator * (entry+empty))^0) + newline
local skipfirst    = (1-newline)^1 * newline
local skipdashes   = (P("-")+separator)^1 * newline
local getfirstline = C((1-newline)^0)

local cache        = { }

local function splitdata(data) -- todo: hash on first line ... maybe move to client module
    if data == "" then
        if trace_sql then
            report_state("no data")
        end
        return { }, { }
    end
    local first = lpegmatch(getfirstline,data)
    if not first then
        if trace_sql then
            report_state("no data")
        end
        return { }, { }
    end
    local p = cache[first]
    if p then
     -- report_state("reusing: %s",first)
        local entries = lpegmatch(p.parser,data)
        return entries or { }, p.keys
    elseif p == false then
        return { }, { }
    elseif p == nil then
        local keys = lpegmatch(getfirst,first) or { }
        if #keys == 0 then
            if trace_sql then
                report_state("no banner")
            end
            cache[first] = false
            return { }, { }
        end
        -- quite generic, could be a helper
        local n = #keys
        if n == 0 then
            report_state("no fields")
            cache[first] = false
            return { }, { }
        end
        if n == 1 then
            local key = keys[1]
            if trace_sql then
                report_state("one field with name %a",key)
            end
            p = Cg(Cc(key) * entry)
        else
            for i=1,n do
                local key = keys[i]
                if trace_sql then
                    report_state("field %s has name %a",i,key)
                end
                local s = Cg(Cc(key) * entry)
                if p then
                    p = p * separator * s
                else
                    p = s
                end
            end
        end
        p = Cf(Ct("") * p,rawset) * newline^1
        if getserver() == "mssql" then
            p = skipfirst * skipdashes * Ct(p^0)
        else
            p = skipfirst * Ct(p^0)
        end
        cache[first] = { parser = p, keys = keys }
        local entries = lpegmatch(p,data)
        return entries or { }, keys
    end
end

local splitter = skipfirst * Ct((Ct(entry * (separator * entry)^0) * newline^1)^0)

local function getdata(data)
    return lpegmatch(splitter,data)
end

helpers.splitdata = splitdata
helpers.getdata   = getdata

local t_runner = {
    mysql = [[mysql --batch --user="%username%" --password="%password%" --host="%host%" --port=%port% --database="%database%" --default-character-set=utf8 < "%queryfile%" > "%resultfile%"]],
    mssql = [[sqlcmd -S %host% %?U: -U "%username%" ?% %?P: -P "%password%" ?% -I -W -w 65535 -s"]] .. "\t" .. [[" -m 1 -i "%queryfile%" -o "%resultfile%"]],
}

local t_runner_login = {
    mysql = [[mysql --login-path="%login%" --batch --database="%database%" --default-character-set=utf8 < "%queryfile%" > "%resultfile%"]],
    mssql = [[sqlcmd -S %host% %?U: -U "%username%" ?% %?P: -P "%password%" ?% -I -W -w 65535 -s"]] .. "\t" .. [[" -m 1 -i "%queryfile%" -o "%resultfile%"]],
}

local t_preamble = {
    mysql = [[
SET GLOBAL SQL_MODE=ANSI_QUOTES;
    ]],
    mssql = [[
:setvar SQLCMDERRORLEVEL 1
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
%?database: USE %database%; ?%
    ]],
}

local function dataprepared(specification)
    local query = preparetemplate(specification)
    if query then
        local preamble  = t_preamble[getserver()] or t_preamble.mysql
        if preamble then
            preamble = replacetemplate(preamble,specification.variables,'sql')
            query = preamble .. "\n" .. query
        end
        io.savedata(specification.queryfile,query)
        os.remove(specification.resultfile)
        if trace_queries then
            report_state("query: %s",query)
        end
        return true
    else
        -- maybe push an error
        os.remove(specification.queryfile)
        os.remove(specification.resultfile)
    end
end

local function datafetched(specification)
    local runner  = (specification.login and t_runner_login or t_runner)[getserver()] or t_runner.mysql
    local command = replacetemplate(runner,specification)
    if trace_sql then
        local t = osclock()
        report_state("command: %s",command)
        -- for now we don't use sandbox.registerrunners as this module is
        -- also used outside context
        local okay = os.execute(command)
        report_state("fetchtime: %.3f sec, return code: %i",osclock()-t,okay) -- not okay under linux
        return okay == 0
    else
        return os.execute(command) == 0
    end
end

local function dataloaded(specification)
    if trace_sql then
        local t = osclock()
        local data = io.loaddata(specification.resultfile) or ""
        report_state("datasize: %.3f MB",#data/1024/1024)
        report_state("loadtime: %.3f sec",osclock()-t)
        return data
    else
        return io.loaddata(specification.resultfile) or ""
    end
end

local function dataconverted(data,converter)
    if converter then
        local data = getdata(data)
        if data then
            data = converter.client(data)
        end
        return data
    elseif trace_sql then
        local t = osclock()
        local data, keys = splitdata(data,target)
        report_state("converttime: %.3f",osclock()-t)
        report_state("keys: %s ",#keys)
        report_state("entries: %s ",#data)
        return data, keys
    else
        return splitdata(data)
    end
end

-- todo: new, etc

local function execute(specification)
    if trace_sql then
        report_state("executing client")
    end
    if not validspecification(specification) then
        report_state("error in specification")
        return
    end
    if not dataprepared(specification) then
        report_state("error in preparation")
        return
    end
    if not datafetched(specification) then
        report_state("error in fetching, query: %s",string.collapsespaces(io.loaddata(specification.queryfile) or "?"))
        return
    end
    local data = dataloaded(specification)
    if not data then
        report_state("error in loading")
        return
    end
    local data, keys = dataconverted(data,specification.converter)
    if not data then
        report_state("error in converting or no data")
        return
    end
    local one = data[1]
    if one then
        setmetatable(data,{ __index = one } )
    end
    return data, keys
end

-- The following is not that (memory) efficient but normally we will use
-- the lib anyway. Of course we could make a dedicated converter and/or
-- hook into the splitter code but ... it makes not much sense because then
-- we can as well move the builder to the library modules.
--
-- Here we reuse data as the indexes are the same, unless we hash.

local wraptemplate = [[
local converters    = utilities.sql.converters
local deserialize   = utilities.sql.deserialize

local tostring      = tostring
local tonumber      = tonumber
local booleanstring = string.booleanstring

%s

return function(data)
    local target = %s -- data or { }
    for i=1,#data do
        local cells = data[i]
        target[%s] = {
            %s
        }
    end
    return target
end
]]

local celltemplate = "cells[%s]"

methods.client = {
    execute      = execute,
    usesfiles    = true,
    wraptemplate = wraptemplate,
    celltemplate = celltemplate,
}
