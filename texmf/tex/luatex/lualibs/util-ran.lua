if not modules then modules = { } end modules ['util-ran'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local random  = math.random
local concat = table.concat
local sub, upper = string.sub, string.upper

local randomizers     = utilities.randomizers or { }
utilities.randomizers = randomizers

local l_one = "bcdfghjklmnpqrstvwxz"
local l_two = "aeiouy"

local u_one = upper(l_one)
local u_two = upper(l_two)

local n_one = #l_one
local n_two = #l_two

function randomizers.word(min,max,separator)
    local t = { }
    for i=1,random(min,max) do
        if i % 2 == 0 then
            local r = random(1,n_one)
            t[i] = sub(l_one,r,r)
        else
            local r = random(1,n_two)
            t[i] = sub(l_two,r,r)
        end
    end
    return concat(t,separator)
end

function randomizers.initials(min,max)
    if not min then
        if not max then
            min, max = 1, 3
        else
            min, max = 1, min
        end
    elseif not max then
        max = min
    end
    local t = { }
    local n = random(min or 1,max or 3)
    local m = 0
    for i=1,n do
        m = m + 1
        if i % 2 == 0 then
            local r = random(1,n_one)
            t[m] = sub(u_one,r,r)
        else
            local r = random(1,n_two)
            t[m] = sub(u_two,r,r)
        end
        m = m + 1
        t[m] = "."
    end
    return concat(t)
end

function randomizers.firstname(min,max)
    if not min then
        if not max then
            min, max = 3, 10
        else
            min, max = 1, min
        end
    elseif not max then
        max = min
    end
    local t = { }
    local n = random(min,max)
    local b = true
    if n % 2 == 0 then
        local r = random(1,n_two)
        t[1] = sub(u_two,r,r)
        b = true
    else
        local r = random(1,n_one)
        t[1] = sub(u_one,r,r)
        b = false
    end
    for i=2,n do
        if b then
            local r = random(1,n_one)
            t[i] = sub(l_one,r,r)
            b = false
        else
            local r = random(1,n_two)
            t[i] = sub(l_two,r,r)
            b = true
        end
    end
    return concat(t,separator)
end

randomizers.surname = randomizers.firstname

-- for i=1,10 do
--     print(randomizers.initials(1,3),randomizers.firstname(5,10),randomizers.surname(5,15))
-- end
