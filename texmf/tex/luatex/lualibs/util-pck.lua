if not modules then modules = { } end modules ['util-pck'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- moved from core-uti

local next, tostring, type = next, tostring, type
local sort, concat = table.sort, table.concat
local sortedhashkeys, sortedkeys, tohash = table.sortedhashkeys, table.sortedkeys, table.tohash

utilities         = utilities         or { }
utilities.packers = utilities.packers or { }
local packers     = utilities.packers
packers.version   = 1.01

local function hashed(t)
    local s, ns = { }, 0
    for k, v in next, t do
        ns = ns + 1
        if type(v) == "table" then
            s[ns] = k .. "={" .. hashed(v) .. "}"
        else
            s[ns] = k .. "=" .. tostring(v)
        end
    end
    sort(s)
    return concat(s,",")
end

local function simplehashed(t)
    local s, ns = { }, 0
    for k, v in next, t do
        ns = ns + 1
        s[ns] = k .. "=" .. v
    end
    sort(s)
    return concat(s,",")
end

packers.hashed       = hashed
packers.simplehashed = simplehashed

-- In luatex < 0.74 (lua 5.1) a next chain was the same for each run so no sort was needed,
-- but in the latest greatest versions (lua 5.2) we really need to sort the keys in order
-- not to get endless runs due to a difference in tuc files.

local function pack(t,keys,skip,hash,index)
    if t then
        local sk = #t > 0 and sortedkeys(t) or sortedhashkeys(t)
        for i=1,#sk do
            local k = sk[i]
            if not skip or not skip[k] then
                local v = t[k]
                --
                if type(v) == "table" then
                    pack(v,keys,skip,hash,index)
                    if keys[k] then
                        local h = hashed(v)
                        local i = hash[h]
                        if not i then
                            i = #index + 1
                            index[i] = v
                            hash[h] = i
                        end
                        t[k] = i
                    end
                end
            end
        end
    end
end

local function unpack(t,keys,skip,index)
    if t then
        for k, v in next, t do
            if keys[k] and type(v) == "number" then
                local iv = index[v]
                if iv then
                    v = iv
                    t[k] = v
                end
            end
            if type(v) == "table" and (not skip or not skip[k]) then
                unpack(v,keys,skip,index)
            end
        end
    end
end

function packers.new(keys,version,skip)
    return {
        version = version or packers.version,
        keys    = tohash(keys),
        skip    = tohash(skip),
        hash    = { },
        index   = { },
    }
end

function packers.pack(t,p,shared)
    if shared then
        pack(t,p.keys,p.skip,p.hash,p.index)
    elseif not t.packer then
        pack(t,p.keys,p.skip,p.hash,p.index)
        if #p.index > 0 then
            t.packer = {
                version = p.version or packers.version,
                keys    = p.keys,
                skip    = p.skip,
                index   = p.index,
            }
        end
        p.hash  = { }
        p.index = { }
    end
end

function packers.unpack(t,p,shared)
    if shared then
        if p then
            unpack(t,p.keys,p.skip,p.index)
        end
    else
        local tp = t.packer
        if tp then
            if tp.version == (p and p.version or packers.version) then
                unpack(t,tp.keys,tp.skip,tp.index)
            else
               return false
            end
            t.packer = nil
        end
    end
    return true
end

function packers.strip(p)
    p.hash = nil
end

-- We could have a packer.serialize where we first flush the shared table
-- and then use inline a reference . This saves an unpack.
