if not modules then modules = { } end modules ['util-sql-imp-ffi'] = {
    version   = 1.001,
    comment   = "companion to util-sql.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- I looked at luajit-mysql to see how the ffi mapping was done but it didn't work
-- out that well (at least not on windows) but I got the picture. As I have somewhat
-- different demands I simplified / redid the ffi bit and just took the swiglib
-- variant and adapted that.

local tonumber = tonumber
local concat = table.concat
local format, byte = string.format, string.byte
local lpegmatch = lpeg.match
local setmetatable, type = setmetatable, type
local sleep = os.sleep

local trace_sql     = false  trackers.register("sql.trace",  function(v) trace_sql     = v end)
local trace_queries = false  trackers.register("sql.queries",function(v) trace_queries = v end)
local report_state  = logs.reporter("sql","ffi")

if not utilities.sql then
    require("util-sql")
end

ffi.cdef [[

    /*
        This is as lean and mean as possible. After all we just need a connection and
        a query. The rest is handled already in the Lua code elsewhere.
    */

    void free(void*ptr);
    void * malloc(size_t size);

    typedef void MYSQL_instance;
    typedef void MYSQL_result;
    typedef char **MYSQL_row;
    typedef unsigned int MYSQL_offset;

    typedef struct st_mysql_field {
        char *name;
        char *org_name;
        char *table;
        char *org_table;
        char *db;
        char *catalog;
        char *def;
        unsigned long length;
        unsigned long max_length;
        unsigned int name_length;
        unsigned int org_name_length;
        unsigned int table_length;
        unsigned int org_table_length;
        unsigned int db_length;
        unsigned int catalog_length;
        unsigned int def_length;
        unsigned int flags;
        unsigned int decimals;
        unsigned int charsetnr;
        int type;
        void *extension;
    } MYSQL_field;

    void free(void*ptr);
    void * malloc(size_t size);

    MYSQL_instance * mysql_init (
        MYSQL_instance *mysql
    );

    MYSQL_instance * mysql_real_connect (
        MYSQL_instance *mysql,
        const char *host,
        const char *user,
        const char *passwd,
        const char *db,
        unsigned int port,
        const char *unix_socket,
        unsigned long clientflag
    );

    unsigned int mysql_errno (
        MYSQL_instance *mysql
    );

    const char *mysql_error (
        MYSQL_instance *mysql
    );

    /* int mysql_query (
        MYSQL_instance *mysql,
        const char *q
    ); */

    int mysql_real_query (
        MYSQL_instance *mysql,
        const char *q,
        unsigned long length
    );

    MYSQL_result * mysql_store_result (
        MYSQL_instance *mysql
    );

    void mysql_free_result (
        MYSQL_result *result
    );

    unsigned long long mysql_num_rows (
        MYSQL_result *res
    );

    MYSQL_row mysql_fetch_row (
        MYSQL_result *result
    );

    unsigned int mysql_affected_rows (
        MYSQL_instance *mysql
    );

    unsigned int mysql_field_count (
        MYSQL_instance *mysql
    );

    unsigned int mysql_num_fields (
        MYSQL_result *res
    );

    /* MYSQL_field *mysql_fetch_field (
        MYSQL_result *result
    ); */

    MYSQL_field * mysql_fetch_fields (
        MYSQL_result *res
    );

    MYSQL_offset mysql_field_seek(
        MYSQL_result *result,
        MYSQL_offset offset
    );

    void mysql_close(
        MYSQL_instance *sock
    );

    /* unsigned long * mysql_fetch_lengths(
        MYSQL_result *result
    ); */

]]

local sql                    = utilities.sql
----- mysql                  = ffi.load(os.name == "windows" and "libmysql" or "libmysqlclient")
----- mysql                  = ffilib(os.name == "windows" and "libmysql" or "libmysqlclient")
local mysql                  = ffilib(os.name == "windows" and "libmysql" or "libmysql")

if not mysql then
    report_state("unable to load library")
end

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

local mysql_open_session     = mysql.mysql_init

local mysql_open_connection  = mysql.mysql_real_connect
local mysql_execute_query    = mysql.mysql_real_query
local mysql_close_connection = mysql.mysql_close

local mysql_affected_rows    = mysql.mysql_affected_rows
local mysql_field_count      = mysql.mysql_field_count
local mysql_field_seek       = mysql.mysql_field_seek
local mysql_num_fields       = mysql.mysql_num_fields
local mysql_fetch_fields     = mysql.mysql_fetch_fields
----- mysql_fetch_field      = mysql.mysql_fetch_field
local mysql_num_rows         = mysql.mysql_num_rows
local mysql_fetch_row        = mysql.mysql_fetch_row
----- mysql_fetch_lengths    = mysql.mysql_fetch_lengths
local mysql_init             = mysql.mysql_init
local mysql_store_result     = mysql.mysql_store_result
local mysql_free_result      = mysql.mysql_free_result

local mysql_error_number     = mysql.mysql_errno
local mysql_error_message    = mysql.mysql_error

local NULL                   = ffi.cast("MYSQL_result *",0)

local ffi_tostring           = ffi.string
local ffi_gc                 = ffi.gc

local instance               = mysql.mysql_init(nil)

local mysql_constant_false   = false
local mysql_constant_true    = true

local wrapresult  do

    local function collect(t)
        local result = t._result_
        if result then
            ffi_gc(result,mysql_free_result)
        end
    end

    local function finish(t)
        local result = t._result_
        if result then
            t._result_ = nil
            ffi_gc(result,mysql_free_result)
        end
    end

    local function getcoldata(t)
        local result = t._result_
        local nofrows   = t.nofrows
        local noffields = t.noffields
        local names     = { }
        local types     = { }
        local fields    = mysql_fetch_fields(result)
        for i=1,noffields do
            local field = fields[i-1]
            names[i] = ffi_tostring(field.name)
            types[i] = tonumber(field.type) -- todo
        end
        t.names = names
        t.types = types
    end

    local function getcolnames(t)
        local names = t.names
        if names then
            return names
        end
        getcoldata(t)
        return t.names
    end

    local function getcoltypes(t)
        local types = t.types
        if types then
            return types
        end
        getcoldata(t)
        return t.types
    end

    local function numrows(t)
        return t.nofrows
    end

    -- local function fetch(t)
    --     local
    --     local row    = mysql_fetch_row(result)
    --     local result = { }
    --     for i=1,t.noffields do
    --         result[i] = ffi_tostring(row[i-1])
    --     end
    --     return unpack(result)
    -- end

    local mt = {
        __gc    = collect,
        __index = {
            _result_    = nil,
            close       = finish,
            numrows     = numrows,
            getcolnames = getcolnames,
            getcoltypes = getcoltypes,
         -- fetch       = fetch, -- not efficient
        }
    }

    wrapresult = function(connection)
        local result = mysql_store_result(connection)
        if result ~= NULL then
            mysql_field_seek(result,0)
            local t = {
                _result_  = result,
                nofrows   = tonumber(mysql_num_rows  (result) or 0) or 0,
                noffields = tonumber(mysql_num_fields(result) or 0) or 0,
            }
            return setmetatable(t,mt)
        elseif tonumber(mysql_field_count(connection) or 0) or 0 > 0 then
            return tonumber(mysql_affected_rows(connection))
        end
    end

end

local initializesession  do

    -- timeouts = [ connect_timeout |wait_timeout | interactive_timeout ]

    local timeout -- = 3600 -- to be tested

    -- connection

    local function close(t)
        -- just a struct ?
    end

    local function execute(t,query)
        if query and query ~= "" then
            local connection = t._connection_
            local result = mysql_execute_query(connection,query,#query)
            if result == 0 then
                return wrapresult(connection)
            else
             -- mysql_error_number(connection)
                return false, ffi_tostring(mysql_error_message(connection))
            end
        end
        return false
    end

    local mt = {
        __index = {
            close   = close,
            execute = execute,
        }
    }

    -- session

    local function open(t,database,username,password,host,port)
        local connection = mysql_open_connection(
            t._session_,
            host or "localhost",
            username or "",
            password or "",
            database or "",
            port or 0,
            NULL,
            0
        )
        if connection ~= NULL then
            if timeout then
                execute(connection,formatters["SET SESSION connect_timeout=%s ;"](timeout))
            end
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
        local connection = t._connection_
        if connection and connection ~= NULL then
            ffi_gc(connection, mysql_close)
            t.connection = nil
        end
    end

    local mt = {
        __index = {
            connect = open,
            close   = close,
            message = message,
        },
    }

    initializesession = function()
        local session = {
            _session_ = mysql_open_session(instance) -- maybe share, single thread anyway
        }
        return setmetatable(session,mt)
    end

end

local executequery  do

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
                session = initializesession()
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
            session = initializesession()
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
            if t == "table" then
                result = r
                okay = true
            elseif t == "number" then
                okay = true
            end
        end
        if not okay then -- can go
            -- why do we close a session
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
                data = converter.ffi(result)
            else
                local _result_  = result._result_
                local noffields = result.noffields
                local nofrows   = result.nofrows
                keys = result:getcolnames()
                data = { }
                if noffields > 0 and nofrows > 0 then
                    for i=1,nofrows do
                        local cells = { }
                        local row   = mysql_fetch_row(_result_)
                        for j=1,noffields do
                            local s = row[j-1]
                            local k = keys[j]
                            if s == NULL then
                                cells[k] = ""
                            else
                                cells[k] = ffi_tostring(s)
                            end
                        end
                        data[i] = cells
                    end
                end
            end
            result:close()
        end
        --
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

    executequery = function(specification)
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

end

local wraptemplate = [[
----- mysql           = ffi.load(os.name == "windows" and "libmysql" or "libmysqlclient")
local mysql           = ffi.load(os.name == "windows" and "libmysql" or "libmysql")

local mysql_fetch_row = mysql.mysql_fetch_row
local ffi_tostring    = ffi.string

local converters      = utilities.sql.converters
local deserialize     = utilities.sql.deserialize

local tostring        = tostring
local tonumber        = tonumber
local booleanstring   = string.booleanstring

local NULL            = ffi.cast("MYSQL_result *",0)

%s

return function(result)
    if not result then
        return { }
    end
    local nofrows = result.nofrows
    if nofrows == 0 then
        return { }
    end
    local noffields = result.noffields
    local target    = { } -- no %s needed here
    local _result_  = result._result_
    -- we can share cells
    for i=1,nofrows do
        local cells = { }
        local row   = mysql_fetch_row(_result_)
        for j=1,noffields do
            local s = row[j-1]
            if s == NULL then
                cells[j] = ""
            else
                cells[j] = ffi_tostring(s)
            end
        end
        target[%s] = {
            %s
        }
    end
    result:close()
    return target
end
]]

local celltemplate = "cells[%s]"

methods.ffi = {
    runner       = function() end,    -- never called
    execute      = executequery,
    initialize   = initializesession, -- returns session
    usesfiles    = false,
    wraptemplate = wraptemplate,
    celltemplate = celltemplate,
}
