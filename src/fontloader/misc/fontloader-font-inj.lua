if not modules then modules = { } end modules ['font-inj'] = {
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

if not nodes.properties then return end

local next, rawget = next, rawget
local utfchar = utf.char
local fastcopy = table.fastcopy

local trace_injections = false  trackers.register("fonts.injections", function(v) trace_injections = v end)

local report_injections = logs.reporter("fonts","injections")

local attributes, nodes, node = attributes, nodes, node

fonts                    = fonts
local fontdata           = fonts.hashes.identifiers

nodes.injections         = nodes.injections or { }
local injections         = nodes.injections

local nodecodes          = nodes.nodecodes
local glyph_code         = nodecodes.glyph
local disc_code          = nodecodes.disc
local kern_code          = nodecodes.kern

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

local traverse_id        = nuts.traverse_id
local insert_node_before = nuts.insert_before
local insert_node_after  = nuts.insert_after
local find_tail          = nuts.tail

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
        local si = rawget(sp,"injections")
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
        local i = rawget(p,"injections")
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
        local i = rawget(p,"injections")
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
    --
    local p = rawget(properties,start)
    if p then
        local i = rawget(p,"injections")
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
        local i = rawget(p,"injections")
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

function injections.setmark(start,base,factor,rlmode,ba,ma,tfmbase,mkmk) -- ba=baseanchor, ma=markanchor
    local dx, dy = factor*(ba[1]-ma[1]), factor*(ba[2]-ma[2])
    nofregisteredmarks = nofregisteredmarks + 1
 -- markanchors[nofregisteredmarks] = base
    if rlmode >= 0 then
        dx = tfmbase.width - dx -- see later commented ox
    end
    local p = rawget(properties,start)
    -- hm, dejavu serif does a sloppy mark2mark before mark2base
    if p then
        local i = rawget(p,"injections")
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
            end
        else
            p.injections = {
                markx        = dx,
                marky        = dy,
                markdir      = rlmode or 0,
                markbase     = nofregisteredmarks,
                markbasenode = base,
                markmark     = mkmk,
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
        elseif id == disc_code then
            local pre     = getfield(n,"pre")
            local post    = getfield(n,"post")
            local replace = getfield(n,"replace")
            if pre then
                showsub(pre,"preinjections","pre")
            end
            if post then
                showsub(post,"postinjections","post")
            end
            if replace then
                showsub(replace,"replaceinjections","replace")
            end
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

local function collect_glyphs(head,offsets)
    local glyphs, glyphi, nofglyphs = { }, { }, 0
    local marks, marki, nofmarks = { }, { }, 0
    local nf, tm = nil, nil
    local n = head

    local function identify(n,what)
        local f = getfont(n)
        if f ~= nf then
            nf = f
            -- other hash in ctx:
            tm = fontdata[nf].resources
            if tm then
                tm = tm.marks
            end
        end
        if tm and tm[getchar(n)] then
            nofmarks = nofmarks + 1
            marks[nofmarks] = n
            marki[nofmarks] = "injections"
        else
            nofglyphs = nofglyphs + 1
            glyphs[nofglyphs] = n
            glyphi[nofglyphs] = what
        end
        if offsets then
            -- yoffsets can influence curs steps
            local p = rawget(properties,n)
            if p then
                local i = rawget(p,what)
                if i then
                    local yoffset = i.yoffset
                    if yoffset and yoffset ~= 0 then
                        setfield(n,"yoffset",yoffset)
                    end
                end
            end
        end
    end

    while n do -- only needed for relevant fonts
        local id = getid(n)
        if id == glyph_code then
            identify(n,"injections")
        elseif id == disc_code then
            local d = getfield(n,"pre")
            if d then
                for n in traverse_id(glyph_code,d) do
                    if getsubtype(n) < 256 then
                        identify(n,"preinjections")
                    end
                end
			end
            local d = getfield(n,"post")
            if d then
                for n in traverse_id(glyph_code,d) do
                    if getsubtype(n) < 256 then
                        identify(n,"postinjections")
                    end
                end
			end
            local d = getfield(n,"replace")
            if d then
                for n in traverse_id(glyph_code,d) do
                    if getsubtype(n) < 256 then
                        identify(n,"replaceinjections")
                    end
                end
			end
        end
		n = getnext(n)
    end

    return glyphs, glyphi, nofglyphs, marks, marki, nofmarks
end

local function inject_marks(marks,marki,nofmarks)
    for i=1,nofmarks do
        local n  = marks[i]
        local pn = rawget(properties,n)
        if pn then
            local ni = marki[i]
            local pn = rawget(pn,ni)
            if pn then
                local p = pn.markbasenode
                if p then
                    local px = getfield(p,"xoffset")
                    local ox = 0
                    local rightkern = nil
                    local pp = rawget(properties,p)
                    if pp then
                        pp = rawget(pp,ni)
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
                        -- we need to deal with fonts that have marks with width
                     -- if pn.markdir < 0 then
                     --     ox = px - pn.markx
                     --  -- report_injections("r2l case 3: %p",ox)
                     -- else
                     --  -- ox = px - getfield(p,"width") + pn.markx
                            ox = px - pn.markx
                         -- report_injections("l2r case 3: %p",ox)
                     -- end
                        local wn = getfield(n,"width") -- in arial marks have widths
                        if wn ~= 0 then
                            -- bad: we should center
                         -- insert_node_before(head,n,newkern(-wn/2))
                         -- insert_node_after(head,n,newkern(-wn/2))
                            pn.leftkern  = -wn/2
                            pn.rightkern = -wn/2
                         -- wx[n] = { 0, -wn/2, 0, -wn }
                        end
                        -- so far
                    end
                    setfield(n,"xoffset",ox)
                    --
                    local py = getfield(p,"yoffset")
--                     local oy = 0
--                     if marks[p] then
--                         oy = py + pn.marky
--                     else
--                         oy = getfield(n,"yoffset") + py + pn.marky
--                     end
                    local oy = getfield(n,"yoffset") + py + pn.marky
                    setfield(n,"yoffset",oy)
                else
                    -- normally this can't happen (only when in trace mode which is a special case anyway)
                 -- report_injections("missing mark anchor %i",pn.markbase or 0)
                end
            end
        end
    end
end

local function inject_cursives(glyphs,glyphi,nofglyphs)
    local cursiveanchor, lastanchor = nil, nil
    local minc, maxc, last = 0, 0, nil
    for i=1,nofglyphs do
        local n  = glyphs[i]
        local pn = rawget(properties,n)
        if pn then
            pn = rawget(pn,glyphi[i])
        end
        if pn then
            local cursivex = pn.cursivex
            if cursivex then
                if cursiveanchor then
                    if cursivex ~= 0 then
                        pn.leftkern = (pn.leftkern or 0) + cursivex
                    end
                    if lastanchor then
                        if maxc == 0 then
                            minc = lastanchor
                        end
                        maxc = lastanchor
                        properties[cursiveanchor].cursivedy = pn.cursivey
                    end
                    last = n
                else
                    maxc = 0
                end
            elseif maxc > 0 then
                local ny = getfield(n,"yoffset")
                for i=maxc,minc,-1 do
                    local ti = glyphs[i]
                    ny = ny + properties[ti].cursivedy
                    setfield(ti,"yoffset",ny) -- why not add ?
                end
                maxc = 0
            end
            if pn.cursiveanchor then
                cursiveanchor = n
                lastanchor = i
            else
                cursiveanchor = nil
                lastanchor = nil
                if maxc > 0 then
                    local ny = getfield(n,"yoffset")
                    for i=maxc,minc,-1 do
                        local ti = glyphs[i]
                        ny = ny + properties[ti].cursivedy
                        setfield(ti,"yoffset",ny) -- why not add ?
                    end
                    maxc = 0
                end
            end
        elseif maxc > 0 then
            local ny = getfield(n,"yoffset")
            for i=maxc,minc,-1 do
                local ti = glyphs[i]
                ny = ny + properties[ti].cursivedy
                setfield(ti,"yoffset",getfield(ti,"yoffset") + ny) -- ?
            end
            maxc = 0
            cursiveanchor = nil
            lastanchor = nil
        end
     -- if maxc > 0 and not cursiveanchor then
     --     local ny = getfield(n,"yoffset")
     --     for i=maxc,minc,-1 do
     --         local ti = glyphs[i][1]
     --         ny = ny + properties[ti].cursivedy
     --         setfield(ti,"yoffset",ny) -- why not add ?
     --     end
     --     maxc = 0
     -- end
    end
    if last and maxc > 0 then
        local ny = getfield(last,"yoffset")
        for i=maxc,minc,-1 do
            local ti = glyphs[i]
            ny = ny + properties[ti].cursivedy
            setfield(ti,"yoffset",ny) -- why not add ?
        end
    end
end

-- G  +D-pre        G
--     D-post+
--    +D-replace+
--
-- G  +D-pre       +D-pre
--     D-post      +D-post
--    +D-replace   +D-replace

local function inject_kerns(head,glist,ilist,length) -- not complete ! compare with inject_kerns_only (but unlikely disc here)
    for i=1,length do
        local n  = glist[i]
        local pn = rawget(properties,n)
        if pn then
			local dp = nil
			local dr = nil
            local ni = ilist[i]
            local p  = nil
			if ni == "injections" then
				p = getprev(n)
				if p then
					local id = getid(p)
					if id == disc_code then
						dp = getfield(p,"post")
						dr = getfield(p,"replace")
					end
				end
			end
			if dp then
				local i = rawget(pn,"postinjections")
				if i then
					local leftkern = i.leftkern
					if leftkern and leftkern ~= 0 then
						local t = find_tail(dp)
						insert_node_after(dp,t,newkern(leftkern))
                        setfield(p,"post",dp) -- currently we need to force a tail refresh
					end
				end
			end
			if dr then
				local i = rawget(pn,"replaceinjections")
				if i then
					local leftkern = i.leftkern
					if leftkern and leftkern ~= 0 then
						local t = find_tail(dr)
						insert_node_after(dr,t,newkern(leftkern))
                        setfield(p,"replace",dr) -- currently we need to force a tail refresh
					end
				end
			else
				local i = rawget(pn,ni)
				if i then
					local leftkern = i.leftkern
					if leftkern and leftkern ~= 0 then
						insert_node_before(head,n,newkern(leftkern)) -- type 0/2
					end
					local rightkern = i.rightkern
					if rightkern and rightkern ~= 0 then
						insert_node_after(head,n,newkern(rightkern)) -- type 0/2
					end
				end
			end
        end
    end
end

local function inject_everything(head,where)
    head = tonut(head)
    if trace_injections then
        trace(head,"everything")
    end
    local glyphs, glyphi, nofglyphs, marks, marki, nofmarks = collect_glyphs(head,nofregisteredpairs > 0)
    if nofglyphs > 0 then
        if nofregisteredcursives > 0 then
            inject_cursives(glyphs,glyphi,nofglyphs)
        end
        if nofregisteredmarks > 0 then -- and nofmarks > 0
            inject_marks(marks,marki,nofmarks)
        end
        inject_kerns(head,glyphs,glyphi,nofglyphs)
    end
    if nofmarks > 0 then
        inject_kerns(head,marks,marki,nofmarks)
	end
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
    local n = head
    local p = nil -- disc node when non-nil
    while n do
        local id = getid(n)
        if id == glyph_code then
            if getsubtype(n) < 256 then
                local pn = rawget(properties,n)
                if pn then
                    if p then
                        local d = getfield(p,"post")
                        if d then
                            local i = rawget(pn,"postinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    local t = find_tail(d)
                                    insert_node_after(d,t,newkern(leftkern))
                                    setfield(p,"post",d) -- currently we need to force a tail refresh
                                end
                            end
                        end
                        local d = getfield(p,"replace")
                        if d then
                            local i = rawget(pn,"replaceinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    local t = find_tail(d)
                                    insert_node_after(d,t,newkern(leftkern))
                                    setfield(p,"replace",d) -- currently we need to force a tail refresh
                                end
                            end
                        else
                            local i = rawget(pn,"injections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    setfield(p,"replace",newkern(leftkern))
                                end
                            end
                        end
                    else
                        -- this is the most common case
                        local i = rawget(pn,"injections")
                        if i then
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                head = insert_node_before(head,n,newkern(leftkern))
                            end
                        end
                    end
                end
            end
            p = nil
        elseif id == disc_code then
            local d = getfield(n,"pre")
            if d then
                local h = d
                for n in traverse_id(glyph_code,d) do
                    if getsubtype(n) < 256 then
                        local pn = rawget(properties,n)
                        if pn then
                            local i = rawget(pn,"preinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    h = insert_node_before(h,n,newkern(leftkern))
                                end
                            end
                        end
                    else
                        break
                    end
                end
                if h ~= d then
                    setfield(n,"pre",h)
                end
            end
            local d = getfield(n,"post")
            if d then
                local h = d
                for n in traverse_id(glyph_code,d) do
                    if getsubtype(n) < 256 then
                        local pn = rawget(properties,n)
                        if pn then
                            local i = rawget(pn,"postinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    h = insert_node_before(h,n,newkern(leftkern))
                                end
                            end
                        end
                    else
                        break
                    end
                end
                if h ~= d then
                    setfield(n,"post",h)
                end
            end
            local d = getfield(n,"replace")
            if d then
                local h = d
                for n in traverse_id(glyph_code,d) do
                    if getsubtype(n) < 256 then
                        local pn = rawget(properties,n)
                        if pn then
                            local i = rawget(pn,"replaceinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    h = insert_node_before(h,n,newkern(leftkern))
                                end
                            end
                        end
                    else
                        break
                    end
                end
                if h ~= d then
                    setfield(n,"replace",h)
                end
            end
            p = n
        else
            p = nil
        end
        n = getnext(n)
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
    local n = head
    local p = nil -- disc node when non-nil
    while n do
        local id = getid(n)
        if id == glyph_code then
            if getsubtype(n) < 256 then
                local pn = rawget(properties,n)
                if pn then
                    if p then
                        local d = getfield(p,"post")
                        if d then
                            local i = rawget(pn,"postinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    local t = find_tail(d)
                                    insert_node_after(d,t,newkern(leftkern))
                                    setfield(p,"post",d) -- currently we need to force a tail refresh
                                end
                             -- local rightkern = i.rightkern
                             -- if rightkern and rightkern ~= 0 then
                             --     insert_node_after(head,n,newkern(rightkern))
                             --     n = getnext(n) -- to be checked
                             -- end
                            end
                        end
                        local d = getfield(p,"replace")
                        if d then
                            local i = rawget(pn,"replaceinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    local t = find_tail(d)
                                    insert_node_after(d,t,newkern(leftkern))
                                    setfield(p,"replace",d) -- currently we need to force a tail refresh
                                end
                             -- local rightkern = i.rightkern
                             -- if rightkern and rightkern ~= 0 then
                             --     insert_node_after(head,n,newkern(rightkern))
                             --     n = getnext(n) -- to be checked
                             -- end
                            end
                        else
                            local i = rawget(pn,"injections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    setfield(p,"replace",newkern(leftkern))
                                end
                             -- local rightkern = i.rightkern
                             -- if rightkern and rightkern ~= 0 then
                             --     insert_node_after(head,n,newkern(rightkern))
                             --     n = getnext(n) -- to be checked
                             -- end
                            end
                        end
                    else
                        -- this is the most common case
                        local i = rawget(pn,"injections")
                        if i then
                            local leftkern = i.leftkern
                            if leftkern and leftkern ~= 0 then
                                head = insert_node_before(head,n,newkern(leftkern))
                            end
                            local rightkern = i.rightkern
                            if rightkern and rightkern ~= 0 then
                                insert_node_after(head,n,newkern(rightkern))
                                n = getnext(n) -- to be checked
                            end
                            local yoffset = i.yoffset
                            if yoffset and yoffset ~= 0 then
                                setfield(n,"yoffset",yoffset)
                            end
                        end
                    end
                end
            end
            p = nil
        elseif id == disc_code then
            local d = getfield(n,"pre")
            if d then
                local h = d
                for n in traverse_id(glyph_code,d) do
                    if getsubtype(n) < 256 then
                        local pn = rawget(properties,n)
                        if pn then
                            local i = rawget(pn,"preinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    h = insert_node_before(h,n,newkern(leftkern))
                                end
                                local rightkern = i.rightkern
                                if rightkern and rightkern ~= 0 then
                                    insert_node_after(head,n,newkern(rightkern))
                                    n = getnext(n) -- to be checked
                                end
                                local yoffset = i.yoffset
                                if yoffset and yoffset ~= 0 then
                                    setfield(n,"yoffset",yoffset)
                                end
                            end
                        end
                    else
                        break
                    end
                end
                if h ~= d then
                    setfield(n,"pre",h)
                end
            end
            local d = getfield(n,"post")
            if d then
                local h = d
                for n in traverse_id(glyph_code,d) do
                    if getsubtype(n) < 256 then
                        local pn = rawget(properties,n)
                        if pn then
                            local i = rawget(pn,"postinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    h = insert_node_before(h,n,newkern(leftkern))
                                end
                                local rightkern = i.rightkern
                                if rightkern and rightkern ~= 0 then
                                    insert_node_after(head,n,newkern(rightkern))
                                    n = getnext(n) -- to be checked
                                end
                                local yoffset = i.yoffset
                                if yoffset and yoffset ~= 0 then
                                    setfield(n,"yoffset",yoffset)
                                end
                            end
                        end
                    else
                        break
                    end
                end
                if h ~= d then
                    setfield(n,"post",h)
                end
            end
            local d = getfield(n,"replace")
            if d then
                local h = d
                for n in traverse_id(glyph_code,d) do
                    if getsubtype(n) < 256 then
                        local pn = rawget(properties,n)
                        if pn then
                            local i = rawget(pn,"replaceinjections")
                            if i then
                                local leftkern = i.leftkern
                                if leftkern and leftkern ~= 0 then
                                    h = insert_node_before(h,n,newkern(leftkern))
                                end
                                local rightkern = i.rightkern
                                if rightkern and rightkern ~= 0 then
                                    insert_node_after(head,n,newkern(rightkern))
                                    n = getnext(n) -- to be checked
                                end
                                local yoffset = i.yoffset
                                if yoffset and yoffset ~= 0 then
                                    setfield(n,"yoffset",yoffset)
                                end
                            end
                        end
                    else
                        break
                    end
                end
                if h ~= d then
                    setfield(n,"replace",h)
                end
            end
            p = n
        else
            p = nil
        end
        n = getnext(n)
    end
    --
    if keepregisteredcounts then
        keepregisteredcounts = false
    else
        nofregisteredpairs = 0
        nofregisteredkerns = 0
    end
    return tonode(head), true
end

function injections.handler(head,where)
    if nofregisteredmarks > 0 or nofregisteredcursives > 0 then
        return inject_everything(head,where)
    elseif nofregisteredpairs > 0 then
        return inject_pairs_only(head,where)
    elseif nofregisteredkerns > 0 then
        return inject_kerns_only(head,where)
    else
        return head, false
    end
end
