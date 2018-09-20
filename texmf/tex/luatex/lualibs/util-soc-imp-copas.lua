-- original file : copas.lua
-- for more into : see util-soc.lua

local socket = socket or require("socket")
local ssl    = ssl or nil -- only loaded upon demand

local WATCH_DOG_TIMEOUT =  120
local UDP_DATAGRAM_MAX  = 8192

local type, next, pcall, getmetatable, tostring = type, next, pcall, getmetatable, tostring
local min, max, random = math.min, math.max, math.random
local find = string.find
local insert, remove = table.insert, table.remove

local gettime          = socket.gettime
local selectsocket     = socket.select

local createcoroutine  = coroutine.create
local resumecoroutine  = coroutine.resume
local yieldcoroutine   = coroutine.yield
local runningcoroutine = coroutine.running

-- Redefines LuaSocket functions with coroutine safe versions (this allows the use
-- of socket.http from within copas).

-- Meta information is public even if beginning with an "_"

local function report(fmt,first,...)
    if logs then
        report = logs and logs.reporter("copas")
        report(fmt,first,...)
    elseif fmt then
        fmt = "copas: " .. fmt
        if first then
            print(format(fmt,first,...))
        else
            print(fmt)
        end
    end
end

local copas = {

    _COPYRIGHT   = "Copyright (C) 2005-2016 Kepler Project",
    _DESCRIPTION = "Coroutine Oriented Portable Asynchronous Services",
    _VERSION     = "Copas 2.0.1",

    autoclose    = true,
    running      = false,

    report       = report,

}

local function statushandler(status, ...)
    if status then
        return ...
    end
    local err = (...)
    if type(err) == "table" then
        err = err[1]
    end
    report("error: %s",tostring(err))
    return nil, err
end

function socket.protect(func)
    return function(...)
        return statushandler(pcall(func,...))
    end
end

function socket.newtry(finalizer)
    return function (...)
        local status = (...)
        if not status then
            local detail = select(2,...)
            pcall(finalizer,detail)
            report("error: %s",tostring(detail))
            return
        end
        return ...
    end
end

-- Simple set implementation based on LuaSocket's tinyirc.lua example
-- adds a FIFO queue for each value in the set

local function newset()
    local reverse = { }
    local set     = { }
    local queue   = { }
    setmetatable(set, {
        __index = {
            insert =
                function(set, value)
                    if not reverse[value] then
                        local n = #set +1
                        set[n] = value
                        reverse[value] = n
                    end
                end,
            remove =
                function(set, value)
                    local index = reverse[value]
                    if index then
                        reverse[value] = nil
                        local n  = #set
                        local top = set[n]
                        set[n] = nil
                        if top ~= value then
                            reverse[top] = index
                            set[index]   = top
                        end
                    end
                end,
            push =
                function (set, key, itm)
                    local entry = queue[key]
                    if entry == nil then -- hm can it be false then?
                        queue[key] = { itm }
                    else
                        entry[#entry + 1] = itm
                    end
                end,
            pop =
                function (set, key)
                    local top = queue[key]
                    if top ~= nil then
                        local ret = remove(top,1)
                        if top[1] == nil then
                            queue[key] = nil
                        end
                        return ret
                    end
                end
        }
    } )
    return set
end

local _sleeping = {
    times    = { }, -- list with wake-up times
    cos      = { }, -- list with coroutines, index matches the 'times' list
    lethargy = { }, -- list of coroutines sleeping without a wakeup time

    insert =
        function()
        end,
    remove =
        function()
        end,
    push =
        function(self, sleeptime, co)
            if not co then
                return
            end
            if sleeptime < 0 then
                --sleep until explicit wakeup through copas.wakeup
                self.lethargy[co] = true
                return
            else
                sleeptime = gettime() + sleeptime
            end
            local t = self.times
            local c = self.cos
            local i = 1
            local n = #t
            while i <= n and t[i] <= sleeptime do
                i = i + 1
            end
            insert(t,i,sleeptime)
            insert(c,i,co)
        end,
    getnext =
        -- returns delay until next sleep expires, or nil if there is none
        function(self)
            local t = self.times
            local delay = t[1] and t[1] - gettime() or nil
            return delay and max(delay, 0) or nil
        end,
    pop =
        -- find the thread that should wake up to the time
        function(self, time)
            local t = self.times
            local c = self.cos
            if #t == 0 or time < t[1] then
                return
            end
            local co = c[1]
            remove(t,1)
            remove(c,1)
            return co
        end,
        wakeup =
            function(self, co)
                local let = self.lethargy
                if let[co] then
                    self:push(0, co)
                    let[co] = nil
                else
                    local c = self.cos
                    local t = self.times
                    for i=1,#c do
                        if c[i] == co then
                            remove(c,i)
                            remove(t,i)
                            self:push(0, co)
                            return
                        end
                    end
                end
            end
}

local _servers     = newset() -- servers being handled
local _reading     = newset() -- sockets currently being read
local _writing     = newset() -- sockets currently being written

local _reading_log = { }
local _writing_log = { }

local _is_timeout  = {        -- set of errors indicating a timeout
    timeout   = true,         -- default LuaSocket timeout
    wantread  = true,         -- LuaSec specific timeout
    wantwrite = true,         -- LuaSec specific timeout
}

-- Coroutine based socket I/O functions.

local function isTCP(socket)
    return not find(tostring(socket),"^udp")
end

-- Reads a pattern from a client and yields to the reading set on timeouts UDP: a
-- UDP socket expects a second argument to be a number, so it MUST be provided as
-- the 'pattern' below defaults to a string. Will throw a 'bad argument' error if
-- omitted.

local function copasreceive(client, pattern, part)
    if not pattern or pattern == "" then
        pattern = "*l"
    end
    local current_log = _reading_log
    local s, err
    repeat
        s, err, part = client:receive(pattern, part)
        if s or (not _is_timeout[err]) then
            current_log[client] = nil
            return s, err, part
        end
        if err == "wantwrite" then
            current_log         = _writing_log
            current_log[client] = gettime()
            yieldcoroutine(client, _writing)
        else
            current_log         = _reading_log
            current_log[client] = gettime()
            yieldcoroutine(client, _reading)
        end
    until false
end

-- Receives data from a client over UDP. Not available for TCP. (this is a copy of
-- receive() method, adapted for receivefrom() use).

local function copasreceivefrom(client, size)
    local s, err, port
    if not size or size == 0 then
        size = UDP_DATAGRAM_MAX
    end
    repeat
        -- upon success err holds ip address
        s, err, port = client:receivefrom(size)
        if s or err ~= "timeout" then
            _reading_log[client] = nil
            return s, err, port
        end
        _reading_log[client] = gettime()
        yieldcoroutine(client, _reading)
    until false
end

-- Same as above but with special treatment when reading chunks, unblocks on any
-- data received.

local function copasreceivepartial(client, pattern, part)
    if not pattern or pattern == "" then
        pattern = "*l"
    end
    local logger = _reading_log
    local queue  = _reading
    local s, err
    repeat
        s, err, part = client:receive(pattern, part)
        if s or (type(pattern) == "number" and part ~= "" and part) or not _is_timeout[err] then
          logger[client] = nil
          return s, err, part
        end
        if err == "wantwrite" then
            logger = _writing_log
            queue  = _writing
        else
            logger = _reading_log
            queue  = _reading
        end
        logger[client] = gettime()
        yieldcoroutine(client, queue)
    until false
end

-- Sends data to a client. The operation is buffered and yields to the writing set
-- on timeouts Note: from and to parameters will be ignored by/for UDP sockets

local function copassend(client, data, from, to)
    if not from then
        from = 1
    end
    local lastIndex = from - 1
    local logger = _writing_log
    local queue  = _writing
    local s, err
    repeat
        s, err, lastIndex = client:send(data, lastIndex + 1, to)
        -- Adds extra coroutine swap and garantees that high throughput doesn't take
        -- other threads to starvation.
        if random(100) > 90 then
            logger[client] = gettime()
            yieldcoroutine(client, queue)
        end
        if s or not _is_timeout[err] then
            logger[client] = nil
            return s, err,lastIndex
        end
        if err == "wantread" then
            logger = _reading_log
            queue  = _reading
        else
            logger = _writing_log
            queue  = _writing
        end
        logger[client] = gettime()
        yieldcoroutine(client, queue)
    until false
end

-- Sends data to a client over UDP. Not available for TCP. (this is a copy of send()
-- method, adapted for sendto() use).

local function copassendto(client, data, ip, port)
    repeat
        local s, err = client:sendto(data, ip, port)
        -- Adds extra coroutine swap and garantees that high throughput doesn't
        -- take other threads to starvation.
        if random(100) > 90 then
            _writing_log[client] = gettime()
            yieldcoroutine(client, _writing)
        end
        if s or err ~= "timeout" then
            _writing_log[client] = nil
            return s, err
        end
        _writing_log[client] = gettime()
        yieldcoroutine(client, _writing)
    until false
end

-- Waits until connection is completed.

local function copasconnect(skt, host, port)
    skt:settimeout(0)
    local ret, err, tried_more_than_once
    repeat
        ret, err = skt:connect (host, port)
        -- A non-blocking connect on Windows results in error "Operation already in
        -- progress" to indicate that it is completing the request async. So
        -- essentially it is the same as "timeout".
        if ret or (err ~= "timeout" and err ~= "Operation already in progress") then
            -- Once the async connect completes, Windows returns the error "already
            -- connected" to indicate it is done, so that error should be ignored.
            -- Except when it is the first call to connect, then it was already
            -- connected to something else and the error should be returned.
            if not ret and err == "already connected" and tried_more_than_once then
                ret = 1
                err = nil
            end
            _writing_log[skt] = nil
            return ret, err
        end
        tried_more_than_once = tried_more_than_once or true
        _writing_log[skt]    = gettime()
        yieldcoroutine(skt, _writing)
    until false
end

-- Peforms an (async) ssl handshake on a connected TCP client socket. Replacec all
-- previous socket references, with the returned new ssl wrapped socket Throws error
-- and does not return nil+error, as that might silently fail in code like this.

local function copasdohandshake(skt, sslt) -- extra ssl parameters
    if not ssl then
        ssl = require("ssl")
    end
    if not ssl then
        report("error: no ssl library")
        return
    end
    local nskt, err = ssl.wrap(skt, sslt)
    if not nskt then
        report("error: %s",tostring(err))
        return
    end
    nskt:settimeout(0)
    local queue
    repeat
        local success, err = nskt:dohandshake()
        if success then
            return nskt
        elseif err == "wantwrite" then
            queue = _writing
        elseif err == "wantread" then
            queue = _reading
        else
            report("error: %s",tostring(err))
            return
        end
        yieldcoroutine(nskt, queue)
    until false
end

-- Flushes a client write buffer.

local function copasflush(client)
end

-- Public.

copas.connect             = copassconnect
copas.send                = copassend
copas.sendto              = copassendto
copas.receive             = copasreceive
copas.receivefrom         = copasreceivefrom
copas.copasreceivepartial = copasreceivepartial
copas.copasreceivePartial = copasreceivepartial
copas.dohandshake         = copasdohandshake
copas.flush               = copasflush

-- Wraps a TCP socket to use Copas methods (send, receive, flush and settimeout).

local function _skt_mt_tostring(self)
    return tostring(self.socket) .. " (copas wrapped)"
end

local _skt_mt_tcp_index = {
    send =
        function(self, data, from, to)
            return copassend (self.socket, data, from, to)
        end,
    receive =
        function (self, pattern, prefix)
            if self.timeout == 0 then
                return copasreceivePartial(self.socket, pattern, prefix)
            else
                return copasreceive(self.socket, pattern, prefix)
            end
        end,

    flush =
        function (self)
            return copasflush(self.socket)
        end,

    settimeout =
        function (self, time)
            self.timeout = time
            return true
        end,
    -- TODO: socket.connect is a shortcut, and must be provided with an alternative
    -- if ssl parameters are available, it will also include a handshake
    connect =
        function(self, ...)
            local res, err = copasconnect(self.socket, ...)
            if res and self.ssl_params then
                res, err = self:dohandshake()
            end
            return res, err
        end,
    close =
        function(self, ...)
            return self.socket:close(...)
        end,
    -- TODO: socket.bind is a shortcut, and must be provided with an alternative
    bind =
        function(self, ...)
            return self.socket:bind(...)
        end,
    -- TODO: is this DNS related? hence blocking?
    getsockname =
        function(self, ...)
            return self.socket:getsockname(...)
        end,
    getstats =
        function(self, ...)
            return self.socket:getstats(...)
        end,
    setstats =
        function(self, ...)
            return self.socket:setstats(...)
        end,
    listen =
        function(self, ...)
            return self.socket:listen(...)
        end,
    accept =
        function(self, ...)
            return self.socket:accept(...)
        end,
    setoption =
        function(self, ...)
            return self.socket:setoption(...)
        end,
    -- TODO: is this DNS related? hence blocking?
    getpeername =
        function(self, ...)
            return self.socket:getpeername(...)
        end,
    shutdown =
        function(self, ...)
            return self.socket:shutdown(...)
        end,
    dohandshake =
        function(self, sslt)
            self.ssl_params = sslt or self.ssl_params
            local nskt, err = copasdohandshake(self.socket, self.ssl_params)
            if not nskt then
                return nskt, err
            end
            self.socket = nskt
            return self
        end,
}

local _skt_mt_tcp = {
    __tostring = _skt_mt_tostring,
    __index    = _skt_mt_tcp_index,
}

-- wraps a UDP socket, copy of TCP one adapted for UDP.

local _skt_mt_udp_index = {
    -- UDP sending is non-blocking, but we provide starvation prevention, so replace
    -- anyway.
    sendto =
        function (self, ...)
            return copassendto(self.socket,...)
        end,
    receive =
        function (self, size)
            return copasreceive(self.socket, size or UDP_DATAGRAM_MAX)
        end,
    receivefrom =
        function (self, size)
            return copasreceivefrom(self.socket, size or UDP_DATAGRAM_MAX)
        end,
    -- TODO: is this DNS related? hence blocking?
    setpeername =
        function(self, ...)
            return self.socket:getpeername(...)
        end,
    setsockname =
        function(self, ...)
            return self.socket:setsockname(...)
        end,
    -- do not close client, as it is also the server for udp.
    close =
        function(self, ...)
            return true
        end
}

local _skt_mt_udp = {
    __tostring = _skt_mt_tostring,
    __index    = _skt_mt_udp_index,
}

for k, v in next, _skt_mt_tcp_index do
    if not _skt_mt_udp_index[k] then
        _skt_mt_udp_index[k] = v
    end
end

-- Wraps a LuaSocket socket object in an async Copas based socket object.

-- @param skt  the socket to wrap
-- @sslt       (optional) Table with ssl parameters, use an empty table to use ssl with defaults
-- @return     wrapped socket object

local function wrap(skt, sslt)
    if getmetatable(skt) == _skt_mt_tcp or getmetatable(skt) == _skt_mt_udp then
        return skt -- already wrapped
    end
    skt:settimeout(0)
    if isTCP(skt) then
        return setmetatable ({ socket = skt, ssl_params = sslt }, _skt_mt_tcp)
    else
        return setmetatable ({ socket = skt }, _skt_mt_udp)
    end
end

copas.wrap = wrap

-- Wraps a handler in a function that deals with wrapping the socket and doing
-- the optional ssl handshake.

function copas.handler(handler, sslparams)
    return function (skt,...)
        skt = wrap(skt)
        if sslparams then
            skt:dohandshake(sslparams)
        end
        return handler(skt,...)
    end
end

-- Error handling (a handler per coroutine).

local _errhandlers = { }

function copas.setErrorHandler(err)
    local co = runningcoroutine()
    if co then
        _errhandlers[co] = err
    end
end

local function _deferror (msg, co, skt)
    report("%s (%s) (%s)", msg, tostring(co), tostring(skt))
end

-- Thread handling

local function _doTick (co, skt, ...)
    if not co then
        return
    end

    local ok, res, new_q = resumecoroutine(co, skt, ...)

    if ok and res and new_q then
        new_q:insert(res)
        new_q:push(res, co)
    else
        if not ok then
            pcall(_errhandlers[co] or _deferror, res, co, skt)
        end
        -- Do not auto-close UDP sockets, as the handler socket is also the server socket.
        if skt and copas.autoclose and isTCP(skt) then
            skt:close()
        end
        _errhandlers[co] = nil
    end
end

-- Accepts a connection on socket input.

local function _accept(input, handler)
    local client = input:accept()
    if client then
        client:settimeout(0)
        local co = createcoroutine(handler)
        _doTick (co, client)
    -- _reading:insert(client)
    end
    return client
end

-- Handle threads on a queue.

local function _tickRead(skt)
    _doTick(_reading:pop(skt), skt)
end

local function _tickWrite(skt)
    _doTick(_writing:pop(skt), skt)
end

-- Adds a server/handler pair to Copas dispatcher.

local function addTCPserver(server, handler, timeout)
    server:settimeout(timeout or 0)
    _servers[server] = handler
    _reading:insert(server)
end

local function addUDPserver(server, handler, timeout)
    server:settimeout(timeout or 0)
    local co = createcoroutine(handler)
    _reading:insert(server)
    _doTick(co, server)
end

function copas.addserver(server, handler, timeout)
    if isTCP(server) then
        addTCPserver(server, handler, timeout)
    else
        addUDPserver(server, handler, timeout)
    end
end

function copas.removeserver(server, keep_open)
    local s  = server
    local mt = getmetatable(server)
    if mt == _skt_mt_tcp or mt == _skt_mt_udp then
        s = server.socket
    end
    _servers[s] = nil
    _reading:remove(s)
    if keep_open then
        return true
    end
    return server:close()
end

-- Adds an new coroutine thread to Copas dispatcher. Create a coroutine that skips
-- the first argument, which is always the socket passed by the scheduler, but `nil`
-- in case of a task/thread

function copas.addthread(handler, ...)
    local thread = createcoroutine(function(_, ...) return handler(...) end)
    _doTick(thread, nil, ...)
    return thread
end

-- tasks registering

local _tasks = { }

-- Lets tasks call the default _tick().

local function addtaskRead(task)
    task.def_tick = _tickRead
    _tasks[task] = true
end

-- Lets tasks call the default _tick().

local function addtaskWrite(task)
    task.def_tick = _tickWrite
    _tasks[task] = true
end

local function tasks()
    return next, _tasks
end

-- A task to check ready to read events.

local _readable_t = {
    events =
        function(self)
            local i = 0
            return function ()
                i = i + 1
                return self._evs[i]
            end
        end,
    tick =
        function(self, input)
            local handler = _servers[input]
            if handler then
                input = _accept(input, handler)
            else
                _reading:remove(input)
                self.def_tick(input)
            end
        end
}

addtaskRead(_readable_t)

-- A task to check ready to write events.

local _writable_t = {
    events =
        function(self)
            local i = 0
            return function()
                i = i + 1
                return self._evs[i]
            end
        end,
    tick =
        function(self, output)
            _writing:remove(output)
            self.def_tick(output)
        end
}

addtaskWrite(_writable_t)

--sleeping threads task

local _sleeping_t = {
    tick = function(self, time, ...)
        _doTick(_sleeping:pop(time), ...)
    end
}

-- yields the current coroutine and wakes it after 'sleeptime' seconds.
-- If sleeptime<0 then it sleeps until explicitly woken up using 'wakeup'
function copas.sleep(sleeptime)
    yieldcoroutine((sleeptime or 0), _sleeping)
end

-- Wakes up a sleeping coroutine 'co'.

function copas.wakeup(co)
    _sleeping:wakeup(co)
end

-- Checks for reads and writes on sockets

local last_cleansing = 0

local function _select(timeout)

    local now = gettime()

    local r_evs, w_evs, err = selectsocket(_reading, _writing, timeout)

    _readable_t._evs = r_evs
    _writable_t._evs = w_evs

    if (last_cleansing - now) > WATCH_DOG_TIMEOUT then

        last_cleansing = now

        -- Check all sockets selected for reading, and check how long they have been
        -- waiting for data already, without select returning them as readable.

        for skt, time in next, _reading_log do

            if not r_evs[skt] and (time - now) > WATCH_DOG_TIMEOUT then

                -- This one timedout while waiting to become readable, so move it in
                -- the readable list and try and read anyway, despite not having
                -- been returned by select.

                local n = #r_evs + 1
                _reading_log[skt] = nil
                r_evs[n]   = skt
                r_evs[skt] = n
            end
        end

        -- Do the same for writing.

        for skt, time in next, _writing_log do
            if not w_evs[skt] and (time - now) > WATCH_DOG_TIMEOUT then
                local n = #w_evs + 1
                _writing_log[skt] = nil
                w_evs[n]   = skt
                w_evs[skt] = n
            end
        end

    end

    if err == "timeout" and #r_evs + #w_evs > 0 then
        return nil
    else
        return err
    end

end

-- Check whether there is something to do. It returns false if there are no sockets
-- for read/write nor tasks scheduled (which means Copas is in an empty spin).

local function copasfinished()
    return not (next(_reading) or next(_writing) or _sleeping:getnext())
end

-- Dispatcher loop step. It listens to client requests and handles them and returns
-- false if no data was handled (timeout), or true if there was data handled (or nil
-- + error message).

local function copasstep(timeout)
    _sleeping_t:tick(gettime())

    local nextwait = _sleeping:getnext()
    if nextwait then
        timeout = timeout and min(nextwait,timeout) or nextwait
    elseif copasfinished() then
        return false
    end

    local err = _select(timeout)
    if err then
        if err == "timeout" then
            return false
        end
        return nil, err
    end

    for task in tasks() do
        for event in task:events() do
            task:tick(event)
        end
    end
    return true
end

copas.finished = copasfinished
copas.step     = copasstep

-- Dispatcher endless loop. It listens to client requests and handles them forever.

function copas.loop(timeout)
    copas.running = true
    while not copasfinished() do
        copasstep(timeout)
    end
    copas.running = false
end

-- _G.copas = copas

package.loaded["copas"] = copas

return copas
