if not modules then modules = { } end modules ['util-sql-sessions'] = {
    version   = 1.001,
    comment   = "companion to lmx-*",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is experimental code and currently part of the base installation simply
-- because it's easier to dirtribute this way. Eventually it will be documented
-- and the related scripts will show up as well.

-- maybe store threshold in session (in seconds)

local tonumber = tonumber
local format = string.format
local ostime, uuid, osfulltime = os.time, os.uuid, os.fulltime
local random = math.random

-- In older frameworks we kept a session table in memory. This time we
-- follow a route where we store session data in a sql table. Each session
-- has a token (similar to what we do on q2p and pod services), a data
-- blob which is just a serialized lua table (we could consider a dump instead)
-- and two times: the creation and last accessed time. The first one is handy
-- for statistics and the second one for cleanup. Both are just numbers so that
-- we don't have to waste code on conversions. Anyhow, we provide variants so that
-- we can always choose what is best.

local sql         = utilities.sql
local sessions    = { }
sql.sessions      = sessions

local trace_sql   = false  trackers.register("sql.sessions.trace", function(v) trace_sql = v end)
local report      = logs.reporter("sql","sessions")

sessions.newtoken = sql.tokens.new

local function checkeddb(presets,datatable)
    return sql.usedatabase(presets,datatable or presets.datatable or "sessions")
end

sessions.usedb = checkeddb

local template =[[
    CREATE TABLE IF NOT EXISTS %basename% (
        `token`    varchar(50)       NOT NULL,
        `data`     longtext          NOT NULL,
        `created`  int(11)           NOT NULL,
        `accessed` int(11)           NOT NULL,
        UNIQUE KEY `token_unique_key` (`token`)
    ) DEFAULT CHARSET = utf8 ;
]]

local sqlite_template =[[
    CREATE TABLE IF NOT EXISTS %basename% (
        `token`    TEXT NOT NULL,
        `data`     TEXT NOT NULL,
        `created`  INTEGER DEFAULT '0',
        `accessed` INTEGER DEFAULT '0'
    ) ;
]]

function sessions.createdb(presets,datatable)

    local db = checkeddb(presets,datatable)

    db.execute {
        template  = db.usedmethod == "sqlite" and sqlite_template or template,
        variables = {
            basename = db.basename,
        },
    }

    report("datatable %a created in %a",db.name,db.base)

    return db

end

local template =[[
    DROP TABLE IF EXISTS %basename% ;
]]

function sessions.deletedb(presets,datatable)

    local db = checkeddb(presets,datatable)

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
        },
    }

    report("datatable %a removed in %a",db.name,db.base)

end

local template =[[
    INSERT INTO %basename% (
        `token`,
        `created`,
        `accessed`,
        `data`
    ) VALUES (
        '%token%',
        %time%,
        %time%,
        '%[data]%'
    ) ;
]]

function sessions.create(db,data)

    local token  = sessions.newtoken()
    local time   = ostime()

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            token    = token,
            time     = time,
            data     = db.serialize(data or { },"return")
        },
    }

    if trace_sql then
        report("created: %s at %s",token,osfulltime(time))
    end

    return {
        token    = token,
        created  = time,
        accessed = time,
        data     = data,
    }
end

local template =[[
    UPDATE
        %basename%
    SET
        `data` = '%[data]%',
        `accessed` = %time%
    WHERE
        `token` = '%token%' ;
]]

function sessions.save(db,session)

    local time  = ostime()
    local data  = db.serialize(session.data or { },"return")
    local token = session.token

    session.accessed = time

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            token    = token,
            time     = ostime(),
            data     = data,
        },
    }

    if trace_sql then
        report("saved: %s at %s",token,osfulltime(time))
    end

    return session
end

local template = [[
    UPDATE
        %basename%
    SET
        `accessed` = %time%
    WHERE
        `token` = '%token%' ;
]]

function sessions.touch(db,token)

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            token    = token,
            time     = ostime(),
        },
    }

end

local template = [[
    UPDATE
        %basename%
    SET
        `accessed` = %time%
    WHERE
        `token` = '%token%' ;
    SELECT
        *
    FROM
        %basename%
    WHERE
        `token` = '%token%' ;
]]

function sessions.restore(db,token)

    local records, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            token    = token,
            time     = ostime(),
        },
    }

    local record = records and records[1]

    if record then
        if trace_sql then
            report("restored: %s",token)
        end
        record.data = db.deserialize(record.data or "")
        return record, keys
    elseif trace_sql then
        report("unknown: %s",token)
    end

end

local template =[[
    DELETE FROM
        %basename%
    WHERE
        `token` = '%token%' ;
]]

function sessions.remove(db,token)

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            token    = token,
        },
    }

    if trace_sql then
        report("removed: %s",token)
    end

end

local template_collect_yes =[[
    SELECT
        *
    FROM
        %basename%
    ORDER BY
        `created` ;
]]

local template_collect_nop =[[
    SELECT
        `accessed`,
        `created`,
        `accessed`,
        `token`
    FROM
        %basename%
    ORDER BY
        `created` ;
]]

function sessions.collect(db,nodata)

    local records, keys = db.execute {
        template  = nodata and template_collect_nop or template_collect_yes,
        variables = {
            basename = db.basename,
        },
    }

    if not nodata then
        db.unpackdata(records)
    end

    if trace_sql then
        report("collected: %s sessions",#records)
    end

    return records, keys

end

local template_cleanup_yes =[[
    SELECT
        *
    FROM
        %basename%
    WHERE
        `accessed` < %time%
    ORDER BY
        `created` ;
    DELETE FROM
        %basename%
    WHERE
        `accessed` < %time% ;
]]

local template_cleanup_nop =[[
    SELECT
        `accessed`,
        `created`,
        `accessed`,
        `token`
    FROM
        %basename%
    WHERE
        `accessed` < %time%
    ORDER BY
        `created` ;
    DELETE FROM
        %basename%
    WHERE
        `accessed` < %time% ;
]]

function sessions.cleanupdb(db,delta,nodata)

    local time = ostime()

    local records, keys = db.execute {
        template  = nodata and template_cleanup_nop or template_cleanup_yes,
        variables = {
            basename = db.basename,
            time     = time - delta
        },
    }

    if not nodata then
        db.unpackdata(records)
    end

    if trace_sql then
        report("cleaned: %s seconds before %s",delta,osfulltime(time))
    end

    return records, keys

end
