-- original file : headers.lua
-- for more into : see util-soc.lua

local next = next
local lower = string.lower
local concat = table.concat

local socket   = socket or require("socket")

local headers  = { }
socket.headers = headers

local canonic = {
    ["accept"]                    = "Accept",
    ["accept-charset"]            = "Accept-Charset",
    ["accept-encoding"]           = "Accept-Encoding",
    ["accept-language"]           = "Accept-Language",
    ["accept-ranges"]             = "Accept-Ranges",
    ["action"]                    = "Action",
    ["alternate-recipient"]       = "Alternate-Recipient",
    ["age"]                       = "Age",
    ["allow"]                     = "Allow",
    ["arrival-date"]              = "Arrival-Date",
    ["authorization"]             = "Authorization",
    ["bcc"]                       = "Bcc",
    ["cache-control"]             = "Cache-Control",
    ["cc"]                        = "Cc",
    ["comments"]                  = "Comments",
    ["connection"]                = "Connection",
    ["content-description"]       = "Content-Description",
    ["content-disposition"]       = "Content-Disposition",
    ["content-encoding"]          = "Content-Encoding",
    ["content-id"]                = "Content-ID",
    ["content-language"]          = "Content-Language",
    ["content-length"]            = "Content-Length",
    ["content-location"]          = "Content-Location",
    ["content-md5"]               = "Content-MD5",
    ["content-range"]             = "Content-Range",
    ["content-transfer-encoding"] = "Content-Transfer-Encoding",
    ["content-type"]              = "Content-Type",
    ["cookie"]                    = "Cookie",
    ["date"]                      = "Date",
    ["diagnostic-code"]           = "Diagnostic-Code",
    ["dsn-gateway"]               = "DSN-Gateway",
    ["etag"]                      = "ETag",
    ["expect"]                    = "Expect",
    ["expires"]                   = "Expires",
    ["final-log-id"]              = "Final-Log-ID",
    ["final-recipient"]           = "Final-Recipient",
    ["from"]                      = "From",
    ["host"]                      = "Host",
    ["if-match"]                  = "If-Match",
    ["if-modified-since"]         = "If-Modified-Since",
    ["if-none-match"]             = "If-None-Match",
    ["if-range"]                  = "If-Range",
    ["if-unmodified-since"]       = "If-Unmodified-Since",
    ["in-reply-to"]               = "In-Reply-To",
    ["keywords"]                  = "Keywords",
    ["last-attempt-date"]         = "Last-Attempt-Date",
    ["last-modified"]             = "Last-Modified",
    ["location"]                  = "Location",
    ["max-forwards"]              = "Max-Forwards",
    ["message-id"]                = "Message-ID",
    ["mime-version"]              = "MIME-Version",
    ["original-envelope-id"]      = "Original-Envelope-ID",
    ["original-recipient"]        = "Original-Recipient",
    ["pragma"]                    = "Pragma",
    ["proxy-authenticate"]        = "Proxy-Authenticate",
    ["proxy-authorization"]       = "Proxy-Authorization",
    ["range"]                     = "Range",
    ["received"]                  = "Received",
    ["received-from-mta"]         = "Received-From-MTA",
    ["references"]                = "References",
    ["referer"]                   = "Referer",
    ["remote-mta"]                = "Remote-MTA",
    ["reply-to"]                  = "Reply-To",
    ["reporting-mta"]             = "Reporting-MTA",
    ["resent-bcc"]                = "Resent-Bcc",
    ["resent-cc"]                 = "Resent-Cc",
    ["resent-date"]               = "Resent-Date",
    ["resent-from"]               = "Resent-From",
    ["resent-message-id"]         = "Resent-Message-ID",
    ["resent-reply-to"]           = "Resent-Reply-To",
    ["resent-sender"]             = "Resent-Sender",
    ["resent-to"]                 = "Resent-To",
    ["retry-after"]               = "Retry-After",
    ["return-path"]               = "Return-Path",
    ["sender"]                    = "Sender",
    ["server"]                    = "Server",
    ["smtp-remote-recipient"]     = "SMTP-Remote-Recipient",
    ["status"]                    = "Status",
    ["subject"]                   = "Subject",
    ["te"]                        = "TE",
    ["to"]                        = "To",
    ["trailer"]                   = "Trailer",
    ["transfer-encoding"]         = "Transfer-Encoding",
    ["upgrade"]                   = "Upgrade",
    ["user-agent"]                = "User-Agent",
    ["vary"]                      = "Vary",
    ["via"]                       = "Via",
    ["warning"]                   = "Warning",
    ["will-retry-until"]          = "Will-Retry-Until",
    ["www-authenticate"]          = "WWW-Authenticate",
    ["x-mailer"]                  = "X-Mailer",
}

headers.canonic = setmetatable(canonic, {
    __index = function(t,k)
        socket.report("invalid header: %s",k)
        t[k] = k
        return k
    end
})

function headers.normalize(headers)
    if not headers then
        return { }
    end
    local normalized = { }
    for k, v in next, headers do
        normalized[#normalized+1] = canonic[k] .. ": " .. v
    end
    normalized[#normalized+1] = ""
    normalized[#normalized+1] = ""
    return concat(normalized,"\r\n")
end

function headers.lower(lowered,headers)
    if not lowered then
        return { }
    end
    if not headers then
        lowered, headers = { }, lowered
    end
    for k, v in next, headers do
        lowered[lower(k)] = v
    end
    return lowered
end

socket.headers = headers

package.loaded["socket.headers"] = headers

return headers
