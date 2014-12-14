if not modules then modules = { } end modules ['l-io'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local io = io
local byte, find, gsub, format = string.byte, string.find, string.gsub, string.format
local concat = table.concat
local floor = math.floor
local type = type

if string.find(os.getenv("PATH"),";",1,true) then
    io.fileseparator, io.pathseparator = "\\", ";"
else
    io.fileseparator, io.pathseparator = "/" , ":"
end

local function readall(f)
    return f:read("*all")
end

-- The next one is upto 50% faster on large files and less memory consumption due
-- to less intermediate large allocations. This phenomena was discussed on the
-- luatex dev list.

local function readall(f)
    local size = f:seek("end")
    if size == 0 then
        return ""
    elseif size < 1024*1024 then
        f:seek("set",0)
        return f:read('*all')
    else
        local done = f:seek("set",0)
        local step
        if size < 1024*1024 then
            step = 1024 * 1024
        elseif size > 16*1024*1024 then
            step = 16*1024*1024
        else
            step = floor(size/(1024*1024)) * 1024 * 1024 / 8
        end
        local data = { }
        while true do
            local r = f:read(step)
            if not r then
                return concat(data)
            else
                data[#data+1] = r
            end
        end
    end
end

io.readall = readall

function io.loaddata(filename,textmode) -- return nil if empty
    local f = io.open(filename,(textmode and 'r') or 'rb')
    if f then
     -- local data = f:read('*all')
        local data = readall(f)
        f:close()
        if #data > 0 then
            return data
        end
    end
end

function io.savedata(filename,data,joiner)
    local f = io.open(filename,"wb")
    if f then
        if type(data) == "table" then
            f:write(concat(data,joiner or ""))
        elseif type(data) == "function" then
            data(f)
        else
            f:write(data or "")
        end
        f:close()
        io.flush()
        return true
    else
        return false
    end
end

-- we can also chunk this one if needed: io.lines(filename,chunksize,"*l")

function io.loadlines(filename,n) -- return nil if empty
    local f = io.open(filename,'r')
    if not f then
        -- no file
    elseif n then
        local lines = { }
        for i=1,n do
            local line = f:read("*lines")
            if line then
                lines[#lines+1] = line
            else
                break
            end
        end
        f:close()
        lines = concat(lines,"\n")
        if #lines > 0 then
            return lines
        end
    else
        local line = f:read("*line") or ""
        f:close()
        if #line > 0 then
            return line
        end
    end
end

function io.loadchunk(filename,n)
    local f = io.open(filename,'rb')
    if f then
        local data = f:read(n or 1024)
        f:close()
        if #data > 0 then
            return data
        end
    end
end

function io.exists(filename)
    local f = io.open(filename)
    if f == nil then
        return false
    else
        f:close()
        return true
    end
end

function io.size(filename)
    local f = io.open(filename)
    if f == nil then
        return 0
    else
        local s = f:seek("end")
        f:close()
        return s
    end
end

function io.noflines(f)
    if type(f) == "string" then
        local f = io.open(filename)
        if f then
            local n = f and io.noflines(f) or 0
            f:close()
            return n
        else
            return 0
        end
    else
        local n = 0
        for _ in f:lines() do
            n = n + 1
        end
        f:seek('set',0)
        return n
    end
end

local nextchar = {
    [ 4] = function(f)
        return f:read(1,1,1,1)
    end,
    [ 2] = function(f)
        return f:read(1,1)
    end,
    [ 1] = function(f)
        return f:read(1)
    end,
    [-2] = function(f)
        local a, b = f:read(1,1)
        return b, a
    end,
    [-4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        return d, c, b, a
    end
}

function io.characters(f,n)
    if f then
        return nextchar[n or 1], f
    end
end

local nextbyte = {
    [4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        if d then
            return byte(a), byte(b), byte(c), byte(d)
        end
    end,
    [3] = function(f)
        local a, b, c = f:read(1,1,1)
        if b then
            return byte(a), byte(b), byte(c)
        end
    end,
    [2] = function(f)
        local a, b = f:read(1,1)
        if b then
            return byte(a), byte(b)
        end
    end,
    [1] = function (f)
        local a = f:read(1)
        if a then
            return byte(a)
        end
    end,
    [-2] = function (f)
        local a, b = f:read(1,1)
        if b then
            return byte(b), byte(a)
        end
    end,
    [-3] = function(f)
        local a, b, c = f:read(1,1,1)
        if b then
            return byte(c), byte(b), byte(a)
        end
    end,
    [-4] = function(f)
        local a, b, c, d = f:read(1,1,1,1)
        if d then
            return byte(d), byte(c), byte(b), byte(a)
        end
    end
}

function io.bytes(f,n)
    if f then
        return nextbyte[n or 1], f
    else
        return nil, nil
    end
end

function io.ask(question,default,options)
    while true do
        io.write(question)
        if options then
            io.write(format(" [%s]",concat(options,"|")))
        end
        if default then
            io.write(format(" [%s]",default))
        end
        io.write(format(" "))
        io.flush()
        local answer = io.read()
        answer = gsub(answer,"^%s*(.*)%s*$","%1")
        if answer == "" and default then
            return default
        elseif not options then
            return answer
        else
            for k=1,#options do
                if options[k] == answer then
                    return answer
                end
            end
            local pattern = "^" .. answer
            for k=1,#options do
                local v = options[k]
                if find(v,pattern) then
                    return v
                end
            end
        end
    end
end

local function readnumber(f,n,m)
    if m then
        f:seek("set",n)
        n = m
    end
    if n == 1 then
        return byte(f:read(1))
    elseif n == 2 then
        local a, b = byte(f:read(2),1,2)
        return 256 * a + b
    elseif n == 3 then
        local a, b, c = byte(f:read(3),1,3)
        return 256*256 * a + 256 * b + c
    elseif n == 4 then
        local a, b, c, d = byte(f:read(4),1,4)
        return 256*256*256 * a + 256*256 * b + 256 * c + d
    elseif n == 8 then
        local a, b = readnumber(f,4), readnumber(f,4)
        return 256 * a + b
    elseif n == 12 then
        local a, b, c = readnumber(f,4), readnumber(f,4), readnumber(f,4)
        return 256*256 * a + 256 * b + c
    elseif n == -2 then
        local b, a = byte(f:read(2),1,2)
        return 256*a + b
    elseif n == -3 then
        local c, b, a = byte(f:read(3),1,3)
        return 256*256 * a + 256 * b + c
    elseif n == -4 then
        local d, c, b, a = byte(f:read(4),1,4)
        return 256*256*256 * a + 256*256 * b + 256*c + d
    elseif n == -8 then
        local h, g, f, e, d, c, b, a = byte(f:read(8),1,8)
        return 256*256*256*256*256*256*256 * a +
                   256*256*256*256*256*256 * b +
                       256*256*256*256*256 * c +
                           256*256*256*256 * d +
                               256*256*256 * e +
                                   256*256 * f +
                                       256 * g +
                                             h
    else
        return 0
    end
end

io.readnumber = readnumber

function io.readstring(f,n,m)
    if m then
        f:seek("set",n)
        n = m
    end
    local str = gsub(f:read(n),"\000","")
    return str
end

--

if not io.i_limiter then function io.i_limiter() end end -- dummy so we can test safely
if not io.o_limiter then function io.o_limiter() end end -- dummy so we can test safely

-- This works quite ok:
--
-- function io.piped(command,writer)
--     local pipe = io.popen(command)
--  -- for line in pipe:lines() do
--  --     print(line)
--  -- end
--     while true do
--         local line = pipe:read(1)
--         if not line then
--             break
--         elseif line ~= "\n" then
--             writer(line)
--         end
--     end
--     return pipe:close() -- ok, status, (error)code
-- end
