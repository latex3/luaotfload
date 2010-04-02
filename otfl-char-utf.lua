if not modules then modules = { } end modules ['char-utf'] = {
    version   = 1.001,
    comment   = "companion to char-utf.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>When a sequence of <l n='utf'/> characters enters the application, it may
be neccessary to collapse subsequences into their composed variant.</p>

<p>This module implements methods for collapsing and expanding <l n='utf'/>
sequences. We also provide means to deal with characters that are
special to <l n='tex'/> as well as 8-bit characters that need to end up
in special kinds of output (for instance <l n='pdf'/>).</p>

<p>We implement these manipulations as filters. One can run multiple filters
over a string.</p>
--ldx]]--

local utf = unicode.utf8
local concat, gmatch = table.concat, string.gmatch
local utfcharacters, utfvalues = string.utfcharacters, string.utfvalues

local ctxcatcodes = tex.ctxcatcodes

characters              = characters              or { }
characters.graphemes    = characters.graphemes    or { }
characters.filters      = characters.filters      or { }
characters.filters.utf  = characters.filters.utf  or { }

characters.filters.utf.initialized = false
characters.filters.utf.collapsing  = true
characters.filters.utf.expanding   = true

local graphemes  = characters.graphemes
local utffilters = characters.filters.utf
local utfchar, utfbyte, utfgsub = utf.char, utf.byte, utf.gsub

--[[ldx--
<p>It only makes sense to collapse at runtime, since we don't expect
source code to depend on collapsing.</p>
--ldx]]--

function utffilters.initialize()
    if utffilters.collapsing and not utffilters.initialized then
        for k,v in next, characters.data do
            -- using vs and first testing for length is faster (.02->.01 s)
            local vs = v.specials
            if vs and #vs == 3 and vs[1] == 'char' then
                local first, second = utfchar(vs[2]), utfchar(vs[3])
                local cgf = graphemes[first]
                if not cgf then
                    cgf = { }
                    graphemes[first] = cgf
                end
                cgf[second] = utfchar(k)
            end
        end
        utffilters.initialized = true
    end
end

-- utffilters.add_grapheme(utfchar(318),'l','\string~')
-- utffilters.add_grapheme('c','a','b')

function utffilters.add_grapheme(result,first,second)
    local r, f, s = tonumber(result), tonumber(first), tonumber(second)
    if r then result = utfchar(r) end
    if f then first  = utfchar(f) end
    if s then second = utfchar(s) end
    if not graphemes[first] then
        graphemes[first] = { [second] = result }
    else
        graphemes[first][second] = result
    end
end

function utffilters.collapse(str) -- old one
    if utffilters.collapsing and str and #str > 1 then
        if not utffilters.initialized then -- saves a call
            utffilters.initialize()
        end
        local tokens, first, done = { }, false, false
        for second in utfcharacters(str) do
            local cgf = graphemes[first]
            if cgf and cgf[second] then
                first, done = cgf[second], true
            elseif first then
                tokens[#tokens+1] = first
                first = second
            else
                first = second
            end
        end
        if done then
            tokens[#tokens+1] = first
            return concat(tokens)
        end
    end
    return str
end

--[[ldx--
<p>In order to deal with 8-bit output, we need to find a way to
go from <l n='utf'/> to 8-bit. This is handled in the
<l n='luatex'/> engine itself.</p>

<p>This leaves us problems with characters that are specific to
<l n='tex'/> like <type>{}</type>, <type>$</type> and alike.</p>

<p>We can remap some chars that tex input files are sensitive for to
a private area (while writing to a utility file) and revert then
to their original slot when we read in such a file. Instead of
reverting, we can (when we resolve characters to glyphs) map them
to their right glyph there.</p>

<p>For this purpose we can use the private planes 0x0F0000 and
0x100000.</p>
--ldx]]--

utffilters.private = {
    high    = { },
    low     = { },
    escapes = { },
}

local low     = utffilters.private.low
local high    = utffilters.private.high
local escapes = utffilters.private.escapes
local special = "~#$%^&_{}\\|"

function utffilters.private.set(ch)
    local cb
    if type(ch) == "number" then
        cb, ch = ch, utfchar(ch)
    else
        cb = utfbyte(ch)
    end
    if cb < 256 then
        low[ch] = utfchar(0x0F0000 + cb)
        high[utfchar(0x0F0000 + cb)] = ch
        escapes[ch] = "\\" .. ch
    end
end

function utffilters.private.replace(str) return utfgsub(str,"(.)", low    ) end
function utffilters.private.revert(str)  return utfgsub(str,"(.)", high   ) end
function utffilters.private.escape(str)  return utfgsub(str,"(.)", escapes) end

local set = utffilters.private.set

for ch in gmatch(special,".") do set(ch) end

--[[ldx--
<p>We get a more efficient variant of this when we integrate
replacements in collapser. This more or less renders the previous
private code redundant. The following code is equivalent but the
first snippet uses the relocated dollars.</p>

<typing>
[󰀤x󰀤] [$x$]
</typing>
--ldx]]--

local cr = utffilters.private.high -- kan via een lpeg
local cf = utffilters

--[[ldx--
<p>The next variant has lazy token collecting, on a 140 page mk.tex this saves
about .25 seconds, which is understandable because we have no graphmes and
not collecting tokens is not only faster but also saves garbage collecting.
</p>
--ldx]]--

-- lpeg variant is not faster

function utffilters.collapse(str) -- not really tested (we could preallocate a table)
    if cf.collapsing and str then
        if #str > 1 then
            if not cf.initialized then -- saves a call
                cf.initialize()
            end
            local tokens, first, done, n = { }, false, false, 0
            for second in utfcharacters(str) do
                if done then
                    local crs = cr[second]
                    if crs then
                        if first then
                            tokens[#tokens+1] = first
                        end
                        first = crs
                    else
                        local cgf = graphemes[first]
                        if cgf and cgf[second] then
                            first = cgf[second]
                        elseif first then
                            tokens[#tokens+1] = first
                            first = second
                        else
                            first = second
                        end
                    end
                else
                    local crs = cr[second]
                    if crs then
                        for s in utfcharacters(str) do
                            if n == 1 then
                                break
                            else
                                tokens[#tokens+1], n = s, n - 1
                            end
                        end
                        if first then
                            tokens[#tokens+1] = first
                        end
                        first, done = crs, true
                    else
                        local cgf = graphemes[first]
                        if cgf and cgf[second] then
                            for s in utfcharacters(str) do
                                if n == 1 then
                                    break
                                else
                                    tokens[#tokens+1], n = s, n -1
                                end
                            end
                            first, done = cgf[second], true
                        else
                            first, n = second, n + 1
                        end
                    end
                end
            end
            if done then
                tokens[#tokens+1] = first
                return concat(tokens) -- seldom called
            end
        elseif #str > 0 then
            return cr[str] or str
        end
    end
    return str
end

--[[ldx--
<p>Next we implement some commands that are used in the user interface.</p>
--ldx]]--

commands = commands or { }

function commands.uchar(first,second)
    tex.sprint(ctxcatcodes,utfchar(first*256+second))
end

--[[ldx--
<p>A few helpers (used to be <t>luat-uni<t/>).</p>
--ldx]]--

function utf.split(str)
    local t = { }
    for snippet in utfcharacters(str) do
        t[#t+1] = snippet
    end
    return t
end

function utf.each(str,fnc)
    for snippet in utfcharacters(str) do
        fnc(snippet)
    end
end
