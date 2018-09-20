if not modules then modules = { } end modules ['util-sql-users'] = {
    version   = 1.001,
    comment   = "companion to lmx-*",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This is experimental code and currently part of the base installation simply
-- because it's easier to dirtribute this way. Eventually it will be documented
-- and the related scripts will show up as well.

local sql = utilities.sql

local find, topattern = string.find, string.topattern
local sumHEXA = md5.sumHEXA
local toboolean = string.toboolean
local lpegmatch = lpeg.match

local sql   = require("util-sql") -- utilities.sql
local users = { }
sql.users   = users

local trace_sql = false  trackers.register("sql.users.trace", function(v) trace_sql = v end)
local report    = logs.reporter("sql","users")

local split = lpeg.splitat(":")

local valid = nil
local hash  = function(s) return "MD5:" .. sumHEXA(s) end
local sha2  = sha2 or (utilities and utilities.sha2)

if not sha2 and LUAVERSION >= 5.3 then
    sha2 = require("util-sha")
end

if sha2 then

    local HASH224 = sha2.HASH224
    local HASH256 = sha2.HASH256
    local HASH384 = sha2.HASH384
    local HASH512 = sha2.HASH512

    valid = {
        MD5    = hash,
        SHA224 = function(s) return "SHA224:" .. HASH224(s) end,
        SHA256 = function(s) return "SHA256:" .. HASH256(s) end,
        SHA384 = function(s) return "SHA384:" .. HASH384(s) end,
        SHA512 = function(s) return "SHA512:" .. HASH512(s) end,
    }

else

    valid = {
        MD5    = hash,
        SHA224 = hash,
        SHA256 = hash,
        SHA384 = hash,
        SHA512 = hash,
    }

end

local function encryptpassword(str,how)
    if not str or str == "" then
        return ""
    end
    local prefix, rest = lpegmatch(split,str)
    if prefix and rest and valid[prefix] then
        return str
    end
    return (how and valid[how] or valid.MD5)(str)
end

local function cleanuppassword(str)
    local prefix, rest = lpegmatch(split,str)
    if prefix and rest and valid[prefix] then
        return rest
    end
    return str
end

local function samepasswords(one,two)
    if not one or not two then
        return false
    end
    return encryptpassword(one) == encryptpassword(two)
end

local function validaddress(address,addresses)
    if address and addresses and address ~= "" and addresses ~= "" then
        if find(address,topattern(addresses,true,true)) then
            return true, "valid remote address"
        end
        return false, "invalid remote address"
    else
        return true, "no remote address check"
    end
end

users.encryptpassword = encryptpassword
users.cleanuppassword = cleanuppassword
users.samepasswords   = samepasswords
users.validaddress    = validaddress

-- print(users.encryptpassword("test")) -- MD5:098F6BCD4621D373CADE4E832627B4F6

local function checkeddb(presets,datatable)
    return sql.usedatabase(presets,datatable or presets.datatable or "users")
end

users.usedb = checkeddb

local groupnames   = { }
local groupnumbers = { }

local function registergroup(name)
    local n = #groupnames + 1
    groupnames  [n]           = name
    groupnames  [tostring(n)] = name
    groupnames  [name]        = name
    groupnumbers[n]           = n
    groupnumbers[tostring(n)] = n
    groupnumbers[name]        = n
    return n
end

registergroup("superuser")
registergroup("administrator")
registergroup("user")
registergroup("guest")

users.groupnames   = groupnames
users.groupnumbers = groupnumbers

-- password 'test':
--
-- INSERT insert into users (`name`,`password`,`group`,`enabled`) values ('...','MD5:098F6BCD4621D373CADE4E832627B4F6',1,1) ;
--
-- MD5:098F6BCD4621D373CADE4E832627B4F6
-- SHA224:90A3ED9E32B2AAF4C61C410EB925426119E1A9DC53D4286ADE99A809
-- SHA256:9F86D081884C7D659A2FEAA0C55AD015A3BF4F1B2B0B822CD15D6C15B0F00A08
-- SHA384:768412320F7B0AA5812FCE428DC4706B3CAE50E02A64CAA16A782249BFE8EFC4B7EF1CCB126255D196047DFEDF17A0A9
-- SHA512:EE26B0DD4AF7E749AA1A8EE3C10AE9923F618980772E473F8819A5D4940E0DB27AC185F8A0E1D5F84F88BC887FD67B143732C304CC5FA9AD8E6F57F50028A8FF

-- old values (a name can have utf and a password a long hash):
--
-- name 80, fullname 80, password 50

local template = [[
    CREATE TABLE `users` (
        `id`       int(11)      NOT NULL AUTO_INCREMENT,
        `name`     varchar(100) NOT NULL,
        `fullname` varchar(100) NOT NULL,
        `password` varchar(200) DEFAULT NULL,
        `group`    int(11)      NOT NULL,
        `enabled`  int(11)      DEFAULT '1',
        `email`    varchar(80)  DEFAULT NULL,
        `address`  varchar(256) DEFAULT NULL,
        `theme`    varchar(50)  DEFAULT NULL,
        `data`     longtext,
        PRIMARY KEY (`id`),
        UNIQUE KEY `name_unique` (`name`)
    ) DEFAULT CHARSET = utf8 ;
]]

local sqlite_template = [[
    CREATE TABLE `users` (
        `id`       INTEGER PRIMARY KEY AUTOINCREMENT,
        `name`     TEXT NOT NULL,
        `fullname` TEXT NOT NULL,
        `password` TEXT DEFAULT NULL,
        `group`    INTEGER NOT NULL,
        `enabled`  INTEGER DEFAULT '1',
        `email`    TEXT DEFAULT NULL,
        `address`  TEXT DEFAULT NULL,
        `theme`    TEXT DEFAULT NULL,
        `data`     TEXT DEFAULT NULL
    ) ;
]]

local converter, fields = sql.makeconverter {
    { name = "id",       type = "number"      },
    { name = "name",     type = "string"      },
    { name = "fullname", type = "string"      },
    { name = "password", type = "string"      },
    { name = "group",    type = groupnames    },
    { name = "enabled",  type = "boolean"     },
    { name = "email",    type = "string"      },
    { name = "address",  type = "string"      },
    { name = "theme",    type = "string"      },
    { name = "data",     type = "deserialize" },
}

function users.createdb(presets,datatable)

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
    SELECT
        %fields%
    FROM
        %basename%
    WHERE
        `name` = '%[name]%'
    AND
        `password` = '%[password]%'
    ;
]]

local template =[[
    SELECT
        %fields%
    FROM
        %basename%
    WHERE
        `name` = '%[name]%'
    ;
]]

function users.valid(db,username,password,address)

    local data = db.execute {
        template  = template,
        converter = converter,
        variables = {
            basename = db.basename,
            fields   = fields,
            name     = username,
        },
    }
    local data = data and data[1]
    if not data then
        return false, "unknown user"
    elseif not data.enabled then
        return false, "disabled user"
    elseif data.password ~= encryptpassword(password) then
        return false, "wrong password"
    elseif not validaddress(address,data.address) then
        return false, "invalid address"
    else
        data.password = nil
        return data, "okay"
    end

end

local template =[[
    INSERT INTO %basename% (
        `name`,
        `fullname`,
        `password`,
        `group`,
        `enabled`,
        `email`,
        `address`,
        `theme`,
        `data`
    ) VALUES (
        '%[name]%',
        '%[fullname]%',
        '%[password]%',
        '%[group]%',
        '%[enabled]%',
        '%[email]%',
        '%[address]%',
        '%[theme]%',
        '%[data]%'
    ) ;
]]

function users.add(db,specification)

    local name = specification.username or specification.name

    if not name or name == "" then
        return
    end

    local data = specification.data

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            name     = name,
            fullname = name or fullname,
            password = encryptpassword(specification.password or ""),
            group    = groupnumbers[specification.group] or groupnumbers.guest,
            enabled  = toboolean(specification.enabled) and "1" or "0",
            email    = specification.email,
            address  = specification.address,
            theme    = specification.theme,
            data     = type(data) == "table" and db.serialize(data,"return") or "",
        },
    }

end

local template =[[
    SELECT
        %fields%
    FROM
        %basename%
    WHERE
        `name` = '%[name]%' ;
]]

function users.getbyname(db,name)

    local data = db.execute {
        template  = template,
        converter = converter,
        variables = {
            basename = db.basename,
            fields   = fields,
            name     = name,
        },
    }

    return data and data[1] or nil

end

local template =[[
    SELECT
        %fields%
    FROM
        %basename%
    WHERE
        `id` = '%id%' ;
]]

local function getbyid(db,id)

    local data = db.execute {
        template  = template,
        converter = converter,
        variables = {
            basename = db.basename,
            fields   = fields,
            id       = id,
        },
    }

    return data and data[1] or nil

end

users.getbyid = getbyid

local template =[[
    UPDATE
        %basename%
    SET
        `fullname` = '%[fullname]%',
        `password` = '%[password]%',
        `group`    = '%[group]%',
        `enabled`  = '%[enabled]%',
        `email`    = '%[email]%',
        `address`  = '%[address]%',
        `theme`    = '%[theme]%',
        `data`     = '%[data]%'
    WHERE
        `id` = '%id%'
    ;
]]

function users.save(db,id,specification)

    id = tonumber(id)

    if not id then
        return
    end

    local user = getbyid(db,id)

    if tonumber(user.id) ~= id then
        return
    end

    local fullname = specification.fullname == nil and user.fulname   or specification.fullname
    local password = specification.password == nil and user.password  or specification.password
    local group    = specification.group    == nil and user.group     or specification.group
    local enabled  = specification.enabled  == nil and user.enabled   or specification.enabled
    local email    = specification.email    == nil and user.email     or specification.email
    local address  = specification.address  == nil and user.address   or specification.address
    local theme    = specification.theme    == nil and user.theme     or specification.theme
    local data     = specification.data     == nil and user.data      or specification.data

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = id,
            fullname = fullname,
            password = encryptpassword(password),
            group    = groupnumbers[group],
            enabled  = toboolean(enabled) and "1" or "0",
            email    = email,
            address  = address,
            theme    = theme,
            data     = type(data) == "table" and db.serialize(data,"return") or "",
        },
    }

    return getbyid(db,id)

end

local template =[[
    DELETE FROM
        %basename%
    WHERE
        `id` = '%id%' ;
]]

function users.remove(db,id)

    db.execute {
        template  = template,
        variables = {
            basename = db.basename,
            id       = id,
        },
    }

end

local template =[[
    SELECT
        %fields%
    FROM
        %basename%
    ORDER BY
        `name` ;
]]

function users.collect(db) -- maybe also an id/name only variant

    local records, keys = db.execute {
        template  = template,
        converter = converter,
        variables = {
            basename = db.basename,
            fields   = fields,
        },
    }

    return records, keys

end
