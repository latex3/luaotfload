if not modules then modules = { } end modules ['font-dsp'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- many 0,0 entry/exit

-- This loader went through a few iterations. First I made a ff compatible one so
-- that we could do some basic checking. Also some verbosity was added (named
-- glyphs). Eventually all that was dropped for a context friendly format, simply
-- because keeping the different table models in sync too to much time. I have the
-- old file somewhere. A positive side effect is that we get an (upto) much smaller
-- smaller tma/tmc file. In the end the loader will be not much slower than the
-- c based ff one.

-- Being binary encoded, an opentype is rather compact. When expanded into a Lua table
-- quite some memory can be used. This is very noticeable in the ff loader, which for
-- a good reason uses a verbose format. However, when we use that data we create a couple
-- of hashes. In the Lua loader we create these hashes directly, which save quite some
-- memory.
--
-- We convert a font file only once and then cache it. Before creating the cached instance
-- packing takes place: common tables get shared. After (re)loading and unpacking we then
-- get a rather efficient internal representation of the font. In the new loader there is a
-- pitfall. Because we use some common coverage magic we put a bit more information in
-- the mark and cursive coverage tables than strickly needed: a reference to the coverage
-- itself. This permits a fast lookup of the second glyph involved. In the marks we
-- expand the class indicator to a class hash, in the cursive we use a placeholder that gets
-- a self reference. This means that we cannot pack these subtables unless we add a unique
-- id per entry (the same one per coverage) and that makes the tables larger. Because only a
-- few fonts benefit from this, I decided to not do this. Experiments demonstrated that it
-- only gives a few percent gain (on for instance husayni we can go from 845K to 828K
-- bytecode). Better stay conceptually clean than messy compact.

-- When we can reduce all basic lookups to one step we might safe a bit in the processing
-- so then only chains are multiple.

-- I used to flatten kerns here but that has been moved elsewhere because it polutes the code
-- here and can be done fast afterwards. One can even wonder if it makes sense to do it as we
-- pack anyway. In a similar fashion the unique placeholders in anchors in marks have been
-- removed because packing doesn't save much there anyway.

-- Although we have a bit more efficient tables in the cached files, the internals are still
-- pretty similar. And although we have a slightly more direct coverage access the processing
-- of node lists is not noticeable faster for latin texts, but for arabic we gain some 10%
-- (and could probably gain a bit more).

local next, type = next, type
local bittest = bit32.btest
local rshift = bit32.rshift
local concat = table.concat
local lower = string.lower
local sub = string.sub
local strip = string.strip
local tohash = table.tohash
local reversed = table.reversed

local setmetatableindex = table.setmetatableindex
local formatters        = string.formatters
local sortedkeys        = table.sortedkeys
local sortedhash        = table.sortedhash

local report            = logs.reporter("otf reader")

local readers           = fonts.handlers.otf.readers
local streamreader      = readers.streamreader

local setposition       = streamreader.setposition
local skipshort         = streamreader.skipshort
local readushort        = streamreader.readcardinal2  -- 16-bit unsigned integer
local readulong         = streamreader.readcardinal4  -- 24-bit unsigned integer
local readshort         = streamreader.readinteger2   -- 16-bit   signed integer
local readfword         = readshort
local readstring        = streamreader.readstring
local readtag           = streamreader.readtag
local readbytes         = streamreader.readbytes

local gsubhandlers      = { }
local gposhandlers      = { }

local lookupidoffset    = -1    -- will become 1 when we migrate (only -1 for comparign with old)

local classes = {
    "base",
    "ligature",
    "mark",
    "component",
}

local gsubtypes = {
    "single",
    "multiple",
    "alternate",
    "ligature",
    "context",
    "chainedcontext",
    "extension",
    "reversechainedcontextsingle",
}

local gpostypes = {
    "single",
    "pair",
    "cursive",
    "marktobase",
    "marktoligature",
    "marktomark",
    "context",
    "chainedcontext",
    "extension",
}

local chaindirections = {
    context                     =  0,
    chainedcontext              =  1,
    reversechainedcontextsingle = -1,
}

-- Traditionally we use these unique names (so that we can flatten the lookup list
-- (we create subsets runtime) but I will adapt the old code to newer names.

-- chainsub
-- reversesub

local lookupnames = {
    gsub = {
        single                      = "gsub_single",
        multiple                    = "gsub_multiple",
        alternate                   = "gsub_alternate",
        ligature                    = "gsub_ligature",
        context                     = "gsub_context",
        chainedcontext              = "gsub_contextchain",
        reversechainedcontextsingle = "gsub_reversecontextchain", -- reversesub
    },
    gpos = {
        single                      = "gpos_single",
        pair                        = "gpos_pair",
        cursive                     = "gpos_cursive",
        marktobase                  = "gpos_mark2base",
        marktoligature              = "gpos_mark2ligature",
        marktomark                  = "gpos_mark2mark",
        context                     = "gpos_context",
        chainedcontext              = "gpos_contextchain",
    }
}

-- keep this as reference:
--
-- local lookupbits = {
--     [0x0001] = "righttoleft",
--     [0x0002] = "ignorebaseglyphs",
--     [0x0004] = "ignoreligatures",
--     [0x0008] = "ignoremarks",
--     [0x0010] = "usemarkfilteringset",
--     [0x00E0] = "reserved",
--     [0xFF00] = "markattachmenttype",
-- }
--
-- local lookupstate = setmetatableindex(function(t,k)
--     local v = { }
--     for kk, vv in next, lookupbits do
--         if bittest(k,kk) then
--             v[vv] = true
--         end
--     end
--     t[k] = v
--     return v
-- end)

local lookupflags = setmetatableindex(function(t,k)
    local v = {
        bittest(k,0x0008) and true or false, -- ignoremarks
        bittest(k,0x0004) and true or false, -- ignoreligatures
        bittest(k,0x0002) and true or false, -- ignorebaseglyphs
        bittest(k,0x0001) and true or false, -- r2l
    }
    t[k] = v
    return v
end)

-- Beware: only use the simple variant if we don't set keys/values (otherwise too many entries). We
-- could also have a variant that applies a function but there is no real benefit in this.

local function readcoverage(f,offset,simple)
    setposition(f,offset)
    local coverageformat = readushort(f)
    local coverage = { }
    if coverageformat == 1 then
        local nofcoverage = readushort(f)
        if simple then
            for i=1,nofcoverage do
                coverage[i] = readushort(f)
            end
        else
            for i=0,nofcoverage-1 do
                coverage[readushort(f)] = i -- index in record
            end
        end
    elseif coverageformat == 2 then
        local nofranges = readushort(f)
        local n = simple and 1 or 0 -- needs checking
        for i=1,nofranges do
            local firstindex = readushort(f)
            local lastindex  = readushort(f)
            local coverindex = readushort(f)
            if simple then
                for i=firstindex,lastindex do
                    coverage[n] = i
                    n = n + 1
                end
            else
                for i=firstindex,lastindex do
                    coverage[i] = n
                    n = n + 1
                end
            end
        end
    else
        report("unknown coverage format %a ",coverageformat)
    end
    return coverage
end

local function readclassdef(f,offset,preset)
    setposition(f,offset)
    local classdefformat = readushort(f)
    local classdef = { }
    if type(preset) == "number" then
        for k=0,preset-1 do
            classdef[k] = 1
        end
    end
    if classdefformat == 1 then
        local index       = readushort(f)
        local nofclassdef = readushort(f)
        for i=1,nofclassdef do
            classdef[index] = readushort(f) + 1
            index = index + 1
        end
    elseif classdefformat == 2 then
        local nofranges = readushort(f)
        local n = 0
        for i=1,nofranges do
            local firstindex = readushort(f)
            local lastindex  = readushort(f)
            local class      = readushort(f) + 1
            for i=firstindex,lastindex do
                classdef[i] = class
            end
        end
    else
        report("unknown classdef format %a ",classdefformat)
    end
    if type(preset) == "table" then
        for k in next, preset do
            if not classdef[k] then
                classdef[k] = 1
            end
        end
    end
    return classdef
end

local function classtocoverage(defs)
    if defs then
        local list = { }
        for index, class in next, defs do
            local c = list[class]
            if c then
                c[#c+1] = index
            else
                list[class] = { index }
            end
        end
        return list
    end
end

-- extra readers

local function readposition(f,format)
    if format == 0 then
        return nil
    end
    -- maybe fast test on 0x0001 + 0x0002 + 0x0004 + 0x0008 (profile first)
    local x = bittest(format,0x0001) and readshort(f) or 0 -- placement
    local y = bittest(format,0x0002) and readshort(f) or 0 -- placement
    local h = bittest(format,0x0004) and readshort(f) or 0 -- advance
    local v = bittest(format,0x0008) and readshort(f) or 0 -- advance
    if x == 0 and y == 0 and h == 0 and v == 0 then
        return nil
    else
        return { x, y, h, v }
    end
end

local function readanchor(f,offset)
    if not offset or offset == 0 then
        return nil -- false
    end
    setposition(f,offset)
    local format = readshort(f)
    if format == 0 then
        report("invalid anchor format %i @ position %i",format,offset)
        return false
    elseif format > 3 then
        report("unsupported anchor format %i @ position %i",format,offset)
        return false
    end
    return { readshort(f), readshort(f) }
end

-- common handlers: inlining can be faster but we cache anyway
-- so we don't bother too much about speed here

local function readfirst(f,offset)
    if offset then
        setposition(f,offset)
    end
    return { readushort(f) }
end

local function readarray(f,offset,first)
    if offset then
        setposition(f,offset)
    end
    local n = readushort(f)
    if first then
        local t = { first }
        for i=2,n do
            t[i] = readushort(f)
        end
        return t, n
    elseif n > 0 then
        local t = { }
        for i=1,n do
            t[i] = readushort(f)
        end
        return t, n
    end
end

local function readcoveragearray(f,offset,t,simple)
    if not t then
        return nil
    end
    local n = #t
    if n == 0 then
        return nil
    end
    for i=1,n do
        t[i] = readcoverage(f,offset+t[i],simple)
    end
    return t
end

local function covered(subset,all)
    local used, u
    for i=1,#subset do
        local s = subset[i]
        if all[s] then
            if used then
                u = u + 1
                used[u] = s
            else
                u = 1
                used = { s }
            end
        end
    end
    return used
end

-- We generalize the chained lookups so that we can do with only one handler
-- when processing them.

-- pruned

local function readlookuparray(f,noflookups,nofcurrent)
    local lookups = { }
    if noflookups > 0 then
        local length = 0
        for i=1,noflookups do
            local index = readushort(f) + 1
            if index > length then
                length = index
            end
            lookups[index] = readushort(f) + 1
        end
        for index=1,length do
            if not lookups[index] then
                lookups[index] = false
            end
        end
     -- if length > nofcurrent then
     --     report_issue("more lookups than currently matched characters")
     -- end
    end
    return lookups
end

-- not pruned
--
-- local function readlookuparray(f,noflookups,nofcurrent)
--     local lookups = { }
--     for i=1,nofcurrent do
--         lookups[i] = false
--     end
--     for i=1,noflookups do
--         local index = readushort(f) + 1
--         if index > nofcurrent then
--             report_issue("more lookups than currently matched characters")
--             for i=nofcurrent+1,index-1 do
--                 lookups[i] = false
--             end
--             nofcurrent = index
--         end
--         lookups[index] = readushort(f) + 1
--     end
--     return lookups
-- end

local function unchainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,what)
    local tableoffset = lookupoffset + offset
    setposition(f,tableoffset)
    local subtype = readushort(f)
    if subtype == 1 then
        local coverage     = readushort(f)
        local subclasssets = readarray(f)
        local rules        = { }
        if subclasssets then
            coverage = readcoverage(f,tableoffset+coverage,true)
            for i=1,#subclasssets do
                local offset = subclasssets[i]
                if offset > 0 then
                    local firstcoverage = coverage[i]
                    local rulesoffset   = tableoffset + offset
                    local subclassrules = readarray(f,rulesoffset)
                    for rule=1,#subclassrules do
                        setposition(f,rulesoffset + subclassrules[rule])
                        local nofcurrent = readushort(f)
                        local noflookups = readushort(f)
                        local current    = { { firstcoverage } }
                        for i=2,nofcurrent do
                            current[i] = { readushort(f) }
                        end
                        local lookups = readlookuparray(f,noflookups,nofcurrent)
                        rules[#rules+1] = {
                            current = current,
                            lookups = lookups
                        }
                    end
                end
            end
        else
            report("empty subclassset in %a subtype %i","unchainedcontext",subtype)
        end
        return {
            format = "glyphs",
            rules  = rules,
        }
    elseif subtype == 2 then
        -- We expand the classes as later on we do a pack over the whole table so then we get
        -- back efficiency. This way we can also apply the coverage to the first current.
        local coverage        = readushort(f)
        local currentclassdef = readushort(f)
        local subclasssets    = readarray(f)
        local rules           = { }
        if subclasssets then
            coverage             = readcoverage(f,tableoffset + coverage)
            currentclassdef      = readclassdef(f,tableoffset + currentclassdef,coverage)
            local currentclasses = classtocoverage(currentclassdef,fontdata.glyphs)
            for class=1,#subclasssets do
                local offset = subclasssets[class]
                if offset > 0 then
                    local firstcoverage = currentclasses[class]
                    if firstcoverage then
                        firstcoverage = covered(firstcoverage,coverage) -- bonus
                        if firstcoverage then
                            local rulesoffset   = tableoffset + offset
                            local subclassrules = readarray(f,rulesoffset)
                            for rule=1,#subclassrules do
                                setposition(f,rulesoffset + subclassrules[rule])
                                local nofcurrent = readushort(f)
                                local noflookups = readushort(f)
                                local current    = { firstcoverage }
                                for i=2,nofcurrent do
                                    current[i] = currentclasses[readushort(f) + 1]
                                end
                                local lookups = readlookuparray(f,noflookups,nofcurrent)
                                rules[#rules+1] = {
                                    current = current,
                                    lookups = lookups
                                }
                            end
                        else
                            report("no coverage")
                        end
                    else
                        report("no coverage class")
                    end
                end
            end
        else
            report("empty subclassset in %a subtype %i","unchainedcontext",subtype)
        end
        return {
            format = "class",
            rules  = rules,
        }
    elseif subtype == 3 then
        local current    = readarray(f)
        local noflookups = readushort(f)
        local lookups    = readlookuparray(f,noflookups,#current)
        current = readcoveragearray(f,tableoffset,current,true)
        return {
            format = "coverage",
            rules  = {
                {
                    current = current,
                    lookups = lookups,
                }
            }
        }
    else
        report("unsupported subtype %a in %a %s",subtype,"unchainedcontext",what)
    end
end

-- todo: optimize for n=1 ?

-- class index needs checking, probably no need for +1

local function chainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,what)
    local tableoffset = lookupoffset + offset
    setposition(f,tableoffset)
    local subtype = readushort(f)
    if subtype == 1 then
        local coverage     = readushort(f)
        local subclasssets = readarray(f)
        local rules        = { }
        if subclasssets then
            coverage = readcoverage(f,tableoffset+coverage,true)
            for i=1,#subclasssets do
                local offset = subclasssets[i]
                if offset > 0 then
                    local firstcoverage = coverage[i]
                    local rulesoffset   = tableoffset + offset
                    local subclassrules = readarray(f,rulesoffset)
                    for rule=1,#subclassrules do
                        setposition(f,rulesoffset + subclassrules[rule])
                        local nofbefore = readushort(f)
                        local before
                        if nofbefore > 0 then
                            before = { }
                            for i=1,nofbefore do
                                before[i] = { readushort(f) }
                            end
                        end
                        local nofcurrent = readushort(f)
                        local current    = { { firstcoverage } }
                        for i=2,nofcurrent do
                            current[i] = { readushort(f) }
                        end
                        local nofafter = readushort(f)
                        local after
                        if nofafter > 0 then
                            after = { }
                            for i=1,nofafter do
                                after[i] = { readushort(f) }
                            end
                        end
                        local noflookups = readushort(f)
                        local lookups    = readlookuparray(f,noflookups,nofcurrent)
                        rules[#rules+1] = {
                            before  = before,
                            current = current,
                            after   = after,
                            lookups = lookups,
                        }
                    end
                end
            end
        else
            report("empty subclassset in %a subtype %i","chainedcontext",subtype)
        end
        return {
            format = "glyphs",
            rules  = rules,
        }
    elseif subtype == 2 then
        local coverage        = readushort(f)
        local beforeclassdef  = readushort(f)
        local currentclassdef = readushort(f)
        local afterclassdef   = readushort(f)
        local subclasssets    = readarray(f)
        local rules           = { }
        if subclasssets then
            local coverage        = readcoverage(f,tableoffset + coverage)
            local beforeclassdef  = readclassdef(f,tableoffset + beforeclassdef,nofglyphs)
            local currentclassdef = readclassdef(f,tableoffset + currentclassdef,coverage)
            local afterclassdef   = readclassdef(f,tableoffset + afterclassdef,nofglyphs)
            local beforeclasses   = classtocoverage(beforeclassdef,fontdata.glyphs)
            local currentclasses  = classtocoverage(currentclassdef,fontdata.glyphs)
            local afterclasses    = classtocoverage(afterclassdef,fontdata.glyphs)
            for class=1,#subclasssets do
                local offset = subclasssets[class]
                if offset > 0 then
                    local firstcoverage = currentclasses[class]
                    if firstcoverage then
                        firstcoverage = covered(firstcoverage,coverage) -- bonus
                        if firstcoverage then
                            local rulesoffset   = tableoffset + offset
                            local subclassrules = readarray(f,rulesoffset)
                            for rule=1,#subclassrules do
                                -- watch out, in context we first get the counts and then the arrays while
                                -- here we get them mixed
                                setposition(f,rulesoffset + subclassrules[rule])
                                local nofbefore = readushort(f)
                                local before
                                if nofbefore > 0 then
                                    before = { }
                                    for i=1,nofbefore do
                                        before[i] = beforeclasses[readushort(f) + 1]
                                    end
                                end
                                local nofcurrent = readushort(f)
                                local current    = { firstcoverage }
                                for i=2,nofcurrent do
                                    current[i] = currentclasses[readushort(f)+ 1]
                                end
                                local nofafter = readushort(f)
                                local after
                                if nofafter > 0 then
                                    after = { }
                                    for i=1,nofafter do
                                        after[i] = afterclasses[readushort(f) + 1]
                                    end
                                end
                                -- no sequence index here (so why in context as it saves nothing)
                                local noflookups = readushort(f)
                                local lookups    = readlookuparray(f,noflookups,nofcurrent)
                                rules[#rules+1] = {
                                    before  = before,
                                    current = current,
                                    after   = after,
                                    lookups = lookups,
                                }
                            end
                        else
                            report("no coverage")
                        end
                    else
                        report("class is not covered")
                    end
                end
            end
        else
            report("empty subclassset in %a subtype %i","chainedcontext",subtype)
        end
        return {
            format = "class",
            rules  = rules,
        }
    elseif subtype == 3 then
        local before     = readarray(f)
        local current    = readarray(f)
        local after      = readarray(f)
        local noflookups = readushort(f)
        local lookups    = readlookuparray(f,noflookups,#current)
        before  = readcoveragearray(f,tableoffset,before,true)
        current = readcoveragearray(f,tableoffset,current,true)
        after   = readcoveragearray(f,tableoffset,after,true)
        return {
            format = "coverage",
            rules  = {
                {
                    before  = before,
                    current = current,
                    after   = after,
                    lookups = lookups,
                }
            }
        }
    else
        report("unsupported subtype %a in %a %s",subtype,"chainedcontext",what)
    end
end

local function extension(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,types,handlers,what)
    local tableoffset = lookupoffset + offset
    setposition(f,tableoffset)
    local subtype = readushort(f)
    if subtype == 1 then
        local lookuptype = types[readushort(f)]
        local faroffset  = readulong(f)
        local handler    = handlers[lookuptype]
        if handler then
            -- maybe we can just pass one offset (or tableoffset first)
            return handler(f,fontdata,lookupid,tableoffset + faroffset,0,glyphs,nofglyphs), lookuptype
        else
            report("no handler for lookuptype %a subtype %a in %s %s",lookuptype,subtype,what,"extension")
        end
    else
        report("unsupported subtype %a in %s %s",subtype,what,"extension")
    end
end

-- gsub handlers

function gsubhandlers.single(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    local tableoffset = lookupoffset + offset
    setposition(f,tableoffset)
    local subtype = readushort(f)
    if subtype == 1 then
        local coverage = readushort(f)
        local delta    = readshort(f) -- can be negative
        local coverage = readcoverage(f,tableoffset+coverage) -- not simple as we need to set key/value anyway
        for index in next, coverage do
            local newindex = index + delta
            if index > nofglyphs or newindex > nofglyphs then
                report("invalid index in %s format %i: %i -> %i (max %i)","single",subtype,index,newindex,nofglyphs)
                coverage[index] = nil
            else
                coverage[index] = newindex
            end
        end
        return {
            coverage = coverage
        }
    elseif subtype == 2 then -- in streamreader a seek and fetch is faster than a temp table
        local coverage        = readushort(f)
        local nofreplacements = readushort(f)
        local replacements    = { }
        for i=1,nofreplacements do
            replacements[i] = readushort(f)
        end
        local coverage = readcoverage(f,tableoffset + coverage) -- not simple as we need to set key/value anyway
        for index, newindex in next, coverage do
            newindex = newindex + 1
            if index > nofglyphs or newindex > nofglyphs then
                report("invalid index in %s format %i: %i -> %i (max %i)","single",subtype,index,newindex,nofglyphs)
                coverage[index] = nil
            else
                coverage[index] = replacements[newindex]
            end
        end
        return {
            coverage = coverage
        }
    else
        report("unsupported subtype %a in %a substitution",subtype,"single")
    end
end

-- we see coverage format 0x300 in some old ms fonts

local function sethandler(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,what)
    local tableoffset = lookupoffset + offset
    setposition(f,tableoffset)
    local subtype = readushort(f)
    if subtype == 1 then
        local coverage    = readushort(f)
        local nofsequence = readushort(f)
        local sequences   = { }
        for i=1,nofsequence do
            sequences[i] = readushort(f)
        end
        for i=1,nofsequence do
            setposition(f,tableoffset + sequences[i])
            local n = readushort(f)
            local s = { }
            for i=1,n do
                s[i] = readushort(f)
            end
            sequences[i] = s
        end
        local coverage = readcoverage(f,tableoffset + coverage)
        for index, newindex in next, coverage do
            newindex = newindex + 1
            if index > nofglyphs or newindex > nofglyphs then
                report("invalid index in %s format %i: %i -> %i (max %i)",what,subtype,index,newindex,nofglyphs)
                coverage[index] = nil
            else
                coverage[index] = sequences[newindex]
            end
        end
        return {
            coverage = coverage
        }
    else
        report("unsupported subtype %a in %a substitution",subtype,what)
    end
end

function gsubhandlers.multiple(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    return sethandler(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"multiple")
end

function gsubhandlers.alternate(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    return sethandler(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"alternate")
end

function gsubhandlers.ligature(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    local tableoffset = lookupoffset + offset
    setposition(f,tableoffset)
    local subtype = readushort(f)
    if subtype == 1 then
        local coverage  = readushort(f)
        local nofsets   = readushort(f)
        local ligatures = { }
        for i=1,nofsets do
            ligatures[i] = readushort(f)
        end
        for i=1,nofsets do
            local offset = lookupoffset + offset + ligatures[i]
            setposition(f,offset)
            local n = readushort(f)
            local l = { }
            for i=1,n do
                l[i] = offset + readushort(f)
            end
            ligatures[i] = l
        end
        local coverage = readcoverage(f,tableoffset + coverage)
        for index, newindex in next, coverage do
            local hash = { }
            local ligatures = ligatures[newindex+1]
            for i=1,#ligatures do
                local offset = ligatures[i]
                setposition(f,offset)
                local lig = readushort(f)
                local cnt = readushort(f)
                local hsh = hash
                for i=2,cnt do
                    local c = readushort(f)
                    local h = hsh[c]
                    if not h then
                        h = { }
                        hsh[c] = h
                    end
                    hsh =  h
                end
                hsh.ligature = lig
            end
            coverage[index] = hash
        end
        return {
            coverage = coverage
        }
    else
        report("unsupported subtype %a in %a substitution",subtype,"ligature")
    end
end

function gsubhandlers.context(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    return unchainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"substitution"), "context"
end

function gsubhandlers.chainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    return chainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"substitution"), "chainedcontext"
end

function gsubhandlers.extension(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    return extension(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,gsubtypes,gsubhandlers,"substitution")
end

function gsubhandlers.reversechainedcontextsingle(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    local tableoffset = lookupoffset + offset
    setposition(f,tableoffset)
    local subtype = readushort(f)
    if subtype == 1 then -- NEEDS CHECKING
        local current      = readfirst(f)
        local before       = readarray(f)
        local after        = readarray(f)
        local replacements = readarray(f)
        current = readcoveragearray(f,tableoffset,current,true)
        before  = readcoveragearray(f,tableoffset,before,true)
        after   = readcoveragearray(f,tableoffset,after,true)
        return {
            coverage = {
                format       = "reversecoverage", -- reversesub
                before       = before,
                current      = current,
                after        = after,
                replacements = replacements,
            }
        }, "reversechainedcontextsingle"
    else
        report("unsupported subtype %a in %a substitution",subtype,"reversechainedcontextsingle")
    end
end

-- gpos handlers

local function readpairsets(f,tableoffset,sets,format1,format2)
    local done = { }
    for i=1,#sets do
        local offset = sets[i]
        local reused = done[offset]
        if not reused then
            setposition(f,tableoffset + offset)
            local n = readushort(f)
            reused = { }
            for i=1,n do
                reused[i] = {
                    readushort(f), -- second glyph id
                    readposition(f,format1),
                    readposition(f,format2)
                }
            end
            done[offset] = reused
        end
        sets[i] = reused
    end
    return sets
end

local function readpairclasssets(f,nofclasses1,nofclasses2,format1,format2)
    local classlist1  = { }
    for i=1,nofclasses1 do
        local classlist2 = { }
        classlist1[i] = classlist2
        for j=1,nofclasses2 do
            local one = readposition(f,format1)
            local two = readposition(f,format2)
            if one or two then
                classlist2[j] = { one, two }
            else
                classlist2[j] = false
            end
        end
    end
    return classlist1
end

-- no real gain in kerns as we pack

function gposhandlers.single(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    local tableoffset = lookupoffset + offset
    setposition(f,tableoffset)
    local subtype = readushort(f)
    if subtype == 1 then
        local coverage = readushort(f)
        local format   = readushort(f)
        local value    = readposition(f,format)
        local coverage = readcoverage(f,tableoffset+coverage)
        for index, newindex in next, coverage do
            coverage[index] = value
        end
        return {
            format   = "pair",
            coverage = coverage
        }
    elseif subtype == 2 then
        local coverage  = readushort(f)
        local format    = readushort(f)
        local values    = { }
        local nofvalues = readushort(f)
        for i=1,nofvalues do
            values[i] = readposition(f,format)
        end
        local coverage = readcoverage(f,tableoffset+coverage)
        for index, newindex in next, coverage do
            coverage[index] = values[newindex+1]
        end
        return {
            format   = "pair",
            coverage = coverage
        }
    else
        report("unsupported subtype %a in %a positioning",subtype,"single")
    end
end

-- this needs checking! if no second pair then another advance over the list

-- ValueFormat1 applies to the ValueRecord of the first glyph in each pair. ValueRecords for all first glyphs must use ValueFormat1. If ValueFormat1 is set to zero (0), the corresponding glyph has no ValueRecord and, therefore, should not be repositioned.
-- ValueFormat2 applies to the ValueRecord of the second glyph in each pair. ValueRecords for all second glyphs must use ValueFormat2. If ValueFormat2 is set to null, then the second glyph of the pair is the “next” glyph for which a lookup should be performed.

-- !!!!! this needs checking: when both false, we have no hit so then we might need to fall through

function gposhandlers.pair(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    local tableoffset = lookupoffset + offset
    setposition(f,tableoffset)
    local subtype = readushort(f)
    if subtype == 1 then
        local coverage = readushort(f)
        local format1  = readushort(f)
        local format2  = readushort(f)
        local sets     = readarray(f)
              sets     = readpairsets(f,tableoffset,sets,format1,format2)
              coverage = readcoverage(f,tableoffset + coverage)
        for index, newindex in next, coverage do
            local set  = sets[newindex+1]
            local hash = { }
            for i=1,#set do
                local value = set[i]
                if value then
                    local other  = value[1]
                    local first  = value[2]
                    local second = value[3]
                    if first or second then
                        hash[other] = { first, second } -- needs checking
                    else
                        hash[other] = nil
                    end
                end
            end
            coverage[index] = hash
        end
        return {
            format   = "pair",
            coverage = coverage
        }
    elseif subtype == 2 then
        local coverage     = readushort(f)
        local format1      = readushort(f)
        local format2      = readushort(f)
        local classdef1    = readushort(f)
        local classdef2    = readushort(f)
        local nofclasses1  = readushort(f) -- incl class 0
        local nofclasses2  = readushort(f) -- incl class 0
        local classlist    = readpairclasssets(f,nofclasses1,nofclasses2,format1,format2)
              coverage     = readcoverage(f,tableoffset+coverage)
              classdef1    = readclassdef(f,tableoffset+classdef1,coverage)
              classdef2    = readclassdef(f,tableoffset+classdef2,nofglyphs)
        local usedcoverage = { }
        for g1, c1 in next, classdef1 do
            if coverage[g1] then
                local l1 = classlist[c1]
                if l1 then
                    local hash = { }
                    for paired, class in next, classdef2 do
                        local offsets = l1[class]
                        if offsets then
                            local first  = offsets[1]
                            local second = offsets[2]
                            if first or second then
                                hash[paired] = { first, second }
                            else
                                -- upto the next lookup for this combination
                            end
                        end
                    end
                    usedcoverage[g1] = hash
                end
            end
        end
        return {
            format   = "pair",
            coverage = usedcoverage
        }
    elseif subtype == 3 then
        report("yet unsupported subtype %a in %a positioning",subtype,"pair")
    else
        report("unsupported subtype %a in %a positioning",subtype,"pair")
    end
end

function gposhandlers.cursive(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    local tableoffset = lookupoffset + offset
    setposition(f,tableoffset)
    local subtype = readushort(f)
    if subtype == 1 then
        local coverage   = tableoffset + readushort(f)
        local nofrecords = readushort(f)
        local records    = { }
        for i=1,nofrecords do
            local entry = readushort(f)
            local exit  = readushort(f)
            records[i] = {
                entry = entry ~= 0 and (tableoffset + entry) or false,
                exit  = exit  ~= 0 and (tableoffset + exit ) or false,
            }
        end
        coverage = readcoverage(f,coverage)
        for i=1,nofrecords do
            local r = records[i]
            records[i] = {
                1, -- will become hash after loading (must be unique per lookup when packed)
                readanchor(f,r.entry) or nil,
                readanchor(f,r.exit ) or nil,
            }
        end
        for index, newindex in next, coverage do
            coverage[index] = records[newindex+1]
        end
        return {
            coverage = coverage
        }
    else
        report("unsupported subtype %a in %a positioning",subtype,"cursive")
    end
end

local function handlemark(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,ligature)
    local tableoffset = lookupoffset + offset
    setposition(f,tableoffset)
    local subtype = readushort(f)
    if subtype == 1 then
        -- we are one based, not zero
        local markcoverage = tableoffset + readushort(f)
        local basecoverage = tableoffset + readushort(f)
        local nofclasses   = readushort(f)
        local markoffset   = tableoffset + readushort(f)
        local baseoffset   = tableoffset + readushort(f)
        --
        local markcoverage = readcoverage(f,markcoverage)
        local basecoverage = readcoverage(f,basecoverage,true) -- TO BE CHECKED: true
        --
        setposition(f,markoffset)
        local markclasses    = { }
        local nofmarkclasses = readushort(f)
        --
        local lastanchor  = fontdata.lastanchor or 0
        local usedanchors = { }
        --
--         local placeholder = (fontdata.markcount or 0) + 1
--         fontdata.markcount = placeholder
-- placeholder = "m" .. placeholder
        --
        for i=1,nofmarkclasses do
            local class  = readushort(f) + 1
            local offset = readushort(f)
            if offset == 0 then
                markclasses[i] = false
            else
--                 markclasses[i] = { placeholder, class, markoffset + offset }
                markclasses[i] = { class, markoffset + offset }
            end
            usedanchors[class] = true
        end
        for i=1,nofmarkclasses do
            local mc = markclasses[i]
            if mc then
--                 mc[3] = readanchor(f,mc[3])
                mc[2] = readanchor(f,mc[2])
            end
        end
        --
        setposition(f,baseoffset)
        local nofbaserecords = readushort(f)
        local baserecords    = { }
        --
        if ligature then
            -- 3 components
            -- 1 : class .. nofclasses -- NULL when empty
            -- 2 : class .. nofclasses -- NULL when empty
            -- 3 : class .. nofclasses -- NULL when empty
            for i=1,nofbaserecords do -- here i is the class
                local offset = readushort(f)
                if offset == 0 then
                    baserecords[i] = false
                else
                    baserecords[i] = baseoffset + offset
                end
            end
            for i=1,nofbaserecords do
                local recordoffset = baserecords[i]
                if recordoffset then
                    setposition(f,recordoffset)
                    local nofcomponents = readushort(f)
                    local components = { }
                    for i=1,nofcomponents do
                        local classes = { }
                        for i=1,nofclasses do
                            local offset = readushort(f)
                            if offset ~= 0 then
                                classes[i] = recordoffset + offset
                            else
                                classes[i] = false
                            end
                        end
                        components[i] = classes
                    end
                    baserecords[i] = components
                end
            end
            local baseclasses = { } -- setmetatableindex("table")
            for i=1,nofclasses do
                baseclasses[i] = { }
            end
            for i=1,nofbaserecords do
                local components = baserecords[i]
                if components then
                    local b = basecoverage[i]
                    for c=1,#components do
                        local classes = components[c]
                        if classes then
                            for i=1,nofclasses do
                                local anchor = readanchor(f,classes[i])
                                local bclass = baseclasses[i]
                                local bentry = bclass[b]
                                if bentry then
                                    bentry[c] = anchor
                                else
                                    bclass[b]= { [c] = anchor }
                                end
                            end
                        end
--                         components[i] = classes
                    end
                end
            end
            for index, newindex in next, markcoverage do
                markcoverage[index] = markclasses[newindex+1] or nil
            end
            return {
                format      = "ligature",
                baseclasses = baseclasses,
                coverage    = markcoverage,
            }
        else
            for i=1,nofbaserecords do
                local r = { }
                for j=1,nofclasses do
                    local offset = readushort(f)
                    if offset == 0 then
                        r[j] = false
                    else
                        r[j] = baseoffset + offset
                    end
                end
                baserecords[i] = r
            end
            local baseclasses = { } -- setmetatableindex("table")
            for i=1,nofclasses do
                baseclasses[i] = { }
            end
            for i=1,nofbaserecords do
                local r = baserecords[i]
                local b = basecoverage[i]
                for j=1,nofclasses do
                    baseclasses[j][b] = readanchor(f,r[j])
                end
            end
            for index, newindex in next, markcoverage do
                markcoverage[index] = markclasses[newindex+1] or nil
            end
            -- we could actually already calculate the displacement if we want
            return {
                format      = "base",
                baseclasses = baseclasses,
                coverage    = markcoverage,
            }
        end
    else
        report("unsupported subtype %a in",subtype)
    end

end

function gposhandlers.marktobase(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    return handlemark(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
end

function gposhandlers.marktoligature(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    return handlemark(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,true)
end

function gposhandlers.marktomark(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    return handlemark(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
end

function gposhandlers.context(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    return unchainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"positioning"), "context"
end

function gposhandlers.chainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    return chainedcontext(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,"positioning"), "chainedcontext"
end

function gposhandlers.extension(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs)
    return extension(f,fontdata,lookupid,lookupoffset,offset,glyphs,nofglyphs,gpostypes,gposhandlers,"positioning")
end

-- main loader

do

    local plugins = { }

    function plugins.size(f,fontdata,tableoffset,parameters)
        if not fontdata.designsize then
            setposition(f,tableoffset+parameters)
            local designsize = readushort(f)
            if designsize > 0 then
                fontdata.designsize    = designsize
                skipshort(f,2)
                fontdata.minsize = readushort(f)
                fontdata.maxsize = readushort(f)
            end
        end
    end

    -- feature order needs checking ... as we loop over a hash

    local function reorderfeatures(fontdata,scripts,features)
        local scriptlangs  = { }
        local featurehash  = { }
        local featureorder = { }
        for script, languages in next, scripts do
            for language, record in next, languages do
                local hash = { }
                local list = record.featureindices
                for k=1,#list do
                    local index   = list[k]
                    local feature = features[index]
                    local lookups = feature.lookups
                    local tag     = feature.tag
                    if tag then
                        hash[tag] = true
                    end
                    if lookups then
                        for i=1,#lookups do
                            local lookup = lookups[i]
                            local o = featureorder[lookup]
                            if o then
                                local okay = true
                                for i=1,#o do
                                    if o[i] == tag then
                                        okay = false
                                        break
                                    end
                                end
                                if okay then
                                    o[#o+1] = tag
                                end
                            else
                                featureorder[lookup] = { tag }
                            end
                            local f = featurehash[lookup]
                            if f then
                                local h = f[tag]
                                if h then
                                    local s = h[script]
                                    if s then
                                        s[language] = true
                                    else
                                        h[script] = { [language] = true }
                                    end
                                else
                                    f[tag] = { [script] = { [language] = true } }
                                end
                            else
                                featurehash[lookup] = { [tag] = { [script] = { [language] = true } } }
                            end
                            --
                            local h = scriptlangs[tag]
                            if h then
                                local s = h[script]
                                if s then
                                    s[language] = true
                                else
                                    h[script] = { [language] = true }
                                end
                            else
                                scriptlangs[tag] = { [script] = { [language] = true } }
                            end
                        end
                    end
                end
            end
        end
        return scriptlangs, featurehash, featureorder
    end

    local function readscriplan(f,fontdata,scriptoffset)
        setposition(f,scriptoffset)
        local nofscripts = readushort(f)
        local scripts    = { }
        for i=1,nofscripts do
            scripts[readtag(f)] = scriptoffset + readushort(f)
        end
        -- script list -> language system info
        local languagesystems = setmetatableindex("table")
        for script, offset in next, scripts do
            setposition(f,offset)
            local defaultoffset = readushort(f)
            local noflanguages  = readushort(f)
            local languages     = { }
            if defaultoffset > 0 then
                languages.dflt = languagesystems[offset + defaultoffset]
            end
            for i=1,noflanguages do
                local language      = readtag(f)
                local offset        = offset + readushort(f)
                languages[language] = languagesystems[offset]
            end
            scripts[script] = languages
        end
        -- script list -> language system info -> feature list
        for offset, usedfeatures in next, languagesystems do
            if offset > 0 then
                setposition(f,offset)
                local featureindices        = { }
                usedfeatures.featureindices = featureindices
                usedfeatures.lookuporder    = readushort(f) -- reserved, not used (yet)
                usedfeatures.requiredindex  = readushort(f) -- relates to required (can be 0xFFFF)
                local noffeatures           = readushort(f)
                for i=1,noffeatures do
                    featureindices[i] = readushort(f) + 1
                end
            end
        end
        return scripts
    end

    local function readfeatures(f,fontdata,featureoffset)
        setposition(f,featureoffset)
        local features    = { }
        local noffeatures = readushort(f)
        for i=1,noffeatures do
            -- also shared?
            features[i] = {
                tag    = readtag(f),
                offset = readushort(f)
            }
        end
        --
        for i=1,noffeatures do
            local feature = features[i]
            local offset  = featureoffset+feature.offset
            setposition(f,offset)
            local parameters = readushort(f) -- feature.parameters
            local noflookups = readushort(f)
            if noflookups > 0 then
                local lookups   = { }
                feature.lookups = lookups
                for j=1,noflookups do
                    lookups[j] = readushort(f) + 1
                end
            end
            if parameters > 0 then
                feature.parameters = parameters
                local plugin = plugins[feature.tag]
                if plugin then
                    plugin(f,fontdata,offset,parameters)
                end
            end
        end
        return features
    end

    local function readlookups(f,lookupoffset,lookuptypes,featurehash,featureorder)
        setposition(f,lookupoffset)
        local lookups    = { }
        local noflookups = readushort(f)
        for i=1,noflookups do
            lookups[i] = readushort(f)
        end
        for lookupid=1,noflookups do
            local index = lookups[lookupid]
            setposition(f,lookupoffset+index)
            local subtables    = { }
            local typebits     = readushort(f)
            local flagbits     = readushort(f)
            local lookuptype   = lookuptypes[typebits]
            local lookupflags  = lookupflags[flagbits]
            local nofsubtables = readushort(f)
            for j=1,nofsubtables do
                local offset = readushort(f)
                subtables[j] = offset + index -- we can probably put lookupoffset here
            end
            -- which one wins?
            local markclass = bittest(flagbits,0x0010) -- usemarkfilteringset
            if markclass then
                markclass = readushort(f) -- + 1
            end
            local markset = rshift(flagbits,8)
            if markset > 0 then
                markclass = markset -- + 1
            end
            lookups[lookupid] = {
                type      = lookuptype,
             -- chain     = chaindirections[lookuptype] or nil,
                flags     = lookupflags,
                name      = lookupid,
                subtables = subtables,
                markclass = markclass,
                features  = featurehash[lookupid], -- not if extension
                order     = featureorder[lookupid],
            }
        end
        return lookups
    end

    local function readscriptoffsets(f,fontdata,tableoffset)
        if not tableoffset then
            return
        end
        setposition(f,tableoffset)
        local version = readulong(f)
        if version ~= 0x00010000 then
            report("table version %a of %a is not supported (yet), maybe font %s is bad",version,what,fontdata.filename)
            return
        end
        --
        return tableoffset + readushort(f), tableoffset + readushort(f), tableoffset + readushort(f)
    end

    local f_lookupname = formatters["%s_%s_%s"]

    local function resolvelookups(f,lookupoffset,fontdata,lookups,lookuptypes,lookuphandlers,what)

        local sequences      = fontdata.sequences   or { }
        local sublookuplist  = fontdata.sublookups  or { }
        fontdata.sequences   = sequences
        fontdata.sublookups  = sublookuplist
        local nofsublookups  = #sublookuplist
        local nofsequences   = #sequences -- 0
        local lastsublookup  = nofsublookups
        local lastsequence   = nofsequences
        local lookupnames    = lookupnames[what]
        local sublookuphash  = { }
        local sublookupcheck = { }
        local glyphs         = fontdata.glyphs
        local nofglyphs      = fontdata.nofglyphs or #glyphs
        local noflookups     = #lookups
        local lookupprefix   = sub(what,2,2) -- g[s|p][ub|os]
        --
        for lookupid=1,noflookups do
            local lookup     = lookups[lookupid]
            local lookuptype = lookup.type
            local subtables  = lookup.subtables
            local features   = lookup.features
            local handler    = lookuphandlers[lookuptype]
            if handler then
                local nofsubtables = #subtables
                local order        = lookup.order
                local flags        = lookup.flags
                -- this is expected in th efont handler (faster checking)
                if flags[1] then flags[1] = "mark" end
                if flags[2] then flags[2] = "ligature" end
                if flags[3] then flags[3] = "base" end
                --
                local markclass    = lookup.markclass
             -- local chain        = lookup.chain
                if nofsubtables > 0 then
                    local steps     = { }
                    local nofsteps  = 0
                    local oldtype   = nil
                    for s=1,nofsubtables do
                        local step, lt = handler(f,fontdata,lookupid,lookupoffset,subtables[s],glyphs,nofglyphs)
                        if lt then
                            lookuptype = lt
                            if oldtype and lt ~= oldtype then
                                report("messy %s lookup type %a and %a",what,lookuptype,oldtype)
                            end
                            oldtype = lookuptype
                        end
                        if not step then
                            report("unsupported %s lookup type %a",what,lookuptype)
                        else
                            nofsteps = nofsteps + 1
                            steps[nofsteps] = step
                            local rules = step.rules
                            if rules then
                                for i=1,#rules do
                                    local rule    = rules[i]
                                    local before  = rule.before
                                    local current = rule.current
                                    local after   = rule.after
                                    if before then
                                        for i=1,#before do
                                            before[i] = tohash(before[i])
                                        end
                                        -- as with original ctx ff loader
                                        rule.before = reversed(before)
                                    end
                                    if current then
                                        for i=1,#current do
                                            current[i] = tohash(current[i])
                                        end
                                    end
                                    if after then
                                        for i=1,#after do
                                            after[i] = tohash(after[i])
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if nofsteps ~= nofsubtables then
                        report("bogus subtables removed in %s lookup type %a",what,lookuptype)
                    end
                    lookuptype = lookupnames[lookuptype] or lookuptype
                    if features then
                        nofsequences = nofsequences + 1
                     -- report("registering %i as sequence step %i",lookupid,nofsequences)
                        local l = {
                            index     = nofsequences,
                            name      = f_lookupname(lookupprefix,"s",lookupid+lookupidoffset),
                            steps     = steps,
                            nofsteps  = nofsteps,
                            type      = lookuptype,
                            markclass = markclass or nil,
                            flags     = flags,
                         -- chain     = chain,
                            order     = order,
                            features  = features,
                        }
                        sequences[nofsequences] = l
                        lookup.done = l
                    else
                        nofsublookups = nofsublookups + 1
                     -- report("registering %i as sublookup %i",lookupid,nofsublookups)
                        local l = {
                            index     = nofsublookups,
                            name      = f_lookupname(lookupprefix,"l",lookupid+lookupidoffset),
                            steps     = steps,
                            nofsteps  = nofsteps,
                            type      = lookuptype,
                            markclass = markclass or nil,
                            flags     = flags,
                         -- chain     = chain,
                        }
                        sublookuplist[nofsublookups] = l
                        sublookuphash[lookupid] = nofsublookups
                        sublookupcheck[lookupid] = 0
                        lookup.done = l
                    end
                else
                    report("no subtables for lookup %a",lookupid)
                end
            else
                report("no handler for lookup %a with type %a",lookupid,lookuptype)
            end
        end

        -- When we have a context, we have sublookups that resolve into lookups for which we need to
        -- know the type. We split the main lookuptable in two parts: sequences (the main lookups)
        -- and subtable lookups (simple specs with no features). We could keep them merged and might do
        -- that once we only use this loader. Then we can also move the simple specs into the sequence.
        -- After all, we pack afterwards.

        local reported = { }

        local function report_issue(i,what,sequence,kind)
            local name = sequence.name
            if not reported[name] then
                report("rule %i in %s lookup %a has %s lookups",i,what,name,kind)
                reported[name] = true
            end
        end

        for i=lastsequence+1,nofsequences do
            local sequence = sequences[i]
            local steps    = sequence.steps
            for i=1,#steps do
                local step  = steps[i]
                local rules = step.rules
                if rules then
                    for i=1,#rules do
                        local rule     = rules[i]
                        local rlookups = rule.lookups
                        if not rlookups then
                            report_issue(i,what,sequence,"no")
                        elseif not next(rlookups) then
                            -- can be ok as it aborts a chain sequence
                            report_issue(i,what,sequence,"empty")
                            rule.lookups = nil
                        else
                            -- we can have holes in rlookups
                         -- for index, lookupid in sortedhash(rlookups) do
                            local length = #rlookups
--                             for index in next, rlookups do
--                                 if index > length then
--                                     length = index
--                                 end
--                             end
                            for index=1,length do
                                local lookupid = rlookups[index]
                                if lookupid then
                                    local h = sublookuphash[lookupid]
                                    if not h then
                                        -- here we have a lookup that is used independent as well
                                        -- as in another one
                                        local lookup = lookups[lookupid]
                                        if lookup then
                                            local d = lookup.done
                                            if d then
                                                nofsublookups = nofsublookups + 1
                                             -- report("registering %i as sublookup %i",lookupid,nofsublookups)
                                                h = {
                                                    index     = nofsublookups, -- handy for tracing
                                                    name      = f_lookupname(lookupprefix,"d",lookupid+lookupidoffset),
                                                    derived   = true,          -- handy for tracing
                                                    steps     = d.steps,
                                                    nofsteps  = d.nofsteps,
                                                    type      = d.lookuptype,
                                                    markclass = d.markclass or nil,
                                                    flags     = d.flags,
                                                 -- chain     = d.chain,
                                                }
                                                sublookuplist[nofsublookups] = h
                                                sublookuphash[lookupid] = nofsublookups
                                                sublookupcheck[lookupid] = 1
                                            else
                                                report_issue(i,what,sequence,"missing")
                                                rule.lookups = nil
                                                break
                                            end
                                        else
                                            report_issue(i,what,sequence,"bad")
                                            rule.lookups = nil
                                            break
                                        end
                                    else
                                        sublookupcheck[lookupid] = sublookupcheck[lookupid] + 1
                                    end
                                    rlookups[index] = h or false
                                else
                                    rlookups[index] = false
                                end
                            end
                        end
                    end
                end
            end
        end

        for i, n in sortedhash(sublookupcheck) do
            local l = lookups[i]
            local t = l.type
            if n == 0 and t ~= "extension" then
                local d = l.done
                report("%s lookup %s of type %a is not used",what,d and d.name or l.name,t)
             -- inspect(l)
            end
        end

    end

    local function readscripts(f,fontdata,what,lookuptypes,lookuphandlers,lookupstoo)
        local datatable = fontdata.tables[what]
        if not datatable then
            return
        end
        local tableoffset = datatable.offset
        if not tableoffset then
            return
        end
        local scriptoffset, featureoffset, lookupoffset = readscriptoffsets(f,fontdata,tableoffset)
        if not scriptoffset then
            return
        end
        --
        local scripts  = readscriplan(f,fontdata,scriptoffset)
        local features = readfeatures(f,fontdata,featureoffset)
        --
        local scriptlangs, featurehash, featureorder = reorderfeatures(fontdata,scripts,features)
        --
        if fontdata.features then
            fontdata.features[what] = scriptlangs
        else
            fontdata.features = { [what] = scriptlangs }
        end
        --
        if not lookupstoo then
            return
        end
        --
        local lookups = readlookups(f,lookupoffset,lookuptypes,featurehash,featureorder)
        --
        if lookups then
            resolvelookups(f,lookupoffset,fontdata,lookups,lookuptypes,lookuphandlers,what)
        end
    end

    local function checkkerns(f,fontdata,specification)
        local datatable = fontdata.tables.kern
        if not datatable then
            return -- no kerns
        end
        local features     = fontdata.features
        local gposfeatures = features and features.gpos
        local name
        if not gposfeatures or not gposfeatures.kern then
            name = "kern"
        elseif specification.globalkerns then
            name = "globalkern"
        else
            report("ignoring global kern table using gpos kern feature")
            return
        end
        report("adding global kern table as gpos feature %a",name)
        setposition(f,datatable.offset)
        local version   = readushort(f)
        local noftables = readushort(f)
        local kerns     = setmetatableindex("table")
        for i=1,noftables do
            local version  = readushort(f)
            local length   = readushort(f)
            local coverage = readushort(f)
            -- bit 8-15 of coverage: format 0 or 2
            local format   = bit32.rshift(coverage,8) -- is this ok?
            if format == 0 then
                local nofpairs      = readushort(f)
                local searchrange   = readushort(f)
                local entryselector = readushort(f)
                local rangeshift    = readushort(f)
                for i=1,nofpairs do
                    kerns[readushort(f)][readushort(f)] = readfword(f)
                end
            elseif format == 2 then
                -- apple specific so let's ignore it
            else
                -- not supported by ms
            end
        end
        local feature = { dflt = { dflt = true } }
        if not features then
            fontdata.features = { gpos = { [name] = feature } }
        elseif not gposfeatures then
            fontdata.features.gpos = { [name] = feature }
        else
            gposfeatures[name] = feature
        end
        local sequences = fontdata.sequences
        if not sequences then
            sequences = { }
            fontdata.sequences = sequences
        end
        local nofsequences = #sequences + 1
        sequences[nofsequences] = {
            index     = nofsequences,
            name      = name,
            steps     = {
                {
                    coverage = kerns,
                    format   = "kern",
                },
            },
            nofsteps  = 1,
            type      = "gpos_pair",
         -- type      = "gpos_single", -- maybe better
            flags     = { false, false, false, false },
            order     = { name },
            features  = { [name] = feature },
        }
    end

    function readers.gsub(f,fontdata,specification)
        if specification.details then
            readscripts(f,fontdata,"gsub",gsubtypes,gsubhandlers,specification.lookups)
        end
    end

    function readers.gpos(f,fontdata,specification)
        if specification.details then
            readscripts(f,fontdata,"gpos",gpostypes,gposhandlers,specification.lookups)
            if specification.lookups then
                checkkerns(f,fontdata,specification)
            end
        end
    end

end

function readers.gdef(f,fontdata,specification)
    if specification.glyphs then
        local datatable = fontdata.tables.gdef
        if datatable then
            local tableoffset = datatable.offset
            setposition(f,tableoffset)
            local version          = readulong(f)
            local classoffset      = tableoffset + readushort(f)
            local attachmentoffset = tableoffset + readushort(f) -- used for bitmaps
            local ligaturecarets   = tableoffset + readushort(f) -- used in editors (maybe nice for tracing)
            local markclassoffset  = tableoffset + readushort(f)
            local marksetsoffset   = version == 0x00010002 and (tableoffset + readushort(f))
            local glyphs           = fontdata.glyphs
            local marks            = { }
            local markclasses      = setmetatableindex("table")
            local marksets         = setmetatableindex("table")
            fontdata.marks         = marks
            fontdata.markclasses   = markclasses
            fontdata.marksets      = marksets
            -- class definitions
            setposition(f,classoffset)
            local classformat = readushort(f)
            if classformat == 1 then
                local firstindex = readushort(f)
                local lastindex  = firstindex + readushort(f) - 1
                for index=firstindex,lastindex do
                    local class = classes[readushort(f)]
                    if class == "mark" then
                        marks[index] = true
                    end
                    glyphs[index].class = class
                end
            elseif classformat == 2 then
                local nofranges = readushort(f)
                for i=1,nofranges do
                    local firstindex = readushort(f)
                    local lastindex  = readushort(f)
                    local class      = classes[readushort(f)]
                    if class then
                        for index=firstindex,lastindex do
                            glyphs[index].class = class
                            if class == "mark" then
                                marks[index] = true
                            end
                        end
                    end
                end
            end
            -- mark classes
            setposition(f,markclassoffset)
            local classformat = readushort(f)
            if classformat == 1 then
                local firstindex = readushort(f)
                local lastindex  = firstindex + readushort(f) - 1
                for index=firstindex,lastindex do
                    markclasses[readushort(f)][index] = true
                end
            elseif classformat == 2 then
                local nofranges = readushort(f)
                for i=1,nofranges do
                    local firstindex = readushort(f)
                    local lastindex  = readushort(f)
                    local class      = markclasses[readushort(f)]
                    for index=firstindex,lastindex do
                        class[index] = true
                    end
                end
            end
            -- mark sets : todo: just make the same as class sets above
            if marksetsoffset then
                setposition(f,marksetsoffset)
                local format = readushort(f)
                if format == 1 then
                    local nofsets = readushort(f)
                    local sets    = { }
                    for i=1,nofsets do
                        sets[i] = readulong(f)
                    end
                    -- somehow this fails on e.g. notosansethiopic-bold.ttf
                    for i=1,nofsets do
                        local offset = sets[i]
                        if offset ~= 0 then
                            marksets[i] = readcoverage(f,marksetsoffset+offset)
                        end
                    end
                end
            end
        end
    end
end

-- We keep this code here instead of font-otm.lua because we need coverage
-- helpers. Okay, these helpers could go to the main reader file some day.

local function readmathvalue(f)
    local v = readshort(f)
    skipshort(f,1) -- offset to device table
    return v
end

local function readmathconstants(f,fontdata,offset)
    setposition(f,offset)
    fontdata.mathconstants = {
        ScriptPercentScaleDown                   = readshort(f),
        ScriptScriptPercentScaleDown             = readshort(f),
        DelimitedSubFormulaMinHeight             = readushort(f),
        DisplayOperatorMinHeight                 = readushort(f),
        MathLeading                              = readmathvalue(f),
        AxisHeight                               = readmathvalue(f),
        AccentBaseHeight                         = readmathvalue(f),
        FlattenedAccentBaseHeight                = readmathvalue(f),
        SubscriptShiftDown                       = readmathvalue(f),
        SubscriptTopMax                          = readmathvalue(f),
        SubscriptBaselineDropMin                 = readmathvalue(f),
        SuperscriptShiftUp                       = readmathvalue(f),
        SuperscriptShiftUpCramped                = readmathvalue(f),
        SuperscriptBottomMin                     = readmathvalue(f),
        SuperscriptBaselineDropMax               = readmathvalue(f),
        SubSuperscriptGapMin                     = readmathvalue(f),
        SuperscriptBottomMaxWithSubscript        = readmathvalue(f),
        SpaceAfterScript                         = readmathvalue(f),
        UpperLimitGapMin                         = readmathvalue(f),
        UpperLimitBaselineRiseMin                = readmathvalue(f),
        LowerLimitGapMin                         = readmathvalue(f),
        LowerLimitBaselineDropMin                = readmathvalue(f),
        StackTopShiftUp                          = readmathvalue(f),
        StackTopDisplayStyleShiftUp              = readmathvalue(f),
        StackBottomShiftDown                     = readmathvalue(f),
        StackBottomDisplayStyleShiftDown         = readmathvalue(f),
        StackGapMin                              = readmathvalue(f),
        StackDisplayStyleGapMin                  = readmathvalue(f),
        StretchStackTopShiftUp                   = readmathvalue(f),
        StretchStackBottomShiftDown              = readmathvalue(f),
        StretchStackGapAboveMin                  = readmathvalue(f),
        StretchStackGapBelowMin                  = readmathvalue(f),
        FractionNumeratorShiftUp                 = readmathvalue(f),
        FractionNumeratorDisplayStyleShiftUp     = readmathvalue(f),
        FractionDenominatorShiftDown             = readmathvalue(f),
        FractionDenominatorDisplayStyleShiftDown = readmathvalue(f),
        FractionNumeratorGapMin                  = readmathvalue(f),
        FractionNumeratorDisplayStyleGapMin      = readmathvalue(f),
        FractionRuleThickness                    = readmathvalue(f),
        FractionDenominatorGapMin                = readmathvalue(f),
        FractionDenominatorDisplayStyleGapMin    = readmathvalue(f),
        SkewedFractionHorizontalGap              = readmathvalue(f),
        SkewedFractionVerticalGap                = readmathvalue(f),
        OverbarVerticalGap                       = readmathvalue(f),
        OverbarRuleThickness                     = readmathvalue(f),
        OverbarExtraAscender                     = readmathvalue(f),
        UnderbarVerticalGap                      = readmathvalue(f),
        UnderbarRuleThickness                    = readmathvalue(f),
        UnderbarExtraDescender                   = readmathvalue(f),
        RadicalVerticalGap                       = readmathvalue(f),
        RadicalDisplayStyleVerticalGap           = readmathvalue(f),
        RadicalRuleThickness                     = readmathvalue(f),
        RadicalExtraAscender                     = readmathvalue(f),
        RadicalKernBeforeDegree                  = readmathvalue(f),
        RadicalKernAfterDegree                   = readmathvalue(f),
        RadicalDegreeBottomRaisePercent          = readshort(f),
    }
end

local function readmathglyphinfo(f,fontdata,offset)
    setposition(f,offset)
    local italics    = readushort(f)
    local accents    = readushort(f)
    local extensions = readushort(f)
    local kerns      = readushort(f)
    local glyphs     = fontdata.glyphs
    if italics ~= 0 then
        setposition(f,offset+italics)
        local coverage  = readushort(f)
        local nofglyphs = readushort(f)
        coverage = readcoverage(f,offset+italics+coverage,true)
        setposition(f,offset+italics+4)
        for i=1,nofglyphs do
            local italic = readmathvalue(f)
            if italic ~= 0 then
                local glyph = glyphs[coverage[i]]
                local math  = glyph.math
                if not math then
                    glyph.math = { italic = italic }
                else
                    math.italic = italic
                end
            end
        end
        fontdata.hasitalics = true
    end
    if accents ~= 0 then
        setposition(f,offset+accents)
        local coverage  = readushort(f)
        local nofglyphs = readushort(f)
        coverage = readcoverage(f,offset+accents+coverage,true)
        setposition(f,offset+accents+4)
        for i=1,nofglyphs do
            local accent = readmathvalue(f)
            if accent ~= 0 then
                local glyph = glyphs[coverage[i]]
                local math  = glyph.math
                if not math then
                    glyph.math = { accent = accent }
                else
                    math.accent = accent
                end
            end
        end
    end
    if extensions ~= 0 then
        setposition(f,offset+extensions)
    end
    if kerns ~= 0 then
        local kernoffset = offset + kerns
        setposition(f,kernoffset)
        local coverage  = readushort(f)
        local nofglyphs = readushort(f)
        if nofglyphs > 0 then
            local function get(offset)
                setposition(f,kernoffset+offset)
                local n = readushort(f)
                if n == 0 then
                    local k = readmathvalue(f)
                    if k == 0 then
                        -- no need for it (happens sometimes)
                    else
                        return { { kern = k } }
                    end
                else
                    local l = { }
                    for i=1,n do
                        l[i] = { height = readmathvalue(f) }
                    end
                    for i=1,n do
                        l[i].kern = readmathvalue(f)
                    end
                    l[n+1] = { kern = readmathvalue(f) }
                    return l
                end
            end
            local kernsets = { }
            for i=1,nofglyphs do
                local topright    = readushort(f)
                local topleft     = readushort(f)
                local bottomright = readushort(f)
                local bottomleft  = readushort(f)
                kernsets[i] = {
                    topright    = topright    ~= 0 and topright    or nil,
                    topleft     = topleft     ~= 0 and topleft     or nil,
                    bottomright = bottomright ~= 0 and bottomright or nil,
                    bottomleft  = bottomleft  ~= 0 and bottomleft  or nil,
                }
            end
            coverage = readcoverage(f,kernoffset+coverage,true)
            for i=1,nofglyphs do
                local kernset = kernsets[i]
                if next(kernset) then
                    local k = kernset.topright    if k then kernset.topright    = get(k) end
                    local k = kernset.topleft     if k then kernset.topleft     = get(k) end
                    local k = kernset.bottomright if k then kernset.bottomright = get(k) end
                    local k = kernset.bottomleft  if k then kernset.bottomleft  = get(k) end
                    if next(kernset) then
                        local glyph = glyphs[coverage[i]]
                        local math  = glyph.math
                        if math then
                            math.kerns = kernset
                        else
                            glyph.math = { kerns = kernset }
                        end
                    end
                end
            end
        end
    end
end

local function readmathvariants(f,fontdata,offset)
    setposition(f,offset)
    local glyphs        = fontdata.glyphs
    local minoverlap    = readushort(f)
    local vcoverage     = readushort(f)
    local hcoverage     = readushort(f)
    local vnofglyphs    = readushort(f)
    local hnofglyphs    = readushort(f)
    local vconstruction = { }
    local hconstruction = { }
    for i=1,vnofglyphs do
        vconstruction[i] = readushort(f)
    end
    for i=1,hnofglyphs do
        hconstruction[i] = readushort(f)
    end

    fontdata.mathconstants.MinConnectorOverlap = minoverlap

    -- variants[i] = {
    --     glyph   = readushort(f),
    --     advance = readushort(f),
    -- }

    local function get(offset,coverage,nofglyphs,construction,kvariants,kparts,kitalic)
        if coverage ~= 0 and nofglyphs > 0 then
            local coverage = readcoverage(f,offset+coverage,true)
            for i=1,nofglyphs do
                local c = construction[i]
                if c ~= 0 then
                    local index = coverage[i]
                    local glyph = glyphs[index]
                    local math  = glyph.math
                    setposition(f,offset+c)
                    local assembly    = readushort(f)
                    local nofvariants = readushort(f)
                    if nofvariants > 0 then
                        local variants, v = nil, 0
                        for i=1,nofvariants do
                            local variant = readushort(f)
                            if variant == index then
                                -- ignore
                            elseif variants then
                                v = v + 1
                                variants[v] = variant
                            else
                                v = 1
                                variants = { variant }
                            end
                            skipshort(f)
                        end
                        if not variants then
                            -- only self
                        elseif not math then
                            math = { [kvariants] = variants }
                            glyph.math = math
                        else
                            math[kvariants] = variants
                        end
                    end
                    if assembly ~= 0 then
                        setposition(f,offset + c + assembly)
                        local italic   = readmathvalue(f)
                        local nofparts = readushort(f)
                        local parts    = { }
                        for i=1,nofparts do
                            local p = {
                                glyph   = readushort(f),
                                start   = readushort(f),
                                ["end"] = readushort(f),
                                advance = readushort(f),
                            }
                            local flags = readushort(f)
                            if bittest(flags,0x0001) then
                                p.extender = 1 -- true
                            end
                            parts[i] = p
                        end
                        if not math then
                            math = {
                                [kparts] = parts
                            }
                            glyph.math = math
                        else
                            math[kparts] = parts
                        end
                        if italic and italic ~= 0 then
                            math[kitalic] = italic
                        end
                    end
                end
            end
        end
    end

    get(offset,vcoverage,vnofglyphs,vconstruction,"vvariants","vparts","vitalic")
    get(offset,hcoverage,hnofglyphs,hconstruction,"hvariants","hparts","hitalic")
end

function readers.math(f,fontdata,specification)
    if specification.glyphs then
        local datatable = fontdata.tables.math
        if datatable then
            local tableoffset = datatable.offset
            setposition(f,tableoffset)
            local version = readulong(f)
            if version ~= 0x00010000 then
                report("table version %a of %a is not supported (yet), maybe font %s is bad",version,"math",fontdata.filename)
                return
            end
            local constants = readushort(f)
            local glyphinfo = readushort(f)
            local variants  = readushort(f)
            if constants == 0 then
                report("the math table of %a has no constants",fontdata.filename)
            else
                readmathconstants(f,fontdata,tableoffset+constants)
            end
            if glyphinfo ~= 0 then
                readmathglyphinfo(f,fontdata,tableoffset+glyphinfo)
            end
            if variants ~= 0 then
                readmathvariants(f,fontdata,tableoffset+variants)
            end
        end
    end
end

function readers.colr(f,fontdata,specification)
    local datatable = fontdata.tables.colr
    if datatable then
        if specification.glyphs then
            local tableoffset = datatable.offset
            setposition(f,tableoffset)
            local version = readushort(f)
            if version ~= 0 then
                report("table version %a of %a is not supported (yet), maybe font %s is bad",version,"colr",fontdata.filename)
                return
            end
            if not fontdata.tables.cpal then
                report("color table %a in font %a has no mandate %a table","colr",fontdata.filename,"cpal")
                fontdata.colorpalettes = { }
            end
            local glyphs       = fontdata.glyphs
            local nofglyphs    = readushort(f)
            local baseoffset   = readulong(f)
            local layeroffset  = readulong(f)
            local noflayers    = readushort(f)
            local layerrecords = { }
            local maxclass     = 0
            -- The special value 0xFFFF is foreground (but we index from 1). It
            -- more looks like indices into a palette so 'class' is a better name
            -- than 'palette'.
            setposition(f,tableoffset + layeroffset)
            for i=1,noflayers do
                local slot    = readushort(f)
                local class = readushort(f)
                if class < 0xFFFF then
                    class = class + 1
                    if class > maxclass then
                        maxclass = class
                    end
                end
                layerrecords[i] = {
                    slot  = slot,
                    class = class,
                }
            end
            fontdata.maxcolorclass = maxclass
            setposition(f,tableoffset + baseoffset)
            for i=0,nofglyphs-1 do
                local glyphindex = readushort(f)
                local firstlayer = readushort(f)
                local noflayers  = readushort(f)
                local t = { }
                for i=1,noflayers do
                    t[i] = layerrecords[firstlayer+i]
                end
                glyphs[glyphindex].colors = t
            end
        end
        fontdata.hascolor = true
    end
end

function readers.cpal(f,fontdata,specification)
    if specification.glyphs then
        local datatable = fontdata.tables.cpal
        if datatable then
            local tableoffset = datatable.offset
            setposition(f,tableoffset)
            local version = readushort(f)
            if version > 1 then
                report("table version %a of %a is not supported (yet), maybe font %s is bad",version,"cpal",fontdata.filename)
                return
            end
            local nofpaletteentries  = readushort(f)
            local nofpalettes        = readushort(f)
            local nofcolorrecords    = readushort(f)
            local firstcoloroffset   = readulong(f)
            local colorrecords       = { }
            local palettes           = { }
            for i=1,nofpalettes do
                palettes[i] = readushort(f)
            end
            if version == 1 then
                -- used for guis
                local palettettypesoffset = readulong(f)
                local palettelabelsoffset = readulong(f)
                local paletteentryoffset  = readulong(f)
            end
            setposition(f,tableoffset+firstcoloroffset)
            for i=1,nofcolorrecords do
                local b, g, r, a = readbytes(f,4)
                colorrecords[i] = {
                    r, g, b, a ~= 255 and a or nil,
                }
            end
            for i=1,nofpalettes do
                local p = { }
                local o = palettes[i]
                for j=1,nofpaletteentries do
                    p[j] = colorrecords[o+j]
                end
                palettes[i] = p
            end
            fontdata.colorpalettes = palettes
        end
    end
end

function readers.svg(f,fontdata,specification)
    local datatable = fontdata.tables.svg
    if datatable then
        if specification.glyphs then
            local tableoffset = datatable.offset
            setposition(f,tableoffset)
            local version = readushort(f)
            if version ~= 0 then
                report("table version %a of %a is not supported (yet), maybe font %s is bad",version,"svg",fontdata.filename)
                return
            end
            local glyphs      = fontdata.glyphs
            local indexoffset = tableoffset + readulong(f)
            local reserved    = readulong(f)
            setposition(f,indexoffset)
            local nofentries  = readushort(f)
            local entries     = { }
            for i=1,nofentries do
                entries[i] = {
                    first  = readushort(f),
                    last   = readushort(f),
                    offset = indexoffset + readulong(f),
                    length = readulong(f),
                }
            end
            for i=1,nofentries do
                local entry = entries[i]
                setposition(f,entry.offset)
                entries[i] = {
                    first = entry.first,
                    last  = entry.last,
                    data  = readstring(f,entry.length)
                }
            end
            fontdata.svgshapes = entries
        end
        fontdata.hascolor = true
    end
end
