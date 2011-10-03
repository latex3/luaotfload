if not modules then modules = { } end modules ['font-map'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local match, format, find, concat, gsub, lower = string.match, string.format, string.find, table.concat, string.gsub, string.lower
local P, R, S, C, Ct, Cc, lpegmatch = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cc, lpeg.match
local utfbyte = utf.byte

local trace_loading = false  trackers.register("fonts.loading",    function(v) trace_loading    = v end)
local trace_mapping = false  trackers.register("fonts.mapping", function(v) trace_unimapping = v end)

local report_fonts  = logs.reporter("fonts","loading") -- not otf only

local fonts    = fonts
local mappings = { }
fonts.mappings = mappings

--[[ldx--
<p>Eventually this code will disappear because map files are kind
of obsolete. Some code may move to runtime or auxiliary modules.</p>
<p>The name to unciode related code will stay of course.</p>
--ldx]]--

local function loadlumtable(filename) -- will move to font goodies
    local lumname = file.replacesuffix(file.basename(filename),"lum")
    local lumfile = resolvers.findfile(lumname,"map") or ""
    if lumfile ~= "" and lfs.isfile(lumfile) then
        if trace_loading or trace_mapping then
            report_fonts("enhance: loading %s ",lumfile)
        end
        lumunic = dofile(lumfile)
        return lumunic, lumfile
    end
end

local hex     = R("AF","09")
local hexfour = (hex*hex*hex*hex) / function(s) return tonumber(s,16) end
local hexsix  = (hex^1)           / function(s) return tonumber(s,16) end
local dec     = (R("09")^1)  / tonumber
local period  = P(".")
local unicode = P("uni")   * (hexfour * (period + P(-1)) * Cc(false) + Ct(hexfour^1) * Cc(true))
local ucode   = P("u")     * (hexsix  * (period + P(-1)) * Cc(false) + Ct(hexsix ^1) * Cc(true))
local index   = P("index") * dec * Cc(false)

local parser  = unicode + ucode + index

local parsers = { }

local function makenameparser(str)
    if not str or str == "" then
        return parser
    else
        local p = parsers[str]
        if not p then
            p = P(str) * period * dec * Cc(false)
            parsers[str] = p
        end
        return p
    end
end

--~ local parser = mappings.makenameparser("Japan1")
--~ local parser = mappings.makenameparser()
--~ local function test(str)
--~     local b, a = lpegmatch(parser,str)
--~     print((a and table.serialize(b)) or b)
--~ end
--~ test("a.sc")
--~ test("a")
--~ test("uni1234")
--~ test("uni1234.xx")
--~ test("uni12349876")
--~ test("index1234")
--~ test("Japan1.123")

local function tounicode16(unicode)
    if unicode < 0x10000 then
        return format("%04X",unicode)
    else
        return format("%04X%04X",unicode/1024+0xD800,unicode%1024+0xDC00)
    end
end

local function tounicode16sequence(unicodes)
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

local function fromunicode16(str)
    if #str == 4 then
        return tonumber(str,16)
    else
        local l, r = match(str,"(....)(....)")
        return (tonumber(l,16)- 0xD800)*0x400  + tonumber(r,16) - 0xDC00
    end
end

--~ This is quite a bit faster but at the cost of some memory but if we
--~ do this we will also use it elsewhere so let's not follow this route
--~ now. I might use this method in the plain variant (no caching there)
--~ but then I need a flag that distinguishes between code branches.
--~
--~ local cache = { }
--~
--~ function mappings.tounicode16(unicode)
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

mappings.loadlumtable        = loadlumtable
mappings.makenameparser      = makenameparser
mappings.tounicode16         = tounicode16
mappings.tounicode16sequence = tounicode16sequence
mappings.fromunicode16       = fromunicode16

local separator   = S("_.")
local other       = C((1 - separator)^1)
local ligsplitter = Ct(other * (separator * other)^0)

--~ print(table.serialize(lpegmatch(ligsplitter,"this")))
--~ print(table.serialize(lpegmatch(ligsplitter,"this.that")))
--~ print(table.serialize(lpegmatch(ligsplitter,"japan1.123")))
--~ print(table.serialize(lpegmatch(ligsplitter,"such_so_more")))
--~ print(table.serialize(lpegmatch(ligsplitter,"such_so_more.that")))

function mappings.addtounicode(data,filename)
    local resources    = data.resources
    local properties   = data.properties
    local descriptions = data.descriptions
    local unicodes     = resources.unicodes
    if not unicodes then
        return
    end
    -- we need to move this code
    unicodes['space']  = unicodes['space']  or 32
    unicodes['hyphen'] = unicodes['hyphen'] or 45
    unicodes['zwj']    = unicodes['zwj']    or 0x200D
    unicodes['zwnj']   = unicodes['zwnj']   or 0x200C
    -- the tounicode mapping is sparse and only needed for alternatives
    local private       = fonts.constructors.privateoffset
    local unknown       = format("%04X",utfbyte("?"))
    local unicodevector = fonts.encodings.agl.unicodes -- loaded runtime in context
    local tounicode     = { }
    local originals     = { }
    resources.tounicode = tounicode
    resources.originals = originals
    local lumunic, uparser, oparser
    local cidinfo, cidnames, cidcodes, usedmap
    if false then -- will become an option
        lumunic = loadlumtable(filename)
        lumunic = lumunic and lumunic.tounicode
    end
    --
    cidinfo = properties.cidinfo
    usedmap = cidinfo and fonts.cid.getmap(cidinfo)
    --
    if usedmap then
        oparser  = usedmap and makenameparser(cidinfo.ordering)
        cidnames = usedmap.names
        cidcodes = usedmap.unicodes
    end
    uparser = makenameparser()
    local ns, nl = 0, 0
    for unic, glyph in next, descriptions do
        local index = glyph.index
        local name  = glyph.name
        if unic == -1 or unic >= private or (unic >= 0xE000 and unic <= 0xF8FF) or unic == 0xFFFE or unic == 0xFFFF then
            local unicode = lumunic and lumunic[name] or unicodevector[name]
            if unicode then
                originals[index] = unicode
                tounicode[index] = tounicode16(unicode)
                ns               = ns + 1
            end
            -- cidmap heuristics, beware, there is no guarantee for a match unless
            -- the chain resolves
            if (not unicode) and usedmap then
                local foundindex = lpegmatch(oparser,name)
                if foundindex then
                    unicode = cidcodes[foundindex] -- name to number
                    if unicode then
                        originals[index] = unicode
                        tounicode[index] = tounicode16(unicode)
                        ns               = ns + 1
                    else
                        local reference = cidnames[foundindex] -- number to name
                        if reference then
                            local foundindex = lpegmatch(oparser,reference)
                            if foundindex then
                                unicode = cidcodes[foundindex]
                                if unicode then
                                    originals[index] = unicode
                                    tounicode[index] = tounicode16(unicode)
                                    ns               = ns + 1
                                end
                            end
                            if not unicode then
                                local foundcodes, multiple = lpegmatch(uparser,reference)
                                if foundcodes then
                                    originals[index] = foundcodes
                                    if multiple then
                                        tounicode[index] = tounicode16sequence(foundcodes)
                                        nl               = nl + 1
                                        unicode          = true
                                    else
                                        tounicode[index] = tounicode16(foundcodes)
                                        ns               = ns + 1
                                        unicode          = foundcodes
                                    end
                                end
                            end
                        end
                    end
                end
            end
            -- a.whatever or a_b_c.whatever or a_b_c (no numbers)
            if not unicode then
                local split = lpegmatch(ligsplitter,name)
                local nplit = split and #split or 0
                if nplit >= 2 then
                    local t, n = { }, 0
                    for l=1,nplit do
                        local base = split[l]
                        local u = unicodes[base] or unicodevector[base]
                        if not u then
                            break
                        elseif type(u) == "table" then
                            n = n + 1
                            t[n] = u[1]
                        else
                            n = n + 1
                            t[n] = u
                        end
                    end
                    if n == 0 then -- done then
                        -- nothing
                    elseif n == 1 then
                        originals[index] = t[1]
                        tounicode[index] = tounicode16(t[1])
                    else
                        originals[index] = t
                        tounicode[index] = tounicode16sequence(t)
                    end
                    nl = nl + 1
                    unicode = true
                else
                    -- skip: already checked and we don't want privates here
                end
            end
            -- last resort (we might need to catch private here as well)
            if not unicode then
                local foundcodes, multiple = lpegmatch(uparser,name)
                if foundcodes then
                    if multiple then
                        originals[index] = foundcodes
                        tounicode[index] = tounicode16sequence(foundcodes)
                        nl               = nl + 1
                        unicode          = true
                    else
                        originals[index] = foundcodes
                        tounicode[index] = tounicode16(foundcodes)
                        ns               = ns + 1
                        unicode          = foundcodes
                    end
                end
            end
         -- if not unicode then
         --     originals[index] = 0xFFFD
         --     tounicode[index] = "FFFD"
         -- end
        end
    end
    if trace_mapping then
        for unic, glyph in table.sortedhash(descriptions) do
            local name  = glyph.name
            local index = glyph.index
            local toun  = tounicode[index]
            if toun then
                report_fonts("internal: 0x%05X, name: %s, unicode: U+%05X, tounicode: %s",index,name,unic,toun)
            else
                report_fonts("internal: 0x%05X, name: %s, unicode: U+%05X",index,name,unic)
            end
        end
    end
    if trace_loading and (ns > 0 or nl > 0) then
        report_fonts("enhance: %s tounicode entries added (%s ligatures)",nl+ns, ns)
    end
end
