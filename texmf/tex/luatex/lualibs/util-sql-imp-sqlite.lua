if not modules then modules = { } end modules ['util-sql-imp-sqlite'] = {
    version   = 1.001,
    comment   = "companion to util-sql.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, tonumber = next, tonumber

local sql                = utilities.sql or require("util-sql")

local trace_sql          = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries      = false  trackers.register("sql.queries",function(v) trace_queries = v end)
local report_state       = logs.reporter("sql","sqlite")

local helpers            = sql.helpers
local methods            = sql.methods
local validspecification = helpers.validspecification
local preparetemplate    = helpers.preparetemplate

local setmetatable       = setmetatable
local formatters         = string.formatters

----- sqlite             = require("swiglib.sqlite.core")
----- swighelpers        = require("swiglib.helpers.core")
-----
----- get_list_item      = sqlite.char_p_array_getitem
----- is_okay            = sqlite.SQLITE_OK
----- execute_query      = sqlite.sqlite3_exec_lua_callback
----- error_message      = sqlite.sqlite3_errmsg
-----
----- new_db             = sqlite.new_sqlite3_p_array
----- open_db            = sqlite.sqlite3_open
----- get_db             = sqlite.sqlite3_p_array_getitem
----- close_db           = sqlite.sqlite3_close
----- dispose_db         = sqlite.delete_sqlite3_p_array

local ffi = require("ffi")

ffi.cdef [[

    typedef struct sqlite3 sqlite3;

    int sqlite3_initialize (
        void
    ) ;

    int sqlite3_open (
        const char *filename,
        sqlite3 **ppDb
    ) ;

    int sqlite3_close (
        sqlite3 *
    ) ;

    int sqlite3_exec (
        sqlite3*,
        const char *sql,
        int (*callback)(void*,int,char**,char**),
        void *,
        char **errmsg
    ) ;

    const char *sqlite3_errmsg (
        sqlite3*
    );
]]

local ffi_tostring = ffi.string

----- sqlite = ffi.load("sqlite3")
local sqlite = ffilib("sqlite3")

sqlite.sqlite3_initialize();

local c_errmsg = sqlite.sqlite3_errmsg
local c_open   = sqlite.sqlite3_open
local c_close  = sqlite.sqlite3_close
local c_exec   = sqlite.sqlite3_exec

local is_okay       = 0
local open_db       = c_open
local close_db      = c_close
local execute_query = c_exec

local function error_message(db)
    return ffi_tostring(c_errmsg(db))
end

local function new_db(n)
    return ffi.new("sqlite3*["..n.."]")
end

local function dispose_db(db)
end

local function get_db(db,n)
    return db[n]
end

-- local function execute_query(dbh,query,callback)
--     local c = ffi.cast("int (*callback)(void*,int,char**,char**)",callback)
--     c_exec(dbh,query,c,nil,nil)
--     c:free()
-- end

local cache = { }

setmetatable(cache, {
    __gc = function(t)
        for k, v in next, t do
            if trace_sql then
                report_state("closing session %a",k)
            end
            close_db(v.dbh)
            dispose_db(v.db)
        end
    end
})

-- synchronous  journal_mode  locking_mode    1000 logger inserts
--
-- normal       normal        normal          6.8
-- off          off           normal          0.1
-- normal       off           normal          2.1
-- normal       persist       normal          5.8
-- normal       truncate      normal          4.2
-- normal       truncate      exclusive       4.1

local f_preamble = formatters[ [[
ATTACH `%s` AS `%s` ;
PRAGMA `%s`.synchronous = normal ;
PRAGMA journal_mode = truncate ;
]] ]

local function execute(specification)
    if trace_sql then
        report_state("executing sqlite")
    end
    if not validspecification(specification) then
        report_state("error in specification")
    end
    local query = preparetemplate(specification)
    if not query then
        report_state("error in preparation")
        return
    end
    local base = specification.database -- or specification.presets and specification.presets.database
    if not base then
        report_state("no database specified")
        return
    end
    local filename = file.addsuffix(base,"db")
    local result   = { }
    local keys     = { }
    local id       = specification.id
    local db       = nil
    local dbh      = nil
    local okay     = false
    local preamble = nil
    if id then
        local session = cache[id]
        if session then
            dbh  = session.dbh
            okay = is_okay
        else
            db       = new_db(1)
            okay     = open_db(filename,db)
            dbh      = get_db(db,0)
            preamble = f_preamble(filename,base,base)
            if okay ~= is_okay then
                report_state("no session database specified")
            else
                cache[id] = {
                    name = filename,
                    db   = db,
                    dbh  = dbh,
                }
            end
        end
    else
        db       = new_db(1)
        okay     = open_db(filename,db)
        dbh      = get_db(db,0)
        preamble = f_preamble(filename,base,base)
    end
    if okay ~= is_okay then
        report_state("no database opened")
    else
        local converter = specification.converter
        local keysdone  = false
        local nofrows   = 0
        local callback  = nil
        if preamble then
            query = preamble .. query -- only needed in open
        end
        if converter then
            local convert = converter.sqlite
            local column  = { }
            callback = function(data,nofcolumns,values,fields)
                for i=1,nofcolumns do
                 -- column[i] = get_list_item(values,i-1)
                    column[i] = ffi_tostring(values[i-1])
                end
                nofrows = nofrows + 1
                result[nofrows] = convert(column)
                return is_okay
            end
        else
            local column = { }
            callback = function(data,nofcolumns,values,fields)
                for i=0,nofcolumns-1 do
                    local field
                    if keysdone then
                        field = keys[i+1]
                    else
                     -- field = get_list_item(fields,i)
                        field = ffi_tostring(fields[i])
                        keys[i+1] = field
                    end
                 -- column[field] = get_list_item(values,i)
                    column[field] = ffi_tostring(values[i])
                end
                nofrows  = nofrows + 1
                keysdone = true
                result[nofrows] = column
                return is_okay
            end
        end
        local okay = execute_query(dbh,query,callback,nil,nil)
        if okay ~= is_okay then
            report_state("error: %s",error_message(dbh))
     -- elseif converter then
     --     result = converter.sqlite(result)
        end
    end
    if not id then
        close_db(dbh)
        dispose_db(db)
    end
    return result, keys
end

local wraptemplate = [[
local converters    = utilities.sql.converters
local deserialize   = utilities.sql.deserialize

local tostring      = tostring
local tonumber      = tonumber
local booleanstring = string.booleanstring

%s

return function(cells)
    -- %s (not needed)
    -- %s (not needed)
    return {
        %s
    }
end
]]

local celltemplate = "cells[%s]"

methods.sqlite = {
    execute      = execute,
    usesfiles    = false,
    wraptemplate = wraptemplate,
    celltemplate = celltemplate,
}
