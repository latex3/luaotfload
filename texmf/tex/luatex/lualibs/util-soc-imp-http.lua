-- original file : http.lua
-- for more into : see util-soc.lua

local tostring, tonumber, setmetatable, next, type = tostring, tonumber, setmetatable, next, type
local find, lower, format, gsub, match  = string.find, string.lower, string.format, string.gsub, string.match
local concat = table.concat

local socket  = socket         or require("socket")
local url     = socket.url     or require("socket.url")
local ltn12   = ltn12          or require("ltn12")
local mime    = mime           or require("mime")
local headers = socket.headers or require("socket.headers")

local normalizeheaders = headers.normalize

local parseurl         = url.parse
local buildurl         = url.build
local absoluteurl      = url.absolute
local unescapeurl      = url.unescape

local skipsocket       = socket.skip
local sinksocket       = socket.sink
local sourcesocket     = socket.source
local trysocket        = socket.try
local tcpsocket        = socket.tcp
local newtrysocket     = socket.newtry
local protectsocket    = socket.protect

local emptysource      = ltn12.source.empty
local stringsource     = ltn12.source.string
local rewindsource     = ltn12.source.rewind
local pumpstep         = ltn12.pump.step
local pumpall          = ltn12.pump.all
local sinknull         = ltn12.sink.null
local sinktable        = ltn12.sink.table

local lowerheaders     = headers.lower

local mimeb64          = mime.b64

-- todo: localize ltn12

local http  = {
    TIMEOUT   = 60,               -- connection timeout in seconds
    USERAGENT = socket._VERSION,  -- user agent field sent in request
}

socket.http = http

local PORT    = 80
local SCHEMES = {
    http = true,
}

-- Reads MIME headers from a connection, unfolding where needed

local function receiveheaders(sock, headers)
    if not headers then
        headers = { }
    end
    -- get first line
    local line, err = sock:receive()
    if err then
        return nil, err
    end
    -- headers go until a blank line is found
    while line ~= "" do
        -- get field-name and value
        local name, value = skipsocket(2, find(line, "^(.-):%s*(.*)"))
        if not (name and value) then
            return nil, "malformed reponse headers"
        end
        name = lower(name)
        -- get next line (value might be folded)
        line, err  = sock:receive()
        if err then
            return nil, err
        end
        -- unfold any folded values
        while find(line, "^%s") do
            value = value .. line
            line  = sock:receive()
            if err then
                return nil, err
            end
        end
        -- save pair in table
        local found = headers[name]
        if found then
            value = found .. ", " .. value
        end
        headers[name] = value
    end
    return headers
end

-- Extra sources and sinks

socket.sourcet["http-chunked"] = function(sock, headers)
    return setmetatable (
        {
            getfd = function() return sock:getfd() end,
            dirty = function() return sock:dirty() end,
        }, {
            __call = function()
                local line, err = sock:receive()
                if err then
                    return nil, err
                end
                local size = tonumber(gsub(line, ";.*", ""), 16)
                if not size then
                    return nil, "invalid chunk size"
                end
                if size > 0 then
                    local chunk, err, part = sock:receive(size)
                    if chunk then
                        sock:receive()
                    end
                    return chunk, err
                else
                    headers, err = receiveheaders(sock, headers)
                    if not headers then
                        return nil, err
                    end
                end
            end
        }
    )
end

socket.sinkt["http-chunked"] = function(sock)
    return setmetatable(
        {
            getfd = function() return sock:getfd() end,
            dirty = function() return sock:dirty() end,
        },
        {
            __call = function(self, chunk, err)
                if not chunk then
                    chunk = ""
                end
                return sock:send(format("%X\r\n%s\r\n",#chunk,chunk))
            end
    })
end

-- Low level HTTP API

local methods = { }
local mt      = { __index = methods }

local function openhttp(host, port, create)
    local c = trysocket((create or tcpsocket)())
    local h = setmetatable({ c = c }, mt)
    local try = newtrysocket(function() h:close() end)
    h.try = try
    try(c:settimeout(http.TIMEOUT))
    try(c:connect(host, port or PORT))
    return h
end

http.open = openhttp

function methods.sendrequestline(self, method, uri)
    local requestline = format("%s %s HTTP/1.1\r\n", method or "GET", uri)
    return self.try(self.c:send(requestline))
end

function methods.sendheaders(self,headers)
    self.try(self.c:send(normalizeheaders(headers)))
    return 1
end

function methods.sendbody(self, headers, source, step)
    if not source then
        source = emptysource()
    end
    if not step then
        step = pumpstep
    end
    local mode = "http-chunked"
    if headers["content-length"] then
        mode = "keep-open"
    end
    return self.try(pumpall(source, sinksocket(mode, self.c), step))
end

function methods.receivestatusline(self)
    local try    = self.try
    local status = try(self.c:receive(5))
    if status ~= "HTTP/" then
        return nil, status -- HTTP/0.9
    end
    status = try(self.c:receive("*l", status))
    local code = skipsocket(2, find(status, "HTTP/%d*%.%d* (%d%d%d)"))
    return try(tonumber(code), status)
end

function methods.receiveheaders(self)
    return self.try(receiveheaders(self.c))
end

function methods.receivebody(self, headers, sink, step)
    if not sink then
        sink = sinknull()
    end
    if not step then
        step = pumpstep
    end
    local length   = tonumber(headers["content-length"])
    local encoding = headers["transfer-encoding"] -- shortcut
    local mode     = "default" -- connection close
    if encoding and encoding ~= "identity" then
        mode = "http-chunked"
    elseif length then
        mode = "by-length"
    end
    --hh: so length can be nil
    return self.try(pumpall(sourcesocket(mode, self.c, length), sink, step))
end

function methods.receive09body(self, status, sink, step)
    local source = rewindsource(sourcesocket("until-closed", self.c))
    source(status)
    return self.try(pumpall(source, sink, step))
end

function methods.close(self)
    return self.c:close()
end

-- High level HTTP API

local function adjusturi(request)
    if not request.proxy and not http.PROXY then
        request = {
           path     = trysocket(request.path, "invalid path 'nil'"),
           params   = request.params,
           query    = request.query,
           fragment = request.fragment,
        }
    end
    return buildurl(request)
end

local function adjustheaders(request)
    local headers = {
        ["user-agent"] = http.USERAGENT,
        ["host"]       = gsub(request.authority, "^.-@", ""),
        ["connection"] = "close, TE",
        ["te"]         = "trailers"
    }
    local username = request.user
    local password = request.password
    if username and password then
        headers["authorization"] = "Basic " ..  (mimeb64(username .. ":" .. unescapeurl(password)))
    end
    local proxy = request.proxy or http.PROXY
    if proxy then
        proxy = parseurl(proxy)
        local username = proxy.user
        local password = proxy.password
        if username and password then
            headers["proxy-authorization"] = "Basic " ..  (mimeb64(username .. ":" .. password))
        end
    end
    local requestheaders = request.headers
    if requestheaders then
        headers = lowerheaders(headers,requestheaders)
    end
    return headers
end

-- default url parts

local default = {
    host   = "",
    port   = PORT,
    path   = "/",
    scheme = "http"
}

local function adjustrequest(originalrequest)
    local url     = originalrequest.url
    local request = url and parseurl(url,default) or { }
    for k, v in next, originalrequest do
        request[k] = v
    end
    local host = request.host
    local port = request.port
    local uri  = request.uri
    if not host or host == "" then
        trysocket(nil, "invalid host '" .. tostring(host) .. "'")
    end
    if port == "" then
        request.port = PORT
    end
    if not uri or uri == "" then
        request.uri = adjusturi(request)
    end
    request.headers = adjustheaders(request)
    local proxy = request.proxy or http.PROXY
    if proxy then
        proxy        = parseurl(proxy)
        request.host = proxy.host
        request.port = proxy.port or 3128
    end
    return request
end

local maxredericts   = 4
local validredirects = { [301] = true, [302] = true, [303] = true, [307] = true }
local validmethods   = { [false] = true, GET = true, HEAD = true }

local function shouldredirect(request, code, headers)
    local location = headers.location
    if not location then
        return false
    end
    location = gsub(location, "%s", "")
    if location == "" then
        return false
    end
    local scheme = match(location, "^([%w][%w%+%-%.]*)%:")
    if scheme and not SCHEMES[scheme] then
        return false
    end
    local method    = request.method
    local redirect  = request.redirect
    local redirects = request.nredirects or 0
    return redirect and validredirects[code] and validmethods[method] and redirects <= maxredericts
end

local function shouldreceivebody(request, code)
    if request.method == "HEAD" then
        return nil
    end
    if code == 204 or code == 304 then
        return nil
    end
    if code >= 100 and code < 200 then
        return nil
    end
    return 1
end

local tredirect, trequest, srequest

tredirect = function(request, location)
    local result, code, headers, status = trequest {
        url        = absoluteurl(request.url,location),
        source     = request.source,
        sink       = request.sink,
        headers    = request.headers,
        proxy      = request.proxy,
        nredirects = (request.nredirects or 0) + 1,
        create     = request.create,
    }
    if not headers then
        headers = { }
    end
    if not headers.location then
        headers.location = location
    end
    return result, code, headers, status
end

trequest = function(originalrequest)
    local request    = adjustrequest(originalrequest)
    local connection = openhttp(request.host, request.port, request.create)
    local headers    = request.headers
    connection:sendrequestline(request.method, request.uri)
    connection:sendheaders(headers)
    if request.source then
        connection:sendbody(headers, request.source, request.step)
    end
    local code, status = connection:receivestatusline()
    if not code then
        connection:receive09body(status, request.sink, request.step)
        return 1, 200
    end
    while code == 100 do
        headers = connection:receiveheaders()
        code, status = connection:receivestatusline()
    end
    headers = connection:receiveheaders()
    if shouldredirect(request, code, headers) and not request.source then
        connection:close()
        return tredirect(originalrequest,headers.location)
    end
    if shouldreceivebody(request, code) then
        connection:receivebody(headers, request.sink, request.step)
    end
    connection:close()
    return 1, code, headers, status
end

-- turns an url and a body into a generic request

local function genericform(url, body)
    local buffer  = { }
    local request = {
        url    = url,
        sink   = sinktable(buffer),
        target = buffer,
    }
    if body then
        request.source  = stringsource(body)
        request.method  = "POST"
        request.headers = {
            ["content-length"] = #body,
            ["content-type"]   = "application/x-www-form-urlencoded"
        }
    end
    return request
end

http.genericform = genericform

srequest = function(url, body)
    local request = genericform(url, body)
    local _, code, headers, status = trequest(request)
    return concat(request.target), code, headers, status
end

http.request = protectsocket(function(request, body)
    if type(request) == "string" then
        return srequest(request, body)
    else
        return trequest(request)
    end
end)

package.loaded["socket.http"] = http

return http
