if not modules then modules = { } end modules ['font-otj'] = {
    version   = 1.001,
    comment   = "companion to font-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- This property based variant is not faster but looks nicer than the attribute one. We
-- need to use rawget (which is apbout 4 times slower than a direct access but we cannot
-- get/set that one for our purpose! This version does a bit more with discretionaries
-- (and Kai has tested it with his collection of weird fonts.)

-- There is some duplicate code here (especially in the the pre/post/replace branches) but
-- we go for speed. We could store a list of glyph and mark nodes when registering but it's
-- cleaner to have an identification pass here. Also, I need to keep tracing in mind so
-- being too clever here is dangerous.

-- The subtype test is not needed as there will be no (new) properties set, given that we
-- reset the properties.

-- As we have a rawget on properties we don't need one on injections.

-- The use_advance code is just a test and is meant for testing and manuals. There is no
-- performance (or whatever) gain and using kerns is somewhat cleaner (at least for now).

-- Maybe: subtype fontkern when pure kerns.

if not nodes.properties then return end

local next, rawget = next, rawget
local fastcopy = table.fastcopy

local registertracker = trackers.register

local trace_injections  = false  registertracker("fonts.injections",         function(v) trace_injections = v end)
local trace_marks       = false  registertracker("fonts.injections.marks",   function(v) trace_marks      = v end)
local trace_cursive     = false  registertracker("fonts.injections.cursive", function(v) trace_cursive    = v end)
local trace_spaces      = false  registertracker("fonts.injections.spaces",  function(v) trace_spaces  = v end)

-- use_advance is just an experiment: it makes copying glyphs (instead of new_glyph) dangerous

local use_advance       = false  directives.register("fonts.injections.advance", function(v) use_advance = v end)

local report_injections = logs.reporter("fonts","injections")
local report_spaces     = logs.reporter("fonts","spaces")

local attributes, nodes, node = attributes, nodes, node

fonts                    = fonts
local hashes             = fonts.hashes
local fontdata           = hashes.identifiers
----- parameters         = fonts.hashes.parameters -- not in generic
----- resources          = fonts.hashes.resources  -- not in generic

nodes.injections         = nodes.injections or { }
local injections         = nodes.injections

local tracers            = nodes.tracers
local setcolor           = tracers and tracers.colors.set
local resetcolor         = tracers and tracers.colors.reset

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local kern_code          = nodecodes.kern
local glue_code          = nodecodes.glue

local nuts               = nodes.nuts
local nodepool           = nuts.pool

local newkern            = nodepool.kern

local tonode             = nuts.tonode
local tonut              = nuts.tonut

local getfield           = nuts.getfield
local setfield           = nuts.setfield
local getnext            = nuts.getnext
local getprev            = nuts.getprev
local getid              = nuts.getid
local getfont            = nuts.getfont
local getsubtype         = nuts.getsubtype
local getchar            = nuts.getchar
local getboth            = nuts.getboth

local ischar             = nuts.is_char

local getdisc            = nuts.getdisc
local setdisc            = nuts.setdisc

local traverse_id        = nuts.traverse_id
local traverse_char      = nuts.traverse_char
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after

local properties         = nodes.properties.data

function injections.installnewkern(nk)
    newkern = nk or newkern
end

local nofregisteredkerns    = 0
local nofregisteredpairs    = 0
local nofregisteredmarks    = 0
local nofregisteredcursives = 0
local keepregisteredcounts  = false

function injections.keepcounts()
    keepregisteredcounts = true
end

function injections.resetcounts()
    nofregisteredkerns    = 0
    nofregisteredpairs    = 0
    nofregisteredmarks    = 0
    nofregisteredcursives = 0
    keepregisteredcounts  = false
end

-- We need to make sure that a possible metatable will not kick in unexpectedly.

-- function injections.reset(n)
--     local p = rawget(properties,n)
--     if p and rawget(p,"injections") then
--         p.injections = nil
--     end
-- end

-- function injections.copy(target,source)
--     local sp = rawget(properties,source)
--     if sp then
--         local tp = rawget(properties,target)
--         local si = rawget(sp,"injections")
--         if si then
--             si = fastcopy(si)
--             if tp then
--                 tp.injections = si
--             else
--                 propertydata[target] = {
--                     injections = si,
--                 }
--             end
--         else
--             if tp then
--                 tp.injections = nil
--             end
--         end
--     end
-- end

function injections.reset(n)
    local p = rawget(properties,n)
    if p then
        p.injections = false -- { }
    else
        properties[n] = false -- { injections = { } }
    end
end

function injections.copy(target,source)
    local sp = rawget(properties,source)
    if sp then
        local tp = rawget(properties,target)
     -- local si = rawget(sp,"injections")
        local si = sp.injections
        if si then
            si = fastcopy(si)
            if tp then
                tp.injections = si
            else
                propertydata[target] = {
                    injections = si,
                }
            end
        elseif tp then
            tp.injections = false -- { }
        else
            properties[target] = { injections = { } }
        end
    else
        local tp = rawget(properties,target)
        if tp then
            tp.injections = false -- { }
        else
            properties[target] = false -- { injections = { } }
        end
    end
end

function injections.setligaindex(n,index)
    local p = rawget(properties,n)
    if p then
     -- local i = rawget(p,"injections")
        local i = p.injections
        if i then
            i.ligaindex = index
        else
            p.injections = {
                ligaindex = index
            }
        end
    else
        properties[n] = {
            injections = {
                ligaindex = index
            }
        }
    end
end

function injections.getligaindex(n,default)
    local p = rawget(properties,n)
    if p then
     -- local i = rawget(p,"injections")
        local i = p.injections
        if i then
            return i.ligaindex or default
        end
    end
    return default
end

function injections.setcursive(start,nxt,factor,rlmode,exit,entry,tfmstart,tfmnext) -- hm: nuts or nodes
    local dx =  factor*(exit[1]-entry[1])
    local dy = -factor*(exit[2]-entry[2])
    local ws = tfmstart.width
    local wn = tfmnext.width
    nofregisteredcursives = nofregisteredcursives + 1
    if rlmode < 0 then
        dx = -(dx + wn)
    else
        dx = dx - ws
    end
    if dx == 0 then
     -- get rid of funny -0
        dx = 0
    end
    --
    local p = rawget(properties,start)
    if p then
     -- local i = rawget(p,"injections")
        local i = p.injections
        if i then
            i.cursiveanchor = true
        else
            p.injections = {
                cursiveanchor = true,
            }
        end
    else
        properties[start] = {
            injections = {
                cursiveanchor = true,
            },
        }
    end
    local p = rawget(properties,nxt)
    if p then
     -- local i = rawget(p,"injections")
        local i = p.injections
        if i then
            i.cursivex = dx
            i.cursivey = dy
        else
            p.injections = {
                cursivex = dx,
                cursivey = dy,
            }
        end
    else
        properties[nxt] = {
            injections = {
                cursivex = dx,
                cursivey = dy,
            },
        }
    end
    return dx, dy, nofregisteredcursives
end

function injections.setpair(current,factor,rlmode,r2lflag,spec,injection) -- r2lflag & tfmchr not used
    local x = factor*spec[1]
    local y = factor*spec[2]
    local w = factor*spec[3]
    local h = factor*spec[4]
    if x ~= 0 or w ~= 0 or y ~= 0 or h ~= 0 then -- okay?
        local yoffset   = y - h
        local leftkern  = x      -- both kerns are set in a pair kern compared
        local rightkern = w - x  -- to normal kerns where we set only leftkern
        if leftkern ~= 0 or rightkern ~= 0 or yoffset ~= 0 then
            nofregisteredpairs = nofregisteredpairs + 1
            if rlmode and rlmode < 0 then
                leftkern, rightkern = rightkern, leftkern
            end
            if not injection then
                injection = "injections"
            end
            local p = rawget(properties,current)
            if p then
             -- local i = p[injection]
                local i = rawget(p,injection)
                if i then
                    if leftkern ~= 0 then
                        i.leftkern  = (i.leftkern  or 0) + leftkern
                    end
                    if rightkern ~= 0 then
                        i.rightkern = (i.rightkern or 0) + rightkern
                    end
                    if yoffset ~= 0 then
                        i.yoffset = (i.yoffset or 0) + yoffset
                    end
                elseif leftkern ~= 0 or rightkern ~= 0 then
                    p[injection] = {
                        leftkern  = leftkern,
                        rightkern = rightkern,
                        yoffset   = yoffset,
                    }
                else
                    p[injection] = {
                        yoffset = yoffset,
                    }
                end
            elseif leftkern ~= 0 or rightkern ~= 0 then
                properties[current] = {
                    [injection] = {
                        leftkern  = leftkern,
                        rightkern = rightkern,
                        yoffset   = yoffset,
                    },
                }
            else
                properties[current] = {
                    [injection] = {
                        yoffset = yoffset,
                    },
                }
            end
            return x, y, w, h, nofregisteredpairs
         end
    end
    return x, y, w, h -- no bound
end

-- This needs checking for rl < 0 but it is unlikely that a r2l script uses kernclasses between
-- glyphs so we're probably safe (KE has a problematic font where marks interfere with rl < 0 in
-- the previous case)

function injections.setkern(current,factor,rlmode,x,injection)
    local dx = factor * x
    if dx ~= 0 then
        nofregisteredkerns = nofregisteredkerns + 1
        local p = rawget(properties,current)
        if not injection then
            injection = "injections"
        end
        if p then
         -- local i = rawget(p,injection)
            local i = rawget(p,injection)
            if i then
                i.leftkern = dx + (i.leftkern or 0)
            else
                p[injection] = {
                    leftkern = dx,
                }
            end
        else
            properties[current] = {
                [injection] = {
                    leftkern = dx,
                },
            }
        end
        return dx, nofregisteredkerns
    else
        return 0, 0
    end
end

function injections.setmark(start,base,factor,rlmode,ba,ma,tfmbase,mkmk,checkmark) -- ba=baseanchor, ma=markanchor

    local dx, dy = factor*(ba[1]-ma[1]), factor*(ba[2]-ma[2])
    nofregisteredmarks = nofregisteredmarks + 1
    if rlmode >= 0 then
        dx = tfmbase.width - dx -- see later commented ox
    end
    local p = rawget(properties,start)
    -- hm, dejavu serif does a sloppy mark2mark before mark2base
    if p then
     -- local i = rawget(p,"injections")
        local i = p.injections
        if i then
            if i.markmark then
                -- out of order mkmk: yes or no or option
            else
                i.markx        = dx
                i.marky        = dy
                i.markdir      = rlmode or 0
                i.markbase     = nofregisteredmarks
                i.markbasenode = base
                i.markmark     = mkmk
                i.checkmark    = checkmark
            end
        else
            p.injections = {
                markx        = dx,
                marky        = dy,
                markdir      = rlmode or 0,
                markbase     = nofregisteredmarks,
                markbasenode = base,
                markmark     = mkmk,
                checkmark    = checkmark,
            }
        end
    else
        properties[start] = {
            injections = {
                markx        = dx,
                marky        = dy,
                markdir      = rlmode or 0,
                markbase     = nofregisteredmarks,
                markbasenode = base,
                markmark     = mkmk,
                checkmark    = checkmark,
            },
        }
    end
    return dx, dy, nofregisteredmarks
end

local function dir(n)
    return (n and n<0 and "r-to-l") or (n and n>0 and "l-to-r") or "unset"
end

local function showchar(n,nested)
    local char = getchar(n)
    report_injections("%wfont %s, char %U, glyph %c",nested and 2 or 0,getfont(n),char,char)
end

local function show(n,what,nested,symbol)
    if n then
        local p = rawget(properties,n)
        if p then
            local i = rawget(p,what)
            if i then
                local leftkern  = i.leftkern  or 0
                local rightkern = i.rightkern or 0
                local yoffset   = i.yoffset   or 0
                local markx     = i.markx     or 0
                local marky     = i.marky     or 0
                local markdir   = i.markdir   or 0
                local markbase  = i.markbase  or 0
                local cursivex  = i.cursivex  or 0
                local cursivey  = i.cursivey  or 0
                local ligaindex = i.ligaindex or 0
                local cursbase  = i.cursiveanchor
                local margin    = nested and 4 or 2
                --
                if rightkern ~= 0 or yoffset ~= 0 then
                    report_injections("%w%s pair: lx %p, rx %p, dy %p",margin,symbol,leftkern,rightkern,yoffset)
                elseif leftkern ~= 0 then
                    report_injections("%w%s kern: dx %p",margin,symbol,leftkern)
                end
                if markx ~= 0 or marky ~= 0 or markbase ~= 0 then
                    report_injections("%w%s mark: dx %p, dy %p, dir %s, base %s",margin,symbol,markx,marky,markdir,markbase ~= 0 and "yes" or "no")
                end
                if cursivex ~= 0 or cursivey ~= 0 then
                    if cursbase then
                        report_injections("%w%s curs: base dx %p, dy %p",margin,symbol,cursivex,cursivey)
                    else
                        report_injections("%w%s curs: dx %p, dy %p",margin,symbol,cursivex,cursivey)
                    end
                elseif cursbase then
                    report_injections("%w%s curs: base",margin,symbol)
                end
                if ligaindex ~= 0 then
                    report_injections("%w%s liga: index %i",margin,symbol,ligaindex)
                end
            end
        end
    end
end

local function showsub(n,what,where)
    report_injections("begin subrun: %s",where)
    for n in traverse_id(glyph_code,n) do
        showchar(n,where)
        show(n,what,where," ")
    end
    report_injections("end subrun")
end

local function trace(head,where)
    report_injections("begin run %s: %s kerns, %s pairs, %s marks and %s cursives registered",
        where or "",nofregisteredkerns,nofregisteredpairs,nofregisteredmarks,nofregisteredcursives)
    local n = head
    while n do
        local id = getid(n)
        if id == glyph_code then
            showchar(n)
            show(n,"injections",false," ")
            show(n,"preinjections",false,"<")
            show(n,"postinjections",false,">")
            show(n,"replaceinjections",false,"=")
            show(n,"emptyinjections",false,"*")
        elseif id == disc_code then
            local pre, post, replace = getdisc(n)
            if pre then
                showsub(pre,"preinjections","pre")
            end
            if post then
                showsub(post,"postinjections","post")
            end
            if replace then
                showsub(replace,"replaceinjections","replace")
            end
            show(n,"emptyinjections",false,"*")
        end
        n = getnext(n)
    end
    report_injections("end run")
end

local function show_result(head)
    local current  = head
    local skipping = false
    while current do
        local id = getid(current)
        if id == glyph_code then
            report_injections("char: %C, width %p, xoffset %p, yoffset %p",
                getchar(current),getfield(current,"width"),getfield(current,"xoffset"),getfield(current,"yoffset"))
            skipping = false
        elseif id == kern_code then
            report_injections("kern: %p",getfield(current,"kern"))
            skipping = false
        elseif not skipping then
            report_injections()
            skipping = true
        end
        current = getnext(current)
    end
end

-- G  +D-pre        G
--     D-post+
--    +D-replace+
--
-- G  +D-pre       +D-pre
--     D-post      +D-post
--    +D-replace   +D-replace

local function inject_kerns_only(head,where)
    head = tonut(head)
    if trace_injections then
        trace(head,"kerns")
    end
    local current     = head
    local prev        = nil
    local next        = nil
    local prevdisc    = nil
    local prevglyph   = nil
    local pre         = nil -- saves a lookup
    local post        = nil -- saves a lookup
    local replace     = nil -- saves a lookup
    local pretail     = nil -- saves a lookup
    local posttail    = nil -- saves a lookup
    local replacetail = nil -- saves a lookup
    while current do
        local id   = getid(current)
        local next = getnext(current)
        if id == glyph_code then
            if getsubtype(current) < 256 then
                local p = rawget(properties,current)
                if p then
                 -- local i = rawget(p,"injections")
                    local i = p.injections
                    if i then
                        -- left|glyph|right
                        local leftkern = i.leftkern
                        if leftkern and leftkern ~= 0 then
                            if use_advance then
                                setfield(current,"xoffset",leftkern)
                                setfield(current,"xadvance",leftkern)
                            else
                                insert_node_before(head,current,newkern(leftkern))
                            end
                        end
                    end
                    if prevdisc then
                        local done = false
                        if post then
                         -- local i = rawget(p,"postinjections")
                            local i = p.postinjections
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    if use_advance then
                                        setfield(post,"xadvance",leftkern)
                                    else
                                        insert_node_after(post,posttail,newkern(leftkern))
                                        done = true
                                    end
                                end
                            end
                        end
                        if replace then
                         -- local i = rawget(p,"replaceinjections")
                            local i = p.replaceinjections
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    if use_advance then
                                        setfield(replace,"xadvance",leftkern)
                                    else
                                        insert_node_after(replace,replacetail,newkern(leftkern))
                                        done = true
                                    end
                                end
                            end
                        else
                         -- local i = rawget(p,"emptyinjections")
                            local i = p.emptyinjections
                            if i then
                                -- glyph|disc|glyph (special case)
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    setfield(prev,"replace",newkern(leftkern)) -- maybe also leftkern
                                end
                            end
                        end
                        if done then
                            setdisc(prevdisc,pre,post,replace)
                        end
                    end
                end
            end
            prevdisc  = nil
            prevglyph = current
        elseif id == disc_code then
            pre, post, replace, pretail, posttail, replacetail = getdisc(current,true)
            local done = false
            if pre then
                -- left|pre glyphs|right
                for n in traverse_char(pre) do
                    local p = rawget(properties,n)
                    if p then
                     -- local i = rawget(p,"injections") or rawget(p,"preinjections")
                        local i = p.injections or p.preinjections
                        if i then
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                if use_advance then
                                    setfield(pre,"xoffset",leftkern)
                                    setfield(pre,"xadvance",leftkern)
                                else
                                    pre  = insert_node_before(pre,n,newkern(leftkern))
                                    done = true
                                end
                            end
                        end
                    end
                end
            end
            if post then
                -- left|post glyphs|right
                for n in traverse_char(post) do
                    local p = rawget(properties,n)
                    if p then
                     -- local i = rawget(p,"injections") or rawget(p,"postinjections")
                        local i = p.injections or p.postinjections
                        if i then
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                if use_advance then
                                    setfield(post,"xoffset",leftkern)
                                    setfield(post,"xadvance",leftkern)
                                else
                                    post = insert_node_before(post,n,newkern(leftkern))
                                    done = true
                                end
                            end
                        end
                    end
                end
            end
            if replace then
                -- left|replace glyphs|right
                for n in traverse_char(replace) do
                    local p = rawget(properties,n)
                    if p then
                     -- local i = rawget(p,"injections") or rawget(p,"replaceinjections")
                        local i = p.injections or p.replaceinjections
                        if i then
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                if use_advance then
                                    setfield(replace,"xoffset",leftkern)
                                    setfield(replace,"xadvance",leftkern)
                                else
                                    replace = insert_node_before(replace,n,newkern(leftkern))
                                    done    = true
                                end
                            end
                        end
                    end
                end
            end
            if done then
                setdisc(current,pre,post,replace)
            end
            prevglyph = nil
            prevdisc  = current
        else
            prevglyph = nil
            prevdisc  = nil
        end
        prev    = current
        current = next
    end
    --
    if keepregisteredcounts then
        keepregisteredcounts = false
    else
        nofregisteredkerns   = 0
    end
    return tonode(head), true
end

local function inject_pairs_only(head,where)
    head = tonut(head)
    if trace_injections then
        trace(head,"pairs")
    end
    local current     = head
    local prev        = nil
    local next        = nil
    local prevdisc    = nil
    local prevglyph   = nil
    local pre         = nil -- saves a lookup
    local post        = nil -- saves a lookup
    local replace     = nil -- saves a lookup
    local pretail     = nil -- saves a lookup
    local posttail    = nil -- saves a lookup
    local replacetail = nil -- saves a lookup
    while current do
        local id   = getid(current)
        local next = getnext(current)
        if id == glyph_code then
            if getsubtype(current) < 256 then
                local p = rawget(properties,current)
                if p then
                 -- local i = rawget(p,"injections")
                    local i = p.injections
                    if i then
                        -- left|glyph|right
                        local yoffset = i.yoffset
                        if yoffset and yoffset ~= 0 then
                            setfield(current,"yoffset",yoffset)
                        end
                        local leftkern = i.leftkern
                        if leftkern and leftkern ~= 0 then
                            head = insert_node_before(head,current,newkern(leftkern))
                        end
                        local rightkern = i.rightkern
                        if rightkern and rightkern ~= 0 then
                            insert_node_after(head,current,newkern(rightkern))
                        end
                    else
                     -- local i = rawget(p,"emptyinjections")
                        local i = p.emptyinjections
                        if i then
                            -- glyph|disc|glyph (special case)
-- is this okay?
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                if next and getid(next) == disc_code then
                                    if replace then
                                        -- error, we expect an empty one
                                    else
                                        setfield(next,"replace",newkern(rightkern)) -- maybe also leftkern
                                    end
                                end
                            end
                        end
                    end
                    if prevdisc then
                        local done = false
                        if post then
                         -- local i = rawget(p,"postinjections")
                            local i = p.postinjections
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    insert_node_after(post,posttail,newkern(leftkern))
                                    done = true
                                end
                            end
                        end
                        if replace then
                         -- local i = rawget(p,"replaceinjections")
                            local i = p.replaceinjections
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    insert_node_after(replace,replacetail,newkern(leftkern))
                                    done = true
                                end
                            end
                        else
                            local i = p.emptyinjections
                            if i then
-- new .. okay?
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    setfield(prev,"replace",newkern(leftkern)) -- maybe also leftkern
                                end
                            end
                        end
                        if done then
                            setdisc(prevdisc,pre,post,replace)
                        end
                    end
                end
            end
            prevdisc  = nil
            prevglyph = current
        elseif id == disc_code then
            pre, post, replace, pretail, posttail, replacetail = getdisc(current,true)
            local done = false
            if pre then
                -- left|pre glyphs|right
                for n in traverse_char(pre) do
                    local p = rawget(properties,n)
                    if p then
                     -- local i = rawget(p,"injections") or rawget(p,"preinjections")
                        local i = p.injections or p.preinjections
                        if i then
                            local yoffset = i.yoffset
                            if yoffset and yoffset ~= 0 then
                                setfield(n,"yoffset",yoffset)
                            end
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                pre  = insert_node_before(pre,n,newkern(leftkern))
                                done = true
                            end
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                insert_node_after(pre,n,newkern(rightkern))
                                done = true
                            end
                        end
                    end
                end
            end
            if post then
                -- left|post glyphs|right
                for n in traverse_char(post) do
                    local p = rawget(properties,n)
                    if p then
                     -- local i = rawget(p,"injections") or rawget(p,"postinjections")
                        local i = p.injections or p.postinjections
                        if i then
                            local yoffset = i.yoffset
                            if yoffset and yoffset ~= 0 then
                                setfield(n,"yoffset",yoffset)
                            end
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                post = insert_node_before(post,n,newkern(leftkern))
                                done = true
                            end
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                insert_node_after(post,n,newkern(rightkern))
                                done = true
                            end
                        end
                    end
                end
            end
            if replace then
                -- left|replace glyphs|right
                for n in traverse_char(replace) do
                    local p = rawget(properties,n)
                    if p then
                     -- local i = rawget(p,"injections") or rawget(p,"replaceinjections")
                        local i = p.injections or p.replaceinjections
                        if i then
                            local yoffset = i.yoffset
                            if yoffset and yoffset ~= 0 then
                                setfield(n,"yoffset",yoffset)
                            end
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                replace = insert_node_before(replace,n,newkern(leftkern))
                                done    = true
                            end
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                insert_node_after(replace,n,newkern(rightkern))
                                done = true
                            end
                        end
                    end
                end
            end
            if prevglyph then
                if pre then
                    local p = rawget(properties,prevglyph)
                    if p then
                     -- local i = rawget(p,"preinjections")
                        local i = p.preinjections
                        if i then
                            -- glyph|pre glyphs
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                pre  = insert_node_before(pre,pre,newkern(rightkern))
                                done = true
                            end
                        end
                    end
                end
                if replace then
                    local p = rawget(properties,prevglyph)
                    if p then
                     -- local i = rawget(p,"replaceinjections")
                        local i = p.replaceinjections
                        if i then
                            -- glyph|replace glyphs
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                replace = insert_node_before(replace,replace,newkern(rightkern))
                                done    = true
                            end
                        end
                    end
                end
            end
            if done then
                setdisc(current,pre,post,replace)
            end
            prevglyph = nil
            prevdisc  = current
        else
            prevglyph = nil
            prevdisc  = nil
        end
        prev    = current
        current = next
    end
    --
    if keepregisteredcounts then
        keepregisteredcounts = false
    else
        nofregisteredkerns   = 0
    end
    return tonode(head), true
end

-- local function showoffset(n,flag)
--     local ox = getfield(n,"xoffset")
--     local oy = getfield(n,"yoffset")
--     if flag then
--         if ox == 0 then
--             setcolor(n,oy == 0 and "darkgray" or "darkgreen")
--         else
--             setcolor(n,oy == 0 and "darkblue" or "darkred")
--         end
--     else
--         if ox == 0 then
--             setcolor(n,oy == 0 and "gray" or "green")
--         else
--             setcolor(n,oy == 0 and "blue" or "red")
--         end
--     end
-- end

local function showoffset(n,flag)
    local o = getfield(n,"xoffset")
    if o == 0 then
        o = getfield(n,"yoffset")
    end
    if o ~= 0 then
        setcolor(n,flag and "darkred" or "darkgreen")
    else
        resetcolor(n)
    end
end

local function inject_everything(head,where)
    head = tonut(head)
    if trace_injections then
        trace(head,"everything")
    end
    local hascursives   = nofregisteredcursives > 0
    local hasmarks      = nofregisteredmarks    > 0
    --
    local current       = head
    local last          = nil
    local font          = font
    local markdata      = nil
    local prev          = nil
    local next          = nil
    local prevdisc      = nil
    local prevglyph     = nil
    local pre           = nil -- saves a lookup
    local post          = nil -- saves a lookup
    local replace       = nil -- saves a lookup
    local pretail       = nil -- saves a lookup
    local posttail      = nil -- saves a lookup
    local replacetail   = nil -- saves a lookup
    --
    local cursiveanchor = nil
    local minc          = 0
    local maxc          = 0
    local glyphs        = { }
    local marks         = { }
    local nofmarks      = 0
    --
    -- move out
    --
    local function processmark(p,n,pn) -- p = basenode
        local px = getfield(p,"xoffset")
        local ox = 0
        local rightkern = nil
        local pp = rawget(properties,p)
        if pp then
         -- pp = rawget(pp,"injections")
            pp = pp.injections
            if pp then
                rightkern = pp.rightkern
            end
        end
        if rightkern then -- x and w ~= 0
            if pn.markdir < 0 then
                -- kern(w-x) glyph(p) kern(x) mark(n)
                ox = px - pn.markx - rightkern
             -- report_injections("r2l case 1: %p",ox)
            else
                -- kern(x) glyph(p) kern(w-x) mark(n)
             -- ox = px - getfield(p,"width") + pn.markx - pp.leftkern
                --
                -- According to Kai we don't need to handle leftkern here but I'm
                -- pretty sure I've run into a case where it was needed so maybe
                -- some day we need something more clever here.
                --
                if false then
                    -- a mark with kerning
                    local leftkern = pp.leftkern
                    if leftkern then
                        ox = px - pn.markx - leftkern
                    else
                        ox = px - pn.markx
                    end
                else
                    ox = px - pn.markx
                end
            end
        else
         -- if pn.markdir < 0 then
         --     ox = px - pn.markx
         --  -- report_injections("r2l case 3: %p",ox)
         -- else
         --  -- ox = px - getfield(p,"width") + pn.markx
                ox = px - pn.markx
             -- report_injections("l2r case 3: %p",ox)
         -- end
            if pn.checkmark then
                local wn = getfield(n,"width") -- in arial marks have widths
                if wn ~= 0 then
                    wn = wn/2
                    if trace_injections then
                        report_injections("correcting non zero width mark %C",getchar(n))
                    end
                    -- -- bad: we should center
                    -- pn.leftkern  = -wn
                    -- pn.rightkern = -wn
                    -- -- we're too late anyway as kerns are already injected so
                    -- -- we do it the ugly way (no checking if the previous is
                    -- -- already a kern) .. maybe we should fix the font instead
                    insert_node_before(n,n,newkern(-wn))
                    insert_node_after(n,n,newkern(-wn))
                end
            end
        end
        local oy = getfield(n,"yoffset") + getfield(p,"yoffset") + pn.marky
        setfield(n,"xoffset",ox)
        setfield(n,"yoffset",oy)
        if trace_marks then
            showoffset(n,true)
        end
    end
    -- todo: marks in disc
    while current do
        local id   = getid(current)
        local next = getnext(current)
        if id == glyph_code then
            if getsubtype(current) < 256 then
                local p = rawget(properties,current)
                if p then
                 -- local i = rawget(p,"injections")
                    local i = p.injections
                    if i then
                        local pm = i.markbasenode
                        if pm then
                            nofmarks = nofmarks + 1
                            marks[nofmarks] = current
                        else
                            local yoffset = i.yoffset
                            if yoffset and yoffset ~= 0 then
                                setfield(current,"yoffset",yoffset)
                            end
                            if hascursives then
                                local cursivex = i.cursivex
                                if cursivex then
                                    if cursiveanchor then
                                        if cursivex ~= 0 then
                                            i.leftkern = (i.leftkern or 0) + cursivex
                                        end
                                        if maxc == 0 then
                                            minc = 1
                                            maxc = 1
                                            glyphs[1] = cursiveanchor
                                        else
                                            maxc = maxc + 1
                                            glyphs[maxc] = cursiveanchor
                                        end
                                        properties[cursiveanchor].cursivedy = i.cursivey -- cursiveprops
                                        last = current
                                    else
                                        maxc = 0
                                    end
                                elseif maxc > 0 then
                                    local ny = getfield(current,"yoffset")
                                    for i=maxc,minc,-1 do
                                        local ti = glyphs[i]
                                        ny = ny + properties[ti].cursivedy
                                        setfield(ti,"yoffset",ny) -- why not add ?
                                        if trace_cursive then
                                            showoffset(ti)
                                        end
                                    end
                                    maxc = 0
                                    cursiveanchor = nil
                                end
                                if i.cursiveanchor then
                                    cursiveanchor = current -- no need for both now
                                else
                                    if maxc > 0 then
                                        local ny = getfield(current,"yoffset")
                                        for i=maxc,minc,-1 do
                                            local ti = glyphs[i]
                                            ny = ny + properties[ti].cursivedy
                                            setfield(ti,"yoffset",ny) -- why not add ?
                                            if trace_cursive then
                                                showoffset(ti)
                                            end
                                        end
                                        maxc = 0
                                    end
                                    cursiveanchor = nil
                                end
                            end
                            -- left|glyph|right
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                insert_node_before(head,current,newkern(leftkern))
                            end
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                insert_node_after(head,current,newkern(rightkern))
                            end
                        end
                    else
                     -- local i = rawget(p,"emptyinjections")
                        local i = p.emptyinjections
                        if i then
                            -- glyph|disc|glyph (special case)
                            -- okay?
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                if next and getid(next) == disc_code then
                                    if replace then
                                        -- error, we expect an empty one
                                    else
                                        setfield(next,"replace",newkern(rightkern)) -- maybe also leftkern
                                    end
                                end
                            end
                        end
                    end
                    if prevdisc then
                        if p then
                            local done = false
                            if post then
                             -- local i = rawget(p,"postinjections")
                                local i = p.postinjections
                                if i then
                                    local leftkern = i.leftkern
                                    if leftkern and leftkern ~= 0 then
                                        insert_node_after(post,posttail,newkern(leftkern))
                                        done = true
                                    end
                                end
                            end
                            if replace then
                             -- local i = rawget(p,"replaceinjections")
                                local i = p.replaceinjections
                                if i then
                                    local leftkern = i.leftkern
                                    if leftkern and leftkern ~= 0 then
                                        insert_node_after(replace,replacetail,newkern(leftkern))
                                        done = true
                                    end
                                end
                            else
                             -- local i = rawget(p,"emptyinjections")
                                local i = p.emptyinjections
                                if i then
                                    local leftkern = i.leftkern
                                    if leftkern and leftkern ~= 0 then
                                        setfield(prev,"replace",newkern(leftkern)) -- maybe also leftkern
                                    end
                                end
                            end
                            if done then
                                setdisc(prevdisc,pre,post,replace)
                            end
                        end
                    end
                else
                    -- cursive
                    if hascursives and maxc > 0 then
                        local ny = getfield(current,"yoffset")
                        for i=maxc,minc,-1 do
                            local ti = glyphs[i]
                            ny = ny + properties[ti].cursivedy
                            setfield(ti,"yoffset",getfield(ti,"yoffset") + ny) -- can be mark
                        end
                        maxc = 0
                        cursiveanchor = nil
                    end
                end
            end
            prevdisc  = nil
            prevglyph = current
        elseif id == disc_code then
            pre, post, replace, pretail, posttail, replacetail = getdisc(current,true)
            local done = false
            if pre then
                -- left|pre glyphs|right
                for n in traverse_char(pre) do
                    local p = rawget(properties,n)
                    if p then
                     -- local i = rawget(p,"injections") or rawget(p,"preinjections")
                        local i = p.injections or p.preinjections
                        if i then
                            local yoffset = i.yoffset
                            if yoffset and yoffset ~= 0 then
                                setfield(n,"yoffset",yoffset)
                            end
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                pre  = insert_node_before(pre,n,newkern(leftkern))
                                done = true
                            end
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                insert_node_after(pre,n,newkern(rightkern))
                                done = true
                            end
                            if hasmarks then
                                local pm = i.markbasenode
                                if pm then
                                    processmark(pm,current,i)
                                end
                            end
                        end
                    end
                end
            end
            if post then
                -- left|post glyphs|right
                for n in traverse_char(post) do
                    local p = rawget(properties,n)
                    if p then
                     -- local i = rawget(p,"injections") or rawget(p,"postinjections")
                        local i = p.injections or p.postinjections
                        if i then
                            local yoffset = i.yoffset
                            if yoffset and yoffset ~= 0 then
                                setfield(n,"yoffset",yoffset)
                            end
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                post = insert_node_before(post,n,newkern(leftkern))
                                done = true
                            end
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                insert_node_after(post,n,newkern(rightkern))
                                done = true
                            end
                            if hasmarks then
                                local pm = i.markbasenode
                                if pm then
                                    processmark(pm,current,i)
                                end
                            end
                        end
                    end
                end
            end
            if replace then
                -- left|replace glyphs|right
                for n in traverse_char(replace) do
                    local p = rawget(properties,n)
                    if p then
                     -- local i = rawget(p,"injections") or rawget(p,"replaceinjections")
                        local i = p.injections or p.replaceinjections
                        if i then
                            local yoffset = i.yoffset
                            if yoffset and yoffset ~= 0 then
                                setfield(n,"yoffset",yoffset)
                            end
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                replace = insert_node_before(replace,n,newkern(leftkern))
                                done    = true
                            end
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                insert_node_after(replace,n,newkern(rightkern))
                                done = true
                            end
                            if hasmarks then
                                local pm = i.markbasenode
                                if pm then
                                    processmark(pm,current,i)
                                end
                            end
                        end
                    end
                end
            end
            if prevglyph then
                if pre then
                    local p = rawget(properties,prevglyph)
                    if p then
                     -- local i = rawget(p,"preinjections")
                        local i = p.preinjections
                        if i then
                            -- glyph|pre glyphs
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                pre  = insert_node_before(pre,pre,newkern(rightkern))
                                done = true
                            end
                        end
                    end
                end
                if replace then
                    local p = rawget(properties,prevglyph)
                    if p then
                     -- local i = rawget(p,"replaceinjections")
                        local i = p.replaceinjections
                        if i then
                            -- glyph|replace glyphs
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                replace = insert_node_before(replace,replace,newkern(rightkern))
                                done    = true
                            end
                        end
                    end
                end
            end
            if done then
                setdisc(current,pre,post,replace)
            end
            prevglyph = nil
            prevdisc  = current
        else
            prevglyph = nil
            prevdisc  = nil
        end
        prev    = current
        current = next
    end
    -- cursive
    if hascursives and maxc > 0 then
        local ny = getfield(last,"yoffset")
        for i=maxc,minc,-1 do
            local ti = glyphs[i]
            ny = ny + properties[ti].cursivedy
            setfield(ti,"yoffset",ny) -- why not add ?
            if trace_cursive then
                showoffset(ti)
            end
        end
    end
    --
    if nofmarks > 0 then
        for i=1,nofmarks do
            local m = marks[i]
            local p = rawget(properties,m)
         -- local i = rawget(p,"injections")
            local i = p.injections
            local b = i.markbasenode
            processmark(b,m,i)
        end
    elseif hasmarks then
        -- sometyhing bad happened
    end
    --
    if keepregisteredcounts then
        keepregisteredcounts  = false
    else
        nofregisteredkerns    = 0
        nofregisteredpairs    = 0
        nofregisteredmarks    = 0
        nofregisteredcursives = 0
    end
    return tonode(head), true
end

-- space triggers

local triggers = false

function nodes.injections.setspacekerns(font,sequence)
    if triggers then
        triggers[font] = sequence
    else
        triggers = { [font] = sequence }
    end
end

local getthreshold

if context then

    local threshold  =  1 -- todo: add a few methods for context
    local parameters = fonts.hashes.parameters

    directives.register("otf.threshold", function(v) threshold = tonumber(v) or 1 end)

    getthreshold  = function(font)
        local p = parameters[font]
        local f = p.factor
        local s = p.spacing
        local t = threshold * (s and s.width or p.space or 0) - 2
        return t > 0 and t or 0, f
    end

else

    injections.threshold = 0

    getthreshold  = function(font)
        local p = fontdata[font].parameters
        local f = p.factor
        local s = p.spacing
        local t = injections.threshold * (s and s.width or p.space or 0) - 2
        return t > 0 and t or 0, f
    end

end

injections.getthreshold = getthreshold

function injections.isspace(n,threshold)
    if getid(n) == glue_code then
        local w = getfield(n,"width")
        if threshold and w > threshold then -- was >=
            return 32
        end
    end
end

local function injectspaces(head)

    if not triggers then
        return head, false
    end

    local lastfont   = nil
    local spacekerns = nil
    local leftkerns  = nil
    local rightkerns = nil
    local factor     = 0
    local threshold  = 0
    local leftkern   = false
    local rightkern  = false

    local function updatefont(font,trig)
        leftkerns  = trig.left
        rightkerns = trig.right
        lastfont   = font
        threshold,
        factor     = getthreshold(font)
    end

    for n in traverse_id(glue_code,tonut(head)) do
        local prev, next = getboth(n)
        local prevchar = ischar(prev)
        local nextchar = ischar(next)
        if nextchar then
            local font = getfont(next)
            local trig = triggers[font]
            if trig then
                if lastfont ~= font then
                    updatefont(font,trig)
                end
                if rightkerns then
                    rightkern = rightkerns[nextchar]
                end
            end
        end
        if prevchar then
            local font = getfont(prev)
            local trig = triggers[font]
            if trig then
                if lastfont ~= font then
                    updatefont(font,trig)
                end
                if leftkerns then
                    leftkern = leftkerns[prevchar]
                end
            end
        end
        if leftkern then
            local old = getfield(n,"width")
            if old > threshold then
                if rightkern then
                    local new = old + (leftkern + rightkern) * factor
                    if trace_spaces then
                        report_spaces("%C [%p -> %p] %C",prevchar,old,new,nextchar)
                    end
                    setfield(n,"width",new)
                    leftkern  = false
                else
                    local new = old + leftkern * factor
                    if trace_spaces then
                        report_spaces("%C [%p -> %p]",prevchar,old,new)
                    end
                    setfield(n,"width",new)
                end
            end
            leftkern  = false
        elseif rightkern then
            local old = getfield(n,"width")
            if old > threshold then
                local new = old + rightkern * factor
                if trace_spaces then
                    report_spaces("[%p -> %p] %C",nextchar,old,new)
                end
                setfield(n,"width",new)
            end
            rightkern = false
        end
    end

    triggers = false
    return head, true
end

--

function injections.handler(head,where)
    if triggers then
        head = injectspaces(head)
    end
    -- todo: marks only run too
    if nofregisteredmarks > 0 or nofregisteredcursives > 0 then
        if trace_injections then
            report_injections("injection variant %a","everything")
        end
        return inject_everything(head,where)
    elseif nofregisteredpairs > 0 then
        if trace_injections then
            report_injections("injection variant %a","pairs")
        end
        return inject_pairs_only(head,where)
    elseif nofregisteredkerns > 0 then
        if trace_injections then
            report_injections("injection variant %a","kerns")
        end
        return inject_kerns_only(head,where)
    else
        return head, false
    end
end
