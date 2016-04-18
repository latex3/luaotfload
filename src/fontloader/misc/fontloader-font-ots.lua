if not modules then modules = { } end modules ['font-ots'] = { -- sequences
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- to be checked: discrun doesn't seem to do something useful now (except run the
-- check again) so if we need it again we'll do a zwnjrun or so

-- beware, on my development machine we test a slightly a more optimized version

-- assumptions:
--
-- cursives don't cross discretionaries
-- marks precede bases
--
-- pitfalls:
--
-- when we append to a dics field we need to set the field in order to update tail
--
-- This is a version of font-otn.lua adapted to the new font loader code. It
-- is a context version which can contain experimental code, but when we
-- have serious patches we will backport to the font-otn files. The plain
-- loader that ships with context also uses this now.
--
-- todo: looks like we have a leak somewhere (probably in ligatures)
-- todo: copy attributes to disc
-- todo: get rid of components, better use the tounicode entry if needed (at all)
--
-- we do some disc juggling where we need to keep in mind that the
-- pre, post and replace fields can have prev pointers to a nesting
-- node ... i wonder if that is still needed
--
-- not possible:
--
-- \discretionary {alpha-} {betagammadelta}
--   {\discretionary {alphabeta-} {gammadelta}
--      {\discretionary {alphabetagamma-} {delta}
--         {alphabetagammadelta}}}

--[[ldx--
<p>This module is a bit more split up that I'd like but since we also want to test
with plain <l n='tex'/> it has to be so. This module is part of <l n='context'/>
and discussion about improvements and functionality mostly happens on the
<l n='context'/> mailing list.</p>

<p>The specification of OpenType is kind of vague. Apart from a lack of a proper
free specifications there's also the problem that Microsoft and Adobe
may have their own interpretation of how and in what order to apply features.
In general the Microsoft website has more detailed specifications and is a
better reference. There is also some information in the FontForge help files.</p>

<p>Because there is so much possible, fonts might contain bugs and/or be made to
work with certain rederers. These may evolve over time which may have the side
effect that suddenly fonts behave differently.</p>

<p>After a lot of experiments (mostly by Taco, me and Idris) we're now at yet another
implementation. Of course all errors are mine and of course the code can be
improved. There are quite some optimizations going on here and processing speed
is currently acceptable. Not all functions are implemented yet, often because I
lack the fonts for testing. Many scripts are not yet supported either, but I will
look into them as soon as <l n='context'/> users ask for it.</p>

<p>The specification leaves room for interpretation. In case of doubt the microsoft
implementation is the reference as it is the most complete one. As they deal with
lots of scripts and fonts, Kai and Ivo did a lot of testing of the generic code and
their suggestions help improve the code. I'm aware that not all border cases can be
taken care of, unless we accept excessive runtime, and even then the interference
with other mechanisms (like hyphenation) are not trivial.</p>

<p>Glyphs are indexed not by unicode but in their own way. This is because there is no
relationship with unicode at all, apart from the fact that a font might cover certain
ranges of characters. One character can have multiple shapes. However, at the
<l n='tex'/> end we use unicode so and all extra glyphs are mapped into a private
space. This is needed because we need to access them and <l n='tex'/> has to include
then in the output eventually.</p>

<p>The initial data table is rather close to the open type specification and also not
that different from the one produced by <l n='fontforge'/> but we uses hashes instead.
In <l n='context'/> that table is packed (similar tables are shared) and cached on disk
so that successive runs can use the optimized table (after loading the table is
unpacked). The flattening code used later is a prelude to an even more compact table
format (and as such it keeps evolving).</p>

<p>This module is sparsely documented because it is a moving target. The table format
of the reader changes and we experiment a lot with different methods for supporting
features.</p>

<p>As with the <l n='afm'/> code, we may decide to store more information in the
<l n='otf'/> table.</p>

<p>Incrementing the version number will force a re-cache. We jump the number by one
when there's a fix in the <l n='fontforge'/> library or <l n='lua'/> code that
results in different tables.</p>
--ldx]]--

local type, next, tonumber = type, next, tonumber
local random = math.random
local formatters = string.formatters
local insert = table.insert

local logs, trackers, nodes, attributes = logs, trackers, nodes, attributes

local registertracker   = trackers.register
local registerdirective = directives.register

local fonts = fonts
local otf   = fonts.handlers.otf

local trace_lookups      = false  registertracker("otf.lookups",      function(v) trace_lookups      = v end)
local trace_singles      = false  registertracker("otf.singles",      function(v) trace_singles      = v end)
local trace_multiples    = false  registertracker("otf.multiples",    function(v) trace_multiples    = v end)
local trace_alternatives = false  registertracker("otf.alternatives", function(v) trace_alternatives = v end)
local trace_ligatures    = false  registertracker("otf.ligatures",    function(v) trace_ligatures    = v end)
local trace_contexts     = false  registertracker("otf.contexts",     function(v) trace_contexts     = v end)
local trace_marks        = false  registertracker("otf.marks",        function(v) trace_marks        = v end)
local trace_kerns        = false  registertracker("otf.kerns",        function(v) trace_kerns        = v end)
local trace_cursive      = false  registertracker("otf.cursive",      function(v) trace_cursive      = v end)
local trace_preparing    = false  registertracker("otf.preparing",    function(v) trace_preparing    = v end)
local trace_bugs         = false  registertracker("otf.bugs",         function(v) trace_bugs         = v end)
local trace_details      = false  registertracker("otf.details",      function(v) trace_details      = v end)
local trace_applied      = false  registertracker("otf.applied",      function(v) trace_applied      = v end)
local trace_steps        = false  registertracker("otf.steps",        function(v) trace_steps        = v end)
local trace_skips        = false  registertracker("otf.skips",        function(v) trace_skips        = v end)
local trace_directions   = false  registertracker("otf.directions",   function(v) trace_directions   = v end)

local trace_kernruns     = false  registertracker("otf.kernruns",     function(v) trace_kernruns     = v end)
local trace_discruns     = false  registertracker("otf.discruns",     function(v) trace_discruns     = v end)
local trace_compruns     = false  registertracker("otf.compruns",     function(v) trace_compruns     = v end)
local trace_testruns     = false  registertracker("otf.testruns",     function(v) trace_testruns     = v end)

local quit_on_no_replacement = true  -- maybe per font
local zwnjruns               = true
local optimizekerns          = true

registerdirective("otf.zwnjruns",                 function(v) zwnjruns = v end)
registerdirective("otf.chain.quitonnoreplacement",function(value) quit_on_no_replacement = value end)

local report_direct   = logs.reporter("fonts","otf direct")
local report_subchain = logs.reporter("fonts","otf subchain")
local report_chain    = logs.reporter("fonts","otf chain")
local report_process  = logs.reporter("fonts","otf process")
----- report_prepare  = logs.reporter("fonts","otf prepare")
local report_warning  = logs.reporter("fonts","otf warning")
local report_run      = logs.reporter("fonts","otf run")
local report_check    = logs.reporter("fonts","otf check")

registertracker("otf.replacements", "otf.singles,otf.multiples,otf.alternatives,otf.ligatures")
registertracker("otf.positions","otf.marks,otf.kerns,otf.cursive")
registertracker("otf.actions","otf.replacements,otf.positions")
registertracker("otf.injections","nodes.injections")

registertracker("*otf.sample","otf.steps,otf.actions,otf.analyzing")

local nuts               = nodes.nuts
local tonode             = nuts.tonode
local tonut              = nuts.tonut

local getfield           = nuts.getfield
local setfield           = nuts.setfield
local getnext            = nuts.getnext
local setnext            = nuts.setnext
local getprev            = nuts.getprev
local setprev            = nuts.setprev
local getboth            = nuts.getboth
local setboth            = nuts.setboth
local getid              = nuts.getid
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getprop            = nuts.getprop
local setprop            = nuts.setprop
local getfont            = nuts.getfont
local getsubtype         = nuts.getsubtype
local setsubtype         = nuts.setsubtype
local getchar            = nuts.getchar
local setchar            = nuts.setchar
local getdisc            = nuts.getdisc
local setdisc            = nuts.setdisc
local setlink            = nuts.setlink

local ischar             = nuts.is_char

local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local delete_node        = nuts.delete
local remove_node        = nuts.remove
local copy_node          = nuts.copy
local copy_node_list     = nuts.copy_list
local find_node_tail     = nuts.tail
local flush_node_list    = nuts.flush_list
local free_node          = nuts.free
local end_of_math        = nuts.end_of_math
local traverse_nodes     = nuts.traverse
local traverse_id        = nuts.traverse_id

local setmetatableindex  = table.setmetatableindex

local zwnj               = 0x200C
local zwj                = 0x200D
local wildcard           = "*"
local default            = "dflt"

local nodecodes          = nodes.nodecodes
local glyphcodes         = nodes.glyphcodes
local disccodes          = nodes.disccodes

local glyph_code         = nodecodes.glyph
local glue_code          = nodecodes.glue
local disc_code          = nodecodes.disc
local math_code          = nodecodes.math
local dir_code           = nodecodes.dir
local localpar_code      = nodecodes.localpar

local discretionary_code = disccodes.discretionary
local ligature_code      = glyphcodes.ligature

local privateattribute   = attributes.private

-- Something is messed up: we have two mark / ligature indices, one at the injection
-- end and one here ... this is based on KE's patches but there is something fishy
-- there as I'm pretty sure that for husayni we need some connection (as it's much
-- more complex than an average font) but I need proper examples of all cases, not
-- of only some.

local a_state            = privateattribute('state')

local injections         = nodes.injections
local setmark            = injections.setmark
local setcursive         = injections.setcursive
local setkern            = injections.setkern
local setpair            = injections.setpair
local resetinjection     = injections.reset
local copyinjection      = injections.copy
local setligaindex       = injections.setligaindex
local getligaindex       = injections.getligaindex

local cursonce           = true

local fonthashes         = fonts.hashes
local fontdata           = fonthashes.identifiers

local otffeatures        = fonts.constructors.newfeatures("otf")
local registerotffeature = otffeatures.register

local onetimemessage     = fonts.loggers.onetimemessage or function() end

otf.defaultnodealternate = "none" -- first last

-- We use a few global variables. The handler can be called nested but this assumes that the
-- same font is used. Nested calls are normally not needed (only for devanagari).

local tfmdata         = false
local characters      = false
local descriptions    = false
local marks           = false
local currentfont     = false
local factor          = 0
local threshold       = 0

local sweepnode       = nil
local sweepprev       = nil
local sweepnext       = nil
local sweephead       = { }

local notmatchpre     = { }
local notmatchpost    = { }
local notmatchreplace = { }

local handlers        = { }

-- helper

local function isspace(n)
    if getid(n) == glue_code then
        local w = getfield(n,"width")
        if w >= threshold then
            return 32
        end
    end
end

-- we use this for special testing and documentation

local checkstep       = (nodes and nodes.tracers and nodes.tracers.steppers.check)    or function() end
local registerstep    = (nodes and nodes.tracers and nodes.tracers.steppers.register) or function() end
local registermessage = (nodes and nodes.tracers and nodes.tracers.steppers.message)  or function() end

local function logprocess(...)
    if trace_steps then
        registermessage(...)
    end
    report_direct(...)
end

local function logwarning(...)
    report_direct(...)
end

local f_unicode = formatters["%U"]
local f_uniname = formatters["%U (%s)"]
local f_unilist = formatters["% t (% t)"]

local function gref(n) -- currently the same as in font-otb
    if type(n) == "number" then
        local description = descriptions[n]
        local name = description and description.name
        if name then
            return f_uniname(n,name)
        else
            return f_unicode(n)
        end
    elseif n then
        local num, nam = { }, { }
        for i=1,#n do
            local ni = n[i]
            if tonumber(ni) then -- later we will start at 2
                local di = descriptions[ni]
                num[i] = f_unicode(ni)
                nam[i] = di and di.name or "-"
            end
        end
        return f_unilist(num,nam)
    else
        return "<error in node mode tracing>"
    end
end

local function cref(dataset,sequence,index)
    if not dataset then
        return "no valid dataset"
    elseif index then
        return formatters["feature %a, type %a, chain lookup %a, index %a"](dataset[4],sequence.type,sequence.name,index)
    else
        return formatters["feature %a, type %a, chain lookup %a"](dataset[4],sequence.type,sequence.name)
    end
end

local function pref(dataset,sequence)
    return formatters["feature %a, type %a, lookup %a"](dataset[4],sequence.type,sequence.name)
end

local function mref(rlmode)
    if not rlmode or rlmode == 0 then
        return "---"
    elseif rlmode == -1 or rlmode == "+TRT" then
        return "r2l"
    else
        return "l2r"
    end
end

-- We can assume that languages that use marks are not hyphenated. We can also assume
-- that at most one discretionary is present.

-- We do need components in funny kerning mode but maybe I can better reconstruct then
-- as we do have the font components info available; removing components makes the
-- previous code much simpler. Also, later on copying and freeing becomes easier.
-- However, for arabic we need to keep them around for the sake of mark placement
-- and indices.

local function copy_glyph(g) -- next and prev are untouched !
    local components = getfield(g,"components")
    if components then
        setfield(g,"components",nil)
        local n = copy_node(g)
        copyinjection(n,g) -- we need to preserve the lig indices
        setfield(g,"components",components)
        return n
    else
        local n = copy_node(g)
        copyinjection(n,g) -- we need to preserve the lig indices
        return n
    end
end

local function flattendisk(head,disc)
    local _, _, replace, _, _, replacetail = getdisc(disc,true)
    setfield(disc,"replace",nil)
    free_node(disc)
    if head == disc then
        local next = getnext(disc)
        if replace then
            if next then
                setlink(replacetail,next)
            end
            return replace, replace
        elseif next then
            return next, next
        else
            return -- maybe warning
        end
    else
        local prev, next = getboth(disc)
        if replace then
            if next then
                setlink(replacetail,next)
            end
            setlink(prev,replace)
            return head, replace
        else
            setlink(prev,next) -- checks for next anyway
            return head, next
        end
    end
end

local function appenddisc(disc,list)
    local pre, post, replace, pretail, posttail, replacetail = getdisc(disc,true)
    local posthead    = list
    local replacehead = copy_node_list(list)
    if post then
        setlink(posttail,posthead)
    else
        post = phead
    end
    if replace then
        setlink(replacetail,replacehead)
    else
        replace = rhead
    end
    setdisc(disc,pre,post,replace)
end

-- start is a mark and we need to keep that one

local function markstoligature(head,start,stop,char)
    if start == stop and getchar(start) == char then
        return head, start
    else
        local prev = getprev(start)
        local next = getnext(stop)
        setprev(start,nil)
        setnext(stop,nil)
        local base = copy_glyph(start)
        if head == start then
            head = base
        end
        resetinjection(base)
        setchar(base,char)
        setsubtype(base,ligature_code)
        setfield(base,"components",start)
        setlink(prev,base)
        setlink(base,next)
        return head, base
    end
end

-- The next code is somewhat complicated by the fact that some fonts can have ligatures made
-- from ligatures that themselves have marks. This was identified by Kai in for instance
-- arabtype:  KAF LAM SHADDA ALEF FATHA (0x0643 0x0644 0x0651 0x0627 0x064E). This becomes
-- KAF LAM-ALEF with a SHADDA on the first and a FATHA op de second component. In a next
-- iteration this becomes a KAF-LAM-ALEF with a SHADDA on the second and a FATHA on the
-- third component.

local function getcomponentindex(start) -- we could store this offset in the glyph (nofcomponents)
    if getid(start) ~= glyph_code then  -- and then get rid of all components
        return 0
    elseif getsubtype(start) == ligature_code then
        local i = 0
        local components = getfield(start,"components")
        while components do
            i = i + getcomponentindex(components)
            components = getnext(components)
        end
        return i
    elseif not marks[getchar(start)] then
        return 1
    else
        return 0
    end
end

local a_noligature = attributes.private("noligature")

local function toligature(head,start,stop,char,dataset,sequence,markflag,discfound) -- brr head
    if getattr(start,a_noligature) == 1 then
        -- so we can do: e\noligature{ff}e e\noligature{f}fie (we only look at the first)
        return head, start
    end
    if start == stop and getchar(start) == char then
        resetinjection(start)
        setchar(start,char)
        return head, start
    end
    -- needs testing (side effects):
    local components = getfield(start,"components")
    if components then
     -- we get a double free .. needs checking
     -- flush_node_list(components)
    end
    --
    local prev = getprev(start)
    local next = getnext(stop)
    local comp = start
    setprev(start,nil)
    setnext(stop,nil)
    local base = copy_glyph(start)
    if start == head then
        head = base
    end
    resetinjection(base)
    setchar(base,char)
    setsubtype(base,ligature_code)
    setfield(base,"components",comp) -- start can have components ... do we need to flush?
    if prev then
        setnext(prev,base)
    end
    if next then
        setprev(next,base)
    end
    setboth(base,prev,next)
    if not discfound then
        local deletemarks = markflag ~= "mark"
        local components = start
        local baseindex = 0
        local componentindex = 0
        local head = base
        local current = base
        -- first we loop over the glyphs in start .. stop
        while start do
            local char = getchar(start)
            if not marks[char] then
                baseindex = baseindex + componentindex
                componentindex = getcomponentindex(start)
            elseif not deletemarks then -- quite fishy
                setligaindex(start,baseindex + getligaindex(start,componentindex))
                if trace_marks then
                    logwarning("%s: keep mark %s, gets index %s",pref(dataset,sequence),gref(char),getligaindex(start))
                end
                local n = copy_node(start)
                copyinjection(n,start)
                head, current = insert_node_after(head,current,n) -- unlikely that mark has components
            elseif trace_marks then
                logwarning("%s: delete mark %s",pref(dataset,sequence),gref(char))
            end
            start = getnext(start)
        end
        -- we can have one accent as part of a lookup and another following
     -- local start = components -- was wrong (component scanning was introduced when more complex ligs in devanagari was added)
        local start = getnext(current)
        while start do
            local char = ischar(start)
            if char then
                if marks[char] then
                    setligaindex(start,baseindex + getligaindex(start,componentindex))
                    if trace_marks then
                        logwarning("%s: set mark %s, gets index %s",pref(dataset,sequence),gref(char),getligaindex(start))
                    end
                    start = getnext(start)
                else
                    break
                end
            else
                break
            end
        end
    else
        -- discfound ... forget about marks .. probably no scripts that hyphenate and have marks
        local discprev, discnext = getboth(discfound)
        if discprev and discnext then
            -- we assume normalization in context, and don't care about generic ... especially
            -- \- can give problems as there we can have a negative char but that won't match
            -- anyway
            local pre, post, replace, pretail, posttail, replacetail = getdisc(discfound,true)
            if not replace then -- todo: signal simple hyphen
                local prev = getprev(base)
                local copied = copy_node_list(comp)
                setprev(discnext,nil) -- also blocks funny assignments
                setnext(discprev,nil) -- also blocks funny assignments
                if pre then
                    setlink(discprev,pre)
                end
                pre = comp
                if post then
                    setlink(posttail,discnext)
                    setprev(post,nil)
                else
                    post = discnext
                end
                setlink(prev,discfound)
                setlink(discfound,next)
                setboth(base,nil,nil)
                setfield(base,"components",copied)
                setdisc(discfound,pre,post,base,discretionary_code)
                base = prev -- restart
            end
        end
    end
    return head, base
end

local function multiple_glyphs(head,start,multiple,ignoremarks)
    local nofmultiples = #multiple
    if nofmultiples > 0 then
        resetinjection(start)
        setchar(start,multiple[1])
        if nofmultiples > 1 then
            local sn = getnext(start)
            for k=2,nofmultiples do
-- untested:
--
-- while ignoremarks and marks[getchar(sn)] then
--     local sn = getnext(sn)
-- end
                local n = copy_node(start) -- ignore components
                resetinjection(n)
                setchar(n,multiple[k])
                insert_node_after(head,start,n)
                start = n
            end
        end
        return head, start, true
    else
        if trace_multiples then
            logprocess("no multiple for %s",gref(getchar(start)))
        end
        return head, start, false
    end
end

local function get_alternative_glyph(start,alternatives,value)
    local n = #alternatives
    if value == "random" then
        local r = random(1,n)
        return alternatives[r], trace_alternatives and formatters["value %a, taking %a"](value,r)
    elseif value == "first" then
        return alternatives[1], trace_alternatives and formatters["value %a, taking %a"](value,1)
    elseif value == "last" then
        return alternatives[n], trace_alternatives and formatters["value %a, taking %a"](value,n)
    end
    value = value == true and 1 or tonumber(value)
    if type(value) ~= "number" then
        return alternatives[1], trace_alternatives and formatters["invalid value %s, taking %a"](value,1)
    end
 -- local a = alternatives[value]
 -- if a then
 --     -- some kind of hash
 --     return a, trace_alternatives and formatters["value %a, taking %a"](value,a)
 -- end
    if value > n then
        local defaultalt = otf.defaultnodealternate
        if defaultalt == "first" then
            return alternatives[n], trace_alternatives and formatters["invalid value %s, taking %a"](value,1)
        elseif defaultalt == "last" then
            return alternatives[1], trace_alternatives and formatters["invalid value %s, taking %a"](value,n)
        else
            return false, trace_alternatives and formatters["invalid value %a, %s"](value,"out of range")
        end
    elseif value == 0 then
        return getchar(start), trace_alternatives and formatters["invalid value %a, %s"](value,"no change")
    elseif value < 1 then
        return alternatives[1], trace_alternatives and formatters["invalid value %a, taking %a"](value,1)
    else
        return alternatives[value], trace_alternatives and formatters["value %a, taking %a"](value,value)
    end
end

-- handlers

function handlers.gsub_single(head,start,dataset,sequence,replacement)
    if trace_singles then
        logprocess("%s: replacing %s by single %s",pref(dataset,sequence),gref(getchar(start)),gref(replacement))
    end
    resetinjection(start)
    setchar(start,replacement)
    return head, start, true
end

function handlers.gsub_alternate(head,start,dataset,sequence,alternative)
    local kind  = dataset[4]
    local what  = dataset[1]
    local value = what == true and tfmdata.shared.features[kind] or what
    local choice, comment = get_alternative_glyph(start,alternative,value)
    if choice then
        if trace_alternatives then
            logprocess("%s: replacing %s by alternative %a to %s, %s",pref(dataset,sequence),gref(getchar(start)),gref(choice),comment)
        end
        resetinjection(start)
        setchar(start,choice)
    else
        if trace_alternatives then
            logwarning("%s: no variant %a for %s, %s",pref(dataset,sequence),value,gref(getchar(start)),comment)
        end
    end
    return head, start, true
end

function handlers.gsub_multiple(head,start,dataset,sequence,multiple)
    if trace_multiples then
        logprocess("%s: replacing %s by multiple %s",pref(dataset,sequence),gref(getchar(start)),gref(multiple))
    end
    return multiple_glyphs(head,start,multiple,sequence.flags[1])
end

function handlers.gsub_ligature(head,start,dataset,sequence,ligature)
    local current   = getnext(start)
    if not current then
        return head, start, false, nil
    end
    local stop      = nil
    local startchar = getchar(start)
    if marks[startchar] then
        while current do
            local char = ischar(current,currentfont)
            if char then
                local lg = ligature[char]
                if lg then
                    stop     = current
                    ligature = lg
                    current  = getnext(current)
                else
                    break
                end
            else
                break
            end
        end
        if stop then
            local lig = ligature.ligature
            if lig then
                if trace_ligatures then
                    local stopchar = getchar(stop)
                    head, start = markstoligature(head,start,stop,lig)
                    logprocess("%s: replacing %s upto %s by ligature %s case 1",pref(dataset,sequence),gref(startchar),gref(stopchar),gref(getchar(start)))
                else
                    head, start = markstoligature(head,start,stop,lig)
                end
                return head, start, true, false
            else
                -- ok, goto next lookup
            end
        end
    else
        local skipmark  = sequence.flags[1]
        local discfound = false
        local lastdisc  = nil
        while current do
            local char, id = ischar(current,currentfont)
            if char then
                if skipmark and marks[char] then
                    current = getnext(current)
                else -- ligature is a tree
                    local lg = ligature[char] -- can there be multiple in a row? maybe in a bad font
                    if lg then
                        if not discfound and lastdisc then
                            discfound = lastdisc
                            lastdisc  = nil
                        end
                        stop     = current -- needed for fake so outside then
                        ligature = lg
                        current  = getnext(current)
                    else
                        break
                    end
                end
            elseif char == false then
                -- kind of weird
                break
            elseif id == disc_code then
                -- tricky .. we also need to do pre here
                local replace = getfield(current,"replace")
                if replace then
                    -- of{f-}{}{f}e  o{f-}{}{f}fe  o{-}{}{ff}e (oe and ff ligature)
                    -- we can end up here when we have a start run .. testruns start at a disc but
                    -- so here we have the other case: char + disc
                    while replace do
                        local char, id = ischar(replace,currentfont)
                        if char then
                            local lg = ligature[char] -- can there be multiple in a row? maybe in a bad font
                            if lg then
                                ligature = lg
                                replace  = getnext(replace)
                            else
                                return head, start, false, false
                            end
                        else
                            return head, start, false, false
                        end
                    end
                    stop = current
                end
                lastdisc = current
                current  = getnext(current)
            else
                break
            end
        end
        local lig = ligature.ligature
        if lig then
            if stop then
                if trace_ligatures then
                    local stopchar = getchar(stop)
                    head, start = toligature(head,start,stop,lig,dataset,sequence,skipmark,discfound)
                    logprocess("%s: replacing %s upto %s by ligature %s case 2",pref(dataset,sequence),gref(startchar),gref(stopchar),gref(lig))
                else
                    head, start = toligature(head,start,stop,lig,dataset,sequence,skipmark,discfound)
                end
            else
                -- weird but happens (in some arabic font)
                resetinjection(start)
                setchar(start,lig)
                if trace_ligatures then
                    logprocess("%s: replacing %s by (no real) ligature %s case 3",pref(dataset,sequence),gref(startchar),gref(lig))
                end
            end
            return head, start, true, discfound
        else
            -- weird but happens, pseudo ligatures ... just the components
        end
    end
    return head, start, false, discfound
end

function handlers.gpos_single(head,start,dataset,sequence,kerns,rlmode,step,i,injection)
    local startchar = getchar(start)
    if step.format == "pair" then
        local dx, dy, w, h = setpair(start,factor,rlmode,sequence.flags[4],kerns,injection)
        if trace_kerns then
            logprocess("%s: shifting single %s by (%p,%p) and correction (%p,%p)",pref(dataset,sequence),gref(startchar),dx,dy,w,h)
        end
    else
        -- needs checking .. maybe no kerns format for single
        local k = setkern(start,factor,rlmode,kerns,injection)
        if trace_kerns then
            logprocess("%s: shifting single %s by %p",pref(dataset,sequence),gref(startchar),k)
        end
    end
    return head, start, false
end

function handlers.gpos_pair(head,start,dataset,sequence,kerns,rlmode,step,i,injection)
    local snext = getnext(start)
    if not snext then
        return head, start, false
    else
        local prev = start
        local done = false
        while snext do
            local nextchar = ischar(snext,currentfont)
            if nextchar then
                local krn = kerns[nextchar]
                if not krn and marks[nextchar] then
                    prev = snext
                    snext = getnext(snext)
                elseif not krn then
                    break
                elseif step.format == "pair" then
                    local a, b = krn[1], krn[2]
                    if optimizekerns then
                        -- this permits a mixed table, but we could also decide to optimize this
                        -- in the loader and use format 'kern'
                        if not b and a[1] == 0 and a[2] == 0 and a[4] == 0 then
                            local k = setkern(snext,factor,rlmode,a[3],injection)
                            if trace_kerns then
                                logprocess("%s: shifting single %s by %p",pref(dataset,sequence),gref(nextchar),k)
                            end
                            done = true
                            break
                        end
                    end
                    if a and #a > 0 then
                        local x, y, w, h = setpair(start,factor,rlmode,sequence.flags[4],a,injection)
                        if trace_kerns then
                            local startchar = getchar(start)
                            logprocess("%s: shifting first of pair %s and %s by (%p,%p) and correction (%p,%p) as %s",pref(dataset,sequence),gref(startchar),gref(nextchar),x,y,w,h,injection or "injections")
                        end
                    end
                    if b and #b > 0 then
                        local x, y, w, h = setpair(snext,factor,rlmode,sequence.flags[4],b,injection)
                        if trace_kerns then
                            local startchar = getchar(snext)
                            logprocess("%s: shifting second of pair %s and %s by (%p,%p) and correction (%p,%p) as %s",pref(dataset,sequence),gref(startchar),gref(nextchar),x,y,w,h,injection or "injections")
                        end
                    end
                    done = true
                    break
                elseif krn ~= 0 then
                    local k = setkern(snext,factor,rlmode,krn,injection)
                    if trace_kerns then
                        logprocess("%s: inserting kern %p between %s and %s as %s",pref(dataset,sequence),k,gref(getchar(prev)),gref(nextchar),injection or "injections")
                    end
                    done = true
                    break
                else -- can't happen
                    break
                end
            else
                break
            end
        end
        return head, start, done
    end
end

--[[ldx--
<p>We get hits on a mark, but we're not sure if the it has to be applied so
we need to explicitly test for basechar, baselig and basemark entries.</p>
--ldx]]--

function handlers.gpos_mark2base(head,start,dataset,sequence,markanchors,rlmode)
    local markchar = getchar(start)
    if marks[markchar] then
        local base = getprev(start) -- [glyph] [start=mark]
        if base then
            local basechar = ischar(base,currentfont)
            if basechar then
                if marks[basechar] then
                    while base do
                        base = getprev(base)
                        if base then
                            basechar = ischar(base,currentfont)
                            if basechar then
                                if not marks[basechar] then
                                    break
                                end
                            else
                                if trace_bugs then
                                    logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),1)
                                end
                                return head, start, false
                            end
                        else
                            if trace_bugs then
                                logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),2)
                            end
                            return head, start, false
                        end
                    end
                end
                local ba = markanchors[1][basechar]
                if ba then
                    local ma = markanchors[2]
                    local dx, dy, bound = setmark(start,base,factor,rlmode,ba,ma,characters[basechar])
                    if trace_marks then
                        logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%p,%p)",
                            pref(dataset,sequence),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                    end
                    return head, start, true
                end
            elseif trace_bugs then
                logwarning("%s: nothing preceding, case %i",pref(dataset,sequence),1)
            end
        elseif trace_bugs then
            logwarning("%s: nothing preceding, case %i",pref(dataset,sequence),2)
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",pref(dataset,sequence),gref(markchar))
    end
    return head, start, false
end

function handlers.gpos_mark2ligature(head,start,dataset,sequence,markanchors,rlmode)
    local markchar = getchar(start)
    if marks[markchar] then
        local base = getprev(start) -- [glyph] [optional marks] [start=mark]
        if base then
            local basechar = ischar(base,currentfont)
            if basechar then
                if marks[basechar] then
                    while base do
                        base = getprev(base)
                        if base then
                            basechar = ischar(base,currentfont)
                            if basechar then
                                if not marks[basechar] then
                                    break
                                end
                            else
                                if trace_bugs then
                                    logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),1)
                                end
                                return head, start, false
                            end
                        else
                            if trace_bugs then
                                logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),2)
                            end
                            return head, start, false
                        end
                    end
                end
                local ba = markanchors[1][basechar]
                if ba then
                    local ma = markanchors[2]
                    if ma then
                        local index = getligaindex(start)
                        ba = ba[index]
                        if ba then
                            local dx, dy, bound = setmark(start,base,factor,rlmode,ba,ma,characters[basechar]) -- index
                            if trace_marks then
                                logprocess("%s, anchor %s, index %s, bound %s: anchoring mark %s to baselig %s at index %s => (%p,%p)",
                                    pref(dataset,sequence),anchor,index,bound,gref(markchar),gref(basechar),index,dx,dy)
                            end
                            return head, start, true
                        else
                            if trace_bugs then
                                logwarning("%s: no matching anchors for mark %s and baselig %s with index %a",pref(dataset,sequence),gref(markchar),gref(basechar),index)
                            end
                        end
                    end
                elseif trace_bugs then
                --  logwarning("%s: char %s is missing in font",pref(dataset,sequence),gref(basechar))
                    onetimemessage(currentfont,basechar,"no base anchors",report_fonts)
                end
            elseif trace_bugs then
                logwarning("%s: prev node is no char, case %i",pref(dataset,sequence),1)
            end
        elseif trace_bugs then
            logwarning("%s: prev node is no char, case %i",pref(dataset,sequence),2)
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",pref(dataset,sequence),gref(markchar))
    end
    return head, start, false
end

function handlers.gpos_mark2mark(head,start,dataset,sequence,markanchors,rlmode)
    local markchar = getchar(start)
    if marks[markchar] then
        local base = getprev(start) -- [glyph] [basemark] [start=mark]
        local slc = getligaindex(start)
        if slc then -- a rather messy loop ... needs checking with husayni
            while base do
                local blc = getligaindex(base)
                if blc and blc ~= slc then
                    base = getprev(base)
                else
                    break
                end
            end
        end
        if base then
            local basechar = ischar(base,currentfont)
            if basechar then -- subtype test can go
                local ba = markanchors[1][basechar] -- slot 1 has been made copy of the class hash
                if ba then
                    local ma = markanchors[2]
                    local dx, dy, bound = setmark(start,base,factor,rlmode,ba,ma,characters[basechar],true)
                    if trace_marks then
                        logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%p,%p)",
                            pref(dataset,sequence),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                    end
                    return head, start, true
                end
            end
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",pref(dataset,sequence),gref(markchar))
    end
    return head, start, false
end

function handlers.gpos_cursive(head,start,dataset,sequence,exitanchors,rlmode,step,i) -- to be checked
    local done = false
    local startchar = getchar(start)
    if marks[startchar] then
        if trace_cursive then
            logprocess("%s: ignoring cursive for mark %s",pref(dataset,sequence),gref(startchar))
        end
    else
        local nxt = getnext(start)
        while not done and nxt do
            local nextchar = ischar(nxt,currentfont)
            if not nextchar then
                break
            elseif marks[nextchar] then
                -- should not happen (maybe warning)
                nxt = getnext(nxt)
            else
                local exit = exitanchors[3]
                if exit then
                    local entry = exitanchors[1][nextchar]
                    if entry then
                        entry = entry[2]
                        if entry then
                            local dx, dy, bound = setcursive(start,nxt,factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
                            if trace_cursive then
                                logprocess("%s: moving %s to %s cursive (%p,%p) using anchor %s and bound %s in %s mode",pref(dataset,sequence),gref(startchar),gref(nextchar),dx,dy,anchor,bound,mref(rlmode))
                            end
                            done = true
                        end
                    end
                end
                break
            end
        end
    end
    return head, start, done
end

--[[ldx--
<p>I will implement multiple chain replacements once I run into a font that uses
it. It's not that complex to handle.</p>
--ldx]]--

local chainprocs = { }

local function logprocess(...)
    if trace_steps then
        registermessage(...)
    end
    report_subchain(...)
end

local logwarning = report_subchain

local function logprocess(...)
    if trace_steps then
        registermessage(...)
    end
    report_chain(...)
end

local logwarning = report_chain

-- We could share functions but that would lead to extra function calls with many
-- arguments, redundant tests and confusing messages.

-- The reversesub is a special case, which is why we need to store the replacements
-- in a bit weird way. There is no lookup and the replacement comes from the lookup
-- itself. It is meant mostly for dealing with Urdu.

local function reversesub(head,start,stop,dataset,sequence,replacements,rlmode)
    local char        = getchar(start)
    local replacement = replacements[char]
    if replacement then
        if trace_singles then
            logprocess("%s: single reverse replacement of %s by %s",cref(dataset,sequence),gref(char),gref(replacement))
        end
        resetinjection(start)
        setchar(start,replacement)
        return head, start, true
    else
        return head, start, false
    end
end


chainprocs.reversesub = reversesub

--[[ldx--
<p>This chain stuff is somewhat tricky since we can have a sequence of actions to be
applied: single, alternate, multiple or ligature where ligature can be an invalid
one in the sense that it will replace multiple by one but not neccessary one that
looks like the combination (i.e. it is the counterpart of multiple then). For
example, the following is valid:</p>

<typing>
<line>xxxabcdexxx [single a->A][multiple b->BCD][ligature cde->E] xxxABCDExxx</line>
</typing>

<p>Therefore we we don't really do the replacement here already unless we have the
single lookup case. The efficiency of the replacements can be improved by deleting
as less as needed but that would also make the code even more messy.</p>
--ldx]]--

--[[ldx--
<p>Here we replace start by a single variant.</p>
--ldx]]--

-- To be done (example needed): what if > 1 steps

-- this is messy: do we need this disc checking also in alternaties?

local function reportmoresteps(dataset,sequence)
    logwarning("%s: more than 1 step",cref(dataset,sequence))
end

function chainprocs.gsub_single(head,start,stop,dataset,sequence,currentlookup,chainindex)
    local steps    = currentlookup.steps
    local nofsteps = currentlookup.nofsteps
    if nofsteps > 1 then
        reportmoresteps(dataset,sequence)
    end
    local current = start
    while current do
        local currentchar = ischar(current)
        if currentchar then
            local replacement = steps[1].coverage[currentchar]
            if not replacement or replacement == "" then
                if trace_bugs then
                    logwarning("%s: no single for %s",cref(dataset,sequence,chainindex),gref(currentchar))
                end
            else
                if trace_singles then
                    logprocess("%s: replacing single %s by %s",cref(dataset,sequence,chainindex),gref(currentchar),gref(replacement))
                end
                resetinjection(current)
                setchar(current,replacement)
            end
            return head, start, true
        elseif currentchar == false then
            -- can't happen
            break
        elseif current == stop then
            break
        else
            current = getnext(current)
        end
    end
    return head, start, false
end

--[[ldx--
<p>Here we replace start by a sequence of new glyphs.</p>
--ldx]]--

function chainprocs.gsub_multiple(head,start,stop,dataset,sequence,currentlookup)
    local steps    = currentlookup.steps
    local nofsteps = currentlookup.nofsteps
    if nofsteps > 1 then
        reportmoresteps(dataset,sequence)
    end
    local startchar   = getchar(start)
    local replacement = steps[1].coverage[startchar]
    if not replacement or replacement == "" then
        if trace_bugs then
            logwarning("%s: no multiple for %s",cref(dataset,sequence),gref(startchar))
        end
    else
        if trace_multiples then
            logprocess("%s: replacing %s by multiple characters %s",cref(dataset,sequence),gref(startchar),gref(replacement))
        end
        return multiple_glyphs(head,start,replacement,currentlookup.flags[1]) -- not sequence.flags?
    end
    return head, start, false
end

--[[ldx--
<p>Here we replace start by new glyph. First we delete the rest of the match.</p>
--ldx]]--

-- char_1 mark_1 -> char_x mark_1 (ignore marks)
-- char_1 mark_1 -> char_x

-- to be checked: do we always have just one glyph?
-- we can also have alternates for marks
-- marks come last anyway
-- are there cases where we need to delete the mark

function chainprocs.gsub_alternate(head,start,stop,dataset,sequence,currentlookup)
    local steps    = currentlookup.steps
    local nofsteps = currentlookup.nofsteps
    if nofsteps > 1 then
        reportmoresteps(dataset,sequence)
    end
    local kind    = dataset[4]
    local what    = dataset[1]
    local value   = what == true and tfmdata.shared.features[kind] or what
    local current = start
    while current do
        local currentchar = ischar(current)
        if currentchar then
            local alternatives = steps[1].coverage[currentchar]
            if alternatives then
                local choice, comment = get_alternative_glyph(current,alternatives,value)
                if choice then
                    if trace_alternatives then
                        logprocess("%s: replacing %s by alternative %a to %s, %s",cref(dataset,sequence),gref(char),choice,gref(choice),comment)
                    end
                    resetinjection(start)
                    setchar(start,choice)
                else
                    if trace_alternatives then
                        logwarning("%s: no variant %a for %s, %s",cref(dataset,sequence),value,gref(char),comment)
                    end
                end
            end
            return head, start, true
        elseif currentchar == false then
            -- can't happen
            break
        elseif current == stop then
            break
        else
            current = getnext(current)
        end
    end
    return head, start, false
end

--[[ldx--
<p>When we replace ligatures we use a helper that handles the marks. I might change
this function (move code inline and handle the marks by a separate function). We
assume rather stupid ligatures (no complex disc nodes).</p>
--ldx]]--

function chainprocs.gsub_ligature(head,start,stop,dataset,sequence,currentlookup,chainindex)
    local steps    = currentlookup.steps
    local nofsteps = currentlookup.nofsteps
    if nofsteps > 1 then
        reportmoresteps(dataset,sequence)
    end
    local startchar = getchar(start)
    local ligatures = steps[1].coverage[startchar]
    if not ligatures then
        if trace_bugs then
            logwarning("%s: no ligatures starting with %s",cref(dataset,sequence,chainindex),gref(startchar))
        end
    else
        local current         = getnext(start)
        local discfound       = false
        local last            = stop
        local nofreplacements = 1
        local skipmark        = currentlookup.flags[1] -- sequence.flags?
        while current do
            -- todo: ischar ... can there really be disc nodes here?
            local id = getid(current)
            if id == disc_code then
                if not discfound then
                    discfound = current
                end
                if current == stop then
                    break -- okay? or before the disc
                else
                    current = getnext(current)
                end
            else
                local schar = getchar(current)
                if skipmark and marks[schar] then -- marks
                    -- if current == stop then -- maybe add this
                    --     break
                    -- else
                        current = getnext(current)
                    -- end
                else
                    local lg = ligatures[schar]
                    if lg then
                        ligatures       = lg
                        last            = current
                        nofreplacements = nofreplacements + 1
                        if current == stop then
                            break
                        else
                            current = getnext(current)
                        end
                    else
                        break
                    end
                end
            end
        end
        local ligature = ligatures.ligature
        if ligature then
            if chainindex then
                stop = last
            end
            if trace_ligatures then
                if start == stop then
                    logprocess("%s: replacing character %s by ligature %s case 3",cref(dataset,sequence,chainindex),gref(startchar),gref(ligature))
                else
                    logprocess("%s: replacing character %s upto %s by ligature %s case 4",cref(dataset,sequence,chainindex),gref(startchar),gref(getchar(stop)),gref(ligature))
                end
            end
            head, start = toligature(head,start,stop,ligature,dataset,sequence,skipmark,discfound)
            return head, start, true, nofreplacements, discfound
        elseif trace_bugs then
            if start == stop then
                logwarning("%s: replacing character %s by ligature fails",cref(dataset,sequence,chainindex),gref(startchar))
            else
                logwarning("%s: replacing character %s upto %s by ligature fails",cref(dataset,sequence,chainindex),gref(startchar),gref(getchar(stop)))
            end
        end
    end
    return head, start, false, 0, false
end

function chainprocs.gpos_single(head,start,stop,dataset,sequence,currentlookup,rlmode,chainindex)
    local steps    = currentlookup.steps
    local nofsteps = currentlookup.nofsteps
    if nofsteps > 1 then
        reportmoresteps(dataset,sequence)
    end
    local startchar = getchar(start)
    local step      = steps[1]
    local kerns     = step.coverage[startchar]
    if not kerns then
        -- skip
    elseif step.format == "pair" then
        local dx, dy, w, h = setpair(start,factor,rlmode,sequence.flags[4],kerns) -- currentlookup.flags ?
        if trace_kerns then
            logprocess("%s: shifting single %s by (%p,%p) and correction (%p,%p)",cref(dataset,sequence),gref(startchar),dx,dy,w,h)
        end
    else -- needs checking .. maybe no kerns format for single
        local k = setkern(start,factor,rlmode,kerns,injection)
        if trace_kerns then
            logprocess("%s: shifting single %s by %p",cref(dataset,sequence),gref(startchar),k)
        end
    end
    return head, start, false
end

function chainprocs.gpos_pair(head,start,stop,dataset,sequence,currentlookup,rlmode,chainindex) -- todo: injections ?
    local steps    = currentlookup.steps
    local nofsteps = currentlookup.nofsteps
    if nofsteps > 1 then
        reportmoresteps(dataset,sequence)
    end
    local snext = getnext(start)
    if snext then
        local startchar = getchar(start)
        local step      = steps[1]
        local kerns     = step.coverage[startchar] -- always 1 step
        if kerns then
            local prev = start
            local done = false
            while snext do
                local nextchar = ischar(snext,currentfont)
                if not nextchar then
                    break
                end
                local krn = kerns[nextchar]
                if not krn and marks[nextchar] then
                    prev = snext
                    snext = getnext(snext)
                elseif not krn then
                    break
                elseif step.format == "pair" then
                    local a, b = krn[1], krn[2]
                    if optimizekerns then
                        -- this permits a mixed table, but we could also decide to optimize this
                        -- in the loader and use format 'kern'
                        if not b and a[1] == 0 and a[2] == 0 and a[4] == 0 then
                            local k = setkern(snext,factor,rlmode,a[3],"injections")
                            if trace_kerns then
                                logprocess("%s: shifting single %s by %p",cref(dataset,sequence),gref(startchar),k)
                            end
                            done = true
                            break
                        end
                    end
                    if a and #a > 0 then
                        local startchar = getchar(start)
                        local x, y, w, h = setpair(start,factor,rlmode,sequence.flags[4],a,"injections") -- currentlookups flags?
                        if trace_kerns then
                            logprocess("%s: shifting first of pair %s and %s by (%p,%p) and correction (%p,%p)",cref(dataset,sequence),gref(startchar),gref(nextchar),x,y,w,h)
                        end
                    end
                    if b and #b > 0 then
                        local startchar = getchar(start)
                        local x, y, w, h = setpair(snext,factor,rlmode,sequence.flags[4],b,"injections")
                        if trace_kerns then
                            logprocess("%s: shifting second of pair %s and %s by (%p,%p) and correction (%p,%p)",cref(dataset,sequence),gref(startchar),gref(nextchar),x,y,w,h)
                        end
                    end
                    done = true
                    break
                elseif krn ~= 0 then
                    local k = setkern(snext,factor,rlmode,krn)
                    if trace_kerns then
                        logprocess("%s: inserting kern %s between %s and %s",cref(dataset,sequence),k,gref(getchar(prev)),gref(nextchar))
                    end
                    done = true
                    break
                else
                    break
                end
            end
            return head, start, done
        end
    end
    return head, start, false
end

function chainprocs.gpos_mark2base(head,start,stop,dataset,sequence,currentlookup,rlmode)
    local steps    = currentlookup.steps
    local nofsteps = currentlookup.nofsteps
    if nofsteps > 1 then
        reportmoresteps(dataset,sequence)
    end
    local markchar = getchar(start)
    if marks[markchar] then
        local markanchors = steps[1].coverage[markchar] -- always 1 step
        if markanchors then
            local base = getprev(start) -- [glyph] [start=mark]
            if base then
                local basechar = ischar(base,currentfont)
                if basechar then
                    if marks[basechar] then
                        while base do
                            base = getprev(base)
                            if base then
                                local basechar = ischar(base,currentfont)
                                if basechar then
                                    if not marks[basechar] then
                                        break
                                    end
                                else
                                    if trace_bugs then
                                        logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),1)
                                    end
                                    return head, start, false
                                end
                            else
                                if trace_bugs then
                                    logwarning("%s: no base for mark %s, case %i",pref(dataset,sequence),gref(markchar),2)
                                end
                                return head, start, false
                            end
                        end
                    end
                    local ba = markanchors[1][basechar]
                    if ba then
                        local ma = markanchors[2]
                        if ma then
                            local dx, dy, bound = setmark(start,base,factor,rlmode,ba,ma,characters[basechar])
                            if trace_marks then
                                logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%p,%p)",
                                    cref(dataset,sequence),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                            end
                            return head, start, true
                        end
                    end
                elseif trace_bugs then
                    logwarning("%s: prev node is no char, case %i",cref(dataset,sequence),1)
                end
            elseif trace_bugs then
                logwarning("%s: prev node is no char, case %i",cref(dataset,sequence),2)
            end
        elseif trace_bugs then
            logwarning("%s: mark %s has no anchors",cref(dataset,sequence),gref(markchar))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",cref(dataset,sequence),gref(markchar))
    end
    return head, start, false
end

function chainprocs.gpos_mark2ligature(head,start,stop,dataset,sequence,currentlookup,rlmode)
    local steps    = currentlookup.steps
    local nofsteps = currentlookup.nofsteps
    if nofsteps > 1 then
        reportmoresteps(dataset,sequence)
    end
    local markchar = getchar(start)
    if marks[markchar] then
        local markanchors = steps[1].coverage[markchar] -- always 1 step
        if markanchors then
            local base = getprev(start) -- [glyph] [optional marks] [start=mark]
            if base then
                local basechar = ischar(base,currentfont)
                if basechar then
                    if marks[basechar] then
                        while base do
                            base = getprev(base)
                            if base then
                                local basechar = ischar(base,currentfont)
                                if basechar then
                                    if not marks[basechar] then
                                        break
                                    end
                                else
                                    if trace_bugs then
                                        logwarning("%s: no base for mark %s, case %i",cref(dataset,sequence),markchar,1)
                                    end
                                    return head, start, false
                                end
                            else
                                if trace_bugs then
                                    logwarning("%s: no base for mark %s, case %i",cref(dataset,sequence),markchar,2)
                                end
                                return head, start, false
                            end
                        end
                    end
                    local ba = markanchors[1][basechar]
                    if ba then
                        local ma = markanchors[2]
                        if ma then
                            local index = getligaindex(start)
                            ba = ba[index]
                            if ba then
                                local dx, dy, bound = setmark(start,base,factor,rlmode,ba,ma,characters[basechar])
                                if trace_marks then
                                    logprocess("%s, anchor %s, bound %s: anchoring mark %s to baselig %s at index %s => (%p,%p)",
                                        cref(dataset,sequence),anchor,a or bound,gref(markchar),gref(basechar),index,dx,dy)
                                end
                                return head, start, true
                            end
                        end
                    end
                elseif trace_bugs then
                    logwarning("%s, prev node is no char, case %i",cref(dataset,sequence),1)
                end
            elseif trace_bugs then
                logwarning("%s, prev node is no char, case %i",cref(dataset,sequence),2)
            end
        elseif trace_bugs then
            logwarning("%s, mark %s has no anchors",cref(dataset,sequence),gref(markchar))
        end
    elseif trace_bugs then
        logwarning("%s, mark %s is no mark",cref(dataset,sequence),gref(markchar))
    end
    return head, start, false
end

function chainprocs.gpos_mark2mark(head,start,stop,dataset,sequence,currentlookup,rlmode)
    local steps    = currentlookup.steps
    local nofsteps = currentlookup.nofsteps
    if nofsteps > 1 then
        reportmoresteps(dataset,sequence)
    end
    local markchar = getchar(start)
    if marks[markchar] then
        local markanchors = steps[1].coverage[markchar] -- always 1 step
        if markanchors then
            local base = getprev(start) -- [glyph] [basemark] [start=mark]
            local slc = getligaindex(start)
            if slc then -- a rather messy loop ... needs checking with husayni
                while base do
                    local blc = getligaindex(base)
                    if blc and blc ~= slc then
                        base = getprev(base)
                    else
                        break
                    end
                end
            end
            if base then -- subtype test can go
                local basechar = ischar(base,currentfont)
                if basechar then
                    local ba = markanchors[1][basechar]
                    if ba then
                        local ma = markanchors[2]
                        if ma then
                            local dx, dy, bound = setmark(start,base,factor,rlmode,ba,ma,characters[basechar],true)
                            if trace_marks then
                                logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%p,%p)",
                                    cref(dataset,sequence),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                            end
                            return head, start, true
                        end
                    end
                elseif trace_bugs then
                    logwarning("%s: prev node is no mark, case %i",cref(dataset,sequence),1)
                end
            elseif trace_bugs then
                logwarning("%s: prev node is no mark, case %i",cref(dataset,sequence),2)
            end
        elseif trace_bugs then
            logwarning("%s: mark %s has no anchors",cref(dataset,sequence),gref(markchar))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",cref(dataset,sequence),gref(markchar))
    end
    return head, start, false
end

function chainprocs.gpos_cursive(head,start,stop,dataset,sequence,currentlookup,rlmode)
    local steps    = currentlookup.steps
    local nofsteps = currentlookup.nofsteps
    if nofsteps > 1 then
        reportmoresteps(dataset,sequence)
    end
    local startchar   = getchar(start)
    local exitanchors = steps[1].coverage[startchar] -- always 1 step
    if exitanchors then
        local done = false
        if marks[startchar] then
            if trace_cursive then
                logprocess("%s: ignoring cursive for mark %s",pref(dataset,sequence),gref(startchar))
            end
        else
            local nxt = getnext(start)
            while not done and nxt do
                local nextchar = ischar(nxt,currentfont)
                if not nextchar then
                    break
                elseif marks[nextchar] then
                    -- should not happen (maybe warning)
                    nxt = getnext(nxt)
                else
                    local exit = exitanchors[3]
                    if exit then
                        local entry = exitanchors[1][nextchar]
                        if entry then
                            entry = entry[2]
                            if entry then
                                local dx, dy, bound = setcursive(start,nxt,factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
                                if trace_cursive then
                                    logprocess("%s: moving %s to %s cursive (%p,%p) using anchor %s and bound %s in %s mode",pref(dataset,sequence),gref(startchar),gref(nextchar),dx,dy,anchor,bound,mref(rlmode))
                                end
                                done = true
                                break
                            end
                        end
                    elseif trace_bugs then
                        onetimemessage(currentfont,startchar,"no entry anchors",report_fonts)
                    end
                    break
                end
            end
        end
        return head, start, done
    else
        if trace_cursive and trace_details then
            logprocess("%s, cursive %s is already done",pref(dataset,sequence),gref(getchar(start)),alreadydone)
        end
        return head, start, false
    end
end

-- what pointer to return, spec says stop
-- to be discussed ... is bidi changer a space?
-- elseif char == zwnj and sequence[n][32] then -- brrr

local function show_skip(dataset,sequence,char,ck,class)
    logwarning("%s: skipping char %s, class %a, rule %a, lookuptype %a",cref(dataset,sequence),gref(char),class,ck[1],ck[8] or ck[2])
end

-- A previous version had disc collapsing code in the (single sub) handler plus some
-- checking in the main loop, but that left the pre/post sequences undone. The best
-- solution is to add some checking there and backtrack when a replace/post matches
-- but it takes a bit of work to figure out an efficient way (this is what the sweep*
-- names refer to). I might look into that variant one day again as it can replace
-- some other code too. In that approach we can have a special version for gub and pos
-- which gains some speed. This method does the test and passes info to the handlers
-- (sweepnode, sweepmode, sweepprev, sweepnext, etc). Here collapsing is handled in the
-- main loop which also makes code elsewhere simpler (i.e. no need for the other special
-- runners and disc code in ligature building). I also experimented with pushing preceding
-- glyphs sequences in the replace/pre fields beforehand which saves checking afterwards
-- but at the cost of duplicate glyphs (memory) but it's too much overhead (runtime).
--
-- In the meantime Kai had moved the code from the single chain into a more general handler
-- and this one (renamed to chaindisk) is used now. I optimized the code a bit and brought
-- it in sycn with the other code. Hopefully I didn't introduce errors. Note: this somewhat
-- complex approach is meant for fonts that implement (for instance) ligatures by character
-- replacement which to some extend is not that suitable for hyphenation. I also use some
-- helpers. This method passes some states but reparses the list. There is room for a bit of
-- speed up but that will be done in the context version. (In fact a partial rewrite of all
-- code can bring some more efficientry.)
--
-- I didn't test it with extremes but successive disc nodes still can give issues but in
-- order to handle that we need more complex code which also slows down even more. The main
-- loop variant could deal with that: test, collapse, backtrack.

local function chaindisk(head,start,last,dataset,sequence,chainlookup,rlmode,k,ck,chainproc)

    if not start then
        return head, start, false
    end

    local startishead   = start == head
    local seq           = ck[3]
    local f             = ck[4]
    local l             = ck[5]
    local s             = #seq
    local done          = false
    local sweepnode     = sweepnode
    local sweeptype     = sweeptype
    local sweepoverflow = false
    local checkdisc     = getprev(head) -- hm bad name head
    local keepdisc      = not sweepnode
    local lookaheaddisc = nil
    local backtrackdisc = nil
    local current       = start
    local last          = start
    local prev          = getprev(start)

    -- fishy: so we can overflow and then go on in the sweep?

    local i = f
    while i <= l do
        local id = getid(current)
        if id == glyph_code then
            i       = i + 1
            last    = current
            current = getnext(current)
        elseif id == disc_code then
            if keepdisc then
                keepdisc = false
                if notmatchpre[current] ~= notmatchreplace[current] then
                    lookaheaddisc = current
                end
                local replace = getfield(current,"replace")
                while replace and i <= l do
                    if getid(replace) == glyph_code then
                        i = i + 1
                    end
                    replace = getnext(replace)
                end
                last    = current
                current = getnext(c)
            else
                head, current = flattendisk(head,current)
            end
        else
            last    = current
            current = getnext(current)
        end
        if current then
            -- go on
        elseif sweepoverflow then
            -- we already are folling up on sweepnode
            break
        elseif sweeptype == "post" or sweeptype == "replace" then
            current = getnext(sweepnode)
            if current then
                sweeptype     = nil
                sweepoverflow = true
            else
                break
            end
        else
            break -- added
        end
    end

    if sweepoverflow then
        local prev = current and getprev(current)
        if not current or prev ~= sweepnode then
            local head = getnext(sweepnode)
            local tail = nil
            if prev then
                tail = prev
                setprev(current,sweepnode)
            else
                tail = find_node_tail(head)
            end
            setnext(sweepnode,current)
            setprev(head,nil)
            setnext(tail,nil)
            appenddisc(sweepnode,head)
        end
    end

    if l < s then
        local i = l
        local t = sweeptype == "post" or sweeptype == "replace"
        while current and i < s do
            local id = getid(current)
            if id == glyph_code then
                i       = i + 1
                current = getnext(current)
            elseif id == disc_code then
                if keepdisc then
                    keepdisc = false
                    if notmatchpre[current] ~= notmatchreplace[current] then
                        lookaheaddisc = current
                    end
                    local replace = getfield(c,"replace")
                    while replace and i < s do
                        if getid(replace) == glyph_code then
                            i = i + 1
                        end
                        replace = getnext(replace)
                    end
                    current = getnext(current)
                elseif notmatchpre[current] ~= notmatchreplace[current] then
                    head, current = flattendisk(head,current)
                else
                    current = getnext(current) -- HH
                end
            else
                current = getnext(current)
            end
            if not current and t then
                current = getnext(sweepnode)
                if current then
                    sweeptype = nil
                end
            end
        end
    end

    if f > 1 then
        local current = prev
        local i       = f
        local t       = sweeptype == "pre" or sweeptype == "replace"
        if not current and t and current == checkdisk then
            current = getprev(sweepnode)
        end
        while current and i > 1 do -- missing getprev added / moved outside
            local id = getid(current)
            if id == glyph_code then
                i = i - 1
            elseif id == disc_code then
                if keepdisc then
                    keepdisc = false
                    if notmatchpost[current] ~= notmatchreplace[current] then
                        backtrackdisc = current
                    end
                    local replace = getfield(current,"replace")
                    while replace and i > 1 do
                        if getid(replace) == glyph_code then
                            i = i - 1
                        end
                        replace = getnext(replace)
                    end
                elseif notmatchpost[current] ~= notmatchreplace[current] then
                    head, current = flattendisk(head,current)
                end
            end
            current = getprev(current)
            if t and current == checkdisk then
                current = getprev(sweepnode)
            end
        end
    end

    local ok = false
    if lookaheaddisc then

        local cf            = start
        local cl            = getprev(lookaheaddisc)
        local cprev         = getprev(start)
        local insertedmarks = 0

        while cprev do
            local char = ischar(cf,currentfont)
            if char and marks[char] then
                insertedmarks = insertedmarks + 1
                cf            = cprev
                startishead   = cf == head
                cprev         = getprev(cprev)
            else
                break
            end
        end

        setprev(lookaheaddisc,cprev)
        if cprev then
            setnext(cprev,lookaheaddisc)
        end
        setprev(cf,nil)
        setnext(cl,nil)
        if startishead then
            head = lookaheaddisc
        end
        local pre, post, replace = getdisc(lookaheaddisc)
        local new  = copy_node_list(cf)
        local cnew = new
        for i=1,insertedmarks do
            cnew = getnext(cnew)
        end
        local clast = cnew
        for i=f,l do
            clast = getnext(clast)
        end
        if not notmatchpre[lookaheaddisc] then
            cf, start, ok = chainproc(cf,start,last,dataset,sequence,chainlookup,rlmode,k)
        end
        if not notmatchreplace[lookaheaddisc] then
            new, cnew, ok = chainproc(new,cnew,clast,dataset,sequence,chainlookup,rlmode,k)
        end
        if pre then
            setlink(cl,pre)
        end
        if replace then
            local tail = find_node_tail(new)
            setlink(tail,replace)
        end
        setdisc(lookaheaddisc,cf,post,new)
        start          = getprev(lookaheaddisc)
        sweephead[cf]  = getnext(clast)
        sweephead[new] = getnext(last)

    elseif backtrackdisc then

        local cf            = getnext(backtrackdisc)
        local cl            = start
        local cnext         = getnext(start)
        local insertedmarks = 0

        while cnext do
            local char = ischar(cnext,currentfont)
            if char and marks[char] then
                insertedmarks = insertedmarks + 1
                cl            = cnext
                cnext         = getnext(cnext)
            else
                break
            end
        end
        if cnext then
            setprev(cnext,backtrackdisc)
        end
        setnext(backtrackdisc,cnext)
        setprev(cf,nil)
        setnext(cl,nil)
        local pre, post, replace, pretail, posttail, replacetail = getdisc(backtrackdisc,true)
        local new  = copy_node_list(cf)
        local cnew = find_node_tail(new)
        for i=1,insertedmarks do
            cnew = getprev(cnew)
        end
        local clast = cnew
        for i=f,l do
            clast = getnext(clast)
        end
        if not notmatchpost[backtrackdisc] then
            cf, start, ok = chainproc(cf,start,last,dataset,sequence,chainlookup,rlmode,k)
        end
        if not notmatchreplace[backtrackdisc] then
            new, cnew, ok = chainproc(new,cnew,clast,dataset,sequence,chainlookup,rlmode,k)
        end
        if post then
            setlink(posttail,cf)
        else
            post = cf
        end
        if replace then
            setlink(replacetail,new)
        else
            replace = new
        end
        setdisc(backtrackdisc,pre,post,replace)
        start              = getprev(backtrackdisc)
        sweephead[post]    = getnext(clast)
        sweephead[replace] = getnext(last)

    else

        head, start, ok = chainproc(head,start,last,dataset,sequence,chainlookup,rlmode,k)

    end

    return head, start, ok
end

-- helpers from elsewhere

-- local function currentmatch(current,n,l)
--     while current do
--         if getid(current) ~= glyph_code then
--             return false
--         elseif seq[n][getchar(current)] then
--             n = n + 1
--             current = getnext(current)
--             if not current then
--                 return true, n, current
--             elseif n > l then
--              -- match = false
--                 return true, n, current
--             end
--         else
--             return false
--         end
--     end
-- end
--
-- local function aftermatch(current,n,l)
--     while current do
--         if getid(current) ~= glyph_code then
--             return false
--         elseif seq[n][getchar(current)] then
--             n = n + 1
--             current = getnext(current)
--             if not current then
--                 return true, n, current
--             elseif n > l then
--              -- match = false
--                 return true, n, current
--             end
--         else
--             return false
--         end
--     end
-- end
--
-- local function beforematch(current,n)
--     local finish  = getprev(current)
--     local current = find_node_tail(current)
--     while current do
--         if getid(current) ~= glyph_code then
--             return false
--         elseif seq[n][getchar(current)] then
--             n = n - 1
--             current = getprev(current)
--             if not current or current == finish then
--                 return true, n, current
--             elseif n < 1 then
--              -- match = false
--                 return true, n, current
--             end
--         else
--             return false
--         end
--     end
-- end

local noflags = { false, false, false, false }

local function handle_contextchain(head,start,dataset,sequence,contexts,rlmode)
    local sweepnode    = sweepnode
    local sweeptype    = sweeptype
    local currentfont  = currentfont
    local diskseen     = false
    local checkdisc    = getprev(head)
    local flags        = sequence.flags or noflags
    local done         = false
    local skipmark     = flags[1]
    local skipligature = flags[2]
    local skipbase     = flags[3]
    local markclass    = sequence.markclass
    local skipped      = false
    for k=1,#contexts do -- i've only seen ccmp having > 1 (e.g. dejavu)
        local match   = true
        local current = start
        local last    = start
        local ck      = contexts[k]
        local seq     = ck[3]
        local s       = #seq
        -- f..l = mid string
        if s == 1 then
            -- never happens
            local char = ischar(current,currentfont)
            if char then
                match = seq[1][char]
            end
        else
            -- maybe we need a better space check (maybe check for glue or category or combination)
            -- we cannot optimize for n=2 because there can be disc nodes
            local f = ck[4]
            local l = ck[5]
            -- current match
            if f == 1 and f == l then -- current only
                -- already a hit
             -- match = true
            else -- before/current/after | before/current | current/after
                -- no need to test first hit (to be optimized)
                if f == l then -- new, else last out of sync (f is > 1)
                 -- match = true
                else
                    local discfound = nil
                    local n = f + 1
                    last = getnext(last)
                    while n <= l do
                        if not last and (sweeptype == "post" or sweeptype == "replace") then
                            last      = getnext(sweepnode)
                            sweeptype = nil
                        end
                        if last then
                            local char, id = ischar(last,currentfont)
                            if char then
                                local ccd = descriptions[char]
                                if ccd then
                                    local class = ccd.class or "base"
                                    if class == skipmark or class == skipligature or class == skipbase or (markclass and class == "mark" and not markclass[char]) then
                                        skipped = true
                                        if trace_skips then
                                            show_skip(dataset,sequence,char,ck,class)
                                        end
                                        last = getnext(last)
                                    elseif seq[n][char] then
                                        if n < l then
                                            last = getnext(last)
                                        end
                                        n = n + 1
                                    else
                                        if discfound then
                                            notmatchreplace[discfound] = true
                                            match = not notmatchpre[discfound]
                                        else
                                            match = false
                                        end
                                        break
                                    end
                                else
                                    if discfound then
                                        notmatchreplace[discfound] = true
                                        match = not notmatchpre[discfound]
                                    else
                                        match = false
                                    end
                                    break
                                end
                                last = getnext(last)
                            elseif char == false then
                                if discfound then
                                    notmatchreplace[discfound] = true
                                    match = not notmatchpre[discfound]
                                else
                                    match = false
                                end
                                break
                            elseif id == disc_code then
                                diskseen              = true
                                discfound             = last
                                notmatchpre[last]     = nil
                                notmatchpost[last]    = true
                                notmatchreplace[last] = nil
                                local pre, post, replace = getdisc(last)
                                if pre then
                                    local n = n
                                    while pre do
                                        if seq[n][getchar(pre)] then
                                            n = n + 1
                                            pre = getnext(pre)
                                            if n > l then
                                                break
                                            end
                                        else
                                            notmatchpre[last] = true
                                            break
                                        end
                                    end
                                    if n <= l then
                                        notmatchpre[last] = true
                                    end
                                else
                                    notmatchpre[last] = true
                                end
                                if replace then
                                    -- so far we never entered this branch
                                    while replace do
                                        if seq[n][getchar(replace)] then
                                            n = n + 1
                                            replace = getnext(replace)
                                            if n > l then
                                                break
                                            end
                                        else
                                            notmatchreplace[last] = true
                                            match = not notmatchpre[last]
                                            break
                                        end
                                    end
                                    match = not notmatchpre[last]
                                end
                                last = getnext(last)
                            else
                                match = false
                                break
                            end
                        else
                            match = false
                            break
                        end
                    end
                end
            end
            -- before
            if match and f > 1 then
                local prev = getprev(start)
                if prev then
                    if prev == checkdisc and (sweeptype == "pre" or sweeptype == "replace") then
                        prev      = getprev(sweepnode)
                     -- sweeptype = nil
                    end
                    if prev then
                        local discfound = nil
                        local n = f - 1
                        while n >= 1 do
                            if prev then
                                local char, id = ischar(prev,currentfont)
                                if char then
                                    local ccd = descriptions[char]
                                    if ccd then
                                        local class = ccd.class
                                        if class == skipmark or class == skipligature or class == skipbase or (markclass and class == "mark" and not markclass[char]) then
                                            skipped = true
                                            if trace_skips then
                                                show_skip(dataset,sequence,char,ck,class)
                                            end
                                        elseif seq[n][char] then
                                            n = n -1
                                        else
                                            if discfound then
                                                notmatchreplace[discfound] = true
                                                match = not notmatchpost[discfound]
                                            else
                                                match = false
                                            end
                                            break
                                        end
                                    else
                                        if discfound then
                                            notmatchreplace[discfound] = true
                                            match = not notmatchpost[discfound]
                                        else
                                            match = false
                                        end
                                        break
                                    end
                                    prev = getprev(prev)
                                elseif char == false then
                                    if discfound then
                                        notmatchreplace[discfound] = true
                                        match = not notmatchpost[discfound]
                                    else
                                        match = false
                                    end
                                    break
                                elseif id == disc_code then
                                    -- the special case: f i where i becomes dottless i ..
                                    diskseen              = true
                                    discfound             = prev
                                    notmatchpre[prev]     = true
                                    notmatchpost[prev]    = nil
                                    notmatchreplace[prev] = nil
                                    local pre, post, replace, pretail, posttail, replacetail = getdisc(prev,true)
                                    if pre ~= start and post ~= start and replace ~= start then
                                        if post then
                                            local n = n
                                            while posttail do
                                                if seq[n][getchar(posttail)] then
                                                    n = n - 1
                                                    if posttail == post then
                                                        break
                                                    else
                                                        posttail = getprev(posttail)
                                                        if n < 1 then
                                                            break
                                                        end
                                                    end
                                                else
                                                    notmatchpost[prev] = true
                                                    break
                                                end
                                            end
                                            if n >= 1 then
                                                notmatchpost[prev] = true
                                            end
                                        else
                                            notmatchpost[prev] = true
                                        end
                                        if replace then
                                            -- we seldom enter this branch (e.g. on brill efficient)
                                            while replacetail do
                                                if seq[n][getchar(replacetail)] then
                                                    n = n - 1
                                                    if replacetail == replace then
                                                        break
                                                    else
                                                        replacetail = getprev(replacetail)
                                                        if n < 1 then
                                                            break
                                                        end
                                                    end
                                                else
                                                    notmatchreplace[prev] = true
                                                    match = not notmatchpost[prev]
                                                    break
                                                end
                                            end
                                            if not match then
                                                break
                                            end
                                        else
                                            -- skip 'm
                                        end
                                    else
                                        -- skip 'm
                                    end
                                elseif seq[n][32] then
                                    n = n - 1
                                else
                                    match = false
                                    break
                                end
                                prev = getprev(prev)
                            elseif seq[n][32] then -- somewhat special, as zapfino can have many preceding spaces
                                n = n - 1
                            else
                                match = false
                                break
                            end
                        end
                    else
                        match = false
                    end
                else
                    match = false
                end
            end
            -- after
            if match and s > l then
                local current = last and getnext(last)
                if not current then
                    if sweeptype == "post" or sweeptype == "replace" then
                        current   = getnext(sweepnode)
                     -- sweeptype = nil
                    end
                end
                if current then
                    local discfound = nil
                    -- removed optimization for s-l == 1, we have to deal with marks anyway
                    local n = l + 1
                    while n <= s do
                        if current then
                            local char, id = ischar(current,currentfont)
                            if char then
                                local ccd = descriptions[char]
                                if ccd then
                                    local class = ccd.class
                                    if class == skipmark or class == skipligature or class == skipbase or (markclass and class == "mark" and not markclass[char]) then
                                        skipped = true
                                        if trace_skips then
                                            show_skip(dataset,sequence,char,ck,class)
                                        end
                                    elseif seq[n][char] then
                                        n = n + 1
                                    else
                                        if discfound then
                                            notmatchreplace[discfound] = true
                                            match = not notmatchpre[discfound]
                                        else
                                            match = false
                                        end
                                        break
                                    end
                                else
                                    if discfound then
                                        notmatchreplace[discfound] = true
                                        match = not notmatchpre[discfound]
                                    else
                                        match = false
                                    end
                                    break
                                end
                            elseif char == false then
                                if discfound then
                                    notmatchreplace[discfound] = true
                                    match = not notmatchpre[discfound]
                                else
                                    match = false
                                end
                                break
                            elseif id == disc_code then
                                diskseen                 = true
                                discfound                = current
                                notmatchpre[current]     = nil
                                notmatchpost[current]    = true
                                notmatchreplace[current] = nil
                                local pre, post, replace = getdisc(current)
                                if pre then
                                    local n = n
                                    while pre do
                                        if seq[n][getchar(pre)] then
                                            n = n + 1
                                            pre = getnext(pre)
                                            if n > s then
                                                break
                                            end
                                        else
                                            notmatchpre[current] = true
                                            break
                                        end
                                    end
                                    if n <= s then
                                        notmatchpre[current] = true
                                    end
                                else
                                    notmatchpre[current] = true
                                end
                                if replace then
                                    -- so far we never entered this branch
                                    while replace do
                                        if seq[n][getchar(replace)] then
                                            n = n + 1
                                            replace = getnext(replace)
                                            if n > s then
                                                break
                                            end
                                        else
                                            notmatchreplace[current] = true
                                            match = notmatchpre[current]
                                            break
                                        end
                                    end
                                    if not match then
                                        break
                                    end
                                else
                                    -- skip 'm
                                end
                            elseif seq[n][32] then -- brrr
                                n = n + 1
                            else
                                match = false
                                break
                            end
                            current = getnext(current)
                        elseif seq[n][32] then
                            n = n + 1
current = getnext(current)
                        else
                            match = false
                            break
                        end
                    end
                else
                    match = false
                end
            end
        end
        if match then
            -- can lookups be of a different type ?
            local diskchain = diskseen or sweepnode
            if trace_contexts then
                local rule       = ck[1]
                local lookuptype = ck[8] or ck[2]
                local first      = ck[4]
                local last       = ck[5]
                local char       = getchar(start)
                logwarning("%s: rule %s matches at char %s for (%s,%s,%s) chars, lookuptype %a",
                    cref(dataset,sequence),rule,gref(char),first-1,last-first+1,s-last,lookuptype)
            end
            local chainlookups = ck[6]
            if chainlookups then
                local nofchainlookups = #chainlookups
                -- we can speed this up if needed
                if nofchainlookups == 1 then
                    local chainlookup = chainlookups[1]
                    local chainkind   = chainlookup.type
                    local chainproc   = chainprocs[chainkind]
                    if chainproc then
                        local ok
                        if diskchain then
                            head, start, ok = chaindisk(head,start,last,dataset,sequence,chainlookup,rlmode,1,ck,chainproc)
                        else
                            head, start, ok = chainproc(head,start,last,dataset,sequence,chainlookup,rlmode,1)
                        end
                        if ok then
                            done = true
                        end
                    else
                        logprocess("%s: %s is not yet supported (1)",cref(dataset,sequence),chainkind)
                    end
                 else
                    local i = 1
                    while start and true do
                        if skipped then
                            while start do -- todo: use properties
                                local char = getchar(start)
                                local ccd = descriptions[char]
                                if ccd then
                                    local class = ccd.class or "base"
                                    if class == skipmark or class == skipligature or class == skipbase or (markclass and class == "mark" and not markclass[char]) then
                                        start = getnext(start)
                                    else
                                        break
                                    end
                                else
                                    break
                                end
                            end
                        end
                        -- see remark in ms standard under : LookupType 5: Contextual Substitution Subtable
                        local chainlookup = chainlookups[1] -- should be i when they can be different
                        if not chainlookup then
                            -- we just advance
                            i = i + 1 -- shouldn't that be #current
                        else
                            local chainkind = chainlookup.type
                            local chainproc = chainprocs[chainkind]
                            if chainproc then
                                local ok, n
                                if diskchain then
                                    head, start, ok    = chaindisk(head,start,last,dataset,sequence,chainlookup,rlmode,i,ck,chainproc)
                                else
                                    head, start, ok, n = chainproc(head,start,last,dataset,sequence,chainlookup,rlmode,i)
                                end
                                -- messy since last can be changed !
                                if ok then
                                    done = true
                                    if n and n > 1 then
                                        -- we have a ligature (cf the spec we advance one but we really need to test it
                                        -- as there are fonts out there that are fuzzy and have too many lookups:
                                        --
                                        -- U+1105 U+119E U+1105 U+119E : sourcehansansklight: script=hang ccmp=yes
                                        --
                                        if i + n > nofchainlookups then
                                         -- if trace_contexts then
                                         --     logprocess("%s: quitting lookups",cref(dataset,sequence))
                                         -- end
                                            break
                                        else
                                            -- we need to carry one
                                        end
                                    end
                                end
                            else
                                -- actually an error
                                logprocess("%s: %s is not yet supported (2)",cref(dataset,sequence),chainkind)
                            end
                            i = i + 1
                        end
                        if i > nofchainlookups or not start then
                            break
                        elseif start then
                            start = getnext(start)
                        end
                    end
                end
            else
                local replacements = ck[7]
                if replacements then
                    head, start, done = reversesub(head,start,last,dataset,sequence,replacements,rlmode)
                else
                    done = quit_on_no_replacement -- can be meant to be skipped / quite inconsistent in fonts
                    if trace_contexts then
                        logprocess("%s: skipping match",cref(dataset,sequence))
                    end
                end
            end
            if done then
                break -- out of contexts (new, needs checking)
            end
        end
    end
    if diskseen then
        notmatchpre     = { }
        notmatchpost    = { }
        notmatchreplace = { }
    end
    return head, start, done
end

handlers.gsub_context             = handle_contextchain
handlers.gsub_contextchain        = handle_contextchain
handlers.gsub_reversecontextchain = handle_contextchain
handlers.gpos_contextchain        = handle_contextchain
handlers.gpos_context             = handle_contextchain

-- this needs testing

local function chained_contextchain(head,start,stop,dataset,sequence,currentlookup,rlmode)
    local steps    = currentlookup.steps
    local nofsteps = currentlookup.nofsteps
    if nofsteps > 1 then
        reportmoresteps(dataset,sequence)
    end
    return handle_contextchain(head,start,dataset,sequence,currentlookup,rlmode)
end

chainprocs.gsub_context             = chained_contextchain
chainprocs.gsub_contextchain        = chained_contextchain
chainprocs.gsub_reversecontextchain = chained_contextchain
chainprocs.gpos_contextchain        = chained_contextchain
chainprocs.gpos_context             = chained_contextchain

local missing = setmetatableindex("table")

local function logprocess(...)
    if trace_steps then
        registermessage(...)
    end
    report_process(...)
end

local logwarning = report_process

local function report_missing_coverage(dataset,sequence)
    local t = missing[currentfont]
    if not t[sequence] then
        t[sequence] = true
        logwarning("missing coverage for feature %a, lookup %a, type %a, font %a, name %a",
            dataset[4],sequence.name,sequence.type,currentfont,tfmdata.properties.fullname)
    end
end

local resolved = { } -- we only resolve a font,script,language pair once

-- todo: pass all these 'locals' in a table

local sequencelists = setmetatableindex(function(t,font)
    local sequences = fontdata[font].resources.sequences
    if not sequences or not next(sequences) then
        sequences = false
    end
    t[font] = sequences
    return sequences
end)

-- fonts.hashes.sequences = sequencelists

local autofeatures    = fonts.analyzers.features
local featuretypes    = otf.tables.featuretypes
local defaultscript   = otf.features.checkeddefaultscript
local defaultlanguage = otf.features.checkeddefaultlanguage

local function initialize(sequence,script,language,enabled,autoscript,autolanguage)
    local features = sequence.features
    if features then
        local order = sequence.order
        if order then
            local featuretype = featuretypes[sequence.type or "unknown"]
            for i=1,#order do
                local kind  = order[i]
                local valid = enabled[kind]
                if valid then
                    local scripts   = features[kind]
                    local languages = scripts and (
                        scripts[script] or
                        scripts[wildcard] or
                        (autoscript and defaultscript(featuretype,autoscript,scripts))
                    )
                    local enabled = languages and (
                        languages[language] or
                        languages[wildcard] or
                        (autolanguage and defaultlanguage(featuretype,autolanguage,languages))
                    )
                    if enabled then
                        return { valid, autofeatures[kind] or false, sequence, kind }
                    end
                end
            end
        else
            -- can't happen
        end
    end
    return false
end

function otf.dataset(tfmdata,font) -- generic variant, overloaded in context
    local shared       = tfmdata.shared
    local properties   = tfmdata.properties
    local language     = properties.language or "dflt"
    local script       = properties.script   or "dflt"
    local enabled      = shared.features
    local autoscript   = enabled and enabled.autoscript
    local autolanguage = enabled and enabled.autolanguage
    local res = resolved[font]
    if not res then
        res = { }
        resolved[font] = res
    end
    local rs = res[script]
    if not rs then
        rs = { }
        res[script] = rs
    end
    local rl = rs[language]
    if not rl then
        rl = {
            -- indexed but we can also add specific data by key
        }
        rs[language] = rl
        local sequences = tfmdata.resources.sequences
        for s=1,#sequences do
            local v = enabled and initialize(sequences[s],script,language,enabled,autoscript,autolanguage)
            if v then
                rl[#rl+1] = v
            end
        end
    end
    return rl
end

local function report_disc(what,n)
    report_run("%s: %s > %s",what,n,languages.serializediscretionary(n))
end

local function kernrun(disc,k_run,font,attr,...)
    --
    -- we catch <font 1><disc font 2>
    --
    if trace_kernruns then
        report_disc("kern",disc)
    end
    --
    local prev, next = getboth(disc)
    --
    local nextstart = next
    local done      = false
    --
    local pre, post, replace, pretail, posttail, replacetail = getdisc(disc,true)
    --
    local prevmarks = prev
    --
    -- can be optional, because why on earth do we get a disc after a mark (okay, maybe when a ccmp
    -- has happened but then it should be in the disc so basically this test indicates an error)
    --
    while prevmarks do
        local char = ischar(prevmarks,font)
        if char and marks[char] then
            prevmarks = getprev(prevmarks)
        else
            break
        end
    end
    --
    if prev and (pre or replace) and not ischar(prev,font) then
        prev = false
    end
    if next and (post or replace) and not ischar(next,font) then
        next = false
    end
    --
    -- we need to get rid of this nest mess some day .. has to be done otherwise
    --
    if pre then
        if k_run(pre,"injections",nil,font,attr,...) then
            done = true
        end
        if prev then
            local nest = getprev(pre)
            setlink(prev,pre)
            if k_run(prevmarks,"preinjections",pre,font,attr,...) then -- or prev?
                done = true
            end
            setprev(pre,nest)
            setnext(prev,disc)
        end
    end
    --
    if post then
        if k_run(post,"injections",nil,font,attr,...) then
            done = true
        end
        if next then
            setlink(posttail,next)
            if k_run(posttail,"postinjections",next,font,attr,...) then
                done = true
            end
            setnext(posttail,nil)
            setprev(next,disc)
        end
    end
    --
    if replace then
        if k_run(replace,"injections",nil,font,attr,...) then
            done = true
        end
        if prev then
            local nest = getprev(replace)
            setlink(prev,replace)
            if k_run(prevmarks,"replaceinjections",replace,font,attr,...) then -- getnext(replace))
                done = true
            end
            setprev(replace,nest)
            setnext(prev,disc)
        end
        if next then
            setlink(replacetail,next)
            if k_run(replacetail,"replaceinjections",next,font,attr,...) then
                done = true
            end
            setnext(replacetail,nil)
            setprev(next,disc)
        end
    elseif prev and next then
        setlink(prev,next)
        if k_run(prevmarks,"emptyinjections",next,font,attr,...) then
            done = true
        end
        setlink(prev,disc)
        setlink(disc,next)
    end
    return nextstart, done
end

local function comprun(disc,c_run,...)
    if trace_compruns then
        report_disc("comp",disc)
    end
    --
    local pre, post, replace = getdisc(disc)
    local renewed = false
    --
    if pre then
        sweepnode = disc
        sweeptype = "pre" -- in alternative code preinjections is uc_c_sed (also used then for proeprties, saves a variable)
        local new, done = c_run(pre,...)
        if done then
            pre     = new
            renewed = true
        end
    end
    --
    if post then
        sweepnode = disc
        sweeptype = "post"
        local new, done = c_run(post,...)
        if done then
            post    = new
            renewed = true
        end
    end
    --
    if replace then
        sweepnode = disc
        sweeptype = "replace"
        local new, done = c_run(replace,...)
        if done then
            replace = new
            renewed = true
        end
    end
    --
    sweepnode = nil
    sweeptype = nil
    if renewed then
        setdisc(disc,pre,post,replace)
    end
    --
    return getnext(disc), renewed
end

local function testrun(disc,t_run,c_run,...)
    if trace_testruns then
        report_disc("test",disc)
    end
    local prev, next = getboth(disc)
    if not next then
        -- weird discretionary
        return
    end
    local pre, post, replace, pretail, posttail, replacetail = getdisc(disc,true)
    local done = false
    if replace and prev then
        -- this is a bit strange as we only do replace here and not post
        -- anyway, we only look ahead ... the idea is that we discard a
        -- disc when there is a ligature crossing the replace boundary
        setlink(replacetail,next)
        local ok, overflow = t_run(replace,next,...)
        if ok and overflow then
            -- so, we can have crossed the boundary
            setfield(disc,"replace",nil)
            setlink(prev,replace)
         -- setlink(replacetail,next)
            setboth(disc)
            flush_node_list(disc)
            return replace, true -- restart .. tricky !
        else
            -- we stay inside the disc
            setnext(replacetail)
            setprev(next,disc)
        end
     -- pre, post, replace, pretail, posttail, replacetail = getdisc(disc,true)
    end
    --
    -- like comprun
    --
    local renewed = false
    --
    if pre then
        sweepnode = disc
        sweeptype = "pre"
        local new, ok = c_run(pre,...)
        if ok then
            pre     = new
            renewed = true
        end
    end
    --
    if post then
        sweepnode = disc
        sweeptype = "post"
        local new, ok = c_run(post,...)
        if ok then
            post    = new
            renewed = true
        end
    end
    --
    if replace then
        sweepnode = disc
        sweeptype = "replace"
        local new, ok = c_run(replace,...)
        if ok then
            replace = new
            renewed = true
        end
    end
    --
    sweepnode = nil
    sweeptype = nil
    if renewed then
        setdisc(disc,pre,post,replace)
        return next, true
    else
        return next, done
    end
end

-- A discrun happens when we have a zwnj. We're gpossing so it is unlikely that
-- there has been a match changing the character. Now, as we check again here
-- the question is: why do we do this ... needs checking as drun seems useless
-- ... maybe that code can go away

-- local function discrun(disc,drun,krun)
--     local prev, next = getboth(disc)
--     if trace_discruns then
--        report_disc("disc",disc)
--     end
--     if next and prev then
--         setnext(prev,next)
--      -- setprev(next,prev)
--         drun(prev)
--         setnext(prev,disc)
--      -- setprev(next,disc)
--     end
--     --
--     if krun then -- currently always false
--         local pre = getfield(disc,"pre")
--         if not pre then
--             -- go on
--         elseif prev then
--             local nest = getprev(pre)
--             setlink(prev,pre)
--             krun(prev,"preinjections")
--             setprev(pre,nest)
--             setnext(prev,disc)
--         else
--             krun(pre,"preinjections")
--         end
--     end
--     return next
-- end

-- We can make some assumptions with respect to discretionaries. First of all it is very
-- unlikely that some of the analysis related attributes applies. Then we can also assume
-- that the ConTeXt specific dynamic attribute is different, although we do use explicit
-- discretionaries (maybe we need to tag those some day). So, at least for now, we don't
-- have the following test in the sub runs:
--
-- -- local a = getattr(start,0)
-- -- if a then
-- --     a = (a == attr) and (not attribute or getprop(start,a_state) == attribute)
-- -- else
-- --     a = not attribute or getprop(start,a_state) == attribute
-- -- end
-- -- if a then
--
-- but use this instead:
--
-- -- local a = getattr(start,0)
-- -- if not a or (a == attr) then
--
-- and even that one is probably not needed.

local nesting = 0

local function c_run_single(head,font,attr,lookupcache,step,dataset,sequence,rlmode,handler)
    local done  = false
    local sweep = sweephead[head]
    if sweep then
        start = sweep
        sweephead[head] = nil
    else
        start = head
    end
    while start do
        local char = ischar(start,font)
        if char then
            local a = getattr(start,0)
            if not a or (a == attr) then
                local lookupmatch = lookupcache[char]
                if lookupmatch then
                    local ok
                    head, start, ok = handler(head,start,dataset,sequence,lookupmatch,rlmode,step,1)
                    if ok then
                        done = true
                    end
                end
                if start then
                    start = getnext(start)
                end
            else
                start = getnext(start)
            end
        elseif char == false then
            return head, done
        elseif sweep then
            -- else we loose the rest
            return head, done
        else
            -- in disc component
            start = getnext(start)
        end
    end
    return head, done
end

local function t_run_single(start,stop,font,attr,lookupcache)
    while start ~= stop do
        local char = ischar(start,font)
        if char then
            local a = getattr(start,0)
            if not a or (a == attr) then
                local lookupmatch = lookupcache[char]
                if lookupmatch then -- hm, hyphens can match (tlig) so we need to really check
                    -- if we need more than ligatures we can outline the code and use functions
                    local s = getnext(start)
                    local l = nil
                    local d = 0
                    while s do
                        if s == stop then
                            d = 1
                        elseif d > 0 then
                            d = d + 1
                        end
                        local lg = lookupmatch[getchar(s)]
                        if lg then
                            l = lg
                            s = getnext(s)
                        else
                            break
                        end
                    end
                    if l and l.ligature then
                        return true, d > 1
                    end
                end
            end
            start = getnext(start)
        else
            break
        end
    end
end

-- local function d_run_single(prev,font,attr,lookupcache,step,dataset,sequence,rlmode,handler)
--     local a = getattr(prev,0)
--     if not a or (a == attr) then
--         local char = ischar(prev) -- can be disc
--         if char then
--             local lookupmatch = lookupcache[char]
--             if lookupmatch then
--                 local h, d, ok = handler(head,start,dataset,sequence,lookupmatch,rlmode,step,1)
--                 if ok then
--                     done = true
--                     success = true
--                 end
--             end
--         end
--     end
-- end

local function k_run_single(sub,injection,last,font,attr,lookupcache,step,dataset,sequence,rlmode,handler)
    local a = getattr(sub,0)
    if not a or (a == attr) then
        for n in traverse_nodes(sub) do -- only gpos
            if n == last then
                break
            end
            local char = ischar(n)
            if char then
                local lookupmatch = lookupcache[char]
                if lookupmatch then
                    local h, d, ok = handler(sub,n,dataset,sequence,lookupmatch,rlmode,step,1,injection)
                    if ok then
                        return true
                    end
                end
            end
        end
    end
end

local function c_run_multiple(head,font,attr,steps,nofsteps,dataset,sequence,rlmode,handler)
    local done  = false
    local sweep = sweephead[head]
    if sweep then
        start = sweep
        sweephead[head] = nil
    else
        start = head
    end
    while start do
        local char = ischar(start,font)
        if char then
            local a = getattr(start,0)
            if not a or (a == attr) then
                for i=1,nofsteps do
                    local step        = steps[i]
                    local lookupcache = step.coverage
                    if lookupcache then
                        local lookupmatch = lookupcache[char]
                        if lookupmatch then
                            -- we could move all code inline but that makes things even more unreadable
                            local ok
                            head, start, ok = handler(head,start,dataset,sequence,lookupmatch,rlmode,step,i)
                            if ok then
                                done = true
                                break
                            elseif not start then
                                -- don't ask why ... shouldn't happen
                                break
                            end
                        end
                    else
                        report_missing_coverage(dataset,sequence)
                    end
                end
                if start then
                    start = getnext(start)
                end
            else
                start = getnext(start)
            end
        elseif char == false then
            -- whatever glyph
            return head, done
        elseif sweep then
            -- else we loose the rest
            return head, done
        else
            -- in disc component
            start = getnext(start)
        end
    end
    return head, done
end

local function t_run_multiple(start,stop,font,attr,steps,nofsteps)
    while start ~= stop do
        local char = ischar(start,font)
        if char then
            local a = getattr(start,0)
            if not a or (a == attr) then
                for i=1,nofsteps do
                    local step = steps[i]
                    local lookupcache = step.coverage
                    if lookupcache then
                        local lookupmatch = lookupcache[char]
                        if lookupmatch then
                            -- if we need more than ligatures we can outline the code and use functions
                            local s = getnext(start)
                            local l = nil
                            local d = 0
                            while s do
                                if s == stop then
                                    d = 1
                                elseif d > 0 then
                                    d = d + 1
                                end
                                local lg = lookupmatch[getchar(s)]
                                if lg then
                                    l = lg
                                    s = getnext(s)
                                else
                                    break
                                end
                            end
                            if l and l.ligature then
                                return true, d > 1
                            end
                        end
                    else
                        report_missing_coverage(dataset,sequence)
                    end
                end
            end
            start = getnext(start)
        else
            break
        end
    end
end

-- local function d_run_multiple(prev,attr,steps,nofsteps,dataset,sequence,rlmode,handler)
--     local a = getattr(prev,0)
--     if not a or (a == attr) then
--         local char = ischar(prev) -- can be disc
--         if char then
--             for i=1,nofsteps do
--                 local step        = steps[i]
--                 local lookupcache = step.coverage
--                 if lookupcache then
--                     local lookupmatch = lookupcache[char]
--                     if lookupmatch then
--                         -- we could move all code inline but that makes things even more unreadable
--                         local h, d, ok = handler(head,prev,dataset,sequence,lookupmatch,rlmode,step,i)
--                         if ok then
--                             done = true
--                             break
--                         end
--                     end
--                 else
--                     report_missing_coverage(dataset,sequence)
--                 end
--             end
--         end
--     end
-- end

local function k_run_multiple(sub,injection,last,font,attr,steps,nofsteps,dataset,sequence,rlmode,handler)
    local a = getattr(sub,0)
    if not a or (a == attr) then
        for n in traverse_nodes(sub) do -- only gpos
            if n == last then
                break
            end
            local char = ischar(n)
            if char then
                for i=1,nofsteps do
                    local step        = steps[i]
                    local lookupcache = step.coverage
                    if lookupcache then
                        local lookupmatch = lookupcache[char]
                        if lookupmatch then
                            local h, d, ok = handler(head,n,dataset,sequence,lookupmatch,step,rlmode,i,injection)
                            if ok then
                                return true
                            end
                        end
                    else
                        report_missing_coverage(dataset,sequence)
                    end
                end
            end
        end
    end
end

-- to be checkedL nowadays we probably can assume properly matched directions
-- so maybe we no longer need a stack

local function txtdirstate(start,stack,top,rlparmode)
    local dir = getfield(start,"dir")
    local new = 1
    if dir == "+TRT" then
        top = top + 1
        stack[top] = dir
        new = -1
    elseif dir == "+TLT" then
        top = top + 1
        stack[top] = dir
    elseif dir == "-TRT" or dir == "-TLT" then
        top = top - 1
        if stack[top] == "+TRT" then
            new = -1
        end
    else
        new = rlparmode
    end
    if trace_directions then
        report_process("directions after txtdir %a: parmode %a, txtmode %a, level %a",dir,mref(rlparmode),mref(new),topstack)
    end
    return getnext(start), top, new
end

local function pardirstate(start)
    local dir = getfield(start,"dir")
    local new = 0
    if dir == "TLT" then
        new = 1
    elseif dir == "TRT" then
        new = -1
    end
    if trace_directions then
        report_process("directions after pardir %a: parmode %a",dir,mref(new))
    end
    return getnext(start), new, new
end

local function featuresprocessor(head,font,attr)

    local sequences = sequencelists[font] -- temp hack

    if not sequencelists then
        return head, false
    end

    nesting = nesting + 1

    if nesting == 1 then

        currentfont     = font
        tfmdata         = fontdata[font]
        descriptions    = tfmdata.descriptions
        characters      = tfmdata.characters
        marks           = tfmdata.resources.marks
        factor          = tfmdata.parameters.factor
        threshold       = tfmdata.parameters.spacing.width or 65536*10

    elseif currentfont ~= font then

        report_warning("nested call with a different font, level %s, quitting",nesting)
        nesting = nesting - 1
        return head, false

    end

    head = tonut(head)

    if trace_steps then
        checkstep(head)
    end

    local rlmode    = 0

    local done      = false
    local datasets  = otf.dataset(tfmdata,font,attr)

    local dirstack  = { } -- could move outside function btu we can have local runss

    sweephead       = { }

    -- We could work on sub start-stop ranges instead but I wonder if there is that
    -- much speed gain (experiments showed that it made not much sense) and we need
    -- to keep track of directions anyway. Also at some point I want to play with
    -- font interactions and then we do need the full sweeps.

    -- Keeping track of the headnode is needed for devanagari (I generalized it a bit
    -- so that multiple cases are also covered.)

    -- We don't goto the next node of a disc node is created so that we can then treat
    -- the pre, post and replace. It's a bit of a hack but works out ok for most cases.

    for s=1,#datasets do
        local dataset      = datasets[s]
        ----- featurevalue = dataset[1] -- todo: pass to function instead of using a global
        local attribute    = dataset[2]
        local sequence     = dataset[3] -- sequences[s] -- also dataset[5]
        local rlparmode    = 0
        local topstack     = 0
        local success      = false
        local typ          = sequence.type
        local gpossing     = typ == "gpos_single" or typ == "gpos_pair" -- store in dataset
        local handler      = handlers[typ]
        local steps        = sequence.steps
        local nofsteps     = sequence.nofsteps
        if not steps then
            -- this permits injection, watch the different arguments
            local h, d, ok = handler(head,start,dataset,sequence,nil,nil,nil,0,font,attr)
            if ok then
                success = true
                if h then
                    head = h
                end
                if d then
                    start = d
                end
            end
        elseif typ == "gsub_reversecontextchain" then
            -- this is a limited case, no special treatments like 'init' etc
            local start = find_node_tail(head)
            while start do
                local char = ischar(start,font)
                if char then
                    local a = getattr(start,0)
                    if not a or (a == attr) then
                        for i=1,nofsteps do
                            local step = steps[i]
                            local lookupcache = step.coverage
                            if lookupcache then
                                local lookupmatch = lookupcache[char]
                                if lookupmatch then
                                    -- todo: disc?
                                    local ok
                                    head, start, ok = handler(head,start,dataset,sequence,lookupmatch,rlmode,step,i)
                                    if ok then
                                        success = true
                                        break
                                    end
                                end
                            else
                                report_missing_coverage(dataset,sequence)
                            end
                        end
                        if start then
                            start = getprev(start)
                        end
                    else
                        start = getprev(start)
                    end
                else
                    start = getprev(start)
                end
            end
        else
            local start = head -- local ?
            rlmode = 0 -- to be checked ?
            if nofsteps == 1 then -- happens often

                local step = steps[1]
                local lookupcache = step.coverage
                if not lookupcache then
                 -- can't happen, no check in loop either
                    report_missing_coverage(dataset,sequence)
                else

                    while start do
                        local char, id = ischar(start,font)
                        if char then
                            local a = getattr(start,0)
                            if a then
                                a = (a == attr) and (not attribute or getprop(start,a_state) == attribute)
                            else
                                a = not attribute or getprop(start,a_state) == attribute
                            end
                            if a then
                                local lookupmatch = lookupcache[char]
                                if lookupmatch then
                                    local ok
                                    head, start, ok = handler(head,start,dataset,sequence,lookupmatch,rlmode,step,1)
                                    if ok then
                                        success = true
                                 -- elseif gpossing and zwnjruns and char == zwnj then
                                 --     discrun(start,d_run,font,attr,lookupcache)
                                    end
                             -- elseif gpossing and zwnjruns and char == zwnj then
                             --     discrun(start,d_run,font,attr,lookupcache)
                                end
                                if start then
                                    start = getnext(start)
                                end
                            else
                               start = getnext(start)
                            end
                        elseif char == false then
                           -- whatever glyph
                           start = getnext(start)
                        elseif id == disc_code then
                            local ok
                            if gpossing then
                                start, ok = kernrun(start,k_run_single,             font,attr,lookupcache,step,dataset,sequence,rlmode,handler)
                            elseif typ == "gsub_ligature" then
                                start, ok = testrun(start,t_run_single,c_run_single,font,attr,lookupcache,step,dataset,sequence,rlmode,handler)
                            else
                                start, ok = comprun(start,c_run_single,             font,attr,lookupcache,step,dataset,sequence,rlmode,handler)
                            end
                            if ok then
                                success = true
                            end
                        elseif id == math_code then
                            start = getnext(end_of_math(start))
                        elseif id == dir_code then
                            start, topstack, rlmode = txtdirstate(start,dirstack,topstack,rlparmode)
                        elseif id == localpar_code then
                            start, rlparmode, rlmode = pardirstate(start)
                        else
                            start = getnext(start)
                        end
                    end
                end

            else

                while start do
                    local char, id = ischar(start,font)
                    if char then
                        local a = getattr(start,0)
                        if a then
                            a = (a == attr) and (not attribute or getprop(start,a_state) == attribute)
                        else
                            a = not attribute or getprop(start,a_state) == attribute
                        end
                        if a then
                            for i=1,nofsteps do
                                local step        = steps[i]
                                local lookupcache = step.coverage
                                if lookupcache then
                                    local lookupmatch = lookupcache[char]
                                    if lookupmatch then
                                        -- we could move all code inline but that makes things even more unreadable
                                        local ok
                                        head, start, ok = handler(head,start,dataset,sequence,lookupmatch,rlmode,step,i)
                                        if ok then
                                            success = true
                                            break
                                        elseif not start then
                                            -- don't ask why ... shouldn't happen
                                            break
                                     -- elseif gpossing and zwnjruns and char == zwnj then
                                     --     discrun(start,d_run,font,attr,steps,nofsteps)
                                        end
                                 -- elseif gpossing and zwnjruns and char == zwnj then
                                 --     discrun(start,d_run,font,attr,steps,nofsteps)
                                    end
                                else
                                    report_missing_coverage(dataset,sequence)
                                end
                            end
                            if start then
                                start = getnext(start)
                            end
                        else
                            start = getnext(start)
                        end
                    elseif char == false then
                        start = getnext(start)
                    elseif id == disc_code then
                        local ok
                        if gpossing then
                            start, ok = kernrun(start,k_run_multiple,               font,attr,steps,nofsteps,dataset,sequence,rlmode,handler)
                        elseif typ == "gsub_ligature" then
                            start, ok = testrun(start,t_run_multiple,c_run_multiple,font,attr,steps,nofsteps,dataset,sequence,rlmode,handler)
                        else
                            start, ok = comprun(start,c_run_multiple,               font,attr,steps,nofsteps,dataset,sequence,rlmode,handler)
                        end
                        if ok then
                            success = true
                        end
                    elseif id == math_code then
                        start = getnext(end_of_math(start))
                    elseif id == dir_code then
                        start, topstack, rlmode = txtdirstate(start,dirstack,topstack,rlparmode)
                    elseif id == localpar_code then
                        start, rlparmode, rlmode = pardirstate(start)
                    else
                        start = getnext(start)
                    end
                end
            end
        end

        if success then
            done = true
        end
        if trace_steps then -- ?
            registerstep(head)
        end

    end

    nesting = nesting - 1
    head    = tonode(head)

    return head, done
end

-- so far

local function featuresinitializer(tfmdata,value)
    -- nothing done here any more
end

registerotffeature {
    name         = "features",
    description  = "features",
    default      = true,
    initializers = {
        position = 1,
        node     = featuresinitializer,
    },
    processors   = {
        node     = featuresprocessor,
    }
}

-- This can be used for extra handlers, but should be used with care!

otf.handlers = handlers -- used in devanagari

-- We implement one here:

local setspacekerns = nodes.injections.setspacekerns if not setspacekerns then os.exit() end

function otf.handlers.trigger_space_kerns(head,start,dataset,sequence,_,_,_,_,font,attr)
 -- if not setspacekerns then
 --     setspacekerns = nodes.injections.setspacekerns
 -- end
    setspacekerns(font,sequence)
    return head, start, true
end

local function hasspacekerns(data)
    local sequences = data.resources.sequences
    for i=1,#sequences do
        local sequence = sequences[i]
        local steps    = sequence.steps
        if steps and sequence.features.kern then
            for i=1,#steps do
                local coverage = steps[i].coverage
                if not coverage then
                    -- maybe an issue
                elseif coverage[32] then
                    return true
                else
                    for k, v in next, coverage do
                        if v[32] then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

otf.readers.registerextender {
    name   = "spacekerns",
    action = function(data)
        data.properties.hasspacekerns = hasspacekerns(data)
    end
}

local function spaceinitializer(tfmdata,value) -- attr
    local resources  = tfmdata.resources
    local spacekerns = resources and resources.spacekerns
    if spacekerns == nil then
        local properties = tfmdata.properties
        if properties and properties.hasspacekerns then
            local sequences = resources.sequences
            local left  = { }
            local right = { }
            local last  = 0
            local feat  = nil
            for i=1,#sequences do
                local sequence = sequences[i]
                local steps    = sequence.steps
                if steps then
                    local kern = sequence.features.kern
                    if kern then
                        feat = feat or kern -- or maybe merge
                        for i=1,#steps do
                            local step = steps[i]
                            local coverage = step.coverage
                            if coverage then
                                local kerns = coverage[32]
                                if kerns then
                                    for k, v in next, kerns do
                                        if type(v) == "table" then
                                            right[k] = v[3] -- needs checking
                                        else
                                            right[k] = v
                                        end
                                    end
                                end
                                for k, v in next, coverage do
                                    local kern = v[32]
                                    if kern then
                                        if type(kern) == "table" then
                                            left[k] = kern[3] -- needs checking
                                        else
                                            left[k] = kern
                                        end
                                    end
                                end
                            end
                        end
                        last = i
                    end
                else
                    -- no steps ... needed for old one ... we could use the basekerns
                    -- instead
                end
            end
            left  = next(left)  and left  or false
            right = next(right) and right or false
            if left or right then
                spacekerns = {
                    left  = left,
                    right = right,
                }
                if last > 0 then
                    local triggersequence = {
                        features = { kern = feat or { dflt = { dflt = true, } } },
                        flags    = noflags,
                        name     = "trigger_space_kerns",
                        order    = { "kern" },
                        type     = "trigger_space_kerns",
                        left     = left,
                        right    = right,
                    }
                    insert(sequences,last,triggersequence)
                end
            else
                spacekerns = false
            end
        else
            spacekerns = false
        end
        resources.spacekerns = spacekerns
    end
    return spacekerns
end

registerotffeature {
    name         = "spacekern",
    description  = "space kern injection",
    default      = true,
    initializers = {
        node     = spaceinitializer,
    },
}
