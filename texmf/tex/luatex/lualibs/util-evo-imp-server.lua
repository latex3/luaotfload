if not modules then modules = { } end modules ['util-imp-evohome-server'] = {
    version   = 1.002,
    comment   = "simple server for simple evohome extensions",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE",
    license   = "see context related readme files"
}

local P, C, patterns, lpegmatch = lpeg.P, lpeg.C, lpeg.patterns, lpeg.match
local urlhashed, urlquery, urlunescapeget  = url.hashed, url.query, url.unescapeget
local ioflush = io.flush

local newline    = patterns.newline
local spacer     = patterns.spacer
local whitespace = patterns.whitespace
local method     = P("GET")
                 + P("POST")
local identify   = (1-method)^0
                 * C(method)
                 * spacer^1
                 * C((1-spacer)^1)
                 * spacer^1
                 * P("HTTP/")
                 * (1-whitespace)^0
                 * C(P(1)^0)

do

    local loaded = package.loaded

    if not loaded.socket then loaded.socket = loaded["socket.core"] end
    if not loaded.mime   then loaded.mime   = loaded["mime.core"]   end

end

local evohome  = require("util-evo")
                 require("trac-lmx")

local report   = logs.reporter("evohome","server")
local convert  = lmx.convert

function evohome.server(specification)

    local filename = specification.filename

    if not filename then
        report("unable to run server, no filename given")
        return
    end

    local step, process, presets = evohome.actions.poller(filename)

    if not (step and process and presets) then
        report("unable to run server, invalid presets")
        return
    end

    local template = presets.files.template

    if not template then
        report("unable to run server, no template given")
        return
    end

    local port = specification.port or (presets.server and presets.server.port) or 8068
    local host = specification.host or (presets.server and presets.server.host) or "*"

    package.extraluapath(presets.filepath)

    local socket = socket or require("socket")
    local copas  = copas  or require("copas")

    local function copashttp(skt)
        local client = copas.wrap(skt)
        local request, e = client:receive()
        if not e then
            local method, fullurl, body = lpegmatch(identify,request)
            if method ~= "" and fullurl ~= "" then
                local fullurl = urlunescapeget(fullurl)
                local hashed  = urlhashed(fullurl)
                process(hashed.queries or { })
                ioflush()
            end
            -- todo: split off css and use that instead of general one, now too much
            local content = convert(presets.results and presets.results.template or template,false,presets)
            if not content then
                report("error in converting template")
                content = "error in template"
            end
            client:send("HTTP/1.1 200 OK\r\n")
            client:send("Connection: close\r\n")
            client:send("Content-Length: " .. #content .. "\r\n")
            client:send("Content-Type: text/html\r\n")
            client:send("Location: " .. host .. "\r\n")
            client:send("Cache-Control: no-cache, no-store, must-revalidate, max-age=0\r\n")
            client:send("\r\n")
            client:send(content)
            client:send("\r\n")
            client:close()
        end
    end

    local function copaspoll()
        while step do
            local delay = step()
            if type(delay) == "number" then
                copas.sleep(delay or 0)
            end
        end
    end

    local server = socket.bind(host,port)

    if server then
        report("server started at %s:%s",host,port)
        ioflush()
        copas.addserver(server,copashttp)
        copas.addthread(copaspoll)
        copas.loop()
    else
        report("unable to start server at %s:%s",host,port)
        os.exit()
    end

end

return evohome
