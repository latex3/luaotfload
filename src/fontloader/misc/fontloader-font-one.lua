if not modules then modules = { } end modules ['font-one'] = {
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

local fonts, logs, trackers, containers, resolvers = fonts, logs, trackers, containers, resolvers

local next, type, tonumber = next, type, tonumber
local match, gmatch, lower, gsub, strip, find = string.match, string.gmatch, string.lower, string.gsub, string.strip, string.find
local char, byte, sub = string.char, string.byte, string.sub
local abs = math.abs
local bxor, rshift = bit32.bxor, bit32.rshift
local P, S, R, Cmt, C, Ct, Cs, lpegmatch, patterns = lpeg.P, lpeg.S, lpeg.R, lpeg.Cmt, lpeg.C, lpeg.Ct, lpeg.Cs, lpeg.match, lpeg.patterns
local derivetable = table.derive

local trace_features     = false  trackers.register("afm.features",   function(v) trace_features = v end)
local trace_indexing     = false  trackers.register("afm.indexing",   function(v) trace_indexing = v end)
local trace_loading      = false  trackers.register("afm.loading",    function(v) trace_loading  = v end)
local trace_defining     = false  trackers.register("fonts.defining", function(v) trace_defining = v end)

local report_afm         = logs.reporter("fonts","afm loading")

local setmetatableindex  = table.setmetatableindex

local findbinfile        = resolvers.findbinfile

local definers           = fonts.definers
local readers            = fonts.readers
local constructors       = fonts.constructors

local afm                = constructors.newhandler("afm")
local pfb                = constructors.newhandler("pfb")
local otf                = fonts.handlers.otf

local otfreaders         = otf.readers
local otfenhancers       = otf.enhancers

local afmfeatures        = constructors.newfeatures("afm")
local registerafmfeature = afmfeatures.register

afm.version              = 1.505 -- incrementing this number one up will force a re-cache
afm.cache                = containers.define("fonts", "afm", afm.version, true)
afm.autoprefixed         = true -- this will become false some day (catches texnansi-blabla.*)

afm.helpdata             = { }  -- set later on so no local for this
afm.syncspace            = true -- when true, nicer stretch values

local overloads          = fonts.mappings.overloads

local applyruntimefixes  = fonts.treatments and fonts.treatments.applyfixes

--[[ldx--
<p>We start with the basic reader which we give a name similar to the
built in <l n='tfm'/> and <l n='otf'/> reader.</p>
--ldx]]--

--~ Comment FONTIDENTIFIER LMMATHSYMBOLS10
--~ Comment CODINGSCHEME TEX MATH SYMBOLS
--~ Comment DESIGNSIZE 10.0 pt
--~ Comment CHECKSUM O 4261307036
--~ Comment SPACE 0 plus 0 minus 0
--~ Comment QUAD 1000
--~ Comment EXTRASPACE 0
--~ Comment NUM 676.508 393.732 443.731
--~ Comment DENOM 685.951 344.841
--~ Comment SUP 412.892 362.892 288.889
--~ Comment SUB 150 247.217
--~ Comment SUPDROP 386.108
--~ Comment SUBDROP 50
--~ Comment DELIM 2390 1010
--~ Comment AXISHEIGHT 250

local comment = P("Comment")
local spacing = patterns.spacer  -- S(" \t")^1
local lineend = patterns.newline -- S("\n\r")
local words   = C((1 - lineend)^1)
local number  = C((R("09") + S("."))^1) / tonumber * spacing^0
local data    = lpeg.Carg(1)

local pattern = ( -- needs testing ... not used anyway as we no longer need math afm's
    comment * spacing *
        (
            data * (
                ("CODINGSCHEME" * spacing * words                                      ) / function(fd,a)                                      end +
                ("DESIGNSIZE"   * spacing * number * words                             ) / function(fd,a)     fd[ 1]                 = a       end +
                ("CHECKSUM"     * spacing * number * words                             ) / function(fd,a)     fd[ 2]                 = a       end +
                ("SPACE"        * spacing * number * "plus" * number * "minus" * number) / function(fd,a,b,c) fd[ 3], fd[ 4], fd[ 5] = a, b, c end +
                ("QUAD"         * spacing * number                                     ) / function(fd,a)     fd[ 6]                 = a       end +
                ("EXTRASPACE"   * spacing * number                                     ) / function(fd,a)     fd[ 7]                 = a       end +
                ("NUM"          * spacing * number * number * number                   ) / function(fd,a,b,c) fd[ 8], fd[ 9], fd[10] = a, b, c end +
                ("DENOM"        * spacing * number * number                            ) / function(fd,a,b  ) fd[11], fd[12]         = a, b    end +
                ("SUP"          * spacing * number * number * number                   ) / function(fd,a,b,c) fd[13], fd[14], fd[15] = a, b, c end +
                ("SUB"          * spacing * number * number                            ) / function(fd,a,b)   fd[16], fd[17]         = a, b    end +
                ("SUPDROP"      * spacing * number                                     ) / function(fd,a)     fd[18]                 = a       end +
                ("SUBDROP"      * spacing * number                                     ) / function(fd,a)     fd[19]                 = a       end +
                ("DELIM"        * spacing * number * number                            ) / function(fd,a,b)   fd[20], fd[21]         = a, b    end +
                ("AXISHEIGHT"   * spacing * number                                     ) / function(fd,a)     fd[22]                 = a       end
            )
          + (1-lineend)^0
        )
  + (1-comment)^1
)^0

local function scan_comment(str)
    local fd = { }
    lpegmatch(pattern,str,1,fd)
    return fd
end

-- On a rainy day I will rewrite this in lpeg ... or we can use the (slower) fontloader
-- as in now supports afm/pfb loading but it's not too bad to have different methods
-- for testing approaches.

local keys = { }

function keys.FontName    (data,line) data.metadata.fontname    = strip    (line) -- get rid of spaces
                                      data.metadata.fullname    = strip    (line) end
function keys.ItalicAngle (data,line) data.metadata.italicangle = tonumber (line) end
function keys.IsFixedPitch(data,line) data.metadata.monospaced  = toboolean(line,true) end
function keys.CharWidth   (data,line) data.metadata.charwidth   = tonumber (line) end
function keys.XHeight     (data,line) data.metadata.xheight     = tonumber (line) end
function keys.Descender   (data,line) data.metadata.descender   = tonumber (line) end
function keys.Ascender    (data,line) data.metadata.ascender    = tonumber (line) end
function keys.Comment     (data,line)
 -- Comment DesignSize 12 (pts)
 -- Comment TFM designsize: 12 (in points)
    line = lower(line)
    local designsize = match(line,"designsize[^%d]*(%d+)")
    if designsize then data.metadata.designsize = tonumber(designsize) end
end

local function get_charmetrics(data,charmetrics,vector)
    local characters = data.characters
    local chr, ind = { }, 0
    for k, v in gmatch(charmetrics,"([%a]+) +(.-) *;") do
        if k == 'C'  then
            v = tonumber(v)
            if v < 0 then
                ind = ind + 1 -- ?
            else
                ind = v
            end
            chr = {
                index = ind
            }
        elseif k == 'WX' then
            chr.width = tonumber(v)
        elseif k == 'N'  then
            characters[v] = chr
        elseif k == 'B'  then
            local llx, lly, urx, ury = match(v,"^ *(.-) +(.-) +(.-) +(.-)$")
            chr.boundingbox = { tonumber(llx), tonumber(lly), tonumber(urx), tonumber(ury) }
        elseif k == 'L'  then
            local plus, becomes = match(v,"^(.-) +(.-)$")
            local ligatures = chr.ligatures
            if ligatures then
                ligatures[plus] = becomes
            else
                chr.ligatures = { [plus] = becomes }
            end
        end
    end
end

local function get_kernpairs(data,kernpairs)
    local characters = data.characters
    for one, two, value in gmatch(kernpairs,"KPX +(.-) +(.-) +(.-)\n") do
        local chr = characters[one]
        if chr then
            local kerns = chr.kerns
            if kerns then
                kerns[two] = tonumber(value)
            else
                chr.kerns = { [two] = tonumber(value) }
            end
        end
    end
end

local function get_variables(data,fontmetrics)
    for key, rest in gmatch(fontmetrics,"(%a+) *(.-)[\n\r]") do
        local keyhandler = keys[key]
        if keyhandler then
            keyhandler(data,rest)
        end
    end
end

-- new (unfinished) pfb loader but i see no differences between
-- old and new (one bad vector with old)

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
        m = tonumber(size)
        return position + 1
    end

    local charstrings = P("/CharStrings")
    local name        = P("/") * C((R("az")+R("AZ")+R("09")+S("-_."))^1)
    local size        = C(R("09")^1)
    local spaces      = P(" ")^1

    local p_filternames = Ct (
        (1-charstrings)^0 * charstrings * spaces * Cmt(size,initialize)
      * (Cmt(name * P(" ")^1 * C(R("09")^1), progress) + P(1))^1
    )

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

        if not find(data,"!PS%-AdobeFont%-") then
            print("no font",filename)
            return
        end

        if not data then
            print("no data",filename)
            return
        end

        local ascii, binary = match(data,"(.*)eexec%s+......(.*)")

        if not binary then
            print("no binary",filename)
            return
        end

        binary = decrypt(binary,4)

        local vector = lpegmatch(p_filternames,binary)

        vector[0] = table.remove(vector,1)

        if not vector then
            print("no vector",filename)
            return
        end

        return vector

    end

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

local function readafm(filename)
    local ok, afmblob, size = resolvers.loadbinfile(filename) -- has logging
    if ok and afmblob then
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
        afmblob = gsub(afmblob,"StartCharMetrics(.-)EndCharMetrics", function(charmetrics)
            if trace_loading then
                report_afm("loading char metrics")
            end
            get_charmetrics(data,charmetrics,vector)
            return ""
        end)
        afmblob = gsub(afmblob,"StartKernPairs(.-)EndKernPairs", function(kernpairs)
            if trace_loading then
                report_afm("loading kern pairs")
            end
            get_kernpairs(data,kernpairs)
            return ""
        end)
        afmblob = gsub(afmblob,"StartFontMetrics%s+([%d%.]+)(.-)EndFontMetrics", function(version,fontmetrics)
            if trace_loading then
                report_afm("loading variables")
            end
            data.afmversion = version
            get_variables(data,fontmetrics)
            data.fontdimens = scan_comment(fontmetrics) -- todo: all lpeg, no time now
            return ""
        end)
        return data
    else
        if trace_loading then
            report_afm("no valid afm file %a",filename)
        end
        return nil
    end
end

--[[ldx--
<p>We cache files. Caching is taken care of in the loader. We cheat a bit by adding
ligatures and kern information to the afm derived data. That way we can set them faster
when defining a font.</p>

<p>We still keep the loading two phased: first we load the data in a traditional
fashion and later we transform it to sequences.</p>
--ldx]]--

local addkerns, unify, normalize, fixnames, addligatures, addtexligatures

function afm.load(filename)
    filename = resolvers.findfile(filename,'afm') or ""
    if filename ~= "" and not fonts.names.ignoredfile(filename) then
        local name = file.removesuffix(file.basename(filename))
        local data = containers.read(afm.cache,name)
        local attr = lfs.attributes(filename)
        local size, time = attr.size or 0, attr.modification or 0
        --
        local pfbfile = file.replacesuffix(name,"pfb")
        local pfbname = resolvers.findfile(pfbfile,"pfb") or ""
        if pfbname == "" then
            pfbname = resolvers.findfile(file.basename(pfbfile),"pfb") or ""
        end
        local pfbsize, pfbtime = 0, 0
        if pfbname ~= "" then
            local attr = lfs.attributes(pfbname)
            pfbsize = attr.size or 0
            pfbtime = attr.modification or 0
        end
        if not data or data.size ~= size or data.time ~= time or data.pfbsize ~= pfbsize or data.pfbtime ~= pfbtime then
            report_afm("reading %a",filename)
            data = readafm(filename)
            if data then
                if pfbname ~= "" then
                    data.resources.filename = resolvers.unresolve(pfbname)
                    get_indexes(data,pfbname)
                elseif trace_loading then
                    report_afm("no pfb file for %a",filename)
                 -- data.resources.filename = "unset" -- better than loading the afm file
                end
                -- we now have all the data loaded
                if trace_loading then
                    report_afm("unifying %a",filename)
                end
                unify(data,filename)
                if trace_loading then
                    report_afm("add ligatures") -- there can be missing ones
                end
                addligatures(data)
                if trace_loading then
                    report_afm("add extra kerns")
                end
                addkerns(data)
                if trace_loading then
                    report_afm("normalizing")
                end
                normalize(data)
                if trace_loading then
                    report_afm("fixing names")
                end
                fixnames(data)
                if trace_loading then
                    report_afm("add tounicode data")
                end
             -- otfreaders.addunicodetable(data) -- only when not done yet
                fonts.mappings.addtounicode(data,filename)
             -- otfreaders.extend(data)
                otfreaders.pack(data)
                data.size = size
                data.time = time
                data.pfbsize = pfbsize
                data.pfbtime = pfbtime
                report_afm("saving %a in cache",name)
             -- data.resources.unicodes = nil -- consistent with otf but here we save not much
                data = containers.write(afm.cache, name, data)
                data = containers.read(afm.cache,name)
            end
        end
        if data then
         -- constructors.addcoreunicodes(unicodes)
            otfreaders.unpack(data)
            otfreaders.expand(data) -- inline tables
            otfreaders.addunicodetable(data) -- only when not done yet
            otfenhancers.apply(data,filename,data)
            if applyruntimefixes then
                applyruntimefixes(filename,data)
            end
        end
        return data
    else
        return nil
    end
end

local uparser = fonts.mappings.makenameparser()

unify = function(data, filename)
    local unicodevector = fonts.encodings.agl.unicodes -- loaded runtime in context
    local unicodes      = { }
    local names         = { }
    local private       = constructors.privateoffset
    local descriptions  = data.descriptions
    for name, blob in next, data.characters do
        local code = unicodevector[name] -- or characters.name_to_unicode[name]
        if not code then
            code = lpegmatch(uparser,name)
            if not code then
                code = private
                private = private + 1
                report_afm("assigning private slot %U for unknown glyph name %a",code,name)
            end
        end
        local index = blob.index
        unicodes[name] = code
        names[name] = index
        blob.name = name
        descriptions[code] = {
            boundingbox = blob.boundingbox,
            width       = blob.width,
            kerns       = blob.kerns,
            index       = index,
            name        = name,
        }
    end
    for unicode, description in next, descriptions do
        local kerns = description.kerns
        if kerns then
            local krn = { }
            for name, kern in next, kerns do
                local unicode = unicodes[name]
                if unicode then
                    krn[unicode] = kern
                else
                 -- print(unicode,name)
                end
            end
            description.kerns = krn
        end
    end
    data.characters = nil
    local resources = data.resources
    local filename = resources.filename or file.removesuffix(file.basename(filename))
    resources.filename = resolvers.unresolve(filename) -- no shortcut
    resources.unicodes = unicodes -- name to unicode
    resources.marks = { } -- todo
 -- resources.names = names -- name to index
    resources.private = private
end

local everywhere = { ["*"] = { ["*"] = true } } -- or: { ["*"] = { "*" } }
local noflags    = { false, false, false, false }

normalize = function(data)
    local ligatures  = setmetatableindex("table")
    local kerns      = setmetatableindex("table")
    local extrakerns = setmetatableindex("table")
    for u, c in next, data.descriptions do
        local l = c.ligatures
        local k = c.kerns
        local e = c.extrakerns
        if l then
            ligatures[u] = l
            for u, v in next, l do
                l[u] = { ligature = v }
            end
            c.ligatures = nil
        end
        if k then
            kerns[u] = k
            for u, v in next, k do
                k[u] = v -- { v, 0 }
            end
            c.kerns = nil
        end
        if e then
            extrakerns[u] = e
            for u, v in next, e do
                e[u] = v -- { v, 0 }
            end
            c.extrakerns = nil
        end
    end
    local features = {
        gpos = { },
        gsub = { },
    }
    local sequences = {
        -- only filled ones
    }
    if next(ligatures) then
        features.gsub.liga = everywhere
        data.properties.hasligatures = true
        sequences[#sequences+1] = {
            features = {
                liga = everywhere,
            },
            flags    = noflags,
            name     = "s_s_0",
            nofsteps = 1,
            order    = { "liga" },
            type     = "gsub_ligature",
            steps    = {
                {
                    coverage = ligatures,
                },
            },
        }
    end
    if next(kerns) then
        features.gpos.kern = everywhere
        data.properties.haskerns = true
        sequences[#sequences+1] = {
            features = {
                kern = everywhere,
            },
            flags    = noflags,
            name     = "p_s_0",
            nofsteps = 1,
            order    = { "kern" },
            type     = "gpos_pair",
            steps    = {
                {
                    format   = "kern",
                    coverage = kerns,
                },
            },
        }
    end
    if next(extrakerns) then
        features.gpos.extrakerns = everywhere
        data.properties.haskerns = true
        sequences[#sequences+1] = {
            features = {
                extrakerns = everywhere,
            },
            flags    = noflags,
            name     = "p_s_1",
            nofsteps = 1,
            order    = { "extrakerns" },
            type     = "gpos_pair",
            steps    = {
                {
                    format   = "kern",
                    coverage = extrakerns,
                },
            },
        }
    end
    -- todo: compress kerns
    data.resources.features  = features
    data.resources.sequences = sequences
end

fixnames = function(data)
    for k, v in next, data.descriptions do
        local n = v.name
        local r = overloads[n]
        if r then
            local name = r.name
            if trace_indexing then
                report_afm("renaming characters %a to %a",n,name)
            end
            v.name    = name
            v.unicode = r.unicode
        end
    end
end

--[[ldx--
<p>These helpers extend the basic table with extra ligatures, texligatures
and extra kerns. This saves quite some lookups later.</p>
--ldx]]--

local addthem = function(rawdata,ligatures)
    if ligatures then
        local descriptions = rawdata.descriptions
        local resources    = rawdata.resources
        local unicodes     = resources.unicodes
     -- local names        = resources.names
        for ligname, ligdata in next, ligatures do
            local one = descriptions[unicodes[ligname]]
            if one then
                for _, pair in next, ligdata do
                    local two, three = unicodes[pair[1]], unicodes[pair[2]]
                    if two and three then
                        local ol = one.ligatures
                        if ol then
                            if not ol[two] then
                                ol[two] = three
                            end
                        else
                            one.ligatures = { [two] = three }
                        end
                    end
                end
            end
        end
    end
end

addligatures    = function(rawdata) addthem(rawdata,afm.helpdata.ligatures   ) end
addtexligatures = function(rawdata) addthem(rawdata,afm.helpdata.texligatures) end

--[[ldx--
<p>We keep the extra kerns in separate kerning tables so that we can use
them selectively.</p>
--ldx]]--

-- This is rather old code (from the beginning when we had only tfm). If
-- we unify the afm data (now we have names all over the place) then
-- we can use shcodes but there will be many more looping then. But we
-- could get rid of the tables in char-cmp then. Als, in the generic version
-- we don't use the character database. (Ok, we can have a context specific
-- variant).

addkerns = function(rawdata) -- using shcodes is not robust here
    local descriptions = rawdata.descriptions
    local resources    = rawdata.resources
    local unicodes     = resources.unicodes
    local function do_it_left(what)
        if what then
            for unicode, description in next, descriptions do
                local kerns = description.kerns
                if kerns then
                    local extrakerns
                    for complex, simple in next, what do
                        complex = unicodes[complex]
                        simple = unicodes[simple]
                        if complex and simple then
                            local ks = kerns[simple]
                            if ks and not kerns[complex] then
                                if extrakerns then
                                    extrakerns[complex] = ks
                                else
                                    extrakerns = { [complex] = ks }
                                end
                            end
                        end
                    end
                    if extrakerns then
                        description.extrakerns = extrakerns
                    end
                end
            end
        end
    end
    local function do_it_copy(what)
        if what then
            for complex, simple in next, what do
                complex = unicodes[complex]
                simple = unicodes[simple]
                if complex and simple then
                    local complexdescription = descriptions[complex]
                    if complexdescription then -- optional
                        local simpledescription = descriptions[complex]
                        if simpledescription then
                            local extrakerns
                            local kerns = simpledescription.kerns
                            if kerns then
                                for unicode, kern in next, kerns do
                                    if extrakerns then
                                        extrakerns[unicode] = kern
                                    else
                                        extrakerns = { [unicode] = kern }
                                    end
                                end
                            end
                            local extrakerns = simpledescription.extrakerns
                            if extrakerns then
                                for unicode, kern in next, extrakerns do
                                    if extrakerns then
                                        extrakerns[unicode] = kern
                                    else
                                        extrakerns = { [unicode] = kern }
                                    end
                                end
                            end
                            if extrakerns then
                                complexdescription.extrakerns = extrakerns
                            end
                        end
                    end
                end
            end
        end
    end
    -- add complex with values of simplified when present
    do_it_left(afm.helpdata.leftkerned)
    do_it_left(afm.helpdata.bothkerned)
    -- copy kerns from simple char to complex char unless set
    do_it_copy(afm.helpdata.bothkerned)
    do_it_copy(afm.helpdata.rightkerned)
end

--[[ldx--
<p>The copying routine looks messy (and is indeed a bit messy).</p>
--ldx]]--

local function adddimensions(data) -- we need to normalize afm to otf i.e. indexed table instead of name
    if data then
        for unicode, description in next, data.descriptions do
            local bb = description.boundingbox
            if bb then
                local ht, dp = bb[4], -bb[2]
                if ht == 0 or ht < 0 then
                    -- no need to set it and no negative heights, nil == 0
                else
                    description.height = ht
                end
                if dp == 0 or dp < 0 then
                    -- no negative depths and no negative depths, nil == 0
                else
                    description.depth  = dp
                end
            end
        end
    end
end

local function copytotfm(data)
    if data and data.descriptions then
        local metadata     = data.metadata
        local resources    = data.resources
        local properties   = derivetable(data.properties)
        local descriptions = derivetable(data.descriptions)
        local goodies      = derivetable(data.goodies)
        local characters   = { }
        local parameters   = { }
        local unicodes     = resources.unicodes
        --
        for unicode, description in next, data.descriptions do -- use parent table
            characters[unicode] = { }
        end
        --
        local filename   = constructors.checkedfilename(resources)
        local fontname   = metadata.fontname or metadata.fullname
        local fullname   = metadata.fullname or metadata.fontname
        local endash     = 0x0020 -- space
        local emdash     = 0x2014
        local spacer     = "space"
        local spaceunits = 500
        --
        local monospaced  = metadata.monospaced
        local charwidth   = metadata.charwidth
        local italicangle = metadata.italicangle
        local charxheight = metadata.xheight and metadata.xheight > 0 and metadata.xheight
        properties.monospaced  = monospaced
        parameters.italicangle = italicangle
        parameters.charwidth   = charwidth
        parameters.charxheight = charxheight
        -- same as otf
        if properties.monospaced then
            if descriptions[endash] then
                spaceunits, spacer = descriptions[endash].width, "space"
            end
            if not spaceunits and descriptions[emdash] then
                spaceunits, spacer = descriptions[emdash].width, "emdash"
            end
            if not spaceunits and charwidth then
                spaceunits, spacer = charwidth, "charwidth"
            end
        else
            if descriptions[endash] then
                spaceunits, spacer = descriptions[endash].width, "space"
            end
            if not spaceunits and charwidth then
                spaceunits, spacer = charwidth, "charwidth"
            end
        end
        spaceunits = tonumber(spaceunits)
        if spaceunits < 200 then
            -- todo: warning
        end
        --
        parameters.slant         = 0
        parameters.space         = spaceunits
        parameters.space_stretch = 500
        parameters.space_shrink  = 333
        parameters.x_height      = 400
        parameters.quad          = 1000
        --
        if italicangle and italicangle ~= 0 then
            parameters.italicangle  = italicangle
            parameters.italicfactor = math.cos(math.rad(90+italicangle))
            parameters.slant        = - math.tan(italicangle*math.pi/180)
        end
        if monospaced then
            parameters.space_stretch = 0
            parameters.space_shrink  = 0
        elseif afm.syncspace then
            parameters.space_stretch = spaceunits/2
            parameters.space_shrink  = spaceunits/3
        end
        parameters.extra_space = parameters.space_shrink
        if charxheight then
            parameters.x_height = charxheight
        else
            -- same as otf
            local x = 0x0078 -- x
            if x then
                local x = descriptions[x]
                if x then
                    parameters.x_height = x.height
                end
            end
            --
        end
        local fd = data.fontdimens
        if fd and fd[8] and fd[9] and fd[10] then -- math
            for k,v in next, fd do
                parameters[k] = v
            end
        end
        --
        parameters.designsize = (metadata.designsize or 10)*65536
        parameters.ascender   = abs(metadata.ascender  or 0)
        parameters.descender  = abs(metadata.descender or 0)
        parameters.units      = 1000
        --
        properties.spacer        = spacer
        properties.encodingbytes = 2
        properties.format        = fonts.formats[filename] or "type1"
        properties.filename      = filename
        properties.fontname      = fontname
        properties.fullname      = fullname
        properties.psname        = fullname
        properties.name          = filename or fullname or fontname
        --
        if next(characters) then
            return {
                characters   = characters,
                descriptions = descriptions,
                parameters   = parameters,
                resources    = resources,
                properties   = properties,
                goodies      = goodies,
            }
        end
    end
    return nil
end

--[[ldx--
<p>Originally we had features kind of hard coded for <l n='afm'/>
files but since I expect to support more font formats, I decided
to treat this fontformat like any other and handle features in a
more configurable way.</p>
--ldx]]--

function afm.setfeatures(tfmdata,features)
    local okay = constructors.initializefeatures("afm",tfmdata,features,trace_features,report_afm)
    if okay then
        return constructors.collectprocessors("afm",tfmdata,features,trace_features,report_afm)
    else
        return { } -- will become false
    end
end

local function addtables(data)
    local resources  = data.resources
    local lookuptags = resources.lookuptags
    local unicodes   = resources.unicodes
    if not lookuptags then
        lookuptags = { }
        resources.lookuptags = lookuptags
    end
    setmetatableindex(lookuptags,function(t,k)
        local v = type(k) == "number" and ("lookup " .. k) or k
        t[k] = v
        return v
    end)
    if not unicodes then
        unicodes = { }
        resources.unicodes = unicodes
        setmetatableindex(unicodes,function(t,k)
            setmetatableindex(unicodes,nil)
            for u, d in next, data.descriptions do
                local n = d.name
                if n then
                    t[n] = u
                end
            end
            return rawget(t,k)
        end)
    end
    constructors.addcoreunicodes(unicodes) -- do we really need this?
end

local function afmtotfm(specification)
    local afmname = specification.filename or specification.name
    if specification.forced == "afm" or specification.format == "afm" then -- move this one up
        if trace_loading then
            report_afm("forcing afm format for %a",afmname)
        end
    else
        local tfmname = findbinfile(afmname,"ofm") or ""
        if tfmname ~= "" then
            if trace_loading then
                report_afm("fallback from afm to tfm for %a",afmname)
            end
            return -- just that
        end
    end
    if afmname ~= "" then
        -- weird, isn't this already done then?
        local features = constructors.checkedfeatures("afm",specification.features.normal)
        specification.features.normal = features
        constructors.hashinstance(specification,true) -- also weird here
        --
        specification = definers.resolve(specification) -- new, was forgotten
        local cache_id = specification.hash
        local tfmdata  = containers.read(constructors.cache, cache_id) -- cache with features applied
        if not tfmdata then
            local rawdata = afm.load(afmname)
            if rawdata and next(rawdata) then
                addtables(rawdata)
                adddimensions(rawdata)
                tfmdata = copytotfm(rawdata)
                if tfmdata and next(tfmdata) then
                    local shared = tfmdata.shared
                    if not shared then
                        shared         = { }
                        tfmdata.shared = shared
                    end
                    shared.rawdata   = rawdata
                    shared.dynamics  = { }
                    tfmdata.changed  = { }
                    shared.features  = features
                    shared.processes = afm.setfeatures(tfmdata,features)
                end
            elseif trace_loading then
                report_afm("no (valid) afm file found with name %a",afmname)
            end
            tfmdata = containers.write(constructors.cache,cache_id,tfmdata)
        end
        return tfmdata
    end
end

--[[ldx--
<p>As soon as we could intercept the <l n='tfm'/> reader, I implemented an
<l n='afm'/> reader. Since traditional <l n='pdftex'/> could use <l n='opentype'/>
fonts with <l n='afm'/> companions, the following method also could handle
those cases, but now that we can handle <l n='opentype'/> directly we no longer
need this features.</p>
--ldx]]--

local function read_from_afm(specification)
    local tfmdata = afmtotfm(specification)
    if tfmdata then
        tfmdata.properties.name = specification.name
        tfmdata = constructors.scale(tfmdata, specification)
        local allfeatures = tfmdata.shared.features or specification.features.normal
        constructors.applymanipulators("afm",tfmdata,allfeatures,trace_features,report_afm)
        fonts.loggers.register(tfmdata,'afm',specification)
    end
    return tfmdata
end

--[[ldx--
<p>Here comes the implementation of a few features. We only implement
those that make sense for this format.</p>
--ldx]]--

local function prepareligatures(tfmdata,ligatures,value)
    if value then
        local descriptions = tfmdata.descriptions
        local hasligatures = false
        for unicode, character in next, tfmdata.characters do
            local description = descriptions[unicode]
            local dligatures = description.ligatures
            if dligatures then
                local cligatures = character.ligatures
                if not cligatures then
                    cligatures = { }
                    character.ligatures = cligatures
                end
                for unicode, ligature in next, dligatures do
                    cligatures[unicode] = {
                        char = ligature,
                        type = 0
                    }
                end
                hasligatures = true
            end
        end
        tfmdata.properties.hasligatures = hasligatures
    end
end

local function preparekerns(tfmdata,kerns,value)
    if value then
        local rawdata      = tfmdata.shared.rawdata
        local resources    = rawdata.resources
        local unicodes     = resources.unicodes
        local descriptions = tfmdata.descriptions
        local haskerns     = false
        for u, chr in next, tfmdata.characters do
            local d = descriptions[u]
            local newkerns = d[kerns]
            if newkerns then
                local kerns = chr.kerns
                if not kerns then
                    kerns = { }
                    chr.kerns = kerns
                end
                for k,v in next, newkerns do
                    local uk = unicodes[k]
                    if uk then
                        kerns[uk] = v
                    end
                end
                haskerns = true
            end
        end
        tfmdata.properties.haskerns = haskerns
    end
end

local list = {
 -- [0x0022] = 0x201D,
    [0x0027] = 0x2019,
 -- [0x0060] = 0x2018,
}

local function texreplacements(tfmdata,value)
    local descriptions = tfmdata.descriptions
    local characters   = tfmdata.characters
    for k, v in next, list do
        characters  [k] = characters  [v] -- we forget about kerns
        descriptions[k] = descriptions[v] -- we forget about kerns
    end
end

-- local function ligatures   (tfmdata,value) prepareligatures(tfmdata,'ligatures',   value) end
-- local function texligatures(tfmdata,value) prepareligatures(tfmdata,'texligatures',value) end
-- local function kerns       (tfmdata,value) preparekerns    (tfmdata,'kerns',       value) end
local function extrakerns  (tfmdata,value) preparekerns    (tfmdata,'extrakerns',  value) end

local function setmode(tfmdata,value)
    if value then
        tfmdata.properties.mode = lower(value)
    end
end

registerafmfeature {
    name         = "mode",
    description  = "mode",
    initializers = {
        base = setmode,
        node = setmode,
    }
}

registerafmfeature {
    name         = "features",
    description  = "features",
    default      = true,
    initializers = {
        node     = otf.nodemodeinitializer,
        base     = otf.basemodeinitializer,
    },
    processors   = {
        node     = otf.featuresprocessor,
    }
}

-- readers

local check_tfm   = readers.check_tfm

fonts.formats.afm = "type1"
fonts.formats.pfb = "type1"

local function check_afm(specification,fullname)
    local foundname = findbinfile(fullname, 'afm') or "" -- just to be sure
    if foundname == "" then
        foundname = fonts.names.getfilename(fullname,"afm") or ""
    end
    if foundname == "" and afm.autoprefixed then
        local encoding, shortname = match(fullname,"^(.-)%-(.*)$") -- context: encoding-name.*
        if encoding and shortname and fonts.encodings.known[encoding] then
            shortname = findbinfile(shortname,'afm') or "" -- just to be sure
            if shortname ~= "" then
                foundname = shortname
                if trace_defining then
                    report_afm("stripping encoding prefix from filename %a",afmname)
                end
            end
        end
    end
    if foundname ~= "" then
        specification.filename = foundname
        specification.format   = "afm"
        return read_from_afm(specification)
    end
end

function readers.afm(specification,method)
    local fullname, tfmdata = specification.filename or "", nil
    if fullname == "" then
        local forced = specification.forced or ""
        if forced ~= "" then
            tfmdata = check_afm(specification,specification.name .. "." .. forced)
        end
        if not tfmdata then
            method = method or definers.method or "afm or tfm"
            if method == "tfm" then
                tfmdata = check_tfm(specification,specification.name)
            elseif method == "afm" then
                tfmdata = check_afm(specification,specification.name)
            elseif method == "tfm or afm" then
                tfmdata = check_tfm(specification,specification.name) or check_afm(specification,specification.name)
            else -- method == "afm or tfm" or method == "" then
                tfmdata = check_afm(specification,specification.name) or check_tfm(specification,specification.name)
            end
        end
    else
        tfmdata = check_afm(specification,fullname)
    end
    return tfmdata
end

function readers.pfb(specification,method) -- only called when forced
    local original = specification.specification
    if trace_defining then
        report_afm("using afm reader for %a",original)
    end
    specification.specification = gsub(original,"%.pfb",".afm")
    specification.forced = "afm"
    return readers.afm(specification,method)
end
