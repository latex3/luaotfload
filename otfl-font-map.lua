if not modules then modules = { } end modules ['font-map'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local match, format, find, concat = string.match, string.format, string.find, table.concat

local trace_loading = false  trackers.register("otf.loading", function(v) trace_loading = v end)

local ctxcatcodes = tex and tex.ctxcatcodes

--[[ldx--
<p>Eventually this code will disappear because map files are kind
of obsolete. Some code may move to runtime or auxiliary modules.</p>
<p>The name to unciode related code will stay of course.</p>
--ldx]]--

fonts               = fonts               or { }
fonts.map           = fonts.map           or { }
fonts.map.data      = fonts.map.data      or { }
fonts.map.encodings = fonts.map.encodings or { }
fonts.map.done      = fonts.map.done      or { }
fonts.map.loaded    = fonts.map.loaded    or { }
fonts.map.direct    = fonts.map.direct    or { }
fonts.map.line      = fonts.map.line      or { }

function fonts.map.line.pdfmapline(tag,str)
    return "\\loadmapline[" .. tag .. "][" .. str .. "]"
end

function fonts.map.line.pdftex(e) -- so far no combination of slant and extend
    if e.name and e.fontfile then
        local fullname = e.fullname or ""
        if e.slant and e.slant ~= 0 then
            if e.encoding then
                return fonts.map.line.pdfmapline("=",format('%s %s "%g SlantFont" <%s <%s',e.name,fullname,e.slant,e.encoding,e.fontfile))
            else
                return fonts.map.line.pdfmapline("=",format('%s %s "%g SlantFont" <%s',e.name,fullname,e.slant,e.fontfile))
            end
        elseif e.extend and e.extend ~= 1 and e.extend ~= 0 then
            if e.encoding then
                return fonts.map.line.pdfmapline("=",format('%s %s "%g ExtendFont" <%s <%s',e.name,fullname,e.extend,e.encoding,e.fontfile))
            else
                return fonts.map.line.pdfmapline("=",format('%s %s "%g ExtendFont" <%s',e.name,fullname,e.extend,e.fontfile))
            end
        else
            if e.encoding then
                return fonts.map.line.pdfmapline("=",format('%s %s <%s <%s',e.name,fullname,e.encoding,e.fontfile))
            else
                return fonts.map.line.pdfmapline("=",format('%s %s <%s',e.name,fullname,e.fontfile))
            end
        end
    else
        return nil
    end
end

function fonts.map.flush(backend) -- will also erase the accumulated data
    local flushline = fonts.map.line[backend or "pdftex"] or fonts.map.line.pdftex
    for _, e in pairs(fonts.map.data) do
        tex.sprint(ctxcatcodes,flushline(e))
    end
    fonts.map.data = { }
end

fonts.map.line.dvips     = fonts.map.line.pdftex
fonts.map.line.dvipdfmx  = function() end

function fonts.map.convert_entries(filename)
    if not fonts.map.loaded[filename] then
        fonts.map.data, fonts.map.encodings = fonts.map.load_file(filename,fonts.map.data, fonts.map.encodings)
        fonts.map.loaded[filename] = true
    end
end

function fonts.map.load_file(filename, entries, encodings)
    entries   = entries   or { }
    encodings = encodings or { }
    local f = io.open(filename)
    if f then
        local data = f:read("*a")
        if data then
            for line in gmatch(data,"(.-)[\n\t]") do
                if find(line,"^[%#%%%s]") then
                    -- print(line)
                else
                    local extend, slant, name, fullname, fontfile, encoding
                    line = line:gsub('"(.+)"', function(s)
                        extend = find(s,'"([^"]+) ExtendFont"')
                        slant = find(s,'"([^"]+) SlantFont"')
                        return ""
                    end)
                    if not name then
                        -- name fullname encoding fontfile
                        name, fullname, encoding, fontfile = match(line,"^(%S+)%s+(%S*)[%s<]+(%S*)[%s<]+(%S*)%s*$")
                    end
                    if not name then
                        -- name fullname (flag) fontfile encoding
                        name, fullname, fontfile, encoding = match(line,"^(%S+)%s+(%S*)[%d%s<]+(%S*)[%s<]+(%S*)%s*$")
                    end
                    if not name then
                        -- name fontfile
                        name, fontfile = match(line,"^(%S+)%s+[%d%s<]+(%S*)%s*$")
                    end
                    if name then
                        if encoding == "" then encoding = nil end
                        entries[name] = {
                            name     = name, -- handy
                            fullname = fullname,
                            encoding = encoding,
                            fontfile = fontfile,
                            slant    = tonumber(slant),
                            extend   = tonumber(extend)
                        }
                        encodings[name] = encoding
                    elseif line ~= "" then
                    --  print(line)
                    end
                end
            end
        end
        f:close()
    end
    return entries, encodings
end

function fonts.map.load_lum_table(filename)
    local lumname = file.replacesuffix(file.basename(filename),"lum")
    local lumfile = resolvers.find_file(lumname,"map") or ""
    if lumfile ~= "" and lfs.isfile(lumfile) then
        if trace_loading or trace_unimapping then
            logs.report("load otf","enhance: loading %s ",lumfile)
        end
        lumunic = dofile(lumfile)
        return lumunic, lumfile
    end
end

local hex     = lpeg.R("AF","09")
local hexfour = (hex*hex*hex*hex) / function(s) return tonumber(s,16) end
local hexsix  = (hex^1)           / function(s) return tonumber(s,16) end
local dec     = (lpeg.R("09")^1)  / tonumber
local period  = lpeg.P(".")

local unicode = lpeg.P("uni")   * (hexfour * (period + lpeg.P(-1)) * lpeg.Cc(false) + lpeg.Ct(hexfour^1) * lpeg.Cc(true))
local ucode   = lpeg.P("u")     * (hexsix  * (period + lpeg.P(-1)) * lpeg.Cc(false) + lpeg.Ct(hexsix ^1) * lpeg.Cc(true))
local index   = lpeg.P("index") * dec * lpeg.Cc(false)

local parser  = unicode + ucode + index

local parsers = { }

function fonts.map.make_name_parser(str)
    if not str or str == "" then
        return parser
    else
        local p = parsers[str]
        if not p then
            p = lpeg.P(str) * period * dec * lpeg.Cc(false)
            parsers[str] = p
        end
        return p
    end
end

--~ local parser = fonts.map.make_name_parser("Japan1")
--~ local parser = fonts.map.make_name_parser()
--~ local function test(str)
--~     local b, a = parser:match(str)
--~     print((a and table.serialize(b)) or b)
--~ end
--~ test("a.sc")
--~ test("a")
--~ test("uni1234")
--~ test("uni1234.xx")
--~ test("uni12349876")
--~ test("index1234")
--~ test("Japan1.123")

function fonts.map.tounicode16(unicode)
    if unicode < 0x10000 then
        return format("%04X",unicode)
    else
        return format("%04X%04X",unicode/1024+0xD800,unicode%1024+0xDC00)
    end
end

function fonts.map.tounicode16sequence(unicodes)
    local t = { }
    for l=1,#unicodes do
        local unicode = unicodes[l]
        if unicode < 0x10000 then
            t[l] = format("%04X",unicode)
        else
            t[l] = format("%04X%04X",unicode/1024+0xD800,unicode%1024+0xDC00)
        end
    end
    return concat(t)
end

--~ This is quite a bit faster but at the cost of some memory but if we
--~ do this we will also use it elsewhere so let's not follow this route
--~ now. I might use this method in the plain variant (no caching there)
--~ but then I need a flag that distinguishes between code branches.
--~
--~ local cache = { }
--~
--~ function fonts.map.tounicode16(unicode)
--~     local s = cache[unicode]
--~     if not s then
--~         if unicode < 0x10000 then
--~             s = format("%04X",unicode)
--~         else
--~             s = format("%04X%04X",unicode/1024+0xD800,unicode%1024+0xDC00)
--~         end
--~         cache[unicode] = s
--~     end
--~     return s
--~ end

