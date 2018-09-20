-- original file : tp.lua
-- for more into : see util-soc.lua

local setmetatable, next, type, tonumber = setmetatable, next, type, tonumber
local find, upper = string.find, string.upper

local socket     = socket or require("socket")
local ltn12      = ltn12  or require("ltn12")

local skipsocket = socket.skip
local sinksocket = socket.sink
local tcpsocket  = socket.tcp

local ltn12pump  = ltn12.pump
local pumpall    = ltn12pump.all
local pumpstep   = ltn12pump.step

local tp = {
    TIMEOUT = 60,
}

socket.tp = tp

local function get_reply(c)
    local line, err = c:receive()
    local reply = line
    if err then return
        nil, err
    end
    local code, sep = skipsocket(2, find(line, "^(%d%d%d)(.?)"))
    if not code then
        return nil, "invalid server reply"
    end
    if sep == "-" then
        local current
        repeat
            line, err = c:receive()
            if err then
                return nil, err
            end
            current, sep = skipsocket(2, find(line, "^(%d%d%d)(.?)"))
            reply = reply .. "\n" .. line
        until code == current and sep == " "
    end
    return code, reply
end

local methods = { }
local mt      = { __index = methods }

function methods.getpeername(self)
    return self.c:getpeername()
end

function methods.getsockname(self)
    return self.c:getpeername()
end

function methods.check(self, ok)
    local code, reply = get_reply(self.c)
    if not code then
        return nil, reply
    end
    local c = tonumber(code)
    local t = type(ok)
    if t == "function" then
        return ok(c,reply)
    elseif t == "table" then
        for i=1,#ok do
            if find(code,ok[i]) then
                return c, reply
            end
        end
        return nil, reply
    elseif find(code, ok) then
        return c, reply
    else
        return nil, reply
    end
end

function methods.command(self, cmd, arg)
    cmd = upper(cmd)
    if arg then
        cmd = cmd .. " " .. arg .. "\r\n"
    else
        cmd = cmd .. "\r\n"
    end
    return self.c:send(cmd)
end

function methods.sink(self, snk, pat)
    local chunk, err = self.c:receive(pat)
    return snk(chunk, err)
end

function methods.send(self, data)
    return self.c:send(data)
end

function methods.receive(self, pat)
    return self.c:receive(pat)
end

function methods.getfd(self)
    return self.c:getfd()
end

function methods.dirty(self)
    return self.c:dirty()
end

function methods.getcontrol(self)
    return self.c
end

function methods.source(self, source, step)
    local sink = sinksocket("keep-open", self.c)
    local ret, err = pumpall(source, sink, step or pumpstep)
    return ret, err
end

function methods.close(self)
    self.c:close()
    return 1
end

function tp.connect(host, port, timeout, create)
    local c, e = (create or tcpsocket)()
    if not c then
        return nil, e
    end
    c:settimeout(timeout or tp.TIMEOUT)
    local r, e = c:connect(host, port)
    if not r then
        c:close()
        return nil, e
    end
    return setmetatable({ c = c }, mt)
end

package.loaded["socket.tp"] = tp

return tp
