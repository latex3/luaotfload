if not modules then modules = { } end modules ['font-onr'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Some code may look a bit obscure but this has to do with the fact that we also use
this code for testing and much code evolved in the transition from <l n='tfm'/> to
<l n='afm'/> to <l n='otf'/>.</p>

<p>The following code still has traces of intermediate font support where we handles
font encodings. Eventually font encoding went away but we kept some code around in
other modules.</p>

<p>This version implements a node mode approach so that users can also more easily
add features.</p>
--ldx]]--

local fonts, logs, trackers, resolvers = fonts, logs, trackers, resolvers

local next, type, tonumber, rawget, rawset = next, type, tonumber, rawget, rawset
local match, lower, gsub, strip, find = string.match, string.lower, string.gsub, string.strip, string.find
local char, byte, sub = string.char, string.byte, string.sub
local abs = math.abs
local bxor, rshift = bit32.bxor, bit32.rshift
local P, S, R, Cmt, C, Ct, Cs, Carg, Cf, Cg = lpeg.P, lpeg.S, lpeg.R, lpeg.Cmt, lpeg.C, lpeg.Ct, lpeg.Cs, lpeg.Carg, lpeg.Cf, lpeg.Cg
local lpegmatch, patterns = lpeg.match, lpeg.patterns

local trace_indexing     = false  trackers.register("afm.indexing",   function(v) trace_indexing = v end)
local trace_loading      = false  trackers.register("afm.loading",    function(v) trace_loading  = v end)

local report_afm         = logs.reporter("fonts","afm loading")
local report_pfb         = logs.reporter("fonts","pfb loading")

local handlers           = fonts.handlers
local afm                = handlers.afm or { }
handlers.afm             = afm
local readers            = afm.readers or { }
afm.readers              = readers

afm.version              = 1.512 -- incrementing this number one up will force a re-cache

--[[ldx--
<p>We start with the basic reader which we give a name similar to the built in <l n='tfm'/>
and <l n='otf'/> reader.</p>
<p>We use a new (unfinished) pfb loader but I see no differences between the old
and new vectors (we actually had one bad vector with the old loader).</p>
--ldx]]--

local get_indexes

do

    local n, m

    local progress = function(str,position,name,size)
        local forward = position + tonumber(size) + 3 + 2
        n = n + 1
        if n >= m then
            return #str, name
        elseif forward < #str then
            return forward, name
        else
            return #str, name
        end
    end

    local initialize = function(str,position,size)
        n = 0
        m = size -- % tonumber(size)
        return position + 1
    end

    local charstrings   = P("/CharStrings")
    local encoding      = P("/Encoding")
    local dup           = P("dup")
    local put           = P("put")
    local array         = P("array")
    local name          = P("/") * C((R("az")+R("AZ")+R("09")+S("-_."))^1)
    local digits        = R("09")^1
    local cardinal      = digits / tonumber
    local spaces        = P(" ")^1
    local spacing       = patterns.whitespace^0

    local p_filternames = Ct (
        (1-charstrings)^0 * charstrings * spaces * Cmt(cardinal,initialize)
      * (Cmt(name * spaces * cardinal, progress) + P(1))^1
    )

    -- /Encoding 256 array
    -- 0 1 255 {1 index exch /.notdef put} for
    -- dup 0 /Foo put

    local p_filterencoding =
        (1-encoding)^0 * encoding * spaces * digits * spaces * array * (1-dup)^0
      * Cf(
            Ct("") * Cg(spacing * dup * spaces * cardinal * spaces * name * spaces * put)^1
        ,rawset)

    -- if one of first 4 not 0-9A-F then binary else hex

    local decrypt

    do

        local r, c1, c2, n = 0, 0, 0, 0

        local function step(c)
            local cipher = byte(c)
            local plain  = bxor(cipher,rshift(r,8))
            r = ((cipher + r) * c1 + c2) % 65536
            return char(plain)
        end

        decrypt = function(binary)
            r, c1, c2, n = 55665, 52845, 22719, 4
            binary       = gsub(binary,".",step)
            return sub(binary,n+1)
        end

     -- local pattern = Cs((P(1) / step)^1)
     --
     -- decrypt = function(binary)
     --     r, c1, c2, n = 55665, 52845, 22719, 4
     --     binary = lpegmatch(pattern,binary)
     --     return sub(binary,n+1)
     -- end

    end

    local function loadpfbvector(filename)
        -- for the moment limited to encoding only

        local data = io.loaddata(resolvers.findfile(filename))

        if not data then
            report_pfb("no data in %a",filename)
            return
        end

        if not (find(data,"!PS%-AdobeFont%-") or find(data,"%%!FontType1")) then
            report_pfb("no font in %a",filename)
            return
        end

        local ascii, binary = match(data,"(.*)eexec%s+......(.*)")

        if not binary then
            report_pfb("no binary data in %a",filename)
            return
        end

        binary = decrypt(binary,4)

        local vector = lpegmatch(p_filternames,binary)

--         if vector[1] == ".notdef" then
--             -- tricky
--             vector[0] = table.remove(vector,1)
--         end

        for i=1,#vector do
            vector[i-1] = vector[i]
        end
        vector[#vector] = nil

        if not vector then
            report_pfb("no vector in %a",filename)
            return
        end

        local encoding = lpegmatch(p_filterencoding,ascii)

        return vector, encoding

    end

    local pfb      = handlers.pfb or { }
    handlers.pfb   = pfb
    pfb.loadvector = loadpfbvector

    get_indexes = function(data,pfbname)
        local vector = loadpfbvector(pfbname)
        if vector then
            local characters = data.characters
            if trace_loading then
                report_afm("getting index data from %a",pfbname)
            end
            for index=1,#vector do
                local name = vector[index]
                local char = characters[name]
                if char then
                    if trace_indexing then
                        report_afm("glyph %a has index %a",name,index)
                    end
                    char.index = index
                end
            end
        end
    end

end

--[[ldx--
<p>We start with the basic reader which we give a name similar to the built in <l n='tfm'/>
and <l n='otf'/> reader. We only need data that is relevant for our use. We don't support
more complex arrangements like multiple master (obsolete), direction specific kerning, etc.</p>
--ldx]]--

local spacer     = patterns.spacer
local whitespace = patterns.whitespace
local lineend    = patterns.newline
local spacing    = spacer^0
local number     = spacing * S("+-")^-1 * (R("09") + S("."))^1 / tonumber
local name       = spacing * C((1 - whitespace)^1)
local words      = spacing * ((1 - lineend)^1 / strip)
local rest       = (1 - lineend)^0
local fontdata   = Carg(1)
local semicolon  = spacing * P(";")
local plus       = spacing * P("plus") * number
local minus      = spacing * P("minus") * number

-- kern pairs

local function addkernpair(data,one,two,value)
    local chr = data.characters[one]
    if chr then
        local kerns = chr.kerns
        if kerns then
            kerns[two] = tonumber(value)
        else
            chr.kerns = { [two] = tonumber(value) }
        end
    end
end

local p_kernpair = (fontdata * P("KPX") * name * name * number) / addkernpair

-- char metrics

local chr = false
local ind = 0

local function start(data,version)
    data.metadata.afmversion = version
    ind = 0
    chr = { }
end

local function stop()
    ind = 0
    chr = false
end

local function setindex(i)
    if i < 0 then
        ind = ind + 1 -- ?
    else
        ind = i
    end
    chr = {
        index = ind
    }
end

local function setwidth(width)
    chr.width = width
end

local function setname(data,name)
    data.characters[name] = chr
end

local function setboundingbox(boundingbox)
    chr.boundingbox = boundingbox
end

local function setligature(plus,becomes)
    local ligatures = chr.ligatures
    if ligatures then
        ligatures[plus] = becomes
    else
        chr.ligatures = { [plus] = becomes }
    end
end

local p_charmetric = ( (
    P("C")  * number          / setindex
  + P("WX") * number          / setwidth
  + P("N")  * fontdata * name / setname
  + P("B")  * Ct((number)^4)  / setboundingbox
  + P("L")  * (name)^2        / setligature
  ) * semicolon )^1

local p_charmetrics = P("StartCharMetrics") * number * (p_charmetric + (1-P("EndCharMetrics")))^0 * P("EndCharMetrics")
local p_kernpairs   = P("StartKernPairs")   * number * (p_kernpair   + (1-P("EndKernPairs"  )))^0 * P("EndKernPairs"  )

local function set_1(data,key,a)     data.metadata[lower(key)] = a           end
local function set_2(data,key,a,b)   data.metadata[lower(key)] = { a, b }    end
local function set_3(data,key,a,b,c) data.metadata[lower(key)] = { a, b, c } end

-- Notice         string
-- EncodingScheme string
-- MappingScheme  integer
-- EscChar        integer
-- CharacterSet   string
-- Characters     integer
-- IsBaseFont     boolean
-- VVector        number number
-- IsFixedV       boolean

local p_parameters = P(false)
  + fontdata
  * ((P("FontName") + P("FullName") + P("FamilyName"))/lower)
  * words / function(data,key,value)
        data.metadata[key] = value
    end
  + fontdata
  * ((P("Weight") + P("Version"))/lower)
  * name / function(data,key,value)
        data.metadata[key] = value
    end
  + fontdata
  * P("IsFixedPitch")
  * name / function(data,pitch)
        data.metadata.monospaced = toboolean(pitch,true)
    end
  + fontdata
  * P("FontBBox")
  * Ct(number^4) / function(data,boundingbox)
        data.metadata.boundingbox = boundingbox
  end
  + fontdata
  * ((P("CharWidth") + P("CapHeight") + P("XHeight") + P("Descender") + P("Ascender") + P("ItalicAngle"))/lower)
  * number / function(data,key,value)
        data.metadata[key] = value
    end
  + P("Comment") * spacing * ( P(false)
      + (fontdata * C("DESIGNSIZE")     * number                   * rest) / set_1 -- 1
      + (fontdata * C("TFM designsize") * number                   * rest) / set_1
      + (fontdata * C("DesignSize")     * number                   * rest) / set_1
      + (fontdata * C("CODINGSCHEME")   * words                    * rest) / set_1 --
      + (fontdata * C("CHECKSUM")       * number * words           * rest) / set_1 -- 2
      + (fontdata * C("SPACE")          * number * plus * minus    * rest) / set_3 -- 3 4 5
      + (fontdata * C("QUAD")           * number                   * rest) / set_1 -- 6
      + (fontdata * C("EXTRASPACE")     * number                   * rest) / set_1 -- 7
      + (fontdata * C("NUM")            * number * number * number * rest) / set_3 -- 8 9 10
      + (fontdata * C("DENOM")          * number * number          * rest) / set_2 -- 11 12
      + (fontdata * C("SUP")            * number * number * number * rest) / set_3 -- 13 14 15
      + (fontdata * C("SUB")            * number * number          * rest) / set_2 -- 16 17
      + (fontdata * C("SUPDROP")        * number                   * rest) / set_1 -- 18
      + (fontdata * C("SUBDROP")        * number                   * rest) / set_1 -- 19
      + (fontdata * C("DELIM")          * number * number          * rest) / set_2 -- 20 21
      + (fontdata * C("AXISHEIGHT")     * number                   * rest) / set_1 -- 22
    )

local fullparser = ( P("StartFontMetrics") * fontdata * name / start )
                 * ( p_charmetrics + p_kernpairs + p_parameters + (1-P("EndFontMetrics")) )^0
                 * ( P("EndFontMetrics") / stop )

local fullparser = ( P("StartFontMetrics") * fontdata * name / start )
                 * ( p_charmetrics + p_kernpairs + p_parameters + (1-P("EndFontMetrics")) )^0
                 * ( P("EndFontMetrics") / stop )

local infoparser = ( P("StartFontMetrics") * fontdata * name / start )
                 * ( p_parameters + (1-P("EndFontMetrics")) )^0
                 * ( P("EndFontMetrics") / stop )

--    infoparser = ( P("StartFontMetrics") * fontdata * name / start )
--               * ( p_parameters + (1-P("EndFontMetrics") - P("StartCharMetrics")) )^0
--               * ( (P("EndFontMetrics") + P("StartCharMetrics")) / stop )

local function read(filename,parser)
    local afmblob = io.loaddata(filename)
    if afmblob then
        local data = {
            resources = {
                filename = resolvers.unresolve(filename),
                version  = afm.version,
                creator  = "context mkiv",
            },
            properties = {
                hasitalics = false,
            },
            goodies = {
            },
            metadata   = {
                filename = file.removesuffix(file.basename(filename))
            },
            characters = {
                -- a temporary store
            },
            descriptions = {
                -- the final store
            },
        }
        if trace_loading then
            report_afm("parsing afm file %a",filename)
        end
        lpegmatch(parser,afmblob,1,data)
        return data
    else
        if trace_loading then
            report_afm("no valid afm file %a",filename)
        end
        return nil
    end
end

function readers.loadfont(afmname,pfbname)
    local data = read(resolvers.findfile(afmname),fullparser)
    if data then
        if not pfbname or pfbname == "" then
            pfbname = file.replacesuffix(file.nameonly(afmname),"pfb")
            pfbname = resolvers.findfile(pfbname)
        end
        if pfbname and pfbname ~= "" then
            data.resources.filename = resolvers.unresolve(pfbname)
            get_indexes(data,pfbname)
        elseif trace_loading then
            report_afm("no pfb file for %a",afmname)
         -- data.resources.filename = "unset" -- better than loading the afm file
        end
        return data
    end
end

function readers.getinfo(filename)
    local data = read(resolvers.findfile(filename),infoparser)
    if data then
        return data.metadata
    end
end
