-- original file : socket.lua
-- for more into : see util-soc.lua

local type, tostring, setmetatable = type, tostring, setmetatable
local min = math.min
local format = string.format

local socket      = require("socket.core")

local connect     = socket.connect
local tcp4        = socket.tcp4
local tcp6        = socket.tcp6
local getaddrinfo = socket.dns.getaddrinfo

local defaulthost = "0.0.0.0"

local function report(fmt,first,...)
    if logs then
        report = logs and logs.reporter("socket")
        report(fmt,first,...)
    elseif fmt then
        fmt = "socket: " .. fmt
        if first then
            print(format(fmt,first,...))
        else
            print(fmt)
        end
    end
end

socket.report = report

function socket.connect4(address, port, laddress, lport)
    return connect(address, port, laddress, lport, "inet")
end

function socket.connect6(address, port, laddress, lport)
    return connect(address, port, laddress, lport, "inet6")
end

function socket.bind(host, port, backlog)
    if host == "*" or host == "" then
        host = defaulthost
    end
    local addrinfo, err = getaddrinfo(host)
    if not addrinfo then
        return nil, err
    end
    for i=1,#addrinfo do
        local alt = addrinfo[i]
        local sock, err = (alt.family == "inet" and tcp4 or tcp6)()
        if not sock then
            return nil, err or "unknown error"
        end
        sock:setoption("reuseaddr", true)
        local res, err = sock:bind(alt.addr, port)
        if res then
            res, err = sock:listen(backlog)
            if res then
                return sock
            else
                sock:close()
            end
        else
            sock:close()
        end
    end
    return nil, "invalid address"
end

socket.try = socket.newtry()

function socket.choose(list)
    return function(name, opt1, opt2)
        if type(name) ~= "string" then
            name, opt1, opt2 = "default", name, opt1
        end
        local f = list[name or "nil"]
        if f then
            return f(opt1, opt2)
        else
            report("error: unknown key '%s'",tostring(name))
        end
    end
end

local sourcet    = { }
local sinkt      = { }

socket.sourcet   = sourcet
socket.sinkt     = sinkt

socket.BLOCKSIZE = 2048

sinkt["close-when-done"] = function(sock)
    return setmetatable (
        {
            getfd = function() return sock:getfd() end,
            dirty = function() return sock:dirty() end,
        },
        {
            __call = function(self, chunk, err)
                if chunk then
                    return sock:send(chunk)
                else
                    sock:close()
                    return 1 -- why 1
                end
            end
        }
    )
end

sinkt["keep-open"] = function(sock)
    return setmetatable (
        {
            getfd = function() return sock:getfd() end,
            dirty = function() return sock:dirty() end,
        }, {
            __call = function(self, chunk, err)
                if chunk then
                    return sock:send(chunk)
                else
                    return 1 -- why 1
                end
            end
        }
    )
end

sinkt["default"] = sinkt["keep-open"]

socket.sink = socket.choose(sinkt)

sourcet["by-length"] = function(sock, length)
    local blocksize = socket.BLOCKSIZE
    return setmetatable (
        {
            getfd = function() return sock:getfd() end,
            dirty = function() return sock:dirty() end,
        },
        {
            __call = function()
                if length <= 0 then
                    return nil
                end
                local chunk, err = sock:receive(min(blocksize,length))
                if err then
                    return nil, err
                end
                length = length - #chunk
                return chunk
            end
        }
    )
end

sourcet["until-closed"] = function(sock)
    local blocksize = socket.BLOCKSIZE
    local done      = false
    return setmetatable (
        {
            getfd = function() return sock:getfd() end,
            dirty = function() return sock:dirty() end,
        }, {
            __call = function()
                if done then
                    return nil
                end
                local chunk, status, partial = sock:receive(blocksize)
                if not status then
                    return chunk
                elseif status == "closed" then
                    sock:close()
                    done = true
                    return partial
                else
                    return nil, status
                end
            end
        }
    )
end

sourcet["default"] = sourcet["until-closed"]

socket.source = socket.choose(sourcet)

_G.socket = socket -- for now global

package.loaded["socket"] = socket

return socket
