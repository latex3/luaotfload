if not modules then modules = { } end modules ['util-sql-tickets'] = {
    version   = 1.001,
    comment   = "companion to lmx-*",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- TODO: MAKE SOME INTO STORED PROCUDURES

-- This is experimental code and currently part of the base installation simply
-- because it's easier to distribute this way. Eventually it will be documented
-- and the related scripts will show up as well.

local tonumber = tonumber
local format = string.format
local ostime, uuid, osfulltime = os.time, os.uuid, os.fulltime
local random = math.random
local concat = table.concat

if not utilities.sql then require("util-sql") end

local sql         = utilities.sql
local tickets     = { }
sql.tickets       = tickets

local trace_sql   = false  trackers.register("sql.tickets.trace", function(v) trace_sql = v end)
local report      = logs.reporter("sql","tickets")

local serialize   = sql.serialize
local deserialize = sql.deserialize

tickets.newtoken  = sql.tokens.new

-- Beware as an index can be a string or a number, we will create
-- a combination of hash and index.

local statustags  = { [0] =
    "unknown",
    "pending",
    "busy",
    "finished",
    "dependent", -- same token but different subtoken (so we only need to find the first)
    "reserved-1",
    "reserved-2",
    "error",
    "deleted",
}

local status       = table.swapped(statustags)
tickets.status     = status
tickets.statustags = statustags

local s_unknown   = status.unknown
local s_pending   = status.pending
local s_busy      = status.busy
----- s_finished  = status.finished
local s_dependent = status.dependent
local s_error     = status.error
local s_deleted   = status.deleted

local s_rubish    = s_error -- and higher

local function checkeddb(presets,datatable)
    return sql.usedatabase(presets,datatable or presets.datatable or "tickets")
end

tickets.usedb = checkeddb

local template = [[
    CREATE TABLE IF NOT EXISTS %basename% (
        `id`        int(11)     NOT NULL AUTO_INCREMENT,
        `token`     varchar(50) NOT NULL,
        `subtoken`  INT(11)     NOT NULL,
        `created`   int(11)     NOT NULL,
        `accessed`  int(11)     NOT NULL,
        `category`  int(11)     NOT NULL,
        `status`    int(11)     NOT NULL,
        `usertoken` varchar(50) NOT NULL,
        `data`      longtext    NOT NULL,
        `comment`   longtext    NOT NULL,

        PRIMARY KEY                     (`id`),
        UNIQUE INDEX `id_unique_index`  (`id` ASC),
        KEY          `token_unique_key` (`token`)
    ) DEFAULT CHARSET = utf8 ;
]]

local sqlite_template = [[
    CREATE TABLE IF NOT EXISTS %basename% (
        `id`        TEXT NOT NULL AUTO_INCREMENT,
        `token`     TEXT NOT NULL,
        `subtoken`  INTEGER DEFAULT '0',
        `created`   INTEGER DEFAULT '0',
        `accessed`  INTEGER DEFAULT '0',
        `category`  INTEGER DEFAULT '0',
        `status`    INTEGER DEFAULT '0',
        `usertoken` TEXT NOT NULL,
        `data`      TEXT NOT NULL,
        `comment`   TEXT NOT NULL
    ) ;
]]

function tickets.createdb(presets,datatable)

    local db = checkeddb(presets,datatable)

    local data, keys = db.execute {
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

function tickets.deletedb(presets,datatable)

    local db = checkeddb(presets,datatable)

    local data, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
        },
    }

    report("datatable %a removed in %a",db.name,db.base)

end

local template_push =[[
    INSERT INTO %basename% (
        `token`,
        `subtoken`,
        `created`,
        `accessed`,
        `status`,
        `category`,
        `usertoken`,
        `data`,
        `comment`
    ) VALUES (
        '%token%',
         %subtoken%,
         %time%,
         %time%,
         %status%,
         %category%,
        '%usertoken%',
        '%[data]%',
        '%[comment]%'
    ) ;
]]

local template_fetch =[[
    SELECT
        *
    FROM
        %basename%
    WHERE
        `token` = '%token%'
    AND
        `subtoken` = '%subtoken%'
    ;
]]

function tickets.create(db,ticket)

    -- We assume a unique token .. if not we're toast anyway. We used to lock and
    -- get the last id etc etc but there is no real need for that.

    -- we could check for dependent here but we don't want the lookup

    local token     = ticket.token     or tickets.newtoken()
    local time      = ostime()
    local status    = ticket.status
    local category  = ticket.category  or 0
    local subtoken  = ticket.subtoken  or 0
    local usertoken = ticket.usertoken or ""
    local comment   = ticket.comment   or ""

    status = not status and subtoken > 1 and s_dependent or s_pending

    local result, message = db.execute {
        template  = template_push,
        variables = {
            basename  = db.basename,
            token     = token,
            subtoken  = subtoken,
            time      = time,
            status    = status,
            category  = category,
            usertoken = usertoken,
            data      = db.serialize(ticket.data or { },"return"),
            comment   = comment,
        },
    }

    -- We could stick to only fetching the id and make the table here
    -- but we're not pushing that many tickets so we can as well follow
    -- the lazy approach and fetch the whole.

    local result, message = db.execute {
        template  = template_fetch,
        variables = {
            basename  = db.basename,
            token     = token,
            subtoken  = subtoken,
        },
    }

    if result and #result > 0 then
        if trace_sql then
            report("created: %s at %s",token,osfulltime(time))
        end
        return result[1]
    else
        report("failed: %s at %s",token,osfulltime(time))
    end

end

local template =[[
    UPDATE
        %basename%
    SET
        `data` = '%[data]%',
        `status` = %status%,
        `accessed` = %time%
    WHERE
        `id` = %id% ;
]]

function tickets.save(db,ticket)

    local time   = ostime()
    local data   = db.serialize(ticket.data or { },"return")
    local status = ticket.status or s_error

-- print("SETTING")
-- inspect(data)

    ticket.status   = status
    ticket.accessed = time

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = ticket.id,
            time     = ostime(),
            status   = status,
            data     = data,
        },
    }

    if trace_sql then
        report("saved: id %s, time %s",id,osfulltime(time))
    end

    return ticket
end

local template =[[
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
        `id` = %id% ;
]]

function tickets.restore(db,id)

    local record, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = id,
            time     = ostime(),
        },
    }

    local record = record and record[1]

    if record then
        if trace_sql then
            report("restored: id %s",id)
        end
        record.data = db.deserialize(record.data or "")
        return record
    elseif trace_sql then
        report("unknown: id %s",id)
    end

end

local template =[[
    DELETE FROM
        %basename%
    WHERE
        `id` = %id% ;
]]

function tickets.remove(db,id)

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = id,
        },
    }

    if trace_sql then
        report("removed: id %s",id)
    end

end

local template_yes =[[
    SELECT
        *
    FROM
        %basename%
    ORDER BY
        `id` ;
]]

local template_nop =[[
    SELECT
        `created`,
        `usertoken`,
        `accessed`,
        `status`
    FROM
        %basename%
    ORDER BY
        `id` ;
]]

function tickets.collect(db,nodata)

    local records, keys = db.execute {
        template  = nodata and template_nop or template_yes,
        variables = {
            basename = db.basename,
            token    = token,
        },
    }

    if not nodata then
        db.unpackdata(records)
    end

    if trace_sql then
        report("collected: %s tickets",#records)
    end

    return records, keys

end

-- We aleays keep the last select in the execute so one can have
-- an update afterwards.

local template =[[
    DELETE FROM
        %basename%
    WHERE
        `accessed` < %time% OR `status` >= %rubish% ;
]]

local template_cleanup_yes =[[
    SELECT
        *
    FROM
        %basename%
    WHERE
        `accessed` < %time%
    ORDER BY
        `id` ;
]] .. template

local template_cleanup_nop =[[
    SELECT
        `accessed`,
        `created`,
        `accessed`,
        `token`
        `usertoken`
    FROM
        %basename%
    WHERE
        `accessed` < %time%
    ORDER BY
        `id` ;
]] .. template

function tickets.cleanupdb(db,delta,nodata) -- maybe delta in db

    local now  = ostime()
    local time = delta and (now - delta) or now

    local records, keys = db.execute {
        template  = nodata and template_cleanup_nop or template_cleanup_yes,
        variables = {
            basename = db.basename,
            time     = time,
            rubish   = s_rubish,
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

-- status related functions

local template =[[
    SELECT
        `status`
    FROM
        %basename%
    WHERE
        `token` = '%token%'
    ORDER BY
        `id`
    ;
]]

function tickets.getstatus(db,token)

    local record, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            token    = token,
        },
    }

    local record = record and record[1]

    return record and record.status or s_unknown

end

local template =[[
    SELECT
        `status`
    FROM
        %basename%
    WHERE
        `status` >= %rubish% OR `accessed` < %time%
    ORDER BY
        `id`
    ;
]]

function tickets.getobsolete(db,delta)

    local time = delta and (ostime() - delta) or 0

    local records = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            time     = time,
            rubish   = s_rubish,
        },
    }

    db.unpackdata(records)

    return records

end

local template =[[
    SELECT
        `id`
    FROM
        %basename%
    WHERE
        `status` = %status%
    LIMIT
        1 ;
]]

function tickets.hasstatus(db,status)

    local records = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            status   = status or s_unknown,
        },
    }

    return records and #records > 0 or false

end

local template =[[
    UPDATE
        %basename%
    SET
        `status` = %status%,
        `accessed` = %time%
    WHERE
        `id` = %id% ;
]]

function tickets.setstatus(db,id,status)

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = id,
            time     = ostime(),
            status   = status or s_error,
        },
    }

end

local template =[[
    DELETE FROM
        %basename%
    WHERE
        `status` IN (%status%) ;
]]

function tickets.prunedb(db,status)

    if type(status) == "table" then
        status = concat(status,",")
    end

    local data, keys = db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            status   = status or s_unknown,
        },
    }

    if trace_sql then
        report("pruned: status %s removed",status)
    end

end

-- START TRANSACTION ; ... COMMIT ;
-- LOCK TABLES %basename% WRITE ; ... UNLOCK TABLES ;

local template_a = [[
    SET
        @last_ticket_token = '' ;
    UPDATE
        %basename%
    SET
        `token` = (@last_ticket_token := `token`),
        `status` = %newstatus%,
        `accessed` = %time%
    WHERE
        `status` = %status%
    ORDER BY
        `id`
    LIMIT
        1
    ;
    SELECT
        *
    FROM
        %basename%
    WHERE
        `token` = @last_ticket_token
    ORDER BY
        `id`
    ;
]]

local template_b = [[
    SELECT
        *
    FROM
        tickets
    WHERE
        `status` = %status%
    ORDER BY
        `id`
    LIMIT
        1
    ;
]]

function tickets.getfirstwithstatus(db,status,newstatus)

    local records

    if type(newstatus) == "number" then -- todo: also accept string

        records = db.execute {
            template  = template_a,
            variables = {
                basename  = db.basename,
                status    = status or s_pending,
                newstatus = newstatus,
                time      = ostime(),
            },
        }


    else

        records = db.execute {
            template  = template_b,
            variables = {
                basename = db.basename,
                status   = status or s_pending,
            },
        }

    end

    if type(records) == "table" and #records > 0 then

        for i=1,#records do
            local record = records[i]
            record.data = db.deserialize(record.data or "")
            record.status = newstatus or s_busy
        end

        return records

    end
end

-- The next getter assumes that we have a sheduler running so that there is
-- one process in charge of changing the status.

local template = [[
    SET
        @last_ticket_token = '' ;
    UPDATE
        %basename%
    SET
        `token` = (@last_ticket_token := `token`),
        `status` = %newstatus%,
        `accessed` = %time%
    WHERE
        `status` = %status%
    ORDER BY
        `id`
    LIMIT
        1
    ;
    SELECT
        @last_ticket_token AS `token`
    ;
]]

function tickets.getfirstinqueue(db,status,newstatus)

    local records = db.execute {
        template  = template,
        variables = {
            basename  = db.basename,
            status    = status or s_pending,
            newstatus = newstatus or s_busy,
            time      = ostime(),
        },
    }

    local token = type(records) == "table" and #records > 0 and records[1].token

    return token ~= "" and token

end

local template =[[
    SELECT
        *
    FROM
        %basename%
    WHERE
        `token` = '%token%'
    ORDER BY
        `id` ;
]]

function tickets.getticketsbytoken(db,token)

    local records, keys = db.execute {
        template  = template,
        variables = {
            basename  = db.basename,
            token = token,
        },
    }

    db.unpackdata(records)

    return records

end

local template =[[
    SELECT
        *
    FROM
        %basename%
    WHERE
        `usertoken` = '%usertoken%' AND `status` < %rubish%
    ORDER BY
        `id` ;
]]

function tickets.getusertickets(db,usertoken)

    -- todo: update accessed
    -- todo: get less fields
    -- maybe only data for status changed (hard to check)

    local records, keys = db.execute {
        template  = template,
        variables = {
            basename  = db.basename,
            usertoken = usertoken,
            rubish    = s_rubish,
        },
    }

    db.unpackdata(records)

    return records

end

local template =[[
    UPDATE
        %basename%
    SET
        `status` = %deleted%
    WHERE
        `usertoken` = '%usertoken%' ;
]]

function tickets.removeusertickets(db,usertoken)

    db.execute {
        template  = template,
        variables = {
            basename  = db.basename,
            usertoken = usertoken,
            deleted   = s_deleted,
        },
    }

    if trace_sql then
        report("removed: usertoken %s",usertoken)
    end

end
