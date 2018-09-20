if not modules then modules = { } end modules ['util-sql-loggers'] = {
    version   = 1.001,
    comment   = "companion to lmx-*",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is experimental code and currently part of the base installation simply
-- because it's easier to dirtribute this way. Eventually it will be documented
-- and the related scripts will show up as well.

local tonumber = tonumber
local format = string.format
local concat = table.concat
local ostime, uuid, osfulltime = os.time, os.uuid, os.fulltime
local random = math.random

local sql           = utilities.sql
local loggers       = { }
sql.loggers         = loggers

local trace_sql     = false  trackers.register("sql.loggers.trace", function(v) trace_sql = v end)
local report        = logs.reporter("sql","loggers")

loggers.newtoken    = sql.tokens.new
local makeconverter = sql.makeconverter

local function checkeddb(presets,datatable)
    return sql.usedatabase(presets,datatable or presets.datatable or "loggers")
end

loggers.usedb = checkeddb

local totype = {
    ["error"]   = 1, [1] = 1, ["1"] = 1,
    ["warning"] = 2, [2] = 2, ["2"] = 2,
    ["debug"]   = 3, [3] = 3, ["3"] = 3,
    ["info"]    = 4, [4] = 4, ["4"] = 4,
}

local fromtype = {
    ["error"]   = "error",   [1] = "error",   ["1"] = "error",
    ["warning"] = "warning", [2] = "warning", ["2"] = "warning",
    ["debug"]   = "debug",   [3] = "debug",   ["3"] = "debug",
    ["info"]    = "info",    [4] = "info",    ["4"] = "info",
}

table.setmetatableindex(totype,  function() return 4      end)
table.setmetatableindex(fromtype,function() return "info" end)

loggers.totype   = totype
loggers.fromtype = fromtype

local template = [[
CREATE TABLE IF NOT EXISTS %basename% (
    `id`     int(11) NOT NULL AUTO_INCREMENT,
    `time`   int(11) NOT NULL,
    `type`   int(11) NOT NULL,
    `action` varchar(15) NOT NULL,
    `data`   longtext,
    PRIMARY KEY (`id`),
    UNIQUE KEY `id_unique_key` (`id`)
) DEFAULT CHARSET = utf8 ;
]]

local sqlite_template = [[
    CREATE TABLE IF NOT EXISTS %basename% (
        `id`     INTEGER PRIMARY KEY AUTOINCREMENT,
        `time`   INTEGER NOT NULL,
        `type`   INTEGER NOT NULL,
        `action` TEXT NOT NULL,
        `data`   TEXT
    ) ;
]]

function loggers.createdb(presets,datatable)

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

function loggers.deletedb(presets,datatable)

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
        `time`,
        `type`,
        `action`,
        `data`
    ) VALUES (
        %time%,
        %type%,
        '%action%',
        '%[data]%'
    ) ;
]]

-- beware, when we either pass a dat afield explicitly or we're using
-- a flat table and then nill type and action in the data (which
-- saves a table)

function loggers.save(db,data)

    if data then

        local time   = ostime()
        local kind   = totype[data.type]
        local action = data.action or "unknown"

        local extra  = data.data

        if extra then
            -- we have a dedicated data table
            data = extra
        else
            -- we have a flat table
            data.type   = nil
            data.action = nil
        end

        db.execute {
            template  = template,
            variables = {
                basename = db.basename,
                time     = ostime(),
                type     = kind,
                action   = action,
                data     = data and db.serialize(data,"return") or "",
            },
        }

    end

end

local template =[[
    DELETE FROM %basename% %WHERE% ;
]]

function loggers.cleanup(db,specification)

    specification = specification or { }

    local today   = os.date("*t")
    local before  = specification.before or today
    local where   = { }

    if type(before) == "number" then
        before = os.date(before)
    end

    before = os.time {
        day    = before.day    or today.day,
        month  = before.month  or today.month,
        year   = before.year   or today.year,
        hour   = before.hour   or 0,
        minute = before.minute or 0,
        second = before.second or 0,
        isdst  = true,
    }

    where[#where+1] = format("`time` < %s",before)

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            WHERE    = format("WHERE\n%s",concat(where," AND ")),
        },
    }

    if db.usedmethod == "sqlite" then
        db.execute {
            template  = "VACUUM ;",
        }
    end

end

local template_nop =[[
    SELECT
        `time`,
        `type`,
        `action`,
        `data`
    FROM
        %basename%
    ORDER BY
        `time`, `type`, `action`
    DESC LIMIT
        %limit% ;
]]

local template_yes =[[
    SELECT
        `time`,
        `type`,
        `action`,
        `data`
    FROM
        %basename%
    %WHERE%
    ORDER BY
        `time`, `type`, `action`
    DESC LIMIT
        %limit% ;
]]

local converter = makeconverter {
 -- { name = "time",   type = os.localtime  },
    { name = "time",   type = "number"      },
    { name = "type",   type = fromtype      },
    { name = "action", type = "string"      },
    { name = "data",   type = "deserialize" },
}

function loggers.collect(db,specification)

    specification = specification or { }

    local start  = specification.start
    local stop   = specification.stop
    local limit  = specification.limit or 100
    local kind   = specification.type
    local action = specification.action

    local filtered = start or stop

    local where  = { }

    if filtered then
        local today = os.date("*t")

        if type(start) ~= "table" then
            start = { }
        end
        start = os.time {
            day    = start.day    or today.day,
            month  = start.month  or today.month,
            year   = start.year   or today.year,
            hour   = start.hour   or 0,
            minute = start.minute or 0,
            second = start.second or 0,
            isdst  = true,
        }

        if type(stop) ~= "table" then
            stop = { }
        end
        stop = os.time {
            day    = stop.day    or today.day,
            month  = stop.month  or today.month,
            year   = stop.year   or today.year,
            hour   = stop.hour   or 24,
            minute = stop.minute or 0,
            second = stop.second or 0,
            isdst  = true,
        }

     -- report("filter: %s => %s",start,stop)

        where[#where+1] = format("`time` BETWEEN %s AND %s",start,stop)

    end

    if kind then
        where[#where+1] = format("`type` = %s",totype[kind])
    end

    if action then
        where[#where+1] = format("`action` = '%s'",action)
    end

    local records = db.execute {
        template  = filtered and template_yes or template_nop,
        converter = converter,
        variables = {
            basename = db.basename,
            limit    = limit,
            WHERE    = #where > 0 and format("WHERE\n%s",concat(where," AND ")) or "",
        },
    }

    if trace_sql then
        report("collected: %s loggers",#records)
    end

    return records, keys

end
