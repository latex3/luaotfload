if not modules then modules = { } end modules ['util-soc'] = {
    version   = 1.001,
    comment   = "support for sockets / protocols",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[--

In LuaTeX we provide the socket library that is more or less the standard one for
Lua. It has been around for a while and seems to be pretty stable. The binary
module is copmpiled into LuaTeX and the accompanying .lua files are preloaded.
These files are mostly written by Diego Nehab, Andre Carregal, Javier Guerra, and
Fabio Mascarenhas with contributions from Diego Nehab, Mike Pall, David Burgess,
Leonardo Godinho, Thomas Harning Jr., and Gary NG. The originals are part of and
copyrighted by the Kepler project.

Here we reload a slightly reworked version of these .lua files. We keep the same
(documented) interface but streamlined some fo the code. No more modules, no more
pre 5.2 Lua, etc. Also, as it loads into the ConTeXt ecosystem, we plug in some
logging. (and maybe tracing in the future). As we don't support serial ports in
LuaTeX, related code has been dropped.

The files are reformatted so that we can more easilly add additional features
and/or tracing options. Any error introduced there is our fault! The url module
might be replaced by the one in ConTeXt. When we need mbox a suitable variant
will be provided.

--]]--

local format = string.format

local smtp  = require("socket.smtp")
local ltn12 = require("ltn12")
local mime  = require("mime")

local mail     = utilities.mail or { }
utilities.mail = mail

local report_mail = logs.reporter("mail")

function mail.send(specification)
    local presets = specification.presets
    if presets then
        table.setmetatableindex(specification,presets)
    end
    local server = specification.server or ""
    if not server then
        report_mail("no server specified")
        return false, "invalid server"
    end
    local to = specification.to or specification.recepient or ""
    if to == "" then
        report_mail("no recipient specified")
        return false, "invalid recipient"
    end
    local from = specification.from or specification.sender or ""
    if from == "" then
        report_mail("no sender specified")
        return false, "invalid sender"
    end
    local message = { }
    local body = specification.body
    if body then
        message[#message+1] = {
            body = body
        }
    end
    local files = specification.files
    if files then
        for i=1,#files do
            local filename = files[i]
            local handle = io.open(filename, "rb")
            if handle then
                report_mail("attaching file %a",filename)
                message[#message+1] = {
                    headers = {
                        ["content-type"]              = format('application/pdf; name="%s"',filename),
                        ["content-disposition"]       = format('attachment; filename="%s"',filename),
                        ["content-description"]       = format('file: %s',filename),
                        ["content-transfer-encoding"] = "BASE64"
                    },
                    body = ltn12.source.chain(
                        ltn12.source.file(handle),
                        ltn12.filter.chain(mime.encode("base64"),mime.wrap())
                    )
                }
            else
                report_mail("file %a not found",filename)
            end
        end
    end
    local user     = specification.user
    local password = specification.password
    local result, detail = smtp.send {
        server   = specification.server,
        port     = specification.port,
        user     = user ~= "" and user or nil,
        password = password ~= "" and password or nil,
        from     = from,
        rcpt     = to,
        source   = smtp.message {
            headers = {
                to      = to,
                from    = from,
                cc      = specification.cc,
                subject = specification.subject or "no subject",
            },
            body = message
        },
    }
    if detail then
        report_mail("error: %s",detail)
        return false, detail
    else
        report_mail("message sent")
        return true
    end
end

-- for now we have this here:

if socket then

    math.initialseed = tonumber(string.sub(string.reverse(tostring(math.ceil(socket.gettime()*10000))),1,6))
    math.randomseed(math.initialseed)

end
