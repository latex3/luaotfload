-- original file : smtp.lua
-- for more into : see util-soc.lua

local type, setmetatable, next = type, setmetatable, next
local find, lower, format = string.find, string.lower, string.format
local osdate, osgetenv = os.date, os.getenv
local random = math.random

local socket           = socket         or require("socket")
local headers          = socket.headers or require("socket.headers")
local ltn12            = ltn12          or require("ltn12")
local tp               = socket.tp      or require("socket.tp")
local mime             = mime           or require("mime")

local mimeb64          = mime.b64
local mimestuff        = mime.stuff

local skipsocket       = socket.skip
local trysocket        = socket.try
local newtrysocket     = socket.newtry
local protectsocket    = socket.protect

local normalizeheaders = headers.normalize
local lowerheaders     = headers.lower

local createcoroutine  = coroutine.create
local resumecoroutine  = coroutine.resume
local yieldcoroutine   = coroutine.resume

local smtp = {
    TIMEOUT = 60,
    SERVER  = "localhost",
    PORT    = 25,
    DOMAIN  = osgetenv("SERVER_NAME") or "localhost",
    ZONE    = "-0000",
}

socket.smtp = smtp

local methods = { }
local mt      = { __index = methods }

function methods.greet(self, domain)
    local try = self.try
    local tp  = self.tp
    try(tp:check("2.."))
    try(tp:command("EHLO", domain or _M.DOMAIN))
    return skipsocket(1, try(tp:check("2..")))
end

function methods.mail(self, from)
    local try = self.try
    local tp  = self.tp
    try(tp:command("MAIL", "FROM:" .. from))
    return try(tp:check("2.."))
end

function methods.rcpt(self, to)
    local try = self.try
    local tp  = self.tp
    try(tp:command("RCPT", "TO:" .. to))
    return try(tp:check("2.."))
end

function methods.data(self, src, step)
    local try = self.try
    local tp  = self.tp
    try(tp:command("DATA"))
    try(tp:check("3.."))
    try(tp:source(src, step))
    try(tp:send("\r\n.\r\n"))
    return try(tp:check("2.."))
end

function methods.quit(self)
    local try = self.try
    local tp  = self.tp
    try(tp:command("QUIT"))
    return try(tp:check("2.."))
end

function methods.close(self)
    return self.tp:close()
end

function methods.login(self, user, password)
    local try = self.try
    local tp  = self.tp
    try(tp:command("AUTH", "LOGIN"))
    try(tp:check("3.."))
    try(tp:send(mimeb64(user) .. "\r\n"))
    try(tp:check("3.."))
    try(tp:send(mimeb64(password) .. "\r\n"))
    return try(tp:check("2.."))
end

function methods.plain(self, user, password)
    local try  = self.try
    local tp   = self.tp
    local auth = "PLAIN " .. mimeb64("\0" .. user .. "\0" .. password)
    try(tp:command("AUTH", auth))
    return try(tp:check("2.."))
end

function methods.auth(self, user, password, ext)
    if not user or not password then
        return 1
    end
    local try = self.try
    if find(ext, "AUTH[^\n]+LOGIN") then
        return self:login(user,password)
    elseif find(ext, "AUTH[^\n]+PLAIN") then
        return self:plain(user,password)
    else
        try(nil, "authentication not supported")
    end
end

function methods.send(self, mail)
    self:mail(mail.from)
    local receipt = mail.rcpt
    if type(receipt) == "table" then
        for i=1,#receipt do
            self:rcpt(receipt[i])
        end
    elseif receipt then
        self:rcpt(receipt)
    end
    self:data(ltn12.source.chain(mail.source, mimestuff()), mail.step)
end

local function opensmtp(self, server, port, create)
    if not server or server == "" then
        server = smtp.SERVER
    end
    if not port or port == "" then
        port = smtp.PORT
    end
    local s = {
        tp  = trysocket(tp.connect(server, port, smtp.TIMEOUT, create)),
        try = newtrysocket(function()
            s:close()
        end),
    }
    setmetatable(s, mt)
    return s
end

smtp.open = opensmtp

local nofboundaries = 0

local function newboundary()
    nofboundaries = nofboundaries + 1
    return format('%s%05d==%05u', osdate('%d%m%Y%H%M%S'), random(0,99999), nofboundaries)
end

local send_message

local function send_headers(headers)
    yieldcoroutine(normalizeheaders(headers))
end

local function send_multipart(message)
    local boundary = newboundary()
    local headers  = lowerheaders(message.headers)
    local body     = message.body
    local preamble = body.preamble
    local epilogue = body.epilogue
    local content  = headers['content-type'] or 'multipart/mixed'
    headers['content-type'] = content .. '; boundary="' ..  boundary .. '"'
    send_headers(headers)
    if preamble then
        yieldcoroutine(preamble)
        yieldcoroutine("\r\n")
    end
    for i=1,#body do
        yieldcoroutine("\r\n--" .. boundary .. "\r\n")
        send_message(body[i])
    end
    yieldcoroutine("\r\n--" .. boundary .. "--\r\n\r\n")
    if epilogue then
        yieldcoroutine(epilogue)
        yieldcoroutine("\r\n")
    end
end

local default_content_type = 'text/plain; charset="UTF-8"'

local function send_source(message)
    local headers = lowerheaders(message.headers)
    if not headers['content-type'] then
        headers['content-type'] = default_content_type
    end
    send_headers(headers)
    local getchunk = message.body
    while true do
        local chunk, err = getchunk()
        if err then
            yieldcoroutine(nil, err)
        elseif chunk then
            yieldcoroutine(chunk)
        else
            break
        end
    end
end

local function send_string(message)
    local headers = lowerheaders(message.headers)
    if not headers['content-type'] then
        headers['content-type'] = default_content_type
    end
    send_headers(headers)
    yieldcoroutine(message.body)
end

function send_message(message)
    local body = message.body
    if type(body) == "table" then
        send_multipart(message)
    elseif type(body) == "function" then
        send_source(message)
    else
        send_string(message)
    end
end

local function adjust_headers(message)
    local headers = lowerheaders(message.headers)
    if not headers["date"] then
        headers["date"] = osdate("!%a, %d %b %Y %H:%M:%S ") .. (message.zone or smtp.ZONE)
    end
    if not headers["x-mailer"] then
        headers["x-mailer"] = socket._VERSION
    end
    headers["mime-version"] = "1.0"
    return headers
end

function smtp.message(message)
    message.headers = adjust_headers(message)
    local action = createcoroutine(function()
        send_message(message)
    end)
    return function()
        local ret, a, b = resumecoroutine(action)
        if ret then
            return a, b
        else
            return nil, a
        end
    end
end

smtp.send = protectsocket(function(mail)
    local snd = opensmtp(smtp,mail.server, mail.port, mail.create)
    local ext = snd:greet(mail.domain)
    snd:auth(mail.user, mail.password, ext)
    snd:send(mail)
    snd:quit()
    return snd:close()
end)

package.loaded["socket.smtp"] = smtp

return smtp
