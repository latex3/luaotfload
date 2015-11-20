if not modules then modules = { } end modules ['font-otn'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- this is a context version which can contain experimental code, but when we
-- have serious patches we also need to change the other two font-otn files

-- at some point i might decide to convert the whole list into a table and then
-- run over that instead (but it has some drawbacks as we also need to deal with
-- attributes and such so we need to keep a lot of track - which is why i rejected
-- that method - although it has become a bit easier in the meantime so it might
-- become an alternative (by that time i probably have gone completely lua) .. the
-- usual chicken-egg issues ... maybe mkix as it's no real tex any more then

-- preprocessors = { "nodes" }

-- anchor class : mark, mkmk, curs, mklg (todo)
-- anchor type  : mark, basechar, baselig, basemark, centry, cexit, max (todo)

-- this is still somewhat preliminary and it will get better in due time;
-- much functionality could only be implemented thanks to the husayni font
-- of Idris Samawi Hamid to who we dedicate this module.

-- in retrospect it always looks easy but believe it or not, it took a lot
-- of work to get proper open type support done: buggy fonts, fuzzy specs,
-- special made testfonts, many skype sessions between taco, idris and me,
-- torture tests etc etc ... unfortunately the code does not show how much
-- time it took ...

-- todo:
--
-- extension infrastructure (for usage out of context)
-- sorting features according to vendors/renderers
-- alternative loop quitters
-- check cursive and r2l
-- find out where ignore-mark-classes went
-- default features (per language, script)
-- handle positions (we need example fonts)
-- handle gpos_single (we might want an extra width field in glyph nodes because adding kerns might interfere)
-- mark (to mark) code is still not what it should be (too messy but we need some more extreem husayni tests)
-- remove some optimizations (when I have a faster machine)
--
-- beware:
--
-- we do some disc jugling where we need to keep in mind that the
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

<p>The raw table as it coms from <l n='fontforge'/> gets reorganized in to fit out needs.
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

-- action                    handler     chainproc
--
-- gsub_single               ok          ok
-- gsub_multiple             ok          ok
-- gsub_alternate            ok          ok
-- gsub_ligature             ok          ok
-- gsub_context              ok          --
-- gsub_contextchain         ok          --
-- gsub_reversecontextchain  ok          --
-- chainsub                  --          ok
-- reversesub                --          ok
-- gpos_mark2base            ok          ok
-- gpos_mark2ligature        ok          ok
-- gpos_mark2mark            ok          ok
-- gpos_cursive              ok          untested
-- gpos_single               ok          ok
-- gpos_pair                 ok          ok
-- gpos_context              ok          --
-- gpos_contextchain         ok          --
--
-- todo: contextpos and contextsub and class stuff
--
-- actions:
--
-- handler   : actions triggered by lookup
-- chainproc : actions triggered by contextual lookup
-- chainmore : multiple substitutions triggered by contextual lookup (e.g. fij -> f + ij)
--
-- remark: the 'not implemented yet' variants will be done when we have fonts that use them

-- We used to have independent hashes for lookups but as the tags are unique
-- we now use only one hash. If needed we can have multiple again but in that
-- case I will probably prefix (i.e. rename) the lookups in the cached font file.

-- Todo: make plugin feature that operates on char/glyphnode arrays

local type, next, tonumber = type, next, tonumber
local random = math.random
local formatters = string.formatters

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

local quit_on_no_replacement = true  -- maybe per font
local zwnjruns               = true

registerdirective("otf.zwnjruns",                 function(v) zwnjruns = v end)
registerdirective("otf.chain.quitonnoreplacement",function(value) quit_on_no_replacement = value end)

local report_direct   = logs.reporter("fonts","otf direct")
local report_subchain = logs.reporter("fonts","otf subchain")
local report_chain    = logs.reporter("fonts","otf chain")
local report_process  = logs.reporter("fonts","otf process")
local report_prepare  = logs.reporter("fonts","otf prepare")
local report_warning  = logs.reporter("fonts","otf warning")
local report_run      = logs.reporter("fonts","otf run")

registertracker("otf.verbose_chain", function(v) otf.setcontextchain(v and "verbose") end)
registertracker("otf.normal_chain",  function(v) otf.setcontextchain(v and "normal")  end)

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
local getprev            = nuts.getprev
local getid              = nuts.getid
local getattr            = nuts.getattr
local setattr            = nuts.setattr
local getprop            = nuts.getprop
local setprop            = nuts.setprop
local getfont            = nuts.getfont
local getsubtype         = nuts.getsubtype
local getchar            = nuts.getchar

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
local whatcodes          = nodes.whatcodes
local glyphcodes         = nodes.glyphcodes
local disccodes          = nodes.disccodes

local glyph_code         = nodecodes.glyph
local glue_code          = nodecodes.glue
local disc_code          = nodecodes.disc
local whatsit_code       = nodecodes.whatsit
local math_code          = nodecodes.math

local dir_code           = whatcodes.dir
local localpar_code      = whatcodes.localpar
local discretionary_code = disccodes.discretionary
local ligature_code      = glyphcodes.ligature

local privateattribute   = attributes.private

-- Something is messed up: we have two mark / ligature indices, one at the injection
-- end and one here ... this is based on KE's patches but there is something fishy
-- there as I'm pretty sure that for husayni we need some connection (as it's much
-- more complex than an average font) but I need proper examples of all cases, not
-- of only some.

local a_state            = privateattribute('state')
local a_cursbase         = privateattribute('cursbase') -- to be checked, probably can go

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

-- we share some vars here, after all, we have no nested lookups and less code

local tfmdata             = false
local characters          = false
local descriptions        = false
local resources           = false
local marks               = false
local currentfont         = false
local lookuptable         = false
local anchorlookups       = false
local lookuptypes         = false
local lookuptags          = false
local handlers            = { }
local rlmode              = 0
local featurevalue        = false

local sweephead           = { }
local sweepnode           = nil
local sweepprev           = nil
local sweepnext           = nil

local notmatchpre         = { }
local notmatchpost        = { }
local notmatchreplace     = { }

-- head is always a whatsit so we can safely assume that head is not changed

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

local function cref(kind,chainname,chainlookupname,lookupname,index) -- not in the mood to alias f_
    if index then
        return formatters["feature %a, chain %a, sub %a, lookup %a, index %a"](kind,chainname,chainlookupname,lookuptags[lookupname],index)
    elseif lookupname then
        return formatters["feature %a, chain %a, sub %a, lookup %a"](kind,chainname,chainlookupname,lookuptags[lookupname])
    elseif chainlookupname then
        return formatters["feature %a, chain %a, sub %a"](kind,lookuptags[chainname],lookuptags[chainlookupname])
    elseif chainname then
        return formatters["feature %a, chain %a"](kind,lookuptags[chainname])
    else
        return formatters["feature %a"](kind)
    end
end

local function pref(kind,lookupname)
    return formatters["feature %a, lookup %a"](kind,lookuptags[lookupname])
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
    local replace = getfield(disc,"replace")
    setfield(disc,"replace",nil)
    free_node(disc)
    if head == disc then
        local next = getnext(disc)
        if replace then
            if next then
                local tail = find_node_tail(replace)
                setfield(tail,"next",next)
                setfield(next,"prev",tail)
            end
            return replace, replace
        elseif next then
            return next, next
        else
            return -- maybe warning
        end
    else
        local next = getnext(disc)
        local prev = getprev(disc)
        if replace then
            local tail = find_node_tail(replace)
            if next then
                setfield(tail,"next",next)
                setfield(next,"prev",tail)
            end
            setfield(prev,"next",replace)
            setfield(replace,"prev",prev)
            return head, replace
        else
            if next then
                setfield(next,"prev",prev)
            end
            setfield(prev,"next",next)
            return head, next
        end
    end
end

local function appenddisc(disc,list)
    local post    = getfield(disc,"post")
    local replace = getfield(disc,"replace")
    local phead   = list
    local rhead   = copy_node_list(list)
    local ptail   = find_node_tail(post)
    local rtail   = find_node_tail(replace)
    if post then
        setfield(ptail,"next",phead)
        setfield(phead,"prev",ptail)
    else
        setfield(disc,"post",phead)
    end
    if replace then
        setfield(rtail,"next",rhead)
        setfield(rhead,"prev",rtail)
    else
        setfield(disc,"replace",rhead)
    end
end

-- start is a mark and we need to keep that one

local function markstoligature(kind,lookupname,head,start,stop,char)
    if start == stop and getchar(start) == char then
        return head, start
    else
        local prev = getprev(start)
        local next = getnext(stop)
        setfield(start,"prev",nil)
        setfield(stop,"next",nil)
        local base = copy_glyph(start)
        if head == start then
            head = base
        end
        resetinjection(base)
        setfield(base,"char",char)
        setfield(base,"subtype",ligature_code)
        setfield(base,"components",start)
        if prev then
            setfield(prev,"next",base)
        end
        if next then
            setfield(next,"prev",base)
        end
        setfield(base,"next",next)
        setfield(base,"prev",prev)
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

local function toligature(kind,lookupname,head,start,stop,char,markflag,discfound) -- brr head
    if getattr(start,a_noligature) == 1 then
        -- so we can do: e\noligature{ff}e e\noligature{f}fie (we only look at the first)
        return head, start
    end
    if start == stop and getchar(start) == char then
        resetinjection(start)
        setfield(start,"char",char)
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
    setfield(start,"prev",nil)
    setfield(stop,"next",nil)
    local base = copy_glyph(start)
    if start == head then
        head = base
    end
    resetinjection(base)
    setfield(base,"char",char)
    setfield(base,"subtype",ligature_code)
    setfield(base,"components",comp) -- start can have components ... do we need to flush?
    if prev then
        setfield(prev,"next",base)
    end
    if next then
        setfield(next,"prev",base)
    end
    setfield(base,"prev",prev)
    setfield(base,"next",next)
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
                    logwarning("%s: keep mark %s, gets index %s",pref(kind,lookupname),gref(char),getligaindex(start))
                end
                local n = copy_node(start)
                copyinjection(n,start)
                head, current = insert_node_after(head,current,n) -- unlikely that mark has components
            elseif trace_marks then
                logwarning("%s: delete mark %s",pref(kind,lookupname),gref(char))
            end
            start = getnext(start)
        end
        -- we can have one accent as part of a lookup and another following
     -- local start = components -- was wrong (component scanning was introduced when more complex ligs in devanagari was added)
        local start = getnext(current)
        while start and getid(start) == glyph_code do
            local char = getchar(start)
            if marks[char] then
                setligaindex(start,baseindex + getligaindex(start,componentindex))
                if trace_marks then
                    logwarning("%s: set mark %s, gets index %s",pref(kind,lookupname),gref(char),getligaindex(start))
                end
            else
                break
            end
            start = getnext(start)
        end
    else
        -- discfound ... forget about marks .. probably no scripts that hyphenate and have marks
        local discprev = getfield(discfound,"prev")
        local discnext = getfield(discfound,"next")
        if discprev and discnext then
            -- we assume normalization in context, and don't care about generic ... especially
            -- \- can give problems as there we can have a negative char but that won't match
            -- anyway
            local pre     = getfield(discfound,"pre")
            local post    = getfield(discfound,"post")
            local replace = getfield(discfound,"replace")
            if not replace then -- todo: signal simple hyphen
                local prev = getfield(base,"prev")
                local copied = copy_node_list(comp)
                setfield(discnext,"prev",nil) -- also blocks funny assignments
                setfield(discprev,"next",nil) -- also blocks funny assignments
                if pre then
                    setfield(discprev,"next",pre)
                    setfield(pre,"prev",discprev)
                end
                pre = comp
                if post then
                    local tail = find_node_tail(post)
                    setfield(tail,"next",discnext)
                    setfield(discnext,"prev",tail)
                    setfield(post,"prev",nil)
                else
                    post = discnext
                end
                setfield(prev,"next",discfound)
                setfield(discfound,"prev",prev)
                setfield(discfound,"next",next)
                setfield(next,"prev",discfound)
                setfield(base,"next",nil)
                setfield(base,"prev",nil)
                setfield(base,"components",copied)
                setfield(discfound,"pre",pre)
                setfield(discfound,"post",post)
                setfield(discfound,"replace",base)
                setfield(discfound,"subtype",discretionary_code)
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
        setfield(start,"char",multiple[1])
        if nofmultiples > 1 then
            local sn = getnext(start)
            for k=2,nofmultiples do -- todo: use insert_node
-- untested:
--
-- while ignoremarks and marks[getchar(sn)] then
--     local sn = getnext(sn)
-- end
                local n = copy_node(start) -- ignore components
                resetinjection(n)
                setfield(n,"char",multiple[k])
                setfield(n,"prev",start)
                setfield(n,"next",sn)
                if sn then
                    setfield(sn,"prev",n)
                end
                setfield(start,"next",n)
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

local function get_alternative_glyph(start,alternatives,value,trace_alternatives)
    local n = #alternatives
    if value == "random" then
        local r = random(1,n)
        return alternatives[r], trace_alternatives and formatters["value %a, taking %a"](value,r)
    elseif value == "first" then
        return alternatives[1], trace_alternatives and formatters["value %a, taking %a"](value,1)
    elseif value == "last" then
        return alternatives[n], trace_alternatives and formatters["value %a, taking %a"](value,n)
    else
        value = tonumber(value)
        if type(value) ~= "number" then
            return alternatives[1], trace_alternatives and formatters["invalid value %s, taking %a"](value,1)
        elseif value > n then
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
end

-- handlers

function handlers.gsub_single(head,start,kind,lookupname,replacement)
    if trace_singles then
        logprocess("%s: replacing %s by single %s",pref(kind,lookupname),gref(getchar(start)),gref(replacement))
    end
    resetinjection(start)
    setfield(start,"char",replacement)
    return head, start, true
end

function handlers.gsub_alternate(head,start,kind,lookupname,alternative,sequence)
    local value = featurevalue == true and tfmdata.shared.features[kind] or featurevalue
    local choice, comment = get_alternative_glyph(start,alternative,value,trace_alternatives)
    if choice then
        if trace_alternatives then
            logprocess("%s: replacing %s by alternative %a to %s, %s",pref(kind,lookupname),gref(getchar(start)),choice,gref(choice),comment)
        end
        resetinjection(start)
        setfield(start,"char",choice)
    else
        if trace_alternatives then
            logwarning("%s: no variant %a for %s, %s",pref(kind,lookupname),value,gref(getchar(start)),comment)
        end
    end
    return head, start, true
end

function handlers.gsub_multiple(head,start,kind,lookupname,multiple,sequence)
    if trace_multiples then
        logprocess("%s: replacing %s by multiple %s",pref(kind,lookupname),gref(getchar(start)),gref(multiple))
    end
    return multiple_glyphs(head,start,multiple,sequence.flags[1])
end

function handlers.gsub_ligature(head,start,kind,lookupname,ligature,sequence)
    local s, stop = getnext(start), nil
    local startchar = getchar(start)
    if marks[startchar] then
        while s do
            local id = getid(s)
            if id == glyph_code and getfont(s) == currentfont and getsubtype(s)<256 then
                local lg = ligature[getchar(s)]
                if lg then
                    stop = s
                    ligature = lg
                    s = getnext(s)
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
                    head, start = markstoligature(kind,lookupname,head,start,stop,lig)
                    logprocess("%s: replacing %s upto %s by ligature %s case 1",pref(kind,lookupname),gref(startchar),gref(stopchar),gref(getchar(start)))
                else
                    head, start = markstoligature(kind,lookupname,head,start,stop,lig)
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
        while s do
            local id = getid(s)
            if id == glyph_code and getsubtype(s)<256 then -- not needed
                if getfont(s) == currentfont then          -- also not needed only when mark
                    local char = getchar(s)
                    if skipmark and marks[char] then
                        s = getnext(s)
                    else -- ligature is a tree
                        local lg = ligature[char] -- can there be multiple in a row? maybe in a bad font
                        if lg then
                            if not discfound and lastdisc then
                                discfound = lastdisc
                                lastdisc  = nil
                            end
                            stop = s -- needed for fake so outside then
                            ligature = lg
                            s = getnext(s)
                        else
                            break
                        end
                    end
                else
                    break
                end
            elseif id == disc_code then
                lastdisc = s
                s = getnext(s)
            else
                break
            end
        end
        local lig = ligature.ligature -- can't we get rid of this .ligature?
        if lig then
            if stop then
                if trace_ligatures then
                    local stopchar = getchar(stop)
                    head, start = toligature(kind,lookupname,head,start,stop,lig,skipmark,discfound)
                    logprocess("%s: replacing %s upto %s by ligature %s case 2",pref(kind,lookupname),gref(startchar),gref(stopchar),gref(getchar(start)))
                else
                    head, start = toligature(kind,lookupname,head,start,stop,lig,skipmark,discfound)
                end
            else
                -- weird but happens (in some arabic font)
                resetinjection(start)
                setfield(start,"char",lig)
                if trace_ligatures then
                    logprocess("%s: replacing %s by (no real) ligature %s case 3",pref(kind,lookupname),gref(startchar),gref(lig))
                end
            end
            return head, start, true, discfound
        else
            -- weird but happens, pseudo ligatures ... just the components
        end
    end
    return head, start, false, discfound
end

function handlers.gpos_single(head,start,kind,lookupname,kerns,sequence,injection)
    local startchar = getchar(start)
    local dx, dy, w, h = setpair(start,tfmdata.parameters.factor,rlmode,sequence.flags[4],kerns,injection) -- ,characters[startchar])
    if trace_kerns then
        logprocess("%s: shifting single %s by (%p,%p) and correction (%p,%p)",pref(kind,lookupname),gref(startchar),dx,dy,w,h)
    end
    return head, start, false
end

function handlers.gpos_pair(head,start,kind,lookupname,kerns,sequence,lookuphash,i,injection)
    -- todo: kerns in disc nodes: pre, post, replace -> loop over disc too
    -- todo: kerns in components of ligatures
    local snext = getnext(start)
    if not snext then
        return head, start, false
    else
        local prev   = start
        local done   = false
        local factor = tfmdata.parameters.factor
        local lookuptype = lookuptypes[lookupname]
        while snext and getid(snext) == glyph_code and getfont(snext) == currentfont and getsubtype(snext)<256 do
            local nextchar = getchar(snext)
            local krn = kerns[nextchar]
            if not krn and marks[nextchar] then
                prev = snext
                snext = getnext(snext)
            else
                if not krn then
                    -- skip
                elseif type(krn) == "table" then
                    if lookuptype == "pair" then -- probably not needed
                        local a, b = krn[2], krn[3]
                        if a and #a > 0 then
                            local x, y, w, h = setpair(start,factor,rlmode,sequence.flags[4],a,injection) -- characters[startchar])
                            if trace_kerns then
                                local startchar = getchar(start)
                                logprocess("%s: shifting first of pair %s and %s by (%p,%p) and correction (%p,%p)",pref(kind,lookupname),gref(startchar),gref(nextchar),x,y,w,h)
                            end
                        end
                        if b and #b > 0 then
                            local x, y, w, h = setpair(snext,factor,rlmode,sequence.flags[4],b,injection) -- characters[nextchar])
                            if trace_kerns then
                                local startchar = getchar(start)
                                logprocess("%s: shifting second of pair %s and %s by (%p,%p) and correction (%p,%p)",pref(kind,lookupname),gref(startchar),gref(nextchar),x,y,w,h)
                            end
                        end
                    else -- wrong ... position has different entries
                        report_process("%s: check this out (old kern stuff)",pref(kind,lookupname))
                     -- local a, b = krn[2], krn[6]
                     -- if a and a ~= 0 then
                     --     local k = setkern(snext,factor,rlmode,a)
                     --     if trace_kerns then
                     --         logprocess("%s: inserting first kern %s between %s and %s",pref(kind,lookupname),k,gref(getchar(prev)),gref(nextchar))
                     --     end
                     -- end
                     -- if b and b ~= 0 then
                     --     logwarning("%s: ignoring second kern xoff %s",pref(kind,lookupname),b*factor)
                     -- end
                    end
                    done = true
                elseif krn ~= 0 then
                    local k = setkern(snext,factor,rlmode,krn,injection)
                    if trace_kerns then
                        logprocess("%s: inserting kern %s between %s and %s",pref(kind,lookupname),k,gref(getchar(prev)),gref(nextchar)) -- prev?
                    end
                    done = true
                end
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

function handlers.gpos_mark2base(head,start,kind,lookupname,markanchors,sequence)
    local markchar = getchar(start)
    if marks[markchar] then
        local base = getprev(start) -- [glyph] [start=mark]
        if base and getid(base) == glyph_code and getfont(base) == currentfont and getsubtype(base)<256 then
            local basechar = getchar(base)
            if marks[basechar] then
                while true do
                    base = getprev(base)
                    if base and getid(base) == glyph_code and getfont(base) == currentfont and getsubtype(base)<256 then
                        basechar = getchar(base)
                        if not marks[basechar] then
                            break
                        end
                    else
                        if trace_bugs then
                            logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
                        end
                        return head, start, false
                    end
                end
            end
            local baseanchors = descriptions[basechar]
            if baseanchors then
                baseanchors = baseanchors.anchors
            end
            if baseanchors then
                local baseanchors = baseanchors['basechar']
                if baseanchors then
                    local al = anchorlookups[lookupname]
                    for anchor,ba in next, baseanchors do
                        if al[anchor] then
                            local ma = markanchors[anchor]
                            if ma then
                                local dx, dy, bound = setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma,characters[basechar])
                                if trace_marks then
                                    logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%p,%p)",
                                        pref(kind,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                                end
                                return head, start, true
                            end
                        end
                    end
                    if trace_bugs then
                        logwarning("%s, no matching anchors for mark %s and base %s",pref(kind,lookupname),gref(markchar),gref(basechar))
                    end
                end
            elseif trace_bugs then
            --  logwarning("%s: char %s is missing in font",pref(kind,lookupname),gref(basechar))
                onetimemessage(currentfont,basechar,"no base anchors",report_fonts)
            end
        elseif trace_bugs then
            logwarning("%s: prev node is no char",pref(kind,lookupname))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
    end
    return head, start, false
end

function handlers.gpos_mark2ligature(head,start,kind,lookupname,markanchors,sequence)
    -- check chainpos variant
    local markchar = getchar(start)
    if marks[markchar] then
        local base = getprev(start) -- [glyph] [optional marks] [start=mark]
        if base and getid(base) == glyph_code and getfont(base) == currentfont and getsubtype(base)<256 then
            local basechar = getchar(base)
            if marks[basechar] then
                while true do
                    base = getprev(base)
                    if base and getid(base) == glyph_code and getfont(base) == currentfont and getsubtype(base)<256 then
                        basechar = getchar(base)
                        if not marks[basechar] then
                            break
                        end
                    else
                        if trace_bugs then
                            logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
                        end
                        return head, start, false
                    end
                end
            end
            local index = getligaindex(start)
            local baseanchors = descriptions[basechar]
            if baseanchors then
                baseanchors = baseanchors.anchors
                if baseanchors then
                   local baseanchors = baseanchors['baselig']
                   if baseanchors then
                        local al = anchorlookups[lookupname]
                        for anchor, ba in next, baseanchors do
                            if al[anchor] then
                                local ma = markanchors[anchor]
                                if ma then
                                    ba = ba[index]
                                    if ba then
                                        local dx, dy, bound = setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma,characters[basechar]) -- index
                                        if trace_marks then
                                            logprocess("%s, anchor %s, index %s, bound %s: anchoring mark %s to baselig %s at index %s => (%p,%p)",
                                                pref(kind,lookupname),anchor,index,bound,gref(markchar),gref(basechar),index,dx,dy)
                                        end
                                        return head, start, true
                                    else
                                        if trace_bugs then
                                            logwarning("%s: no matching anchors for mark %s and baselig %s with index %a",pref(kind,lookupname),gref(markchar),gref(basechar),index)
                                        end
                                    end
                                end
                            end
                        end
                        if trace_bugs then
                            logwarning("%s: no matching anchors for mark %s and baselig %s",pref(kind,lookupname),gref(markchar),gref(basechar))
                        end
                    end
                end
            elseif trace_bugs then
            --  logwarning("%s: char %s is missing in font",pref(kind,lookupname),gref(basechar))
                onetimemessage(currentfont,basechar,"no base anchors",report_fonts)
            end
        elseif trace_bugs then
            logwarning("%s: prev node is no char",pref(kind,lookupname))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
    end
    return head, start, false
end

function handlers.gpos_mark2mark(head,start,kind,lookupname,markanchors,sequence)
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
        if base and getid(base) == glyph_code and getfont(base) == currentfont and getsubtype(base)<256 then -- subtype test can go
            local basechar = getchar(base)
            local baseanchors = descriptions[basechar]
            if baseanchors then
                baseanchors = baseanchors.anchors
                if baseanchors then
                    baseanchors = baseanchors['basemark']
                    if baseanchors then
                        local al = anchorlookups[lookupname]
                        for anchor,ba in next, baseanchors do
                            if al[anchor] then
                                local ma = markanchors[anchor]
                                if ma then
                                    local dx, dy, bound = setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma,characters[basechar],true)
                                    if trace_marks then
                                        logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%p,%p)",
                                            pref(kind,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                                    end
                                    return head, start, true
                                end
                            end
                        end
                        if trace_bugs then
                            logwarning("%s: no matching anchors for mark %s and basemark %s",pref(kind,lookupname),gref(markchar),gref(basechar))
                        end
                    end
                end
            elseif trace_bugs then
            --  logwarning("%s: char %s is missing in font",pref(kind,lookupname),gref(basechar))
                onetimemessage(currentfont,basechar,"no base anchors",report_fonts)
            end
        elseif trace_bugs then
            logwarning("%s: prev node is no mark",pref(kind,lookupname))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",pref(kind,lookupname),gref(markchar))
    end
    return head, start, false
end

function handlers.gpos_cursive(head,start,kind,lookupname,exitanchors,sequence) -- to be checked
    local alreadydone = cursonce and getprop(start,a_cursbase)
    if not alreadydone then
        local done = false
        local startchar = getchar(start)
        if marks[startchar] then
            if trace_cursive then
                logprocess("%s: ignoring cursive for mark %s",pref(kind,lookupname),gref(startchar))
            end
        else
            local nxt = getnext(start)
            while not done and nxt and getid(nxt) == glyph_code and getfont(nxt) == currentfont and getsubtype(nxt)<256 do
                local nextchar = getchar(nxt)
                if marks[nextchar] then
                    -- should not happen (maybe warning)
                    nxt = getnext(nxt)
                else
                    local entryanchors = descriptions[nextchar]
                    if entryanchors then
                        entryanchors = entryanchors.anchors
                        if entryanchors then
                            entryanchors = entryanchors['centry']
                            if entryanchors then
                                local al = anchorlookups[lookupname]
                                for anchor, entry in next, entryanchors do
                                    if al[anchor] then
                                        local exit = exitanchors[anchor]
                                        if exit then
                                            local dx, dy, bound = setcursive(start,nxt,tfmdata.parameters.factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
                                            if trace_cursive then
                                                logprocess("%s: moving %s to %s cursive (%p,%p) using anchor %s and bound %s in rlmode %s",pref(kind,lookupname),gref(startchar),gref(nextchar),dx,dy,anchor,bound,rlmode)
                                            end
                                            done = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    elseif trace_bugs then
                    --  logwarning("%s: char %s is missing in font",pref(kind,lookupname),gref(startchar))
                        onetimemessage(currentfont,startchar,"no entry anchors",report_fonts)
                    end
                    break
                end
            end
        end
        return head, start, done
    else
        if trace_cursive and trace_details then
            logprocess("%s, cursive %s is already done",pref(kind,lookupname),gref(getchar(start)),alreadydone)
        end
        return head, start, false
    end
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

function chainprocs.chainsub(head,start,stop,kind,chainname,currentcontext,lookuphash,lookuplist,chainlookupname)
    logwarning("%s: a direct call to chainsub cannot happen",cref(kind,chainname,chainlookupname))
    return head, start, false
end

-- The reversesub is a special case, which is why we need to store the replacements
-- in a bit weird way. There is no lookup and the replacement comes from the lookup
-- itself. It is meant mostly for dealing with Urdu.

function chainprocs.reversesub(head,start,stop,kind,chainname,currentcontext,lookuphash,replacements)
    local char = getchar(start)
    local replacement = replacements[char]
    if replacement then
        if trace_singles then
            logprocess("%s: single reverse replacement of %s by %s",cref(kind,chainname),gref(char),gref(replacement))
        end
        resetinjection(start)
        setfield(start,"char",replacement)
        return head, start, true
    else
        return head, start, false
    end
end

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

-- local function delete_till_stop(head,start,stop,ignoremarks) -- keeps start
--     local n = 1
--     if start == stop then
--         -- done
--     elseif ignoremarks then
--         repeat -- start x x m x x stop => start m
--             local next = getnext(start)
--             if not marks[getchar(next)] then
--                 local components = getfield(next,"components")
--                 if components then -- probably not needed
--                     flush_node_list(components)
--                 end
--                 head = delete_node(head,next)
--             end
--             n = n + 1
--         until next == stop
--     else -- start x x x stop => start
--         repeat
--             local next = getnext(start)
--             local components = getfield(next,"components")
--             if components then -- probably not needed
--                 flush_node_list(components)
--             end
--             head = delete_node(head,next)
--             n = n + 1
--         until next == stop
--     end
--     return head, n
-- end

--[[ldx--
<p>Here we replace start by a single variant.</p>
--ldx]]--

function chainprocs.gsub_single(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname,chainindex)
    -- todo: marks ?
    local current = start
    local subtables = currentlookup.subtables
    if #subtables > 1 then
        logwarning("todo: check if we need to loop over the replacements: % t",subtables)
    end
    while current do
        if getid(current) == glyph_code then
            local currentchar = getchar(current)
            local lookupname = subtables[1] -- only 1
            local replacement = lookuphash[lookupname]
            if not replacement then
                if trace_bugs then
                    logwarning("%s: no single hits",cref(kind,chainname,chainlookupname,lookupname,chainindex))
                end
            else
                replacement = replacement[currentchar]
                if not replacement or replacement == "" then
                    if trace_bugs then
                        logwarning("%s: no single for %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(currentchar))
                    end
                else
                    if trace_singles then
                        logprocess("%s: replacing single %s by %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(currentchar),gref(replacement))
                    end
                    resetinjection(current)
                    setfield(current,"char",replacement)
                end
            end
            return head, start, true
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

function chainprocs.gsub_multiple(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
 -- local head, n = delete_till_stop(head,start,stop)
    local startchar = getchar(start)
    local subtables = currentlookup.subtables
    local lookupname = subtables[1]
    local replacements = lookuphash[lookupname]
    if not replacements then
        if trace_bugs then
            logwarning("%s: no multiple hits",cref(kind,chainname,chainlookupname,lookupname))
        end
    else
        replacements = replacements[startchar]
        if not replacements or replacement == "" then
            if trace_bugs then
                logwarning("%s: no multiple for %s",cref(kind,chainname,chainlookupname,lookupname),gref(startchar))
            end
        else
            if trace_multiples then
                logprocess("%s: replacing %s by multiple characters %s",cref(kind,chainname,chainlookupname,lookupname),gref(startchar),gref(replacements))
            end
            return multiple_glyphs(head,start,replacements,currentlookup.flags[1])
        end
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

function chainprocs.gsub_alternate(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
    local current = start
    local subtables = currentlookup.subtables
    local value  = featurevalue == true and tfmdata.shared.features[kind] or featurevalue
    while current do
        if getid(current) == glyph_code then -- is this check needed?
            local currentchar = getchar(current)
            local lookupname = subtables[1]
            local alternatives = lookuphash[lookupname]
            if not alternatives then
                if trace_bugs then
                    logwarning("%s: no alternative hit",cref(kind,chainname,chainlookupname,lookupname))
                end
            else
                alternatives = alternatives[currentchar]
                if alternatives then
                    local choice, comment = get_alternative_glyph(current,alternatives,value,trace_alternatives)
                    if choice then
                        if trace_alternatives then
                            logprocess("%s: replacing %s by alternative %a to %s, %s",cref(kind,chainname,chainlookupname,lookupname),gref(char),choice,gref(choice),comment)
                        end
                        resetinjection(start)
                        setfield(start,"char",choice)
                    else
                        if trace_alternatives then
                            logwarning("%s: no variant %a for %s, %s",cref(kind,chainname,chainlookupname,lookupname),value,gref(char),comment)
                        end
                    end
                elseif trace_bugs then
                    logwarning("%s: no alternative for %s, %s",cref(kind,chainname,chainlookupname,lookupname),gref(currentchar),comment)
                end
            end
            return head, start, true
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

function chainprocs.gsub_ligature(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname,chainindex)
    local startchar = getchar(start)
    local subtables = currentlookup.subtables
    local lookupname = subtables[1]
    local ligatures = lookuphash[lookupname]
    if not ligatures then
        if trace_bugs then
            logwarning("%s: no ligature hits",cref(kind,chainname,chainlookupname,lookupname,chainindex))
        end
    else
        ligatures = ligatures[startchar]
        if not ligatures then
            if trace_bugs then
                logwarning("%s: no ligatures starting with %s",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar))
            end
        else
            local s = getnext(start)
            local discfound = false
            local last = stop
            local nofreplacements = 1
            local skipmark = currentlookup.flags[1]
            while s do
                local id = getid(s)
                if id == disc_code then
                    if not discfound then
                        discfound = s
                    end
                    if s == stop then
                        break -- okay? or before the disc
                    else
                        s = getnext(s)
                    end
                else
                    local schar = getchar(s)
                    if skipmark and marks[schar] then -- marks
                        s = getnext(s)
                    else
                        local lg = ligatures[schar]
                        if lg then
                            ligatures, last, nofreplacements = lg, s, nofreplacements + 1
                            if s == stop then
                                break
                            else
                                s = getnext(s)
                            end
                        else
                            break
                        end
                    end
                end
            end
            local l2 = ligatures.ligature
            if l2 then
                if chainindex then
                    stop = last
                end
                if trace_ligatures then
                    if start == stop then
                        logprocess("%s: replacing character %s by ligature %s case 3",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(l2))
                    else
                        logprocess("%s: replacing character %s upto %s by ligature %s case 4",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(getchar(stop)),gref(l2))
                    end
                end
                head, start = toligature(kind,lookupname,head,start,stop,l2,currentlookup.flags[1],discfound)
                return head, start, true, nofreplacements, discfound
            elseif trace_bugs then
                if start == stop then
                    logwarning("%s: replacing character %s by ligature fails",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar))
                else
                    logwarning("%s: replacing character %s upto %s by ligature fails",cref(kind,chainname,chainlookupname,lookupname,chainindex),gref(startchar),gref(getchar(stop)))
                end
            end
        end
    end
    return head, start, false, 0, false
end

function chainprocs.gpos_single(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname,chainindex,sequence)
    -- untested .. needs checking for the new model
    local startchar = getchar(start)
    local subtables = currentlookup.subtables
    local lookupname = subtables[1]
    local kerns = lookuphash[lookupname]
    if kerns then
        kerns = kerns[startchar] -- needed ?
        if kerns then
            local dx, dy, w, h = setpair(start,tfmdata.parameters.factor,rlmode,sequence.flags[4],kerns) -- ,characters[startchar])
            if trace_kerns then
                logprocess("%s: shifting single %s by (%p,%p) and correction (%p,%p)",cref(kind,chainname,chainlookupname),gref(startchar),dx,dy,w,h)
            end
        end
    end
    return head, start, false
end

function chainprocs.gpos_pair(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname,chainindex,sequence)
    local snext = getnext(start)
    if snext then
        local startchar = getchar(start)
        local subtables = currentlookup.subtables
        local lookupname = subtables[1]
        local kerns = lookuphash[lookupname]
        if kerns then
            kerns = kerns[startchar]
            if kerns then
                local lookuptype = lookuptypes[lookupname]
                local prev, done = start, false
                local factor = tfmdata.parameters.factor
                while snext and getid(snext) == glyph_code and getfont(snext) == currentfont and getsubtype(snext)<256 do
                    local nextchar = getchar(snext)
                    local krn = kerns[nextchar]
                    if not krn and marks[nextchar] then
                        prev = snext
                        snext = getnext(snext)
                    else
                        if not krn then
                            -- skip
                        elseif type(krn) == "table" then
                            if lookuptype == "pair" then
                                local a, b = krn[2], krn[3]
                                if a and #a > 0 then
                                    local startchar = getchar(start)
                                    local x, y, w, h = setpair(start,factor,rlmode,sequence.flags[4],a) -- ,characters[startchar])
                                    if trace_kerns then
                                        logprocess("%s: shifting first of pair %s and %s by (%p,%p) and correction (%p,%p)",cref(kind,chainname,chainlookupname),gref(startchar),gref(nextchar),x,y,w,h)
                                    end
                                end
                                if b and #b > 0 then
                                    local startchar = getchar(start)
                                    local x, y, w, h = setpair(snext,factor,rlmode,sequence.flags[4],b) -- ,characters[nextchar])
                                    if trace_kerns then
                                        logprocess("%s: shifting second of pair %s and %s by (%p,%p) and correction (%p,%p)",cref(kind,chainname,chainlookupname),gref(startchar),gref(nextchar),x,y,w,h)
                                    end
                                end
                            else
                                report_process("%s: check this out (old kern stuff)",cref(kind,chainname,chainlookupname))
                             -- local a, b = krn[2], krn[6]
                             -- if a and a ~= 0 then
                             --     local k = setkern(snext,factor,rlmode,a)
                             --     if trace_kerns then
                             --         logprocess("%s: inserting first kern %s between %s and %s",cref(kind,chainname,chainlookupname),k,gref(getchar(prev)),gref(nextchar))
                             --     end
                             -- end
                             -- if b and b ~= 0 then
                             --     logwarning("%s: ignoring second kern xoff %s",cref(kind,chainname,chainlookupname),b*factor)
                             -- end
                            end
                            done = true
                        elseif krn ~= 0 then
                            local k = setkern(snext,factor,rlmode,krn)
                            if trace_kerns then
                                logprocess("%s: inserting kern %s between %s and %s",cref(kind,chainname,chainlookupname),k,gref(getchar(prev)),gref(nextchar))
                            end
                            done = true
                        end
                        break
                    end
                end
                return head, start, done
            end
        end
    end
    return head, start, false
end

function chainprocs.gpos_mark2base(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
    local markchar = getchar(start)
    if marks[markchar] then
        local subtables = currentlookup.subtables
        local lookupname = subtables[1]
        local markanchors = lookuphash[lookupname]
        if markanchors then
            markanchors = markanchors[markchar]
        end
        if markanchors then
            local base = getprev(start) -- [glyph] [start=mark]
            if base and getid(base) == glyph_code and getfont(base) == currentfont and getsubtype(base)<256 then
                local basechar = getchar(base)
                if marks[basechar] then
                    while true do
                        base = getprev(base)
                        if base and getid(base) == glyph_code and getfont(base) == currentfont and getsubtype(base)<256 then
                            basechar = getchar(base)
                            if not marks[basechar] then
                                break
                            end
                        else
                            if trace_bugs then
                                logwarning("%s: no base for mark %s",pref(kind,lookupname),gref(markchar))
                            end
                            return head, start, false
                        end
                    end
                end
                local baseanchors = descriptions[basechar].anchors
                if baseanchors then
                    local baseanchors = baseanchors['basechar']
                    if baseanchors then
                        local al = anchorlookups[lookupname]
                        for anchor,ba in next, baseanchors do
                            if al[anchor] then
                                local ma = markanchors[anchor]
                                if ma then
                                    local dx, dy, bound = setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma,characters[basechar])
                                    if trace_marks then
                                        logprocess("%s, anchor %s, bound %s: anchoring mark %s to basechar %s => (%p,%p)",
                                            cref(kind,chainname,chainlookupname,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                                    end
                                    return head, start, true
                                end
                            end
                        end
                        if trace_bugs then
                            logwarning("%s, no matching anchors for mark %s and base %s",cref(kind,chainname,chainlookupname,lookupname),gref(markchar),gref(basechar))
                        end
                    end
                end
            elseif trace_bugs then
                logwarning("%s: prev node is no char",cref(kind,chainname,chainlookupname,lookupname))
            end
        elseif trace_bugs then
            logwarning("%s: mark %s has no anchors",cref(kind,chainname,chainlookupname,lookupname),gref(markchar))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",cref(kind,chainname,chainlookupname),gref(markchar))
    end
    return head, start, false
end

function chainprocs.gpos_mark2ligature(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
    local markchar = getchar(start)
    if marks[markchar] then
        local subtables = currentlookup.subtables
        local lookupname = subtables[1]
        local markanchors = lookuphash[lookupname]
        if markanchors then
            markanchors = markanchors[markchar]
        end
        if markanchors then
            local base = getprev(start) -- [glyph] [optional marks] [start=mark]
            if base and getid(base) == glyph_code and getfont(base) == currentfont and getsubtype(base)<256 then
                local basechar = getchar(base)
                if marks[basechar] then
                    while true do
                        base = getprev(base)
                        if base and getid(base) == glyph_code and getfont(base) == currentfont and getsubtype(base)<256 then
                            basechar = getchar(base)
                            if not marks[basechar] then
                                break
                            end
                        else
                            if trace_bugs then
                                logwarning("%s: no base for mark %s",cref(kind,chainname,chainlookupname,lookupname),markchar)
                            end
                            return head, start, false
                        end
                    end
                end
                -- todo: like marks a ligatures hash
                local index = getligaindex(start)
                local baseanchors = descriptions[basechar].anchors
                if baseanchors then
                   local baseanchors = baseanchors['baselig']
                   if baseanchors then
                        local al = anchorlookups[lookupname]
                        for anchor,ba in next, baseanchors do
                            if al[anchor] then
                                local ma = markanchors[anchor]
                                if ma then
                                    ba = ba[index]
                                    if ba then
                                        local dx, dy, bound = setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma,characters[basechar])
                                        if trace_marks then
                                            logprocess("%s, anchor %s, bound %s: anchoring mark %s to baselig %s at index %s => (%p,%p)",
                                                cref(kind,chainname,chainlookupname,lookupname),anchor,a or bound,gref(markchar),gref(basechar),index,dx,dy)
                                        end
                                        return head, start, true
                                    end
                                end
                            end
                        end
                        if trace_bugs then
                            logwarning("%s: no matching anchors for mark %s and baselig %s",cref(kind,chainname,chainlookupname,lookupname),gref(markchar),gref(basechar))
                        end
                    end
                end
            elseif trace_bugs then
                logwarning("feature %s, lookup %s: prev node is no char",kind,lookupname)
            end
        elseif trace_bugs then
            logwarning("%s: mark %s has no anchors",cref(kind,chainname,chainlookupname,lookupname),gref(markchar))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",cref(kind,chainname,chainlookupname),gref(markchar))
    end
    return head, start, false
end

function chainprocs.gpos_mark2mark(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
    local markchar = getchar(start)
    if marks[markchar] then
    --  local markanchors = descriptions[markchar].anchors markanchors = markanchors and markanchors.mark
        local subtables = currentlookup.subtables
        local lookupname = subtables[1]
        local markanchors = lookuphash[lookupname]
        if markanchors then
            markanchors = markanchors[markchar]
        end
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
            if base and getid(base) == glyph_code and getfont(base) == currentfont and getsubtype(base)<256 then -- subtype test can go
                local basechar = getchar(base)
                local baseanchors = descriptions[basechar].anchors
                if baseanchors then
                    baseanchors = baseanchors['basemark']
                    if baseanchors then
                        local al = anchorlookups[lookupname]
                        for anchor,ba in next, baseanchors do
                            if al[anchor] then
                                local ma = markanchors[anchor]
                                if ma then
                                    local dx, dy, bound = setmark(start,base,tfmdata.parameters.factor,rlmode,ba,ma,characters[basechar],true)
                                    if trace_marks then
                                        logprocess("%s, anchor %s, bound %s: anchoring mark %s to basemark %s => (%p,%p)",
                                            cref(kind,chainname,chainlookupname,lookupname),anchor,bound,gref(markchar),gref(basechar),dx,dy)
                                    end
                                    return head, start, true
                                end
                            end
                        end
                        if trace_bugs then
                            logwarning("%s: no matching anchors for mark %s and basemark %s",gref(kind,chainname,chainlookupname,lookupname),gref(markchar),gref(basechar))
                        end
                    end
                end
            elseif trace_bugs then
                logwarning("%s: prev node is no mark",cref(kind,chainname,chainlookupname,lookupname))
            end
        elseif trace_bugs then
            logwarning("%s: mark %s has no anchors",cref(kind,chainname,chainlookupname,lookupname),gref(markchar))
        end
    elseif trace_bugs then
        logwarning("%s: mark %s is no mark",cref(kind,chainname,chainlookupname),gref(markchar))
    end
    return head, start, false
end

function chainprocs.gpos_cursive(head,start,stop,kind,chainname,currentcontext,lookuphash,currentlookup,chainlookupname)
    local alreadydone = cursonce and getprop(start,a_cursbase)
    if not alreadydone then
        local startchar = getchar(start)
        local subtables = currentlookup.subtables
        local lookupname = subtables[1]
        local exitanchors = lookuphash[lookupname]
        if exitanchors then
            exitanchors = exitanchors[startchar]
        end
        if exitanchors then
            local done = false
            if marks[startchar] then
                if trace_cursive then
                    logprocess("%s: ignoring cursive for mark %s",pref(kind,lookupname),gref(startchar))
                end
            else
                local nxt = getnext(start)
                while not done and nxt and getid(nxt) == glyph_code and getfont(nxt) == currentfont and getsubtype(nxt)<256 do
                    local nextchar = getchar(nxt)
                    if marks[nextchar] then
                        -- should not happen (maybe warning)
                        nxt = getnext(nxt)
                    else
                        local entryanchors = descriptions[nextchar]
                        if entryanchors then
                            entryanchors = entryanchors.anchors
                            if entryanchors then
                                entryanchors = entryanchors['centry']
                                if entryanchors then
                                    local al = anchorlookups[lookupname]
                                    for anchor, entry in next, entryanchors do
                                        if al[anchor] then
                                            local exit = exitanchors[anchor]
                                            if exit then
                                                local dx, dy, bound = setcursive(start,nxt,tfmdata.parameters.factor,rlmode,exit,entry,characters[startchar],characters[nextchar])
                                                if trace_cursive then
                                                    logprocess("%s: moving %s to %s cursive (%p,%p) using anchor %s and bound %s in rlmode %s",pref(kind,lookupname),gref(startchar),gref(nextchar),dx,dy,anchor,bound,rlmode)
                                                end
                                                done = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        elseif trace_bugs then
                        --  logwarning("%s: char %s is missing in font",pref(kind,lookupname),gref(startchar))
                            onetimemessage(currentfont,startchar,"no entry anchors",report_fonts)
                        end
                        break
                    end
                end
            end
            return head, start, done
        else
            if trace_cursive and trace_details then
                logprocess("%s, cursive %s is already done",pref(kind,lookupname),gref(getchar(start)),alreadydone)
            end
            return head, start, false
        end
    end
    return head, start, false
end

-- what pointer to return, spec says stop
-- to be discussed ... is bidi changer a space?
-- elseif char == zwnj and sequence[n][32] then -- brrr

-- somehow l or f is global
-- we don't need to pass the currentcontext, saves a bit
-- make a slow variant then can be activated but with more tracing

local function show_skip(kind,chainname,char,ck,class)
    if ck[9] then
        logwarning("%s: skipping char %s, class %a, rule %a, lookuptype %a, %a => %a",cref(kind,chainname),gref(char),class,ck[1],ck[2],ck[9],ck[10])
    else
        logwarning("%s: skipping char %s, class %a, rule %a, lookuptype %a",cref(kind,chainname),gref(char),class,ck[1],ck[2])
    end
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

local function chaindisk(head,start,last,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,chainindex,sequence,chainproc)

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
        end
    end

    if sweepoverflow then
        local prev = current and getprev(current)
        if not current or prev ~= sweepnode then
            local head = getnext(sweepnode)
            local tail = nil
            if prev then
                tail = prev
                setfield(current,"prev",sweepnode)
            else
                tail = find_node_tail(head)
            end
            setfield(sweepnode,"next",current)
            setfield(head,"prev",nil)
            setfield(tail,"next",nil)
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

        while cprev and getid(cf) == glyph_code and getfont(cf) == currentfont and getsubtype(cf) < 256 and marks[getchar(cf)] do
            insertedmarks = insertedmarks + 1
            cf            = cprev
            startishead   = cf == head
            cprev         = getprev(cprev)
        end

        setfield(lookaheaddisc,"prev",cprev)
        if cprev then
            setfield(cprev,"next",lookaheaddisc)
        end
        setfield(cf,"prev",nil)
        setfield(cl,"next",nil)
        if startishead then
            head = lookaheaddisc
        end

        local replace = getfield(lookaheaddisc,"replace")
        local pre     = getfield(lookaheaddisc,"pre")
        local new     = copy_node_list(cf)
        local cnew = new
        for i=1,insertedmarks do
            cnew = getnext(cnew)
        end
        local clast = cnew
        for i=f,l do
            clast = getnext(clast)
        end
        if not notmatchpre[lookaheaddisc] then
            cf, start, ok = chainproc(cf,start,last,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,nil,sequence)
        end
        if not notmatchreplace[lookaheaddisc] then
            new, cnew, ok = chainproc(new,cnew,clast,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,nil,sequence)
        end
        if pre then
            setfield(cl,"next",pre)
            setfield(pre,"prev",cl)
        end
        if replace then
            local tail = find_node_tail(new)
            setfield(tail,"next",replace)
            setfield(replace,"prev",tail)
        end
        setfield(lookaheaddisc,"pre",cf)      -- also updates tail
        setfield(lookaheaddisc,"replace",new) -- also updates tail

        start          = getprev(lookaheaddisc)
        sweephead[cf]  = getnext(clast)
        sweephead[new] = getnext(last)

    elseif backtrackdisc then

        local cf            = getnext(backtrackdisc)
        local cl            = start
        local cnext         = getnext(start)
        local insertedmarks = 0

        while cnext and getid(cnext) == glyph_code and getfont(cnext) == currentfont and getsubtype(cnext) < 256 and marks[getchar(cnext)] do
            insertedmarks = insertedmarks + 1
            cl            = cnext
            cnext         = getnext(cnext)
        end
        if cnext then
            setfield(cnext,"prev",backtrackdisc)
        end
        setfield(backtrackdisc,"next",cnext)
        setfield(cf,"prev",nil)
        setfield(cl,"next",nil)
        local replace = getfield(backtrackdisc,"replace")
        local post    = getfield(backtrackdisc,"post")
        local new     = copy_node_list(cf)
        local cnew    = find_node_tail(new)
        for i=1,insertedmarks do
            cnew = getprev(cnew)
        end
        local clast = cnew
        for i=f,l do
            clast = getnext(clast)
        end
        if not notmatchpost[backtrackdisc] then
            cf, start, ok = chainproc(cf,start,last,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,nil,sequence)
        end
        if not notmatchreplace[backtrackdisc] then
            new, cnew, ok = chainproc(new,cnew,clast,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,nil,sequence)
        end
        if post then
            local tail = find_node_tail(post)
            setfield(tail,"next",cf)
            setfield(cf,"prev",tail)
        else
            post = cf
        end
        if replace then
            local tail = find_node_tail(replace)
            setfield(tail,"next",new)
            setfield(new,"prev",tail)
        else
            replace = new
        end
        setfield(backtrackdisc,"post",post)       -- also updates tail
        setfield(backtrackdisc,"replace",replace) -- also updates tail
        start              = getprev(backtrackdisc)
        sweephead[post]    = getnext(clast)
        sweephead[replace] = getnext(last)

    else

        head, start, ok = chainproc(head,start,last,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,nil,sequence)

    end

    return head, start, ok
end

local function normal_handle_contextchain(head,start,kind,chainname,contexts,sequence,lookuphash)
    local sweepnode    = sweepnode
    local sweeptype    = sweeptype
    local diskseen     = false
    local checkdisc    = getprev(head)
    local flags        = sequence.flags
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
            match = getid(current) == glyph_code and getfont(current) == currentfont and getsubtype(current)<256 and seq[1][getchar(current)]
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
                            local id = getid(last)
                            if id == glyph_code then
                                if getfont(last) == currentfont and getsubtype(last)<256 then
                                    local char = getchar(last)
                                    local ccd = descriptions[char]
                                    if ccd then
                                        local class = ccd.class or "base"
                                        if class == skipmark or class == skipligature or class == skipbase or (markclass and class == "mark" and not markclass[char]) then
                                            skipped = true
                                            if trace_skips then
                                                show_skip(kind,chainname,char,ck,class)
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
                                else
                                    if discfound then
                                        notmatchreplace[discfound] = true
                                        match = not notmatchpre[discfound]
                                    else
                                        match = false
                                    end
                                    break
                                end
                            elseif id == disc_code then
                                diskseen              = true
                                discfound             = last
                                notmatchpre[last]     = nil
                                notmatchpost[last]    = true
                                notmatchreplace[last] = nil
                                local pre     = getfield(last,"pre")
                                local replace = getfield(last,"replace")
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
                                local id = getid(prev)
                                if id == glyph_code then
                                    if getfont(prev) == currentfont and getsubtype(prev)<256 then -- normal char
                                        local char = getchar(prev)
                                        local ccd = descriptions[char]
                                        if ccd then
                                            local class = ccd.class
                                            if class == skipmark or class == skipligature or class == skipbase or (markclass and class == "mark" and not markclass[char]) then
                                                skipped = true
                                                if trace_skips then
                                                    show_skip(kind,chainname,char,ck,class)
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
                                    else
                                        if discfound then
                                            notmatchreplace[discfound] = true
                                            match = not notmatchpost[discfound]
                                        else
                                            match = false
                                        end
                                        break
                                    end
                                elseif id == disc_code then
                                    -- the special case: f i where i becomes dottless i ..
                                    diskseen              = true
                                    discfound             = prev
                                    notmatchpre[prev]     = true
                                    notmatchpost[prev]    = nil
                                    notmatchreplace[prev] = nil
                                    local pre     = getfield(prev,"pre")
                                    local post    = getfield(prev,"post")
                                    local replace = getfield(prev,"replace")
                                    if pre ~= start and post ~= start and replace ~= start then
                                        if post then
                                            local n = n
                                            local posttail = find_node_tail(post)
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
                                            local replacetail = find_node_tail(replace)
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
                                    n = n -1
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
                            local id = getid(current)
                            if id == glyph_code then
                                if getfont(current) == currentfont and getsubtype(current)<256 then -- normal char
                                    local char = getchar(current)
                                    local ccd = descriptions[char]
                                    if ccd then
                                        local class = ccd.class
                                        if class == skipmark or class == skipligature or class == skipbase or (markclass and class == "mark" and not markclass[char]) then
                                            skipped = true
                                            if trace_skips then
                                                show_skip(kind,chainname,char,ck,class)
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
                                else
                                    if discfound then
                                        notmatchreplace[discfound] = true
                                        match = not notmatchpre[discfound]
                                    else
                                        match = false
                                    end
                                    break
                                end
                            elseif id == disc_code then
                                diskseen                 = true
                                discfound                = current
                                notmatchpre[current]     = nil
                                notmatchpost[current]    = true
                                notmatchreplace[current] = nil
                                local pre     = getfield(current,"pre")
                                local replace = getfield(current,"replace")
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
                local rule, lookuptype, f, l = ck[1], ck[2], ck[4], ck[5]
                local char = getchar(start)
                if ck[9] then
                    logwarning("%s: rule %s matches at char %s for (%s,%s,%s) chars, lookuptype %a, %a => %a",
                        cref(kind,chainname),rule,gref(char),f-1,l-f+1,s-l,lookuptype,ck[9],ck[10])
                else
                    logwarning("%s: rule %s matches at char %s for (%s,%s,%s) chars, lookuptype %a",
                        cref(kind,chainname),rule,gref(char),f-1,l-f+1,s-l,lookuptype)
                end
            end
            local chainlookups = ck[6]
            if chainlookups then
                local nofchainlookups = #chainlookups
                -- we can speed this up if needed
                if nofchainlookups == 1 then
                    local chainlookupname = chainlookups[1]
                    local chainlookup = lookuptable[chainlookupname]
                    if chainlookup then
                        local chainproc = chainprocs[chainlookup.type]
                        if chainproc then
                            local ok
                            if diskchain then
                                head, start, ok = chaindisk(head,start,last,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,nil,sequence,chainproc)
                            else
                                head, start, ok = chainproc(head,start,last,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,nil,sequence)
                            end
                            if ok then
                                done = true
                            end
                        else
                            logprocess("%s: %s is not yet supported",cref(kind,chainname,chainlookupname),chainlookup.type)
                        end
                    else -- shouldn't happen
                        logprocess("%s is not yet supported",cref(kind,chainname,chainlookupname))
                    end
                 else
                    local i = 1
                    while start and true do
                        if skipped then
                            while true do -- todo: use properties
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
                        local chainlookupname = chainlookups[i]
                        local chainlookup = lookuptable[chainlookupname]
                        if not chainlookup then
                            -- we just advance
                            i = i + 1
                        else
                            local chainproc = chainprocs[chainlookup.type]
                            if not chainproc then
                                -- actually an error
                                logprocess("%s: %s is not yet supported",cref(kind,chainname,chainlookupname),chainlookup.type)
                                i = i + 1
                            else
                                local ok, n
                                if diskchain then
                                    head, start, ok    = chaindisk(head,start,last,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,nil,sequence,chainproc)
                                else
                                    head, start, ok, n = chainproc(head,start,last,kind,chainname,ck,lookuphash,chainlookup,chainlookupname,i,sequence)
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
                                         --     logprocess("%s: quitting lookups",cref(kind,chainname))
                                         -- end
                                            break
                                        else
                                            -- we need to carry one
                                        end
                                    end
                                end
                                i = i + 1
                            end
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
                    head, start, done = chainprocs.reversesub(head,start,last,kind,chainname,ck,lookuphash,replacements) -- sequence
                else
                    done = quit_on_no_replacement -- can be meant to be skipped / quite inconsistent in fonts
                    if trace_contexts then
                        logprocess("%s: skipping match",cref(kind,chainname))
                    end
                end
            end
            if done then
                break -- out of contexts (new, needs checking)
            end
        end
    end
    if diskseen then -- maybe move up so that we can turn checking on/off
        notmatchpre     = { }
        notmatchpost    = { }
        notmatchreplace = { }
    end
    return head, start, done
end

-- Because we want to keep this elsewhere (an because speed is less an issue) we
-- pass the font id so that the verbose variant can access the relevant helper tables.

local verbose_handle_contextchain = function(font,...)
    logwarning("no verbose handler installed, reverting to 'normal'")
    otf.setcontextchain()
    return normal_handle_contextchain(...)
end

otf.chainhandlers = {
    normal  = normal_handle_contextchain,
    verbose = verbose_handle_contextchain,
}

function otf.setcontextchain(method)
    if not method or method == "normal" or not otf.chainhandlers[method] then
        if handlers.contextchain then -- no need for a message while making the format
            logwarning("installing normal contextchain handler")
        end
        handlers.contextchain = normal_handle_contextchain
    else
        logwarning("installing contextchain handler %a",method)
        local handler = otf.chainhandlers[method]
        handlers.contextchain = function(...)
            return handler(currentfont,...) -- hm, get rid of ...
        end
    end
    handlers.gsub_context             = handlers.contextchain
    handlers.gsub_contextchain        = handlers.contextchain
    handlers.gsub_reversecontextchain = handlers.contextchain
    handlers.gpos_contextchain        = handlers.contextchain
    handlers.gpos_context             = handlers.contextchain
end

otf.setcontextchain()

local missing = { } -- we only report once

local function logprocess(...)
    if trace_steps then
        registermessage(...)
    end
    report_process(...)
end

local logwarning = report_process

local function report_missing_cache(typ,lookup)
    local f = missing[currentfont] if not f then f = { } missing[currentfont] = f end
    local t = f[typ]               if not t then t = { } f[typ]               = t end
    if not t[lookup] then
        t[lookup] = true
        logwarning("missing cache for lookup %a, type %a, font %a, name %a",lookup,typ,currentfont,tfmdata.properties.fullname)
    end
end

local resolved = { } -- we only resolve a font,script,language pair once

-- todo: pass all these 'locals' in a table

local lookuphashes = { }

setmetatableindex(lookuphashes, function(t,font)
    local lookuphash = fontdata[font].resources.lookuphash
    if not lookuphash or not next(lookuphash) then
        lookuphash = false
    end
    t[font] = lookuphash
    return lookuphash
end)

-- fonts.hashes.lookups = lookuphashes

local autofeatures = fonts.analyzers.features -- was: constants

local function initialize(sequence,script,language,enabled)
    local features = sequence.features
    if features then
        local order = sequence.order
        if order then
            for i=1,#order do --
                local kind  = order[i] --
                local valid = enabled[kind]
                if valid then
                    local scripts = features[kind] --
                    local languages = scripts[script] or scripts[wildcard]
                    if languages and (languages[language] or languages[wildcard]) then
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
    local shared     = tfmdata.shared
    local properties = tfmdata.properties
    local language   = properties.language or "dflt"
    local script     = properties.script   or "dflt"
    local enabled    = shared.features
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
            local v = enabled and initialize(sequences[s],script,language,enabled)
            if v then
                rl[#rl+1] = v
            end
        end
    end
    return rl
end

-- assumptions:
--
-- * languages that use complex disc nodes

local function kernrun(disc,run)
    --
    -- we catch <font 1><disc font 2>
    --
    if trace_kernruns then
        report_run("kern") -- will be more detailed
    end
    --
    local prev      = getprev(disc) -- todo, keep these in the main loop
    local next      = getnext(disc) -- todo, keep these in the main loop
    --
    local pre       = getfield(disc,"pre")
    local post      = getfield(disc,"post")
    local replace   = getfield(disc,"replace")
    --
    local prevmarks = prev
    --
    -- can be optional, because why on earth do we get a disc after a mark (okay, maybe when a ccmp
    -- has happened but then it should be in the disc so basically this test indicates an error)
    --
    while prevmarks and getid(prevmarks) == glyph_code and marks[getchar(prevmarks)] and getfont(prevmarks) == currentfont and getsubtype(prevmarks) < 256 do
        prevmarks = getprev(prevmarks)
    end
    --
    if prev and (pre or replace) and not (getid(prev) == glyph_code and getfont(prev) == currentfont and getsubtype(prev)<256) then
        prev = false
    end
    if next and (post or replace) and not (getid(next) == glyph_code and getfont(next) == currentfont and getsubtype(next)<256) then
        next = false
    end
    --
    if not pre then
        -- go on
    elseif prev then
        local nest = getprev(pre)
        setfield(pre,"prev",prev)
        setfield(prev,"next",pre)
        run(prevmarks,"preinjections")
        setfield(pre,"prev",nest)
        setfield(prev,"next",disc)
    else
        run(pre,"preinjections")
    end
    --
    if not post then
        -- go on
    elseif next then
        local tail = find_node_tail(post)
        setfield(tail,"next",next)
        setfield(next,"prev",tail)
        run(post,"postinjections",next)
        setfield(tail,"next",nil)
        setfield(next,"prev",disc)
    else
        run(post,"postinjections")
    end
    --
    if not replace and prev and next then
        -- this should be already done by discfound
        setfield(prev,"next",next)
        setfield(next,"prev",prev)
        run(prevmarks,"injections",next)
        setfield(prev,"next",disc)
        setfield(next,"prev",disc)
    elseif prev and next then
        local tail = find_node_tail(replace)
        local nest = getprev(replace)
        setfield(replace,"prev",prev)
        setfield(prev,"next",replace)
        setfield(tail,"next",next)
        setfield(next,"prev",tail)
        run(prevmarks,"replaceinjections",next)
        setfield(replace,"prev",nest)
        setfield(prev,"next",disc)
        setfield(tail,"next",nil)
        setfield(next,"prev",disc)
    elseif prev then
        local nest = getprev(replace)
        setfield(replace,"prev",prev)
        setfield(prev,"next",replace)
        run(prevmarks,"replaceinjections")
        setfield(replace,"prev",nest)
        setfield(prev,"next",disc)
    elseif next then
        local tail = find_node_tail(replace)
        setfield(tail,"next",next)
        setfield(next,"prev",tail)
        run(replace,"replaceinjections",next)
        setfield(tail,"next",nil)
        setfield(next,"prev",disc)
    else
        run(replace,"replaceinjections")
    end
end

-- the if new test might be dangerous as luatex will check / set some tail stuff
-- in a temp node

local function comprun(disc,run)
    if trace_compruns then
        report_run("comp: %s",languages.serializediscretionary(disc))
    end
    --
    local pre = getfield(disc,"pre")
    if pre then
        sweepnode = disc
        sweeptype = "pre" -- in alternative code preinjections is used (also used then for proeprties, saves a variable)
        local new, done = run(pre)
        if done then
            setfield(disc,"pre",new)
        end
    end
    --
    local post = getfield(disc,"post")
    if post then
        sweepnode = disc
        sweeptype = "post"
        local new, done = run(post)
        if done then
            setfield(disc,"post",new)
        end
    end
    --
    local replace = getfield(disc,"replace")
    if replace then
        sweepnode = disc
        sweeptype = "replace"
        local new, done = run(replace)
        if done then
            setfield(disc,"replace",new)
        end
    end
    sweepnode = nil
    sweeptype = nil
end

local function testrun(disc,trun,crun) -- use helper
    local next = getnext(disc)
    if next then
        local replace = getfield(disc,"replace")
        if replace then
            local prev = getprev(disc)
            if prev then
                -- only look ahead
                local tail = find_node_tail(replace)
             -- local nest = getprev(replace)
                setfield(tail,"next",next)
                setfield(next,"prev",tail)
                if trun(replace,next) then
                    setfield(disc,"replace",nil) -- beware, side effects of nest so first
                    setfield(prev,"next",replace)
                    setfield(replace,"prev",prev)
                    setfield(next,"prev",tail)
                    setfield(tail,"next",next)
                    setfield(disc,"prev",nil)
                    setfield(disc,"next",nil)
                    flush_node_list(disc)
                    return replace -- restart
                else
                    setfield(tail,"next",nil)
                    setfield(next,"prev",disc)
                end
            else
                -- weird case
            end
        else
            -- no need
        end
    else
        -- weird case
    end
    comprun(disc,crun)
    return next
end

local function discrun(disc,drun,krun)
    local next = getnext(disc)
    local prev = getprev(disc)
    if trace_discruns then
        report_run("disc") -- will be more detailed
    end
    if next and prev then
        setfield(prev,"next",next)
     -- setfield(next,"prev",prev)
        drun(prev)
        setfield(prev,"next",disc)
     -- setfield(next,"prev",disc)
    end
    --
    local pre = getfield(disc,"pre")
    if not pre then
        -- go on
    elseif prev then
        local nest = getprev(pre)
        setfield(pre,"prev",prev)
        setfield(prev,"next",pre)
        krun(prev,"preinjections")
        setfield(pre,"prev",nest)
        setfield(prev,"next",disc)
    else
        krun(pre,"preinjections")
    end
    return next
end

-- todo: maybe run lr and rl stretches

local function featuresprocessor(head,font,attr)

    local lookuphash = lookuphashes[font] -- we can also check sequences here

    if not lookuphash then
        return head, false
    end

    head = tonut(head)

    if trace_steps then
        checkstep(head)
    end

    tfmdata         = fontdata[font]
    descriptions    = tfmdata.descriptions
    characters      = tfmdata.characters
    resources       = tfmdata.resources

    marks           = resources.marks
    anchorlookups   = resources.lookup_to_anchor
    lookuptable     = resources.lookups
    lookuptypes     = resources.lookuptypes
    lookuptags      = resources.lookuptags

    currentfont     = font
    rlmode          = 0
    sweephead       = { }

    local sequences = resources.sequences
    local done      = false
    local datasets  = otf.dataset(tfmdata,font,attr)

    local dirstack  = { } -- could move outside function

    -- We could work on sub start-stop ranges instead but I wonder if there is that
    -- much speed gain (experiments showed that it made not much sense) and we need
    -- to keep track of directions anyway. Also at some point I want to play with
    -- font interactions and then we do need the full sweeps.

    -- Keeping track of the headnode is needed for devanagari (I generalized it a bit
    -- so that multiple cases are also covered.)

    -- We don't goto the next node of a disc node is created so that we can then treat
    -- the pre, post and replace. It's abit of a hack but works out ok for most cases.

    -- there can be less subtype and attr checking in the comprun etc helpers

    for s=1,#datasets do
        local dataset      = datasets[s]
              featurevalue = dataset[1] -- todo: pass to function instead of using a global
        local attribute    = dataset[2]
        local sequence     = dataset[3] -- sequences[s] -- also dataset[5]
        local kind         = dataset[4]
        ----- chain        = dataset[5] -- sequence.chain or 0
        local rlparmode    = 0
        local topstack     = 0
        local success      = false
        local typ          = sequence.type
        local gpossing     = typ == "gpos_single" or typ == "gpos_pair" -- maybe all of them
        local subtables    = sequence.subtables
        local handler      = handlers[typ]
        if typ == "gsub_reversecontextchain" then -- chain < 0
            -- this is a limited case, no special treatments like 'init' etc
            -- we need to get rid of this slide! probably no longer needed in latest luatex
            local start = find_node_tail(head) -- slow (we can store tail because there's always a skip at the end): todo
            while start do
                local id = getid(start)
                if id == glyph_code then
                    if getfont(start) == font and getsubtype(start) < 256 then
                        local a = getattr(start,0)
                        if a then
                            a = a == attr
                        else
                            a = true
                        end
                        if a then
                            local char = getchar(start)
                            for i=1,#subtables do
                                local lookupname = subtables[i]
                                local lookupcache = lookuphash[lookupname]
                                if lookupcache then
                                    local lookupmatch = lookupcache[char]
                                    if lookupmatch then
                                        -- todo: disc?
                                        head, start, success = handler(head,start,kind,lookupname,lookupmatch,sequence,lookuphash,i)
                                        if success then
                                            break
                                        end
                                    end
                                else
                                    report_missing_cache(typ,lookupname)
                                end
                            end
                            if start then start = getprev(start) end
                        else
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
            local ns = #subtables
            local start = head -- local ?
            rlmode = 0 -- to be checked ?
            if ns == 1 then -- happens often
                local lookupname  = subtables[1]
                local lookupcache = lookuphash[lookupname]
                if not lookupcache then -- also check for empty cache
                    report_missing_cache(typ,lookupname)
                else

                    local function c_run(head) -- no need to check for 256 and attr probably also the same
                        local done  = false
                        local start = sweephead[head]
                        if start then
                            sweephead[head] = nil
                        else
                            start = head
                        end
                        while start do
                            local id = getid(start)
                            if id ~= glyph_code then
                                -- very unlikely
                                start = getnext(start)
                            elseif getfont(start) == font and getsubtype(start) < 256 then
                                local a = getattr(start,0)
                                if a then
                                    a = (a == attr) and (not attribute or getprop(start,a_state) == attribute)
                                else
                                    a = not attribute or getprop(start,a_state) == attribute
                                end
                                if a then
                                    local lookupmatch = lookupcache[getchar(start)]
                                    if lookupmatch then
                                        -- sequence kan weg
                                        local ok
                                        head, start, ok = handler(head,start,kind,lookupname,lookupmatch,sequence,lookuphash,1)
                                        if ok then
                                            done = true
                                        end
                                    end
                                    if start then start = getnext(start) end
                                else
                                    start = getnext(start)
                                end
                            else
                                return head, false
                            end
                        end
                        if done then
                            success = true -- needed in this subrun?
                        end
                        return head, done
                    end

                    local function t_run(start,stop)
                        while start ~= stop do
                            local id = getid(start)
                            if id == glyph_code and getfont(start) == font and getsubtype(start) < 256 then
                                local a = getattr(start,0)
                                if a then
                                    a = (a == attr) and (not attribute or getprop(start,a_state) == attribute)
                                else
                                    a = not attribute or getprop(start,a_state) == attribute
                                end
                                if a then
                                    local lookupmatch = lookupcache[getchar(start)]
                                    if lookupmatch then -- hm, hyphens can match (tlig) so we need to really check
                                        -- if we need more than ligatures we can outline the code and use functions
                                        local s = getnext(start)
                                        local l = nil
                                        while s do
                                            local lg = lookupmatch[getchar(s)]
                                            if lg then
                                                l = lg
                                                s = getnext(s)
                                            else
                                                break
                                            end
                                        end
                                        if l and l.ligature then
                                            return true
                                        end
                                    end
                                end
                                start = getnext(start)
                            else
                                break
                            end
                        end
                    end

                    local function d_run(prev) -- we can assume that prev and next are glyphs
                        local a = getattr(prev,0)
                        if a then
                            a = (a == attr) and (not attribute or getprop(prev,a_state) == attribute)
                        else
                            a = not attribute or getprop(prev,a_state) == attribute
                        end
                        if a then
                            local lookupmatch = lookupcache[getchar(prev)]
                            if lookupmatch then
                                -- sequence kan weg
                                local h, d, ok = handler(head,prev,kind,lookupname,lookupmatch,sequence,lookuphash,1)
                                if ok then
                                    done    = true
                                    success = true
                                end
                            end
                        end
                    end

                    local function k_run(sub,injection,last)
                        local a = getattr(sub,0)
                        if a then
                            a = (a == attr) and (not attribute or getprop(sub,a_state) == attribute)
                        else
                            a = not attribute or getprop(sub,a_state) == attribute
                        end
                        if a then
                            -- sequence kan weg
                            for n in traverse_nodes(sub) do -- only gpos
                                if n == last then
                                    break
                                end
                                local id = getid(n)
                                if id == glyph_code then
                                    local lookupmatch = lookupcache[getchar(n)]
                                    if lookupmatch then
                                        local h, d, ok = handler(sub,n,kind,lookupname,lookupmatch,sequence,lookuphash,1,injection)
                                        if ok then
                                            done    = true
                                            success = true
                                        end
                                    end
                                else
                                    -- message
                                end
                            end
                        end
                    end

                    while start do
                        local id = getid(start)
                        if id == glyph_code then
                            if getfont(start) == font and getsubtype(start) < 256 then -- why a 256 test ...
                                local a = getattr(start,0)
                                if a then
                                    a = (a == attr) and (not attribute or getprop(start,a_state) == attribute)
                                else
                                    a = not attribute or getprop(start,a_state) == attribute
                                end
                                if a then
                                    local char        = getchar(start)
                                    local lookupmatch = lookupcache[char]
                                    if lookupmatch then
                                        -- sequence kan weg
                                        local ok
                                        head, start, ok = handler(head,start,kind,lookupname,lookupmatch,sequence,lookuphash,1)
                                        if ok then
                                            success = true
                                        elseif gpossing and zwnjruns and char == zwnj then
                                            discrun(start,d_run)
                                        end
                                    elseif gpossing and zwnjruns and char == zwnj then
                                        discrun(start,d_run)
                                    end
                                    if start then start = getnext(start) end
                                else
                                   start = getnext(start)
                                end
                            else
                                start = getnext(start)
                            end
                        elseif id == disc_code then
                            if gpossing then
                                kernrun(start,k_run)
                                start = getnext(start)
                            elseif typ == "gsub_ligature" then
                                start = testrun(start,t_run,c_run)
                            else
                                comprun(start,c_run)
                                start = getnext(start)
                            end
                        elseif id == whatsit_code then -- will be function
                            local subtype = getsubtype(start)
                            if subtype == dir_code then
                                local dir = getfield(start,"dir")
                                if dir == "+TLT" then
                                    topstack = topstack + 1
                                    dirstack[topstack] = dir
                                    rlmode = 1
                                elseif dir == "+TRT" then
                                    topstack = topstack + 1
                                    dirstack[topstack] = dir
                                    rlmode = -1
                                elseif dir == "-TLT" or dir == "-TRT" then
                                    topstack = topstack - 1
                                    rlmode = dirstack[topstack] == "+TRT" and -1 or 1
                                else
                                    rlmode = rlparmode
                                end
                                if trace_directions then
                                    report_process("directions after txtdir %a: parmode %a, txtmode %a, # stack %a, new dir %a",dir,rlparmode,rlmode,topstack,newdir)
                                end
                            elseif subtype == localpar_code then
                                local dir = getfield(start,"dir")
                                if dir == "TRT" then
                                    rlparmode = -1
                                elseif dir == "TLT" then
                                    rlparmode = 1
                                else
                                    rlparmode = 0
                                end
                                -- one might wonder if the par dir should be looked at, so we might as well drop the next line
                                rlmode = rlparmode
                                if trace_directions then
                                    report_process("directions after pardir %a: parmode %a, txtmode %a",dir,rlparmode,rlmode)
                                end
                            end
                            start = getnext(start)
                        elseif id == math_code then
                            start = getnext(end_of_math(start))
                        else
                            start = getnext(start)
                        end
                    end
                end

            else

                local function c_run(head)
                    local done  = false
                    local start = sweephead[head]
                    if start then
                        sweephead[head] = nil
                    else
                        start = head
                    end
                    while start do
                        local id = getid(start)
                        if id ~= glyph_code then
                            -- very unlikely
                            start = getnext(start)
                        elseif getfont(start) == font and getsubtype(start) < 256 then
                            local a = getattr(start,0)
                            if a then
                                a = (a == attr) and (not attribute or getprop(start,a_state) == attribute)
                            else
                                a = not attribute or getprop(start,a_state) == attribute
                            end
                            if a then
                                local char = getchar(start)
                                for i=1,ns do
                                    local lookupname = subtables[i]
                                    local lookupcache = lookuphash[lookupname]
                                    if lookupcache then
                                        local lookupmatch = lookupcache[char]
                                        if lookupmatch then
                                            -- we could move all code inline but that makes things even more unreadable
                                            local ok
                                            head, start, ok = handler(head,start,kind,lookupname,lookupmatch,sequence,lookuphash,i)
                                            if ok then
                                                done = true
                                                break
                                            elseif not start then
                                                -- don't ask why ... shouldn't happen
                                                break
                                            end
                                        end
                                    else
                                        report_missing_cache(typ,lookupname)
                                    end
                                end
                                if start then start = getnext(start) end
                            else
                                start = getnext(start)
                            end
                        else
                            return head, false
                        end
                    end
                    if done then
                        success = true
                    end
                    return head, done
                end

                local function d_run(prev)
                    local a = getattr(prev,0)
                    if a then
                        a = (a == attr) and (not attribute or getprop(prev,a_state) == attribute)
                    else
                        a = not attribute or getprop(prev,a_state) == attribute
                    end
                    if a then
                        -- brr prev can be disc
                        local char = getchar(prev)
                        for i=1,ns do
                            local lookupname  = subtables[i]
                            local lookupcache = lookuphash[lookupname]
                            if lookupcache then
                                local lookupmatch = lookupcache[char]
                                if lookupmatch then
                                    -- we could move all code inline but that makes things even more unreadable
                                    local h, d, ok = handler(head,prev,kind,lookupname,lookupmatch,sequence,lookuphash,i)
                                    if ok then
                                        done = true
                                        break
                                    end
                                end
                            else
                                report_missing_cache(typ,lookupname)
                            end
                        end
                    end
                end

               local function k_run(sub,injection,last)
                    local a = getattr(sub,0)
                    if a then
                        a = (a == attr) and (not attribute or getprop(sub,a_state) == attribute)
                    else
                        a = not attribute or getprop(sub,a_state) == attribute
                    end
                    if a then
                        for n in traverse_nodes(sub) do -- only gpos
                            if n == last then
                                break
                            end
                            local id = getid(n)
                            if id == glyph_code then
                                local char = getchar(n)
                                for i=1,ns do
                                    local lookupname  = subtables[i]
                                    local lookupcache = lookuphash[lookupname]
                                    if lookupcache then
                                        local lookupmatch = lookupcache[char]
                                        if lookupmatch then
                                            local h, d, ok = handler(head,n,kind,lookupname,lookupmatch,sequence,lookuphash,i,injection)
                                            if ok then
                                                done = true
                                                break
                                            end
                                        end
                                    else
                                        report_missing_cache(typ,lookupname)
                                    end
                                end
                            else
                                -- message
                            end
                        end
                    end
                end

                local function t_run(start,stop)
                    while start ~= stop do
                        local id = getid(start)
                        if id == glyph_code and getfont(start) == font and getsubtype(start) < 256 then
                            local a = getattr(start,0)
                            if a then
                                a = (a == attr) and (not attribute or getprop(start,a_state) == attribute)
                            else
                                a = not attribute or getprop(start,a_state) == attribute
                            end
                            if a then
                                local char = getchar(start)
                                for i=1,ns do
                                    local lookupname  = subtables[i]
                                    local lookupcache = lookuphash[lookupname]
                                    if lookupcache then
                                        local lookupmatch = lookupcache[char]
                                        if lookupmatch then
                                            -- if we need more than ligatures we can outline the code and use functions
                                            local s = getnext(start)
                                            local l = nil
                                            while s do
                                                local lg = lookupmatch[getchar(s)]
                                                if lg then
                                                    l = lg
                                                    s = getnext(s)
                                                else
                                                    break
                                                end
                                            end
                                            if l and l.ligature then
                                                return true
                                            end
                                        end
                                    else
                                        report_missing_cache(typ,lookupname)
                                    end
                                end
                            end
                            start = getnext(start)
                        else
                            break
                        end
                    end
                end

                while start do
                    local id = getid(start)
                    if id == glyph_code then
                        if getfont(start) == font and getsubtype(start) < 256 then
                            local a = getattr(start,0)
                            if a then
                                a = (a == attr) and (not attribute or getprop(start,a_state) == attribute)
                            else
                                a = not attribute or getprop(start,a_state) == attribute
                            end
                            if a then
                                for i=1,ns do
                                    local lookupname  = subtables[i]
                                    local lookupcache = lookuphash[lookupname]
                                    if lookupcache then
                                        local char = getchar(start)
                                        local lookupmatch = lookupcache[char]
                                        if lookupmatch then
                                            -- we could move all code inline but that makes things even more unreadable
                                            local ok
                                            head, start, ok = handler(head,start,kind,lookupname,lookupmatch,sequence,lookuphash,i)
                                            if ok then
                                                success = true
                                                break
                                            elseif not start then
                                                -- don't ask why ... shouldn't happen
                                                break
                                            elseif gpossing and zwnjruns and char == zwnj then
                                                discrun(start,d_run)
                                            end
                                        elseif gpossing and zwnjruns and char == zwnj then
                                            discrun(start,d_run)
                                        end
                                    else
                                        report_missing_cache(typ,lookupname)
                                    end
                                end
                                if start then start = getnext(start) end
                            else
                                start = getnext(start)
                            end
                        else
                            start = getnext(start)
                        end
                    elseif id == disc_code then
                        if gpossing then
                            kernrun(start,k_run)
                            start = getnext(start)
                        elseif typ == "gsub_ligature" then
                            start = testrun(start,t_run,c_run)
                        else
                            comprun(start,c_run)
                            start = getnext(start)
                        end
                    elseif id == whatsit_code then
                        local subtype = getsubtype(start)
                        if subtype == dir_code then
                            local dir = getfield(start,"dir")
                            if dir == "+TLT" then
                                topstack = topstack + 1
                                dirstack[topstack] = dir
                                rlmode = 1
                            elseif dir == "+TRT" then
                                topstack = topstack + 1
                                dirstack[topstack] = dir
                                rlmode = -1
                            elseif dir == "-TLT" or dir == "-TRT" then
                                topstack = topstack - 1
                                rlmode = dirstack[topstack] == "+TRT" and -1 or 1
                            else
                                rlmode = rlparmode
                            end
                            if trace_directions then
                                report_process("directions after txtdir %a: parmode %a, txtmode %a, # stack %a, new dir %a",dir,rlparmode,rlmode,topstack,newdir)
                            end
                        elseif subtype == localpar_code then
                            local dir = getfield(start,"dir")
                            if dir == "TRT" then
                                rlparmode = -1
                            elseif dir == "TLT" then
                                rlparmode = 1
                            else
                                rlparmode = 0
                            end
                            rlmode = rlparmode
                            if trace_directions then
                                report_process("directions after pardir %a: parmode %a, txtmode %a",dir,rlparmode,rlmode)
                            end
                        end
                        start = getnext(start)
                    elseif id == math_code then
                        start = getnext(end_of_math(start))
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

    head = tonode(head)

    return head, done
end

-- this might move to the loader

local function generic(lookupdata,lookupname,unicode,lookuphash)
    local target = lookuphash[lookupname]
    if target then
        target[unicode] = lookupdata
    else
        lookuphash[lookupname] = { [unicode] = lookupdata }
    end
end

local function ligature(lookupdata,lookupname,unicode,lookuphash)
    local target = lookuphash[lookupname]
    if not target then
        target = { }
        lookuphash[lookupname] = target
    end
    for i=1,#lookupdata do
        local li = lookupdata[i]
        local tu = target[li]
        if not tu then
            tu = { }
            target[li] = tu
        end
        target = tu
    end
    target.ligature = unicode
end

local function pair(lookupdata,lookupname,unicode,lookuphash)
    local target = lookuphash[lookupname]
    if not target then
        target = { }
        lookuphash[lookupname] = target
    end
    local others = target[unicode]
    local paired = lookupdata[1]
    if others then
        others[paired] = lookupdata
    else
        others = { [paired] = lookupdata }
        target[unicode] = others
    end
end

local action = {
    substitution = generic,
    multiple     = generic,
    alternate    = generic,
    position     = generic,
    ligature     = ligature,
    pair         = pair,
    kern         = pair,
}

local function prepare_lookups(tfmdata)

    local rawdata          = tfmdata.shared.rawdata
    local resources        = rawdata.resources
    local lookuphash       = resources.lookuphash
    local anchor_to_lookup = resources.anchor_to_lookup
    local lookup_to_anchor = resources.lookup_to_anchor
    local lookuptypes      = resources.lookuptypes
    local characters       = tfmdata.characters
    local descriptions     = tfmdata.descriptions
    local duplicates       = resources.duplicates

    -- we cannot free the entries in the descriptions as sometimes we access
    -- then directly (for instance anchors) ... selectively freeing does save
    -- much memory as it's only a reference to a table and the slot in the
    -- description hash is not freed anyway

    -- we can delay this using metatables so that we don't make the hashes for
    -- features we don't use but then we need to loop over the characters
    -- many times so we gain nothing

    for unicode, character in next, characters do -- we cannot loop over descriptions !

        local description = descriptions[unicode]

        if description then

            local lookups = description.slookups
            if lookups then
                for lookupname, lookupdata in next, lookups do
                    action[lookuptypes[lookupname]](lookupdata,lookupname,unicode,lookuphash,duplicates)
                end
            end

            local lookups = description.mlookups
            if lookups then
                for lookupname, lookuplist in next, lookups do
                    local lookuptype = lookuptypes[lookupname]
                    for l=1,#lookuplist do
                        local lookupdata = lookuplist[l]
                        action[lookuptype](lookupdata,lookupname,unicode,lookuphash,duplicates)
                    end
                end
            end

            local list = description.kerns
            if list then
                for lookup, krn in next, list do  -- ref to glyph, saves lookup
                    local target = lookuphash[lookup]
                    if target then
                        target[unicode] = krn
                    else
                        lookuphash[lookup] = { [unicode] = krn }
                    end
                end
            end

            local list = description.anchors
            if list then
                for typ, anchors in next, list do -- types
                    if typ == "mark" or typ == "cexit" then -- or entry?
                        for name, anchor in next, anchors do
                            local lookups = anchor_to_lookup[name]
                            if lookups then
                                for lookup in next, lookups do
                                    local target = lookuphash[lookup]
                                    if target then
                                        target[unicode] = anchors
                                    else
                                        lookuphash[lookup] = { [unicode] = anchors }
                                    end
                                end
                            end
                        end
                    end
                end
            end

        end

    end

end

-- so far

local function split(replacement,original)
    local result = { }
    for i=1,#replacement do
        result[original[i]] = replacement[i]
    end
    return result
end

local valid = {
    coverage        = { chainsub = true, chainpos = true, contextsub = true },
    reversecoverage = { reversesub = true },
    glyphs          = { chainsub = true, chainpos = true },
}

local function prepare_contextchains(tfmdata)
    local rawdata    = tfmdata.shared.rawdata
    local resources  = rawdata.resources
    local lookuphash = resources.lookuphash
    local lookuptags = resources.lookuptags
    local lookups    = rawdata.lookups
    if lookups then
        for lookupname, lookupdata in next, rawdata.lookups do
            local lookuptype = lookupdata.type
            if lookuptype then
                local rules = lookupdata.rules
                if rules then
                    local format = lookupdata.format
                    local validformat = valid[format]
                    if not validformat then
                        report_prepare("unsupported format %a",format)
                    elseif not validformat[lookuptype] then
                        -- todo: dejavu-serif has one (but i need to see what use it has)
                        report_prepare("unsupported format %a, lookuptype %a, lookupname %a",format,lookuptype,lookuptags[lookupname])
                    else
                        local contexts = lookuphash[lookupname]
                        if not contexts then
                            contexts = { }
                            lookuphash[lookupname] = contexts
                        end
                        local t, nt = { }, 0
                        for nofrules=1,#rules do
                            local rule         = rules[nofrules]
                            local current      = rule.current
                            local before       = rule.before
                            local after        = rule.after
                            local replacements = rule.replacements
                            local sequence     = { }
                            local nofsequences = 0
                            -- Eventually we can store start, stop and sequence in the cached file
                            -- but then less sharing takes place so best not do that without a lot
                            -- of profiling so let's forget about it.
                            if before then
                                for n=1,#before do
                                    nofsequences = nofsequences + 1
                                    sequence[nofsequences] = before[n]
                                end
                            end
                            local start = nofsequences + 1
                            for n=1,#current do
                                nofsequences = nofsequences + 1
                                sequence[nofsequences] = current[n]
                            end
                            local stop = nofsequences
                            if after then
                                for n=1,#after do
                                    nofsequences = nofsequences + 1
                                    sequence[nofsequences] = after[n]
                                end
                            end
                            if sequence[1] then
                                -- Replacements only happen with reverse lookups as they are single only. We
                                -- could pack them into current (replacement value instead of true) and then
                                -- use sequence[start] instead but it's somewhat ugly.
                                nt = nt + 1
                                t[nt] = { nofrules, lookuptype, sequence, start, stop, rule.lookups, replacements }
                                for unic in next, sequence[start] do
                                    local cu = contexts[unic]
                                    if not cu then
                                        contexts[unic] = t
                                    end
                                end
                            end
                        end
                    end
                else
                    -- no rules
                end
            else
                report_prepare("missing lookuptype for lookupname %a",lookuptags[lookupname])
            end
        end
    end
end

-- we can consider lookuphash == false (initialized but empty) vs lookuphash == table

local function featuresinitializer(tfmdata,value)
    if true then -- value then
        -- beware we need to use the topmost properties table
        local rawdata    = tfmdata.shared.rawdata
        local properties = rawdata.properties
        if not properties.initialized then
            local starttime = trace_preparing and os.clock()
            local resources = rawdata.resources
            resources.lookuphash = resources.lookuphash or { }
            prepare_contextchains(tfmdata)
            prepare_lookups(tfmdata)
            properties.initialized = true
            if trace_preparing then
                report_prepare("preparation time is %0.3f seconds for %a",os.clock()-starttime,tfmdata.properties.fullname)
            end
        end
    end
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

otf.handlers = handlers
