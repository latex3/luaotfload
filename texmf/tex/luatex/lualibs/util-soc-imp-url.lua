-- original file : url.lua
-- for more into : see util-soc.lua

local tonumber, tostring, type = tonumber, tostring, type

local gsub, sub, match, find, format, byte, char = string.gsub, string.sub, string.match, string.find, string.format, string.byte, string.char
local insert = table.insert

local socket = socket or require("socket")

local url = {
    _VERSION = "URL 1.0.3",
}

socket.url = url

function url.escape(s)
    return (gsub(s, "([^A-Za-z0-9_])", function(c)
        return format("%%%02x", byte(c))
    end))
end

local function make_set(t) -- table.tohash
    local s = { }
    for i=1,#t do
        s[t[i]] = true
    end
    return s
end

local segment_set = make_set {
    "-", "_", ".", "!", "~", "*", "'", "(",
    ")", ":", "@", "&", "=", "+", "$", ",",
}

local function protect_segment(s)
    return gsub(s, "([^A-Za-z0-9_])", function(c)
        if segment_set[c] then
            return c
        else
            return format("%%%02X", byte(c))
        end
    end)
end

function url.unescape(s)
    return (gsub(s, "%%(%x%x)", function(hex)
        return char(tonumber(hex,16))
    end))
end

local function absolute_path(base_path, relative_path)
    if find(relative_path,"^/") then
        return relative_path
    end
    local path = gsub(base_path, "[^/]*$", "")
    path = path .. relative_path
    path = gsub(path, "([^/]*%./)", function (s)
        if s ~= "./" then
            return s
        else
            return ""
        end
    end)
    path = gsub(path, "/%.$", "/")
    local reduced
    while reduced ~= path do
        reduced = path
        path = gsub(reduced, "([^/]*/%.%./)", function (s)
            if s ~= "../../" then
                return ""
            else
                return s
            end
        end)
    end
    path = gsub(reduced, "([^/]*/%.%.)$", function (s)
        if s ~= "../.." then
            return ""
        else
            return s
        end
    end)
    return path
end

function url.parse(url, default)
    local parsed = { }
    for k, v in next, default or parsed do
        parsed[k] = v
    end
    if not url or url == "" then
        return nil, "invalid url"
    end
    url = gsub(url, "#(.*)$", function(f)
        parsed.fragment = f
        return ""
    end)
    url = gsub(url, "^([%w][%w%+%-%.]*)%:", function(s)
        parsed.scheme = s
        return ""
    end)
    url = gsub(url, "^//([^/]*)", function(n)
        parsed.authority = n
        return ""
    end)
    url = gsub(url, "%?(.*)", function(q)
        parsed.query = q
        return ""
    end)
    url = gsub(url, "%;(.*)", function(p)
        parsed.params = p
        return ""
    end)
    if url ~= "" then
        parsed.path = url
    end
    local authority = parsed.authority
    if not authority then
        return parsed
    end
    authority = gsub(authority,"^([^@]*)@", function(u)
        parsed.userinfo = u
        return ""
    end)
    authority = gsub(authority, ":([^:%]]*)$", function(p)
        parsed.port = p
        return ""
    end)
    if authority ~= "" then
        parsed.host = match(authority, "^%[(.+)%]$") or authority
    end
    local userinfo = parsed.userinfo
    if not userinfo then
        return parsed
    end
    userinfo = gsub(userinfo, ":([^:]*)$", function(p)
        parsed.password = p
        return ""
    end)
    parsed.user = userinfo
    return parsed
end

function url.build(parsed)
    local url = parsed.path or ""
    if parsed.params then
        url = url .. ";" .. parsed.params
    end
    if parsed.query then
        url = url .. "?" .. parsed.query
    end
    local authority = parsed.authority
    if parsed.host then
        authority = parsed.host
        if find(authority, ":") then -- IPv6?
            authority = "[" .. authority .. "]"
        end
        if parsed.port then
            authority = authority .. ":" .. tostring(parsed.port)
        end
        local userinfo = parsed.userinfo
        if parsed.user then
            userinfo = parsed.user
            if parsed.password then
                userinfo = userinfo .. ":" .. parsed.password
            end
        end
        if userinfo then authority = userinfo .. "@" .. authority end
    end
    if authority then
        url = "//" .. authority .. url
    end
    if parsed.scheme then
        url = parsed.scheme .. ":" .. url
    end
    if parsed.fragment then
        url = url .. "#" .. parsed.fragment
    end
    return url
end

function url.absolute(base_url, relative_url)
    local base_parsed
    if type(base_url) == "table" then
        base_parsed = base_url
        base_url = url.build(base_parsed)
    else
        base_parsed = url.parse(base_url)
    end
    local relative_parsed = url.parse(relative_url)
    if not base_parsed then
        return relative_url
    elseif not relative_parsed then
        return base_url
    elseif relative_parsed.scheme then
        return relative_url
    else
        relative_parsed.scheme = base_parsed.scheme
        if not relative_parsed.authority then
            relative_parsed.authority = base_parsed.authority
            if not relative_parsed.path then
                relative_parsed.path = base_parsed.path
                if not relative_parsed.params then
                    relative_parsed.params = base_parsed.params
                    if not relative_parsed.query then
                        relative_parsed.query = base_parsed.query
                    end
                end
            else
                relative_parsed.path = absolute_path(base_parsed.path or "", relative_parsed.path)
            end
        end
        return url.build(relative_parsed)
    end
end

function url.parse_path(path)
    local parsed = { }
    path = path or ""
    gsub(path, "([^/]+)", function (s)
        insert(parsed, s)
    end)
    for i=1,#parsed do
        parsed[i] = url.unescape(parsed[i])
    end
    if sub(path, 1, 1) == "/" then
        parsed.is_absolute = 1
    end
    if sub(path, -1, -1) == "/" then
        parsed.is_directory = 1
    end
    return parsed
end

function url.build_path(parsed, unsafe)
    local path = ""
    local n = #parsed
    if unsafe then
        for i = 1, n-1 do
            path = path .. parsed[i] .. "/"
        end
        if n > 0 then
            path = path .. parsed[n]
            if parsed.is_directory then
                path = path .. "/"
            end
        end
    else
        for i = 1, n-1 do
            path = path .. protect_segment(parsed[i]) .. "/"
        end
        if n > 0 then
            path = path .. protect_segment(parsed[n])
            if parsed.is_directory then
                path = path .. "/"
            end
        end
    end
    if parsed.is_absolute then
        path = "/" .. path
    end
    return path
end

package.loaded["socket.url"] = url

return url
