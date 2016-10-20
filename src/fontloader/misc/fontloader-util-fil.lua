if not modules then modules = { } end modules ['util-fil'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local byte    = string.byte
local char    = string.char
local extract = bit32 and bit32.extract
local floor   = math.floor

-- Here are a few helpers (the starting point were old ones I used for parsing
-- flac files). In Lua 5.3 we can probably do this better. Some code will move
-- here.

utilities       = utilities or { }
local files     = { }
utilities.files = files

local zerobased = { }

function files.open(filename,zb)
    local f = io.open(filename,"rb")
    if f then
        zerobased[f] = zb or false
    end
    return f
end

function files.close(f)
    zerobased[f] = nil
    f:close()
end

function files.size(f)
    return f:seek("end")
end

files.getsize = files.size

function files.setposition(f,n)
    if zerobased[f] then
        f:seek("set",n)
    else
        f:seek("set",n - 1)
    end
end

function files.getposition(f)
    if zerobased[f] then
        return f:seek()
    else
        return f:seek() + 1
    end
end

function files.look(f,n,chars)
    local p = f:seek()
    local s = f:read(n)
    f:seek("set",p)
    if chars then
        return s
    else
        return byte(s,1,#s)
    end
end

function files.skip(f,n)
    if n == 1 then
        f:read(n)
    else
        f:seek("set",f:seek()+n)
    end
end

function files.readbyte(f)
    return byte(f:read(1))
end

function files.readbytes(f,n)
    return byte(f:read(n),1,n)
end

function files.readchar(f)
    return f:read(1)
end

function files.readstring(f,n)
    return f:read(n or 1)
end

function files.readinteger1(f)  -- one byte
    local n = byte(f:read(1))
    if n  >= 0x80 then
     -- return n - 0xFF - 1
        return n - 0x100
    else
        return n
    end
end

files.readcardinal1 = files.readbyte  -- one byte
files.readcardinal  = files.readcardinal1
files.readinteger   = files.readinteger1

function files.readcardinal2(f)
    local a, b = byte(f:read(2),1,2)
    return 0x100 * a + b
end
function files.readcardinal2le(f)
    local b, a = byte(f:read(2),1,2)
    return 0x100 * a + b
end

function files.readinteger2(f)
    local a, b = byte(f:read(2),1,2)
    local n = 0x100 * a + b
    if n >= 0x8000 then
     -- return n - 0xFFFF - 1
        return n - 0x10000
    else
        return n
    end
end
function files.readinteger2le(f)
    local b, a = byte(f:read(2),1,2)
    local n = 0x100 * a + b
    if n >= 0x8000 then
     -- return n - 0xFFFF - 1
        return n - 0x10000
    else
        return n
    end
end

function files.readcardinal3(f)
    local a, b, c = byte(f:read(3),1,3)
    return 0x10000 * a + 0x100 * b + c
end
function files.readcardinal3le(f)
    local c, b, a = byte(f:read(3),1,3)
    return 0x10000 * a + 0x100 * b + c
end

function files.readinteger3(f)
    local a, b, c = byte(f:read(3),1,3)
    local n = 0x10000 * a + 0x100 * b + c
    if n >= 0x80000 then
     -- return n - 0xFFFFFF - 1
        return n - 0x1000000
    else
        return n
    end
end
function files.readinteger3le(f)
    local c, b, a = byte(f:read(3),1,3)
    local n = 0x10000 * a + 0x100 * b + c
    if n >= 0x80000 then
     -- return n - 0xFFFFFF - 1
        return n - 0x1000000
    else
        return n
    end
end

function files.readcardinal4(f)
    local a, b, c, d = byte(f:read(4),1,4)
    return 0x1000000 * a + 0x10000 * b + 0x100 * c + d
end
function files.readcardinal4le(f)
    local d, c, b, a = byte(f:read(4),1,4)
    return 0x1000000 * a + 0x10000 * b + 0x100 * c + d
end

function files.readinteger4(f)
    local a, b, c, d = byte(f:read(4),1,4)
    local n = 0x1000000 * a + 0x10000 * b + 0x100 * c + d
    if n >= 0x8000000 then
     -- return n - 0xFFFFFFFF - 1
        return n - 0x100000000
    else
        return n
    end
end
function files.readinteger4le(f)
    local d, c, b, a = byte(f:read(4),1,4)
    local n = 0x1000000 * a + 0x10000 * b + 0x100 * c + d
    if n >= 0x8000000 then
     -- return n - 0xFFFFFFFF - 1
        return n - 0x100000000
    else
        return n
    end
end

function files.readfixed4(f)
    local a, b, c, d = byte(f:read(4),1,4)
    local n = 0x100 * a + b
    if n >= 0x8000 then
     -- return n - 0xFFFF - 1 + (0x100 * c + d)/0xFFFF
        return n - 0x10000    + (0x100 * c + d)/0xFFFF
    else
        return n              + (0x100 * c + d)/0xFFFF
    end
end

if extract then

    function files.read2dot14(f)
        local a, b = byte(f:read(2),1,2)
        local n = 0x100 * a + b
        local m = extract(n,0,30)
        if n > 0x7FFF then
            n = extract(n,30,2)
            return m/0x4000 - 4
        else
            n = extract(n,30,2)
            return n + m/0x4000
        end
    end

end

function files.skipshort(f,n)
    f:read(2*(n or 1))
end

function files.skiplong(f,n)
    f:read(4*(n or 1))
end

-- writers (kind of slow)

function files.writecardinal2(f,n)
    local a = char(n % 256)
    n = floor(n/256)
    local b = char(n % 256)
    f:write(b,a)
end

function files.writecardinal4(f,n)
    local a = char(n % 256)
    n = floor(n/256)
    local b = char(n % 256)
    n = floor(n/256)
    local c = char(n % 256)
    n = floor(n/256)
    local d = char(n % 256)
    f:write(d,c,b,a)
end

function files.writestring(f,s)
    f:write(char(byte(s,1,#s)))
end

function files.writebyte(f,b)
    f:write(char(b))
end

