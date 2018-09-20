if not modules then modules = { } end modules ['util-sql-logins'] = {
    version   = 1.001,
    comment   = "companion to lmx-*",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if not utilities.sql then require("util-sql") end

local sql              = utilities.sql
local sqlexecute       = sql.execute
local sqlmakeconverter = sql.makeconverter

local format = string.format
local ostime = os.time
local formatter = string.formatter

local trace_logins  = true
local report_logins = logs.reporter("sql","logins")

local logins = sql.logins or { }
sql.logins   = logins

logins.maxnoflogins = logins.maxnoflogins or 10
logins.cooldowntime = logins.cooldowntime or 10 * 60
logins.purgetime    = logins.purgetime    or  1 * 60 * 60
logins.autopurge    = true

local function checkeddb(presets,datatable)
    return sql.usedatabase(presets,datatable or presets.datatable or "logins")
end

logins.usedb = checkeddb

local template = [[
    CREATE TABLE IF NOT EXISTS %basename% (
        `id`    int(11)     NOT NULL AUTO_INCREMENT,
        `name`  varchar(50) NOT NULL,
        `time`  int(11)     DEFAULT '0',
        `n`     int(11)     DEFAULT '0',
        `state` int(11)     DEFAULT '0',

        PRIMARY KEY                  (`id`),
        UNIQUE KEY `id_unique_index` (`id`),
        UNIQUE KEY `name_unique_key` (`name`)
    ) DEFAULT CHARSET = utf8 ;
]]

local sqlite_template = [[
    CREATE TABLE IF NOT EXISTS %basename% (
        `id`    INTEGER NOT NULL AUTO_INCREMENT,
        `name`  TEXT    NOT NULL,
        `time`  INTEGER DEFAULT '0',
        `n`     INTEGER DEFAULT '0',
        `state` INTEGER DEFAULT '0'
    ) ;
]]

function logins.createdb(presets,datatable)

    local db = checkeddb(presets,datatable)

    local data, keys = db.execute {
        template  = db.usedmethod == "sqlite" and sqlite_template or template,
        variables = {
            basename = db.basename,
        },
    }

    report_logins("datatable %a created in %a",db.name,db.base)

    return db

end

local template =[[
    DROP TABLE IF EXISTS %basename% ;
]]

function logins.deletedb(presets,datatable)

    local db = checkeddb(presets,datatable)

    local data, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
        },
    }

    report_logins("datatable %a removed in %a",db.name,db.base)

end

local states = {
    [0] = "unset",
    [1] = "known",
    [2] = "unknown",
}

local converter_fetch, fields_fetch = sqlmakeconverter {
    { name = "id",    type = "number" },
    { name = "name",  type = "string" },
    { name = "time",  type = "number" },
    { name = "n",     type = "number" },
    { name = "state", type = "number" }, -- faster than mapping
}

local template_fetch = format( [[
    SELECT
      %s
    FROM
        `logins`
    WHERE
        `name` = '%%[name]%%'
]], fields_fetch )

local template_insert = [[
    INSERT INTO `logins`
        ( `name`, `state`, `time`, `n`)
    VALUES
        ('%[name]%', %state%, %time%, %n%)
]]

local template_update = [[
    UPDATE
        `logins`
    SET
        `state` = %state%,
        `time` = %time%,
        `n` = %n%
    WHERE
        `name` = '%[name]%'
]]

local template_delete = [[
    DELETE FROM
        `logins`
    WHERE
        `name` = '%[name]%'
]]

local template_purge = [[
    DELETE FROM
        `logins`
    WHERE
        `time` < '%time%'
]]

-- todo: auto cleanup (when new attempt)

local cache = { } setmetatable(cache, { __mode = 'v' })

-- local function usercreate(presets)
--     sqlexecute {
--         template = template_create,
--         presets  = presets,
--     }
-- end

function logins.userunknown(db,name)
    local d = {
        name  = name,
        state = 2,
        time  = ostime(),
        n     = 0,
    }
    db.execute {
        template  = template_update,
        variables = d,
    }
    cache[name] = d
    report_logins("user %a is registered as unknown",name)
end

function logins.userknown(db,name)
    local d = {
        name  = name,
        state = 1,
        time  = ostime(),
        n     = 0,
    }
    db.execute {
        template  = template_update,
        variables = d,
    }
    cache[name] = d
    report_logins("user %a is registered as known",name)
end

function logins.userreset(db,name)
    db.execute {
        template  = template_delete,
    }
    cache[name] = nil
    report_logins("user %a is reset",name)
end

local function userpurge(db,delay)
    db.execute {
        template  = template_purge,
        variables = {
            time  = ostime() - (delay or logins.purgetime),
        }
    }
    cache = { }
    report_logins("users are purged")
end

logins.userpurge = userpurge

local function verdict(okay,...)
--     if not trace_logins then
--         -- no tracing
--     else
    if okay then
        report_logins("%s, granted",formatter(...))
    else
        report_logins("%s, blocked",formatter(...))
    end
    return okay
end

local lasttime  = 0

function logins.userpermitted(db,name)
    local currenttime = ostime()
    if logins.autopurge and (lasttime == 0 or (currenttime - lasttime > logins.purgetime)) then
        report_logins("automatic purge triggered")
        userpurge(db)
        lasttime = currenttime
    end
    local data = cache[name]
    if data then
        report_logins("user %a is cached",name)
    else
        report_logins("user %a is fetched",name)
        data = db.execute {
            template  = template_fetch,
            converter = converter_fetch,
            variables = {
                name = name,
            }
        }
    end
    if not data or not data.name then
        if not data then
            report_logins("no user data for %a",name)
        else
            report_logins("no name entry for %a",name)
        end
        local d = {
            name  = name,
            state = 0,
            time  = currenttime,
            n     = 1,
        }
        db.execute {
            template  = template_insert,
            variables = d,
        }
        cache[name] = d
        return verdict(true,"creating new entry for %a",name)
    end
    cache[name] = data[1]
    local state = data.state
    if state == 2 then -- unknown
        return verdict(false,"user %a has state %a",name,states[state])
    end
    local n = data.n
    local m = logins.maxnoflogins
    if n > m then
        local deltatime = currenttime - data.time
        local cooldowntime = logins.cooldowntime
        if deltatime < cooldowntime then
            return verdict(false,"user %a is blocked for %s seconds out of %s",name,cooldowntime-deltatime,cooldowntime)
        else
            n = 0
        end
    end
    if n == 0 then
        local d = {
            name  = name,
            state = 0,
            time  = currenttime,
            n     = 1,
        }
        db.execute {
            template  = template_update,
            variables = d,
        }
        cache[name] = d
        return verdict(true,"user %a gets a first chance",name)
    else
        local d = {
            name  = name,
            state = 0,
            time  = currenttime,
            n     = n + 1,
        }
        db.execute {
            template  = template_update,
            variables = d,
        }
        cache[name] = d
        return verdict(true,"user %a gets a new chance, %s attempts out of %s done",name,n,m)
    end
end

return logins
