-- original file : ftp.lua
-- for more into : see util-soc.lua

local setmetatable, type, next = setmetatable, type, next
local find, format, gsub, match = string.find, string.format, string.gsub, string.match
local concat = table.concat
local mod = math.mod

local socket        = socket     or require("socket")
local url           = socket.url or require("socket.url")
local tp            = socket.tp  or require("socket.tp")
local ltn12         = ltn12      or require("ltn12")

local tcpsocket     = socket.tcp
local trysocket     = socket.try
local skipsocket    = socket.skip
local sinksocket    = socket.sink
local selectsocket  = socket.select
local bindsocket    = socket.bind
local newtrysocket  = socket.newtry
local sourcesocket  = socket.source
local protectsocket = socket.protect

local parseurl      = url.parse
local unescapeurl   = url.unescape

local pumpall       = ltn12.pump.all
local pumpstep      = ltn12.pump.step
local sourcestring  = ltn12.source.string
local sinktable     = ltn12.sink.table

local ftp = {
    TIMEOUT  = 60,
    USER     = "ftp",
    PASSWORD = "anonymous@anonymous.org",
}

socket.ftp    = ftp

local PORT    = 21

local methods = { }
local mt      = { __index = methods }

function ftp.open(server, port, create)
    local tp = trysocket(tp.connect(server, port or PORT, ftp.TIMEOUT, create))
    local f = setmetatable({ tp = tp }, metat)
    f.try = newtrysocket(function() f:close() end)
    return f
end

function methods.portconnect(self)
    local try    = self.try
    local server = self.server
    try(server:settimeout(ftp.TIMEOUT))
    self.data = try(server:accept())
    try(self.data:settimeout(ftp.TIMEOUT))
end

function methods.pasvconnect(self)
    local try = self.try
    self.data = try(tcpsocket())
    self(self.data:settimeout(ftp.TIMEOUT))
    self(self.data:connect(self.pasvt.address, self.pasvt.port))
end

function methods.login(self, user, password)
    local try = self.try
    local tp  = self.tp
    try(tp:command("user", user or ftp.USER))
    local code, reply = try(tp:check{"2..", 331})
    if code == 331 then
        try(tp:command("pass", password or ftp.PASSWORD))
        try(tp:check("2.."))
    end
    return 1
end

function methods.pasv(self)
    local try = self.try
    local tp  = self.tp
    try(tp:command("pasv"))
    local code, reply = try(self.tp:check("2.."))
    local pattern = "(%d+)%D(%d+)%D(%d+)%D(%d+)%D(%d+)%D(%d+)"
    local a, b, c, d, p1, p2 = skipsocket(2, find(reply, pattern))
    try(a and b and c and d and p1 and p2, reply)
    local address = format("%d.%d.%d.%d", a, b, c, d)
    local port    = p1*256 + p2
    local server  = self.server
    self.pasvt = {
        address = address,
        port    = port,
    }
    if server then
        server:close()
        self.server = nil
    end
    return address, port
end

function methods.epsv(self)
    local try = self.try
    local tp  = self.tp
    try(tp:command("epsv"))
    local code, reply = try(tp:check("229"))
    local pattern = "%((.)(.-)%1(.-)%1(.-)%1%)"
    local d, prt, address, port = match(reply, pattern)
    try(port, "invalid epsv response")
    local address = tp:getpeername()
    local server  = self.server
    self.pasvt = {
        address = address,
        port    = port,
    }
    if self.server then
        server:close()
        self.server = nil
    end
    return address, port
end

function methods.port(self, address, port)
    local try = self.try
    local tp  = self.tp
    self.pasvt = nil
    if not address then
        address, port = try(tp:getsockname())
        self.server   = try(bindsocket(address, 0))
        address, port = try(self.server:getsockname())
        try(self.server:settimeout(ftp.TIMEOUT))
    end
    local pl  = mod(port,256)
    local ph  = (port - pl)/256
    local arg = gsub(format("%s,%d,%d", address, ph, pl), "%.", ",")
    try(tp:command("port", arg))
    try(tp:check("2.."))
    return 1
end

function methods.eprt(self, family, address, port)
    local try = self.try
    local tp  = self.tp
    self.pasvt = nil
    if not address then
        address, port = try(tp:getsockname())
        self.server   = try(bindsocket(address, 0))
        address, port = try(self.server:getsockname())
        try(self.server:settimeout(ftp.TIMEOUT))
    end
    local arg = format("|%s|%s|%d|", family, address, port)
    try(tp:command("eprt", arg))
    try(tp:check("2.."))
    return 1
end

function methods.send(self, sendt)
    local try = self.try
    local tp  = self.tp
    -- so we try a table or string ?
    try(self.pasvt or self.server, "need port or pasv first")
    if self.pasvt then
        self:pasvconnect()
    end
    local argument = sendt.argument or unescapeurl(gsub(sendt.path or "", "^[/\\]", ""))
    if argument == "" then
        argument = nil
    end
    local command = sendt.command or "stor"
    try(tp:command(command, argument))
    local code, reply = try(tp:check{"2..", "1.."})
    if not self.pasvt then
        self:portconnect()
    end
    local step = sendt.step or pumpstep
    local readt = { tp }
    local checkstep = function(src, snk)
        local readyt = selectsocket(readt, nil, 0)
        if readyt[tp] then
            code = try(tp:check("2.."))
        end
        return step(src, snk)
    end
    local sink = sinksocket("close-when-done", self.data)
    try(pumpall(sendt.source, sink, checkstep))
    if find(code, "1..") then
        try(tp:check("2.."))
    end
    self.data:close()
    local sent = skipsocket(1, self.data:getstats())
    self.data = nil
    return sent
end

function methods.receive(self, recvt)
    local try = self.try
    local tp  = self.tp
    try(self.pasvt or self.server, "need port or pasv first")
    if self.pasvt then self:pasvconnect() end
    local argument = recvt.argument or unescapeurl(gsub(recvt.path or "", "^[/\\]", ""))
    if argument == "" then
        argument = nil
    end
    local command = recvt.command or "retr"
    try(tp:command(command, argument))
    local code,reply = try(tp:check{"1..", "2.."})
    if code >= 200 and code <= 299 then
        recvt.sink(reply)
        return 1
    end
    if not self.pasvt then
        self:portconnect()
    end
    local source = sourcesocket("until-closed", self.data)
    local step   = recvt.step or pumpstep
    try(pumpall(source, recvt.sink, step))
    if find(code, "1..") then
        try(tp:check("2.."))
    end
    self.data:close()
    self.data = nil
    return 1
end

function methods.cwd(self, dir)
    local try = self.try
    local tp  = self.tp
    try(tp:command("cwd", dir))
    try(tp:check(250))
    return 1
end

function methods.type(self, typ)
    local try = self.try
    local tp  = self.tp
    try(tp:command("type", typ))
    try(tp:check(200))
    return 1
end

function methods.greet(self)
    local try = self.try
    local tp  = self.tp
    local code = try(tp:check{"1..", "2.."})
    if find(code, "1..") then
        try(tp:check("2.."))
    end
    return 1
end

function methods.quit(self)
    local try = self.try
    try(self.tp:command("quit"))
    try(self.tp:check("2.."))
    return 1
end

function methods.close(self)
    local data = self.data
    if data then
        data:close()
    end
    local server = self.server
    if server then
        server:close()
    end
    local tp = self.tp
    if tp then
        tp:close()
    end
end

local function override(t)
    if t.url then
        local u = parseurl(t.url)
        for k, v in next, t do
            u[k] = v
        end
        return u
    else
        return t
    end
end

local function tput(putt)
    putt = override(putt)
    local host = putt.host
    trysocket(host, "missing hostname")
    local f = ftp.open(host, putt.port, putt.create)
    f:greet()
    f:login(putt.user, putt.password)
    local typ = putt.type
    if typ then
        f:type(typ)
    end
    f:epsv()
    local sent = f:send(putt)
    f:quit()
    f:close()
    return sent
end

local default = {
    path   = "/",
    scheme = "ftp",
}

local function genericform(u)
    local t = trysocket(parseurl(u, default))
    trysocket(t.scheme == "ftp", "wrong scheme '" .. t.scheme .. "'")
    trysocket(t.host, "missing hostname")
    local pat = "^type=(.)$"
    if t.params then
        local typ = skipsocket(2, find(t.params, pat))
        t.type = typ
        trysocket(typ == "a" or typ == "i", "invalid type '" .. typ .. "'")
    end
    return t
end

ftp.genericform = genericform

local function sput(u, body)
    local putt = genericform(u)
    putt.source = sourcestring(body)
    return tput(putt)
end

ftp.put = protectsocket(function(putt, body)
    if type(putt) == "string" then
        return sput(putt, body)
    else
        return tput(putt)
    end
end)

local function tget(gett)
    gett = override(gett)
    local host = gett.host
    trysocket(host, "missing hostname")
    local f = ftp.open(host, gett.port, gett.create)
    f:greet()
    f:login(gett.user, gett.password)
    if gett.type then
        f:type(gett.type)
    end
    f:epsv()
    f:receive(gett)
    f:quit()
    return f:close()
end

local function sget(u)
    local gett = genericform(u)
    local t    = { }
    gett.sink = sinktable(t)
    tget(gett)
    return concat(t)
end

ftp.command = protectsocket(function(cmdt)
    cmdt = override(cmdt)
    local command  = cmdt.command
    local argument = cmdt.argument
    local check    = cmdt.check
    local host     = cmdt.host
    trysocket(host, "missing hostname")
    trysocket(command, "missing command")
    local f   = ftp.open(host, cmdt.port, cmdt.create)
    local try = f.try
    local tp  = f.tp
    f:greet()
    f:login(cmdt.user, cmdt.password)
    if type(command) == "table" then
        local argument = argument or { }
        for i=1,#command do
            local cmd = command[i]
            try(tp:command(cmd, argument[i]))
            if check and check[i] then
                try(tp:check(check[i]))
            end
        end
    else
        try(tp:command(command, argument))
        if check then
            try(tp:check(check))
        end
    end
    f:quit()
    return f:close()
end)

ftp.get = protectsocket(function(gett)
    if type(gett) == "string" then
        return sget(gett)
    else
        return tget(gett)
    end
end)

package.loaded["socket.ftp"] = ftp

return ftp
