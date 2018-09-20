-- original file : mime.lua
-- for more into : see util-soc.lua

local type, tostring = type, tostring

local mime        = require("mime.core")
local ltn12       = ltn12 or require("ltn12")

local filtercycle = ltn12.filter.cycle

local function report(fmt,first,...)
    if logs then
        report = logs and logs.reporter("mime")
        report(fmt,first,...)
    elseif fmt then
        fmt = "mime: " .. fmt
        if first then
            print(format(fmt,first,...))
        else
            print(fmt)
        end
    end
end

mime.report = report

local encodet     = { }
local decodet     = { }
local wrapt       = { }

mime.encodet      = encodet
mime.decodet      = decodet
mime.wrapt        = wrapt

local mime_b64    = mime.b64
local mime_qp     = mime.qp
local mime_unb64  = mime.unb64
local mime_unqp   = mime.unqp
local mime_wrp    = mime.wrp
local mime_qpwrp  = mime.qpwrp
local mime_eol    = mime_eol
local mime_dot    = mime_dot

encodet['base64'] = function()
    return filtercycle(mime_b64,"")
end

encodet['quoted-printable'] = function(mode)
    return filtercycle(mime_qp, "", mode == "binary" and "=0D=0A" or "\r\n")
end

decodet['base64'] = function()
    return filtercycle(mime_unb64, "")
end

decodet['quoted-printable'] = function()
    return filtercycle(mime_unqp, "")
end

local wraptext = function(length)
    if not length then
        length = 76
    end
    return filtercycle(mime_wrp, length, length)
end

local wrapquoted = function()
    return filtercycle(mime_qpwrp, 76, 76)
end

wrapt['text']             = wraptext
wrapt['base64']           = wraptext
wrapt['default']          = wraptext
wrapt['quoted-printable'] = wrapquoted

function mime.normalize(marker)
    return filtercycle(mime_eol, 0, marker)
end

function mime.stuff()
    return filtercycle(mime_dot, 2)
end

local function choose(list)
    return function(name, opt1, opt2)
        if type(name) ~= "string" then
            name, opt1, opt2 = "default", name, opt1
        end
        local filter = list[name or "nil"]
        if filter then
            return filter(opt1, opt2)
        else
            report("error: unknown key '%s'",tostring(name))
        end
    end
end

mime.encode = choose(encodet)
mime.decode = choose(decodet)
mime.wrap   = choose(wrapt)

package.loaded["mime"] = mime

return mime
