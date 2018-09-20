if not modules then modules = { } end modules ['util-sql-tracers'] = {
    version   = 1.001,
    comment   = "companion to m-sql.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local sql     = utilities.sql
local tracers = { }
sql.tracers   = tracers

sql.setmethod("swiglib")

local gsub, lower = string.gsub, string.lower

local t_names = {
    mysql = [[SHOW TABLES FROM `%database%`]],
    mssql = [[SELECT table_name FROM %database%.information_schema.tables;]],
    mssql = [[SELECT "name" FROM "%database%"."sys"."databases" ORDER BY "name";]],
    mssql = [[SELECT name FROM "%database%"."sys"."objects" WHERE "type" IN ('P', 'U', 'V', 'TR', 'FN', 'TF');]],
}

local t_fields = {
    mysql = [[SHOW FIELDS FROM `%database%`.`%table%` ]],
    mssql = [[SELECT column_name "field", data_type "type", column_default "default", is_nullable "null" FROM %database%.information_schema.columns WHERE table_name='%table%']],
}

function sql.tracers.gettables(presets)
    local servertype = sql.getserver()

    local results, keys = sql.execute {
        presets   = presets,
        template  = t_names[servertype],
        variables = {
            database = presets.database,
        },
    }

    local key    = keys and keys[1]
    local tables = { }

    if keys then
        for i=1,#results do
            local name = results[i][key]
            local results, keys = sql.execute {
                presets   = presets,
                template  = t_fields[servertype],
                variables = {
                    database = presets.database,
                    table    = name
                },
            }
            if #results > 0 then
                for i=1,#results do
                    local result = table.loweredkeys(results[i])
                    -- ms cleanup
                    result.default = gsub(result.default,"^[%(']+(.-)[%)']+$","%1")
                    result.null    = lower(result.null)
                    --
                    results[i] = result
                end
                tables[name] = results
            else
                -- a view
            end
        end
    end

    return tables
end
