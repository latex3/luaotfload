if not modules then modules = { } end modules ['util-sql-imp-swiglib'] = {
    version   = 1.001,
    comment   = "companion to util-sql.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- As the regular library is flawed (i.e. there are crashes in the table
-- construction code) and also not that efficient, Luigi Scarso looked into
-- a swig binding. This is a bit more low level approach but as we stay
-- closer to the original library it's also less dependant.

local concat = table.concat
local format, byte = string.format, string.byte
local lpegmatch = lpeg.match
local setmetatable, type = setmetatable, type
local sleep = os.sleep

local trace_sql              = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries          = false  trackers.register("sql.queries",function(v) trace_queries = v end)
local report_state           = logs.reporter("sql","swiglib")

local helpers                = require("swiglib.helpers.core")
local sql                    = utilities.sql
local mysql                  = require("swiglib.mysql.core") -- "5.6.14"
----- mysql                  = swiglib("mysql.core") -- "5.6.14"

local new_u_char_array       = helpers.new_u_char_array     or helpers.new_ucharArray
local ucharArray_setitem     = helpers.u_char_array_setitem or helpers.ucharArray_setitem
local int_p_assign           = helpers.int_p_assign
local ulongArray_getitem     = helpers.u_long_array_getitem or helpers.ulongArray_getitem

-- inspect(table.sortedkeys(mysql))

local nofretries             = 5
local retrydelay             = 1

local cache                  = { }
local helpers                = sql.helpers
local methods                = sql.methods
local validspecification     = helpers.validspecification
local querysplitter          = helpers.querysplitter
local dataprepared           = helpers.preparetemplate
local serialize              = sql.serialize
local deserialize            = sql.deserialize

local mysql_initialize       = mysql.mysql_init

local mysql_open_connection  = mysql.mysql_real_connect
local mysql_execute_query    = mysql.mysql_real_query
local mysql_close_connection = mysql.mysql_close

local mysql_field_seek       = mysql.mysql_field_seek
local mysql_num_fields       = mysql.mysql_num_fields
local mysql_fetch_field      = mysql.mysql_fetch_field
local mysql_num_rows         = mysql.mysql_num_rows
local mysql_fetch_row        = mysql.mysql_fetch_row
local mysql_fetch_lengths    = mysql.mysql_fetch_lengths
local mysql_init             = mysql.mysql_init
local mysql_store_result     = mysql.mysql_store_result
local mysql_free_result      = mysql.mysql_free_result
local mysql_use_result       = mysql.mysql_use_result

local mysql_error_message    = mysql.mysql_error
----- mysql_options_argument = mysql.mysql_options_argument

local instance               = mysql.MYSQL()

local mysql_constant_false   = false
local mysql_constant_true    = true

----- util_getbytearray      = mysql.util_getbytearray

-- if mysql_options_argument then
--
--     mysql_constant_false = mysql_options_argument(false) -- 0 "\0"
--     mysql_constant_true  = mysql_options_argument(true)  -- 1 "\1"
--
--     -- print(swig_type(mysql_constant_false))
--     -- print(swig_type(mysql_constant_true))
--
--     mysql.mysql_options(instance,mysql.MYSQL_OPT_RECONNECT,mysql_constant_true);
--
-- else
--
--     print("")
--     print("incomplete swiglib.mysql interface")
--     print("")
--
-- end

-- some helpers:

function mysql.options_argument(arg)
    local targ = type(arg)
    if targ == "boolean" then
        local o = new_u_char_array(1)
        ucharArray_setitem(o,0,arg == true and 64 or 0)
        return o
    elseif targ == "string" then
        local o = new_u_char_array(#arg)
        ucharArray_setitem(o,0,0)
        for i=1,#arg do
            ucharArray_setitem(o,i-1,byte(arg,i))
        end
        return o
    elseif targ == "number" then
        local o = core.new_int_p()
        int_p_assign(o, arg)
        return o
    else
        return nil
    end
end

-- function mysql.util_unpackbytearray(row,noffields,len)
--     if row == nil then
--         return { }
--     elseif noffields < 1 then
--         return { }
--     else
--         local t = { }
--         for i=0,noffields-1 do
--             local l = ulongArray_getitem(len,i)  -- zero based ... element from len array
--             local r = util_getbytearray(row,i,l) -- zero based ... element from len array
--             t[#t+1]= r
--         end
--         return t
--     end
-- end

--

-- local typemap = mysql.MYSQL_TYPE_VAR_STRING and {
--     [mysql.MYSQL_TYPE_VAR_STRING ]  = "string",
--     [mysql.MYSQL_TYPE_STRING     ]  = "string",
--     [mysql.MYSQL_TYPE_DECIMAL    ]  = "number",
--     [mysql.MYSQL_TYPE_SHORT      ]  = "number",
--     [mysql.MYSQL_TYPE_LONG       ]  = "number",
--     [mysql.MYSQL_TYPE_FLOAT      ]  = "number",
--     [mysql.MYSQL_TYPE_DOUBLE     ]  = "number",
--     [mysql.MYSQL_TYPE_LONGLONG   ]  = "number",
--     [mysql.MYSQL_TYPE_INT24      ]  = "number",
--     [mysql.MYSQL_TYPE_YEAR       ]  = "number",
--     [mysql.MYSQL_TYPE_TINY       ]  = "number",
--     [mysql.MYSQL_TYPE_TINY_BLOB  ]  = "binary",
--     [mysql.MYSQL_TYPE_MEDIUM_BLOB]  = "binary",
--     [mysql.MYSQL_TYPE_LONG_BLOB  ]  = "binary",
--     [mysql.MYSQL_TYPE_BLOB       ]  = "binary",
--     [mysql.MYSQL_TYPE_DATE       ]  = "date",
--     [mysql.MYSQL_TYPE_NEWDATE    ]  = "date",
--     [mysql.MYSQL_TYPE_DATETIME   ]  = "datetime",
--     [mysql.MYSQL_TYPE_TIME       ]  = "time",
--     [mysql.MYSQL_TYPE_TIMESTAMP  ]  = "time",
--     [mysql.MYSQL_TYPE_ENUM       ]  = "set",
--     [mysql.MYSQL_TYPE_SET        ]  = "set",
--     [mysql.MYSQL_TYPE_NULL       ]  = "null",
-- }

-- real_escape_string

local function finish(t)
    local r = t._result_
    if r then
        mysql_free_result(r)
    end
end

-- will become metatable magic

-- local function analyze(result)
--     mysql_field_seek(result,0)
--     local nofrows = mysql_num_rows(result) or 0
--     local noffields = mysql_num_fields(result)
--     local names = { }
--     local types = { }
--     for i=1,noffields do
--         local field = mysql_fetch_field(result)
--         names[i] = field.name
--         types[i] = field.type
--     end
--     return names, types, noffields, nofrows
-- end

local function getcolnames(t)
    return t.names
end

local function getcoltypes(t)
    return t.types
end

local function numrows(t)
    return t.nofrows
end

local fetch_fields_from_current_row = mysql.util_mysql_fetch_fields_from_current_row
local fetch_all_rows                = mysql.util_mysql_fetch_all_rows

-- swig_type

-- local function list(t)
--     local result = t._result_
--     local row = mysql_fetch_row(result)
--     local len = mysql_fetch_lengths(result)
--     local result = { }
--     for i=1,t.noffields do
--         local r = i - 1 -- zero offset
--         result[i] = util_getbytearray(row,r,ulongArray_getitem(len,r))
--     end
--     return result
-- end

-- local function hash(t)
--     local list = fetch_fields_from_current_row(t._result_)
--     local result = t._result_
--     local fields = t.names
--     local row = mysql_fetch_row(result)
--     local len = mysql_fetch_lengths(result)
--     local result = { }
--     for i=1,t.noffields do
--         local r = i - 1 -- zero offset
--         result[fields[i]] = util_getbytearray(row,r,ulongArray_getitem(len,r))
--     end
--     return result
-- end

local function list(t)
    return fetch_fields_from_current_row(t._result_)
end

local function hash(t)
    local list = fetch_fields_from_current_row(t._result_)
    local fields = t.names
    local data = { }
    for i=1,t.noffields do
        data[fields[i]] = list[i]
    end
    return data
end

local function wholelist(t)
    return fetch_all_rows(t._result_)
end

local mt = { __index = {
        -- regular
        finish      = finish,
        list        = list,
        hash        = hash,
        wholelist   = wholelist,
        -- compatibility
        numrows     = numrows,
        getcolnames = getcolnames,
        getcoltypes = getcoltypes,
        -- fallback
        _result_    = nil,
        names       = { },
        types       = { },
        noffields   = 0,
        nofrows     = 0,
    }
}

local nt = setmetatable({},mt)

-- session

local function close(t)
    mysql_close_connection(t._connection_)
end

local function execute(t,query)
    if query and query ~= "" then
        local connection = t._connection_
        local result = mysql_execute_query(connection,query,#query)
        if result == 0 then
            local result = mysql_store_result(connection)
            if result then
                mysql_field_seek(result,0)
                local nofrows   = mysql_num_rows(result) or 0
                local noffields = mysql_num_fields(result)
                local names     = { }
                local types     = { }
                for i=1,noffields do
                    local field = mysql_fetch_field(result)
                    names[i] = field.name
                    types[i] = field.type
                end
                local t = {
                    _result_  = result,
                    names     = names,
                    types     = types,
                    noffields = noffields,
                    nofrows   = nofrows,
                }
                return setmetatable(t,mt)
            else
                return nt
            end
        end
    end
    return false
end

local mt = { __index = {
        close   = close,
        execute = execute,
    }
}

local function open(t,database,username,password,host,port)
    local connection = mysql_open_connection(t._session_,host or "localhost",username or "",password or "",database or "",port or 0,0,0)
    if connection then
        local t = {
            _connection_ = connection,
        }
        return setmetatable(t,mt)
    end
end

local function message(t)
    return mysql_error_message(t._session_)
end

local function close(t)
    -- dummy, as we have a global session
end

local mt = {
    __index = {
        connect = open,
        close   = close,
        message = message,
    }
}

local function initialize()
    local session = {
        _session_ = mysql_initialize(instance) -- maybe share, single thread anyway
    }
    return setmetatable(session,mt)
end

-- -- -- --

local function connect(session,specification)
    return session:connect(
        specification.database or "",
        specification.username or "",
        specification.password or "",
        specification.host     or "",
        specification.port
    )
end

local function error_in_connection(specification,action)
    report_state("error in connection: [%s] %s@%s to %s:%s",
            action or "unknown",
            specification.database or "no database",
            specification.username or "no username",
            specification.host     or "no host",
            specification.port     or "no port"
        )
end

local function datafetched(specification,query,converter)
    if not query or query == "" then
        report_state("no valid query")
        return { }, { }
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
            connection = connect(session,specification)
            if not connection then
                for i=1,nofretries do
                    sleep(retrydelay)
                    report_state("retrying to connect: [%s.%s] %s@%s to %s:%s",
                            id,i,
                            specification.database or "no database",
                            specification.username or "no username",
                            specification.host     or "no host",
                            specification.port     or "no port"
                        )
                    connection = connect(session,specification)
                    if connection then
                        break
                    end
                end
            end
            if connection then
                cache[id] = { session = session, connection = connection }
            end
        end
    else
        session = initialize()
        connection = connect(session,specification)
        if not connection then
            for i=1,nofretries do
                sleep(retrydelay)
                report_state("retrying to connect: [%s] %s@%s to %s:%s",
                        i,
                        specification.database or "no database",
                        specification.username or "no username",
                        specification.host     or "no host",
                        specification.port     or "no port"
                    )
                connection = connect(session,specification)
                if connection then
                    break
                end
            end
        end
    end
    if not connection then
        report_state("error in connection: %s@%s to %s:%s",
                specification.database or "no database",
                specification.username or "no username",
                specification.host     or "no host",
                specification.port     or "no port"
            )
        return { }, { }
    end
    query = lpegmatch(querysplitter,query)
    local result, message, okay
    for i=1,#query do
        local q = query[i]
        local r, m = connection:execute(q)
        if m then
            report_state("error in query, stage: %s",string.collapsespaces(q or "?"))
            message = message and format("%s\n%s",message,m) or m
        end
        if type(r) == "table" then
            result = r
            okay = true
        elseif not m  then
            okay = true
        end
    end
    local data, keys
    if result then
        if converter then
            data = converter.swiglib(result)
        else
            keys = result.names
            data = { }
            for i=1,result.nofrows do
                data[i] = result:hash()
            end
        end
        result:finish() -- result:close()
    elseif message then
        report_state("message %s",message)
    end
    if not keys then
        keys = { }
    end
    if not data then
        data = { }
    end
    if not id then
        connection:close()
        session:close()
    end
    return data, keys
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

local wraptemplate = [[
local mysql         = require("swiglib.mysql.core") -- will be stored in method

local fetch_fields  = mysql.util_mysql_fetch_fields_from_current_row

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
    local nofrows = result.nofrows or 0
    if nofrows == 0 then
        return { }
    end
    local noffields = result.noffields or 0
    local target = { } -- no %s needed here
    result = result._result_
    for i=1,nofrows do
        local cells = fetch_fields(result)
        target[%s] = {
            %s
        }
    end
    return target
end
]]

local celltemplate = "cells[%s]"

methods.swiglib = {
    runner       = function() end, -- never called
    execute      = execute,
    initialize   = initialize, -- returns session
    usesfiles    = false,
    wraptemplate = wraptemplate,
    celltemplate = celltemplate,
}
