if not modules then modules = { } end modules ['math-vfu'] = {
    version   = 1.001,
    comment   = "companion to math-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- All these math vectors .. thanks to Aditya and Mojca they become
-- better and better. If you have problems with math fonts or miss
-- characters report it to the ConTeXt mailing list.

local type, next = type, next

local trace_virtual = false trackers.register("math.virtual", function(v) trace_virtual = v end)
local trace_timings = false trackers.register("math.timings", function(v) trace_timings = v end)

fonts.enc.math = fonts.enc.math or { }

local shared = { }

fonts.vf.math          = fonts.vf.math or { }
fonts.vf.math.optional = false

local push, pop, back = { "push" }, { "pop" }, { "slot", 1, 0x2215 }

local function negate(main,unicode,basecode)
    local characters = main.characters
    if not characters[unicode] then
        local basechar = characters[basecode]
        if basechar then
            local ht, wd = basechar.height, basechar.width
            characters[unicode] = {
                width    = wd,
                height   = ht,
                depth    = basechar.depth,
                italic   = basechar.italic,
                kerns    = basechar.kerns,
                commands = {
                    { "slot", 1, basecode },
                    push,
                    { "down",    ht/5},
                    { "right", - wd/2},
                    back,
                    push,
                }
            }
        end
    end
end

--~ \Umathchardef\braceld="0 "1 "FF07A
--~ \Umathchardef\bracerd="0 "1 "FF07B
--~ \Umathchardef\bracelu="0 "1 "FF07C
--~ \Umathchardef\braceru="0 "1 "FF07D

local function brace(main,unicode,first,rule,left,right,rule,last)
    local characters = main.characters
    if not characters[unicode] then
        characters[unicode] = {
            horiz_variants = {
                { extender = 0, glyph = first },
                { extender = 1, glyph = rule  },
                { extender = 0, glyph = left  },
                { extender = 0, glyph = right },
                { extender = 1, glyph = rule  },
                { extender = 0, glyph = last  },
            }
        }
    end
end

local function arrow(main,unicode,arrow,minus,isleft)
    if isleft then
        t = {
            { extender = 0, glyph = arrow },
            { extender = 1, glyph = minus  },
        }
    else
        t = {
            { extender = 0, glyph = minus },
            { extender = 1, glyph = arrow },
        }
    end
--~     main.characters[unicode] = { horiz_variants = t }
    main.characters[unicode].horiz_variants = t
end

local function parent(main,unicode,first,rule,last)
    local characters = main.characters
    if not characters[unicode] then
        characters[unicode] = {
            horiz_variants = {
                { extender = 0, glyph = first },
                { extender = 1, glyph = rule  },
                { extender = 0, glyph = last  },
            }
        }
    end
end

local push, pop, step = { "push" }, { "pop" }, 0.2 -- 0.1 is nicer but gives larger files

local function make(main,id,size,n,m)
    local characters = main.characters
    local xu = main.parameters.x_height + 0.3*size
    local xd = 0.3*size
    local old, upslot, dnslot, uprule, dnrule = 0xFF000+n, 0xFF100+n, 0xFF200+n, 0xFF300+m, 0xFF400+m
    local c = characters[old]
    if c then
        local w, h, d = c.width, c.height, c.depth
        local thickness = h - d
        local rulewidth = step*size -- we could use an overlap
        local slot = { "slot", id, old }
        local rule = { "rule", thickness, rulewidth  }
        local up = { "down", -xu }
        local dn = { "down", xd }
        local ht, dp = xu + 3*thickness, 0
        if not characters[uprule] then
            characters[uprule] = { width = rulewidth, height = ht, depth = dp, commands = { push, up, rule, pop } }
        end
        characters[upslot] = { width = w, height = ht, depth = dp, commands = { push, up, slot, pop } }
        local ht, dp = 0, xd + 3*thickness
        if not characters[dnrule] then
            characters[dnrule] = { width = rulewidth, height = ht, depth = dp, commands = { push, dn, rule, pop } }
        end
        characters[dnslot] = { width = w, height = ht, depth = dp, commands = { push, dn, slot, pop } }
    end
end

local function minus(main,id,size,unicode)
    local characters = main.characters
    local mu = size/18
    local minus = characters[0x002D]
    local width = minus.width - 5*mu
    characters[unicode] = {
        width = width, height = minus.height, depth = minus.depth,
        commands = { push, { "right", -3*mu }, { "slot", id, 0x002D }, pop }
    }
end

local function dots(main,id,size,unicode)
    local characters = main.characters
    local c = characters[0x002E]
    local w, h, d = c.width, c.height, c.depth
    local mu = size/18
    local right3mu  = { "right", 3*mu }
    local right1mu  = { "right", 1*mu }
    local up1size   = { "down", -.1*size }
    local up4size   = { "down", -.4*size }
    local up7size   = { "down", -.7*size }
    local right2muw = { "right", 2*mu + w }
    local slot = { "slot", id, 0x002E }
    if unicode == 0x22EF then
        local c = characters[0x022C5]
        if c then
            local w, h, d = c.width, c.height, c.depth
            local slot = { "slot", id, 0x022C5 }
            characters[unicode] = {
                width = 3*w + 2*3*mu, height = h, depth = d,
                commands = { push, slot, right3mu, slot, right3mu, slot, pop }
            }
        end
    elseif unicode == 0x22EE then
        -- weird height !
        characters[unicode] = {
            width = w, height = h+(1.4)*size, depth = 0,
            commands = { push, push, slot, pop, up4size, push, slot, pop, up4size, slot, pop }
        }
    elseif unicode == 0x22F1 then
        characters[unicode] = {
            width = 3*w + 6*size/18, height = 1.5*size, depth = 0,
            commands = {
                push,
                    right1mu,
                    push, up7size, slot, pop,
                    right2muw,
                    push, up4size, slot, pop,
                    right2muw,
                    push, up1size, slot, pop,
                    right1mu,
                pop
            }
        }
    elseif unicode == 0x22F0 then
        characters[unicode] = {
            width = 3*w + 6*size/18, height = 1.5*size, depth = 0,
            commands = {
                push,
                    right1mu,
                    push, up1size, slot, pop,
                    right2muw,
                    push, up4size, slot, pop,
                    right2muw,
                    push, up7size, slot, pop,
                    right1mu,
                pop
            }
        }
    else
        characters[unicode] = {
            width = 3*w + 2*3*mu, height = h, depth = d,
            commands = { push, slot, right3mu, slot, right3mu, slot, pop }
        }
    end
end

function fonts.vf.math.alas(main,id,size)
    for i=0x7A,0x7D do
        make(main,id,size,i,1)
    end
    brace (main,0x23DE,0xFF17A,0xFF301,0xFF17D,0xFF17C,0xFF301,0xFF17B)
    brace (main,0x23DF,0xFF27C,0xFF401,0xFF27B,0xFF27A,0xFF401,0xFF27D)
    parent(main,0x23DC,0xFF17A,0xFF301,0xFF17B)
    parent(main,0x23DD,0xFF27C,0xFF401,0xFF27D)
    negate(main,0x2260,0x003D)
    dots(main,id,size,0x2026) -- ldots
    dots(main,id,size,0x22EE) -- vdots
    dots(main,id,size,0x22EF) -- cdots
    dots(main,id,size,0x22F1) -- ddots
    dots(main,id,size,0x22F0) -- udots
    minus(main,id,size,0xFF501)
    arrow(main,0x2190,0xFE190,0xFF501,true) -- left
    arrow(main,0x2192,0xFE192,0xFF501,false) -- right
end

local unique = 0 -- testcase: \startTEXpage \math{!\text{-}\text{-}\text{-}} \stopTEXpage

function fonts.basecopy(tfmtable,name)
    local characters, parameters, fullname = tfmtable.characters, tfmtable.parameters, tfmtable.fullname
    local t, c, p = { }, { }, { }
    for k, v in next, tfmtable do
        t[k] = v
    end
    if characters then
        for k, v in next, characters do
            c[k] = v
        end
        t.characters = c
    else
        logs.report("math virtual","font %s has no characters",name)
    end
    if parameters then
        for k, v in next, parameters do
            p[k] = v
        end
        t.parameters = p
    else
        logs.report("math virtual","font %s has no parameters",name)
    end
    -- tricky ... what if fullname does not exist
    if fullname then
        unique = unique + 1
        t.fullname = fullname .. "-" .. unique
    end
    return t
end

local reported = { }
local reverse -- index -> unicode

function fonts.vf.math.define(specification,set)
    if not reverse then
        reverse = { }
        for k, v in next, fonts.enc.math do
            local r = { }
            for u, i in next, v do
                r[i] = u
            end
            reverse[k] = r
        end
    end
    local name = specification.name -- symbolic name
    local size = specification.size -- given size
    local fnt, lst, main = { }, { }, nil
    local start = (trace_virtual or trace_timings) and os.clock()
    local okset, n = { }, 0
    for s=1,#set do
        local ss = set[s]
        local ssname = ss.name
        if ss.optional and fonts.vf.math.optional then
            if trace_virtual then
                logs.report("math virtual","loading font %s subfont %s with name %s at %s is skipped",name,s,ssname,size)
            end
        else
            if ss.features then ssname = ssname .. "*" .. ss.features end
            if ss.main then main = s end
            local f, id = fonts.tfm.read_and_define(ssname,size)
            if not f then
                logs.report("math virtual","loading font %s subfont %s with name %s at %s is skipped, not found",name,s,ssname,size)
            else
                n = n + 1
                okset[n] = ss
                fnt[n] = f
                lst[n] = { id = id, size = size }
                if not shared[s] then shared[n] = { } end
                if trace_virtual then
                    logs.report("math virtual","loading font %s subfont %s with name %s at %s as id %s using encoding %s",name,s,ssname,size,id,ss.vector or "none")
                end
            end
        end
    end
    -- beware, fnt[1] is already passed to tex (we need to make a simple copy then .. todo)
    main = fonts.basecopy(fnt[1],name)
    main.name, main.fonts, main.virtualized, main.math_parameters = name, lst, true, { }
    local characters, descriptions = main.characters, main.descriptions
    local mp = main.parameters
    if mp then
        mp.x_height = mp.x_height or 0
    end
    local already_reported = false
    for s=1,n do
        local ss, fs = okset[s], fnt[s]
        if not fs then
            -- skip, error
        elseif ss.optional and fonts.vf.math.optional then
            -- skip, redundant
        else
            local mm, fp = main.math_parameters, fs.parameters
            if mm and fp and mp then
                if ss.extension then
                    mm.math_x_height          = fp.x_height or 0 -- math_x_height           height of x
                    mm.default_rule_thickness = fp[ 8] or 0 -- default_rule_thickness  thickness of \over bars
                    mm.big_op_spacing1        = fp[ 9] or 0 -- big_op_spacing1         minimum clearance above a displayed op
                    mm.big_op_spacing2        = fp[10] or 0 -- big_op_spacing2         minimum clearance below a displayed op
                    mm.big_op_spacing3        = fp[11] or 0 -- big_op_spacing3         minimum baselineskip above displayed op
                    mm.big_op_spacing4        = fp[12] or 0 -- big_op_spacing4         minimum baselineskip below displayed op
                    mm.big_op_spacing5        = fp[13] or 0 -- big_op_spacing5         padding above and below displayed limits
                --  logs.report("math virtual","loading and virtualizing font %s at size %s, setting ex parameters",name,size)
                elseif ss.parameters then
                    mp.x_height      = fp.x_height or mp.x_height
                    mm.x_height      = mm.x_height or fp.x_height or 0 -- x_height                height of x
                    mm.num1          = fp[ 8] or 0 -- num1                    numerator shift-up in display styles
                    mm.num2          = fp[ 9] or 0 -- num2                    numerator shift-up in non-display, non-\atop
                    mm.num3          = fp[10] or 0 -- num3                    numerator shift-up in non-display \atop
                    mm.denom1        = fp[11] or 0 -- denom1                  denominator shift-down in display styles
                    mm.denom2        = fp[12] or 0 -- denom2                  denominator shift-down in non-display styles
                    mm.sup1          = fp[13] or 0 -- sup1                    superscript shift-up in uncramped display style
                    mm.sup2          = fp[14] or 0 -- sup2                    superscript shift-up in uncramped non-display
                    mm.sup3          = fp[15] or 0 -- sup3                    superscript shift-up in cramped styles
                    mm.sub1          = fp[16] or 0 -- sub1                    subscript shift-down if superscript is absent
                    mm.sub2          = fp[17] or 0 -- sub2                    subscript shift-down if superscript is present
                    mm.sup_drop      = fp[18] or 0 -- sup_drop                superscript baseline below top of large box
                    mm.sub_drop      = fp[19] or 0 -- sub_drop                subscript baseline below bottom of large box
                    mm.delim1        = fp[20] or 0 -- delim1                  size of \atopwithdelims delimiters in display styles
                    mm.delim2        = fp[21] or 0 -- delim2                  size of \atopwithdelims delimiters in non-displays
                    mm.axis_height   = fp[22] or 0 -- axis_height             height of fraction lines above the baseline
                --  logs.report("math virtual","loading and virtualizing font %s at size %s, setting sy parameters",name,size)
                end
            else
                logs.report("math virtual","font %s, no parameters set",name)
            end
            local vectorname = ss.vector
            if vectorname then
                local offset = 0xFF000
                local vector = fonts.enc.math[vectorname]
                local rotcev = reverse[vectorname]
                if vector then
                    local fc, fd, si = fs.characters, fs.descriptions, shared[s]
                    local skewchar = ss.skewchar
                    for unicode, index in next, vector do
                        local fci = fc[index]
                        if not fci then
                            local fontname = fs.name or "unknown"
                            local rf = reported[fontname]
                            if not rf then rf = { } reported[fontname] = rf end
                            local rv = rf[vectorname]
                            if not rv then rv = { } rf[vectorname] = rv end
                            local ru = rv[unicode]
                            if not ru then
                                if trace_virtual then
                                    logs.report("math virtual", "unicode point U+%05X has no index %04X in vector %s for font %s",unicode,index,vectorname,fontname)
                                elseif not already_reported then
                                    logs.report("math virtual", "the mapping is incomplete for '%s' at %s",name,number.topoints(size))
                                    already_reported = true
                                end
                                rv[unicode] = true
                            end
                        else
                            local ref = si[index]
                            if not ref then
                                ref = { { 'slot', s, index } }
                                si[index] = ref
                            end
                            local kerns = fci.kerns
                            if kerns then
                                local width = fci.width
                                local krn = { }
                                for k=1,#kerns do
                                    local rk = rotcev[k]
                                    if rk then
                                        krn[rk] = kerns[k]
                                    end
                                end
                                if not next(krn) then
                                    krn = nil
                                end
                                local t = {
                                    width    = width,
                                    height   = fci.height,
                                    depth    = fci.depth,
                                    italic   = fci.italic,
                                    kerns    = krn,
                                    commands = ref,
                                }
                                if skewchar and kerns then
                                    local k = kerns[skewchar]
                                    if k then
                                        t.top_accent = width/2 + k
                                    end
                                end
                                characters[unicode] = t
                            else
                                characters[unicode] = {
                                    width    = fci.width,
                                    height   = fci.height,
                                    depth    = fci.depth,
                                    italic   = fci.italic,
                                    commands = ref,
                                }
                            end
                        end
                    end
                    if ss.extension then
                        -- todo: if multiple ex, then 256 offsets per instance
                        local extension = fonts.enc.math["large-to-small"]
                        local variants_done = fs.variants_done
                        for index, fci in next, fc do -- the raw ex file
                            if type(index) == "number" then
                                local ref = si[index]
                                if not ref then
                                    ref = { { 'slot', s, index } }
                                    si[index] = ref
                                end
                                local t = {
                                    width    = fci.width,
                                    height   = fci.height,
                                    depth    = fci.depth,
                                    italic   = fci.italic,
                                    commands = ref,
                                }
                                local n = fci.next
                                if n then
                                    t.next = offset + n
                                elseif variants_done then
                                    local vv = fci.vert_variants
                                    if vv then
                                        t.vert_variants = vv
                                    end
                                    local hv = fci.horiz_variants
                                    if hv then
                                        t.horiz_variants = hv
                                    end
                                else
                                    local vv = fci.vert_variants
                                    if vv then
                                        for i=1,#vv do
                                            local vvi = vv[i]
                                            vvi.glyph = vvi.glyph + offset
                                        end
                                        t.vert_variants = vv
                                    end
                                    local hv = fci.horiz_variants
                                    if hv then
                                        for i=1,#hv do
                                            local hvi = hv[i]
                                            hvi.glyph = hvi.glyph + offset
                                        end
                                        t.horiz_variants = hv
                                    end
                                end
                                characters[offset + index] = t
                            end
                        end
                        fs.variants_done = true
                        for unicode, index in next, extension do
                            local cu = characters[unicode]
                            if cu then
                                cu.next = offset + index
                                --~ local n, c, d = unicode, cu, { }
                                --~ print("START", unicode)
                                --~ while n do
                                --~     n = c.next
                                --~     if n then
                                --~         print("NEXT", n)
                                --~         c = characters[n]
                                --~         if not c then
                                --~             print("EXIT")
                                --~         elseif d[n] then
                                --~             print("LOOP")
                                --~             break
                                --~         end
                                --~         d[n] = true
                                --~     end
                                --~ end
                            else
                                local fci = fc[index]
                                if not fci then
--~                                     characters[unicode] = {
--~                                         width    = 0,
--~                                         height   = 0,
--~                                         depth    = 0,
--~                                         index    = 0,
--~                                     }
                                else
                                    local ref = si[index]
                                    if not ref then
                                        ref = { { 'slot', s, index } }
                                        si[index] = ref
                                    end
                                    local kerns = fci.kerns
                                    if kerns then
                                        local krn = { }
                                        for k=1,#kerns do
                                            krn[offset + k] = kerns[k]
                                        end
                                        characters[unicode] = {
                                            width    = fci.width,
                                            height   = fci.height,
                                            depth    = fci.depth,
                                            italic   = fci.italic,
                                            commands = ref,
                                            kerns    = krn,
                                            next     = offset + index,
                                        }
                                    else
                                        characters[unicode] = {
                                            width    = fci.width,
                                            height   = fci.height,
                                            depth    = fci.depth,
                                            italic   = fci.italic,
                                            commands = ref,
                                            next     = offset + index,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            mathematics.extras.copy(main) --not needed here (yet)
        end
    end
    lst[#lst+1] = { id = font.nextid(), size = size }
    if mp then -- weak catch
        fonts.vf.math.alas(main,#lst,size)
    end
    if trace_virtual or trace_timings then
        logs.report("math virtual","loading and virtualizing font %s at size %s took %0.3f seconds",name,size,os.clock()-start)
    end
    main.has_italic = true
    main.type = "virtual" -- not needed
    mathematics.scaleparameters(main,main,1)
    main.nomath = false
--~ print(table.serialize(characters[0x222B]))
--~ print(main.fontname,table.serialize(main.MathConstants))
    return main
end

function mathematics.make_font(name, set)
    fonts.define.methods[name] = function(specification)
        return fonts.vf.math.define(specification,set)
    end
end

-- varphi is part of the alphabet, contrary to the other var*s'

fonts.enc.math["large-to-small"] = {
    [0x00028] = 0x00, -- (
    [0x00029] = 0x01, -- )
    [0x0005B] = 0x02, -- [
    [0x0005D] = 0x03, -- ]
    [0x0230A] = 0x04, -- lfloor
    [0x0230B] = 0x05, -- rfloor
    [0x02308] = 0x06, -- lceil
    [0x02309] = 0x07, -- rceil
    [0x0007B] = 0x08, -- {
    [0x0007D] = 0x09, -- }
    [0x027E8] = 0x0A, -- <
    [0x027E9] = 0x0B, -- >
    [0x0007C] = 0x0C, -- |
--~ [0x0]     = 0x0D, -- lVert rVert Vert
--  [0x0002F] = 0x0E, -- /
    [0x0005C] = 0x0F, -- \
--~ [0x0]     = 0x3A, -- lgroup
--~ [0x0]     = 0x3B, -- rgroup
--~ [0x0]     = 0x3C, -- arrowvert
--~ [0x0]     = 0x3D, -- Arrowvert
    [0x02195] = 0x3F, -- updownarrow
--~ [0x0]     = 0x40, -- lmoustache
--~ [0x0]     = 0x41, -- rmoustache
    [0x0221A] = 0x70, -- sqrt
    [0x021D5] = 0x77, -- Updownarrow
    [0x02191] = 0x78, -- uparrow
    [0x02193] = 0x79, -- downarrow
    [0x021D1] = 0x7E, -- Uparrow
    [0x021D3] = 0x7F, -- Downarrow
    [0x0220F] = 0x59, -- prod
    [0x02210] = 0x61, -- coprod
    [0x02211] = 0x58, -- sum
    [0x0222B] = 0x5A, -- intop
    [0x0222E] = 0x49, -- ointop
    [0xFE302] = 0x62, -- widehat
    [0xFE303] = 0x65, -- widetilde
    [0x022C0] = 0x5E, -- bigwedge
    [0x022C1] = 0x5F, -- bigvee
    [0x022C2] = 0x5C, -- bigcap
    [0x022C3] = 0x5B, -- bigcup
    [0x02044] = 0x0E, -- /
}

fonts.enc.math["tex-ex"] = {
    [0x0220F] = 0x51, -- prod
    [0x0222B] = 0x52, -- intop
    [0x02210] = 0x60, -- coprod
    [0x02211] = 0x50, -- sum
    [0x022C0] = 0x56, -- bigwedge
    [0x022C1] = 0x57, -- bigvee
    [0x022C2] = 0x54, -- bigcap
    [0x022C3] = 0x53, -- bigcup
    [0x02A04] = 0x55, -- biguplus
    [0x02A02] = 0x4E, -- bigotimes
    [0x02A01] = 0x4C, -- bigoplus
    [0x02A03] = 0x4A, -- bigodot
    [0x0222E] = 0x48, -- ointop
    [0x02A06] = 0x46, -- bigsqcup
}

-- only math stuff is needed, since we always use an lm or gyre
-- font as main font

fonts.enc.math["tex-mr"] = {
    [0x00393] = 0x00, -- Gamma
    [0x00394] = 0x01, -- Delta
    [0x00398] = 0x02, -- Theta
    [0x0039B] = 0x03, -- Lambda
    [0x0039E] = 0x04, -- Xi
    [0x003A0] = 0x05, -- Pi
    [0x003A3] = 0x06, -- Sigma
    [0x003A5] = 0x07, -- Upsilon
    [0x003A6] = 0x08, -- Phi
    [0x003A8] = 0x09, -- Psi
    [0x003A9] = 0x0A, -- Omega
--  [0x00060] = 0x12, -- [math]grave
--  [0x000B4] = 0x13, -- [math]acute
--  [0x002C7] = 0x14, -- [math]check
--  [0x002D8] = 0x15, -- [math]breve
--  [0x000AF] = 0x16, -- [math]bar
--  [0x00021] = 0x21, -- !
--  [0x00028] = 0x28, -- (
--  [0x00029] = 0x29, -- )
--  [0x0002B] = 0x2B, -- +
--  [0x0002F] = 0x2F, -- /
--  [0x0003A] = 0x3A, -- :
--  [0x02236] = 0x3A, -- colon
--  [0x0003B] = 0x3B, -- ;
--  [0x0003C] = 0x3C, -- <
--  [0x0003D] = 0x3D, -- =
--  [0x0003E] = 0x3E, -- >
--  [0x0003F] = 0x3F, -- ?
    [0x00391] = 0x41, -- Alpha
    [0x00392] = 0x42, -- Beta
    [0x02145] = 0x44,
    [0x00395] = 0x45, -- Epsilon
    [0x00397] = 0x48, -- Eta
    [0x00399] = 0x49, -- Iota
    [0x0039A] = 0x4B, -- Kappa
    [0x0039C] = 0x4D, -- Mu
    [0x0039D] = 0x4E, -- Nu
    [0x0039F] = 0x4F, -- Omicron
    [0x003A1] = 0x52, -- Rho
    [0x003A4] = 0x54, -- Tau
    [0x003A7] = 0x58, -- Chi
    [0x00396] = 0x5A, -- Zeta
--  [0x0005B] = 0x5B, -- [
--  [0x0005D] = 0x5D, -- ]
--  [0x0005E] = 0x5E, -- [math]hat -- the text one
    [0x00302] = 0x5E, -- [math]hat -- the real math one
--  [0x002D9] = 0x5F, -- [math]dot
    [0x02146] = 0x64,
    [0x02147] = 0x65,
--  [0x002DC] = 0x7E, -- [math]tilde -- the text one
    [0x00303] = 0x7E, -- [math]tilde -- the real one
--  [0x000A8] = 0x7F, -- [math]ddot
}

fonts.enc.math["tex-mr-missing"] = {
    [0x02236] = 0x3A, -- colon
}

fonts.enc.math["tex-mi"] = {
    [0x1D6E4] = 0x00, -- Gamma
    [0x1D6E5] = 0x01, -- Delta
    [0x1D6E9] = 0x02, -- Theta
    [0x1D6F3] = 0x02, -- varTheta (not present in TeX)
    [0x1D6EC] = 0x03, -- Lambda
    [0x1D6EF] = 0x04, -- Xi
    [0x1D6F1] = 0x05, -- Pi
    [0x1D6F4] = 0x06, -- Sigma
    [0x1D6F6] = 0x07, -- Upsilon
    [0x1D6F7] = 0x08, -- Phi
    [0x1D6F9] = 0x09, -- Psi
    [0x1D6FA] = 0x0A, -- Omega
    [0x1D6FC] = 0x0B, -- alpha
    [0x1D6FD] = 0x0C, -- beta
    [0x1D6FE] = 0x0D, -- gamma
    [0x1D6FF] = 0x0E, -- delta
    [0x1D716] = 0x0F, -- epsilon TODO: 1D716
    [0x1D701] = 0x10, -- zeta
    [0x1D702] = 0x11, -- eta
    [0x1D703] = 0x12, -- theta TODO: 1D703
    [0x1D704] = 0x13, -- iota
    [0x1D705] = 0x14, -- kappa
    [0x1D718] = 0x14, -- varkappa, not in tex fonts
    [0x1D706] = 0x15, -- lambda
    [0x1D707] = 0x16, -- mu
    [0x1D708] = 0x17, -- nu
    [0x1D709] = 0x18, -- xi
    [0x1D70B] = 0x19, -- pi
    [0x1D70C] = 0x1A, -- rho
    [0x1D70E] = 0x1B, -- sigma
    [0x1D70F] = 0x1C, -- tau
    [0x1D710] = 0x1D, -- upsilon
    [0x1D719] = 0x1E, -- phi
    [0x1D712] = 0x1F, -- chi
    [0x1D713] = 0x20, -- psi
    [0x1D714] = 0x21, -- omega
    [0x1D700] = 0x22, -- varepsilon (the other way around)
    [0x1D717] = 0x23, -- vartheta
    [0x1D71B] = 0x24, -- varpi
    [0x1D71A] = 0x25, -- varrho
    [0x1D70D] = 0x26, -- varsigma
    [0x1D711] = 0x27, -- varphi (the other way around)
    [0x021BC] = 0x28, -- leftharpoonup
    [0x021BD] = 0x29, -- leftharpoondown
    [0x021C0] = 0x2A, -- rightharpoonup
    [0x021C1] = 0x2B, -- rightharpoondown
    [0xFE322] = 0x2C, -- lhook (hook for combining arrows)
    [0xFE323] = 0x2D, -- rhook (hook for combining arrows)
    [0x022B3] = 0x2E, -- triangleright (TODO: which one is right?)
    [0x022B2] = 0x2F, -- triangleleft (TODO: which one is right?)
--  [0x00041] = 0x30, -- 0
--  [0x00041] = 0x31, -- 1
--  [0x00041] = 0x32, -- 2
--  [0x00041] = 0x33, -- 3
--  [0x00041] = 0x34, -- 4
--  [0x00041] = 0x35, -- 5
--  [0x00041] = 0x36, -- 6
--  [0x00041] = 0x37, -- 7
--  [0x00041] = 0x38, -- 8
--  [0x00041] = 0x39, -- 9
--~     [0x0002E] = 0x3A, -- .
    [0x0002C] = 0x3B, -- ,
    [0x0003C] = 0x3C, -- <
--  [0x0002F] = 0x3D, -- /, slash, solidus
    [0x02044] = 0x3D, -- / AM: Not sure
    [0x0003E] = 0x3E, -- >
    [0x022C6] = 0x3F, -- star
    [0x02202] = 0x40, -- partial
--
    [0x0266D] = 0x5B, -- flat
    [0x0266E] = 0x5C, -- natural
    [0x0266F] = 0x5D, -- sharp
    [0x02323] = 0x5E, -- smile
    [0x02322] = 0x5F, -- frown
    [0x02113] = 0x60, -- ell
--
    [0x1D6A4] = 0x7B, -- imath (TODO: also 0131)
    [0x1D6A5] = 0x7C, -- jmath (TODO: also 0237)
    [0x02118] = 0x7D, -- wp
    [0x020D7] = 0x7E, -- vec (TODO: not sure)
--              0x7F, -- (no idea what that could be)
}


fonts.enc.math["tex-it"] = {
--  [0x1D434] = 0x41, -- A
    [0x1D6E2] = 0x41, -- Alpha
--  [0x1D435] = 0x42, -- B
    [0x1D6E3] = 0x42, -- Beta
--  [0x1D436] = 0x43, -- C
--  [0x1D437] = 0x44, -- D
--  [0x1D438] = 0x45, -- E
    [0x1D6E6] = 0x45, -- Epsilon
--  [0x1D439] = 0x46, -- F
--  [0x1D43A] = 0x47, -- G
--  [0x1D43B] = 0x48, -- H
    [0x1D6E8] = 0x48, -- Eta
--  [0x1D43C] = 0x49, -- I
    [0x1D6EA] = 0x49, -- Iota
--  [0x1D43D] = 0x4A, -- J
--  [0x1D43E] = 0x4B, -- K
    [0x1D6EB] = 0x4B, -- Kappa
--  [0x1D43F] = 0x4C, -- L
--  [0x1D440] = 0x4D, -- M
    [0x1D6ED] = 0x4D, -- Mu
--  [0x1D441] = 0x4E, -- N
    [0x1D6EE] = 0x4E, -- Nu
--  [0x1D442] = 0x4F, -- O
    [0x1D6F0] = 0x4F, -- Omicron
--  [0x1D443] = 0x50, -- P
    [0x1D6F2] = 0x50, -- Rho
--  [0x1D444] = 0x51, -- Q
--  [0x1D445] = 0x52, -- R
--  [0x1D446] = 0x53, -- S
--  [0x1D447] = 0x54, -- T
    [0x1D6F5] = 0x54, -- Tau
--  [0x1D448] = 0x55, -- U
--  [0x1D449] = 0x56, -- V
--  [0x1D44A] = 0x57, -- W
--  [0x1D44B] = 0x58, -- X
    [0x1D6F8] = 0x58, -- Chi
--  [0x1D44C] = 0x59, -- Y
--  [0x1D44D] = 0x5A, -- Z
--
--  [0x1D44E] = 0x61, -- a
--  [0x1D44F] = 0x62, -- b
--  [0x1D450] = 0x63, -- c
--  [0x1D451] = 0x64, -- d
--  [0x1D452] = 0x65, -- e
--  [0x1D453] = 0x66, -- f
--  [0x1D454] = 0x67, -- g
--  [0x1D455] = 0x68, -- h
    [0x0210E] = 0x68, -- Planck constant (h)
--  [0x1D456] = 0x69, -- i
--  [0x1D457] = 0x6A, -- j
--  [0x1D458] = 0x6B, -- k
--  [0x1D459] = 0x6C, -- l
--  [0x1D45A] = 0x6D, -- m
--  [0x1D45B] = 0x6E, -- n
--  [0x1D45C] = 0x6F, -- o
    [0x1D70A] = 0x6F, -- omicron
--  [0x1D45D] = 0x70, -- p
--  [0x1D45E] = 0x71, -- q
--  [0x1D45F] = 0x72, -- r
--  [0x1D460] = 0x73, -- s
--  [0x1D461] = 0x74, -- t
--  [0x1D462] = 0x75, -- u
--  [0x1D463] = 0x76, -- v
--  [0x1D464] = 0x77, -- w
--  [0x1D465] = 0x78, -- x
--  [0x1D466] = 0x79, -- y
--  [0x1D467] = 0x7A, -- z
}

fonts.enc.math["tex-ss"]           = { }
fonts.enc.math["tex-tt"]           = { }
fonts.enc.math["tex-bf"]           = { }
fonts.enc.math["tex-bi"]           = { }
fonts.enc.math["tex-fraktur"]      = { }
fonts.enc.math["tex-fraktur-bold"] = { }

function fonts.vf.math.set_letters(font_encoding, name, uppercase, lowercase)
    local enc = font_encoding[name]
    for i = 0,25 do
        enc[uppercase+i] = i + 0x41
        enc[lowercase+i] = i + 0x61
    end
end

function fonts.vf.math.set_digits(font_encoding, name, digits)
    local enc = font_encoding[name]
    for i = 0,9 do
        enc[digits+i] = i + 0x30
    end
end

fonts.enc.math["tex-sy"] = {
    [0x0002D] = 0x00, -- -
    [0x02212] = 0x00, -- -
--  [0x02201] = 0x00, -- complement
--  [0x02206] = 0x00, -- increment
--  [0x02204] = 0x00, -- not exists
--~     [0x000B7] = 0x01, -- cdot
    [0x022C5] = 0x01, -- cdot
    [0x000D7] = 0x02, -- times
    [0x0002A] = 0x03, -- *
    [0x02217] = 0x03, -- *
    [0x000F7] = 0x04, -- div
    [0x022C4] = 0x05, -- diamond
    [0x000B1] = 0x06, -- pm
    [0x02213] = 0x07, -- mp
    [0x02295] = 0x08, -- oplus
    [0x02296] = 0x09, -- ominus
    [0x02297] = 0x0A, -- otimes
    [0x02298] = 0x0B, -- oslash
    [0x02299] = 0x0C, -- odot
    [0x025EF] = 0x0D, -- bigcirc, Orb (either 25EF or 25CB) -- todo
    [0x02218] = 0x0E, -- circ
    [0x02219] = 0x0F, -- bullet
    [0x02022] = 0x0F, -- bullet
    [0x0224D] = 0x10, -- asymp
    [0x02261] = 0x11, -- equiv
    [0x02286] = 0x12, -- subseteq
    [0x02287] = 0x13, -- supseteq
    [0x02264] = 0x14, -- leq
    [0x02265] = 0x15, -- geq
    [0x02AAF] = 0x16, -- preceq
--  [0x0227C] = 0x16, -- preceq, AM:No see 2AAF
    [0x02AB0] = 0x17, -- succeq
--  [0x0227D] = 0x17, -- succeq, AM:No see 2AB0
    [0x0223C] = 0x18, -- sim
    [0x02248] = 0x19, -- approx
    [0x02282] = 0x1A, -- subset
    [0x02283] = 0x1B, -- supset
    [0x0226A] = 0x1C, -- ll
    [0x0226B] = 0x1D, -- gg
    [0x0227A] = 0x1E, -- prec
    [0x0227B] = 0x1F, -- succ
    [0x02190] = 0x20, -- leftarrow
    [0x02192] = 0x21, -- rightarrow
--~ [0xFE190] = 0x20, -- leftarrow
--~ [0xFE192] = 0x21, -- rightarrow
    [0x02191] = 0x22, -- uparrow
    [0x02193] = 0x23, -- downarrow
    [0x02194] = 0x24, -- leftrightarrow
    [0x02197] = 0x25, -- nearrow
    [0x02198] = 0x26, -- searrow
    [0x02243] = 0x27, -- simeq
    [0x021D0] = 0x28, -- Leftarrow
    [0x021D2] = 0x29, -- Rightarrow
    [0x021D1] = 0x2A, -- Uparrow
    [0x021D3] = 0x2B, -- Downarrow
    [0x021D4] = 0x2C, -- Leftrightarrow
    [0x02196] = 0x2D, -- nwarrow
    [0x02199] = 0x2E, -- swarrow
    [0x0221D] = 0x2F, -- propto
    [0x02032] = 0x30, -- prime
    [0x0221E] = 0x31, -- infty
    [0x02208] = 0x32, -- in
    [0x0220B] = 0x33, -- ni
    [0x025B3] = 0x34, -- triangle, bigtriangleup
    [0x025BD] = 0x35, -- bigtriangledown
    [0x00338] = 0x36, -- not
--              0x37, -- (beginning of arrow)
    [0x02200] = 0x38, -- forall
    [0x02203] = 0x39, -- exists
    [0x000AC] = 0x3A, -- neg, lnot
    [0x02205] = 0x3B, -- empty set
    [0x0211C] = 0x3C, -- Re
    [0x02111] = 0x3D, -- Im
    [0x022A4] = 0x3E, -- top
    [0x022A5] = 0x3F, -- bot, perp
    [0x02135] = 0x40, -- aleph
    [0x1D49C] = 0x41, -- script A
    [0x0212C] = 0x42, -- script B
    [0x1D49E] = 0x43, -- script C
    [0x1D49F] = 0x44, -- script D
    [0x02130] = 0x45, -- script E
    [0x02131] = 0x46, -- script F
    [0x1D4A2] = 0x47, -- script G
    [0x0210B] = 0x48, -- script H
    [0x02110] = 0x49, -- script I
    [0x1D4A5] = 0x4A, -- script J
    [0x1D4A6] = 0x4B, -- script K
    [0x02112] = 0x4C, -- script L
    [0x02133] = 0x4D, -- script M
    [0x1D4A9] = 0x4E, -- script N
    [0x1D4AA] = 0x4F, -- script O
    [0x1D4AB] = 0x50, -- script P
    [0x1D4AC] = 0x51, -- script Q
    [0x0211B] = 0x52, -- script R
    [0x1D4AE] = 0x53, -- script S
    [0x1D4AF] = 0x54, -- script T
    [0x1D4B0] = 0x55, -- script U
    [0x1D4B1] = 0x56, -- script V
    [0x1D4B2] = 0x57, -- script W
    [0x1D4B3] = 0x58, -- script X
    [0x1D4B4] = 0x59, -- script Y
    [0x1D4B5] = 0x5A, -- script Z
    [0x0222A] = 0x5B, -- cup
    [0x02229] = 0x5C, -- cap
    [0x0228E] = 0x5D, -- uplus
    [0x02227] = 0x5E, -- wedge, land
    [0x02228] = 0x5F, -- vee, lor
    [0x022A2] = 0x60, -- vdash
    [0x022A3] = 0x61, -- dashv
    [0x0230A] = 0x62, -- lfloor
    [0x0230B] = 0x63, -- rfloor
    [0x02308] = 0x64, -- lceil
    [0x02309] = 0x65, -- rceil
    [0x0007B] = 0x66, -- {, lbrace
    [0x0007D] = 0x67, -- }, rbrace
    [0x027E8] = 0x68, -- <, langle
    [0x027E9] = 0x69, -- >, rangle
    [0x0007C] = 0x6A, -- |, mid, lvert, rvert
    [0x02225] = 0x6B, -- parallel, Vert, lVert, rVert, arrowvert
    [0x02195] = 0x6C, -- updownarrow
    [0x021D5] = 0x6D, -- Updownarrow
    [0x0005C] = 0x6E, -- \, backslash, setminus
    [0x02216] = 0x6E, -- setminus
    [0x02240] = 0x6F, -- wr
    [0x0221A] = 0x70, -- sqrt. AM: Check surd??
    [0x02A3F] = 0x71, -- amalg
    [0x1D6FB] = 0x72, -- nabla
--  [0x0222B] = 0x73, -- smallint (TODO: what about intop?)
    [0x02294] = 0x74, -- sqcup
    [0x02293] = 0x75, -- sqcap
    [0x02291] = 0x76, -- sqsubseteq
    [0x02292] = 0x77, -- sqsupseteq
    [0x000A7] = 0x78, -- S
    [0x02020] = 0x79, -- dagger, dag
    [0x02021] = 0x7A, -- ddagger, ddag
    [0x000B6] = 0x7B, -- P
    [0x02663] = 0x7C, -- clubsuit
    [0x02662] = 0x7D, -- diamondsuit
    [0x02661] = 0x7E, -- heartsuit
    [0x02660] = 0x7F, -- spadesuit
    [0xFE321] = 0x37, -- mapstochar
}

-- The names in masm10.enc can be trusted best and are shown in the first
-- column, while in the second column we show the tex/ams names. As usual
-- it costs hours to figure out such a table.

fonts.enc.math["tex-ma"] = {
    [0x022A1] = 0x00, -- squaredot             \boxdot
    [0x0229E] = 0x01, -- squareplus            \boxplus
    [0x022A0] = 0x02, -- squaremultiply        \boxtimes
    [0x025A1] = 0x03, -- square                \square \Box
    [0x025A0] = 0x04, -- squaresolid           \blacksquare
    [0x000B7] = 0x05, -- squaresmallsolid      \centerdot
    [0x022C4] = 0x06, -- diamond               \Diamond \lozenge
    [0x029EB] = 0x07, -- diamondsolid          \blacklozenge
    [0x021BA] = 0x08, -- clockwise             \circlearrowright
    [0x021BB] = 0x09, -- anticlockwise         \circlearrowleft
    [0x021CC] = 0x0A, -- harpoonleftright      \rightleftharpoons
    [0x021CB] = 0x0B, -- harpoonrightleft      \leftrightharpoons
    [0x0229F] = 0x0C, -- squareminus           \boxminus
    [0x022A9] = 0x0D, -- forces                \Vdash
    [0x022AA] = 0x0E, -- forcesbar             \Vvdash
    [0x022A8] = 0x0F, -- satisfies             \vDash
    [0x021A0] = 0x10, -- dblarrowheadright     \twoheadrightarrow
    [0x0219E] = 0x11, -- dblarrowheadleft      \twoheadleftarrow
    [0x021C7] = 0x12, -- dblarrowleft          \leftleftarrows
    [0x021C9] = 0x13, -- dblarrowright         \rightrightarrows
    [0x021C8] = 0x14, -- dblarrowup            \upuparrows
    [0x021CA] = 0x15, -- dblarrowdwn           \downdownarrows
    [0x021BE] = 0x16, -- harpoonupright        \upharpoonright \restriction
    [0x021C2] = 0x17, -- harpoondownright      \downharpoonright
    [0x021BF] = 0x18, -- harpoonupleft         \upharpoonleft
    [0x021C3] = 0x19, -- harpoondownleft       \downharpoonleft
    [0x021A3] = 0x1A, -- arrowtailright        \rightarrowtail
    [0x021A2] = 0x1B, -- arrowtailleft         \leftarrowtail
    [0x021C6] = 0x1C, -- arrowparrleftright    \leftrightarrows
--  [0x021C5] = 0x00, --                       \updownarrows (missing in lm)
    [0x021C4] = 0x1D, -- arrowparrrightleft    \rightleftarrows
    [0x021B0] = 0x1E, -- shiftleft             \Lsh
    [0x021B1] = 0x1F, -- shiftright            \Rsh
    [0x021DD] = 0x20, -- squiggleright         \leadsto \rightsquigarrow
    [0x021AD] = 0x21, -- squiggleleftright     \leftrightsquigarrow
    [0x021AB] = 0x22, -- curlyleft             \looparrowleft
    [0x021AC] = 0x23, -- curlyright            \looparrowright
    [0x02257] = 0x24, -- circleequal           \circeq
    [0x0227F] = 0x25, -- followsorequal        \succsim
    [0x02273] = 0x26, -- greaterorsimilar      \gtrsim
    [0x02A86] = 0x27, -- greaterorapproxeql    \gtrapprox
    [0x022B8] = 0x28, -- multimap              \multimap
    [0x02234] = 0x29, -- therefore             \therefore
    [0x02235] = 0x2A, -- because               \because
    [0x02251] = 0x2B, -- equalsdots            \Doteq \doteqdot
    [0x0225C] = 0x2C, -- defines               \triangleq
    [0x0227E] = 0x2D, -- precedesorequal       \precsim
    [0x02272] = 0x2E, -- lessorsimilar         \lesssim
    [0x02A85] = 0x2F, -- lessorapproxeql       \lessapprox
    [0x02A95] = 0x30, -- equalorless           \eqslantless
    [0x02A96] = 0x31, -- equalorgreater        \eqslantgtr
    [0x022DE] = 0x32, -- equalorprecedes       \curlyeqprec
    [0x022DF] = 0x33, -- equalorfollows        \curlyeqsucc
    [0x0227C] = 0x34, -- precedesorcurly       \preccurlyeq
    [0x02266] = 0x35, -- lessdblequal          \leqq
    [0x02A7D] = 0x36, -- lessorequalslant      \leqslant
    [0x02276] = 0x37, -- lessorgreater         \lessgtr
    [0x02035] = 0x38, -- primereverse          \backprime
    --  [0x0] = 0x39, -- axisshort             \dabar
    [0x02253] = 0x3A, -- equaldotrightleft     \risingdotseq
    [0x02252] = 0x3B, -- equaldotleftright     \fallingdotseq
    [0x0227D] = 0x3C, -- followsorcurly        \succcurlyeq
    [0x02267] = 0x3D, -- greaterdblequal       \geqq
    [0x02A7E] = 0x3E, -- greaterorequalslant   \geqslant
    [0x02277] = 0x3F, -- greaterorless         \gtrless
    [0x0228F] = 0x40, -- squareimage           \sqsubset
    [0x02290] = 0x41, -- squareoriginal        \sqsupset
    -- wrong:
    [0x022B3] = 0x42, -- triangleright         \rhd \vartriangleright
    [0x022B2] = 0x43, -- triangleleft          \lhd \vartriangleleft
    [0x022B5] = 0x44, -- trianglerightequal    \unrhd \trianglerighteq
    [0x022B4] = 0x45, -- triangleleftequal     \unlhd \trianglelefteq
    --
    [0x02605] = 0x46, -- star                  \bigstar
    [0x0226C] = 0x47, -- between               \between
    [0x025BC] = 0x48, -- triangledownsld       \blacktriangledown
    [0x025B6] = 0x49, -- trianglerightsld      \blacktriangleright
    [0x025C0] = 0x4A, -- triangleleftsld       \blacktriangleleft
    --  [0x0] = 0x4B, -- arrowaxisright
    --  [0x0] = 0x4C, -- arrowaxisleft
    [0x025B2] = 0x4D, -- triangle              \triangleup \vartriangle
    [0x025B2] = 0x4E, -- trianglesolid         \blacktriangle
    [0x025BC] = 0x4F, -- triangleinv           \triangledown
    [0x02256] = 0x50, -- ringinequal           \eqcirc
    [0x022DA] = 0x51, -- lessequalgreater      \lesseqgtr
    [0x022DB] = 0x52, -- greaterlessequal      \gtreqless
    [0x02A8B] = 0x53, -- lessdbleqlgreater     \lesseqqgtr
    [0x02A8C] = 0x54, -- greaterdbleqlless     \gtreqqless
    [0x000A5] = 0x55, -- Yen                   \yen
    [0x021DB] = 0x56, -- arrowtripleright      \Rrightarrow
    [0x021DA] = 0x57, -- arrowtripleleft       \Lleftarrow
    [0x02713] = 0x58, -- check                 \checkmark
    [0x022BB] = 0x59, -- orunderscore          \veebar
    [0x022BC] = 0x5A, -- nand                  \barwedge
    [0x02306] = 0x5B, -- perpcorrespond        \doublebarwedge
    [0x02220] = 0x5C, -- angle                 \angle
    [0x02221] = 0x5D, -- measuredangle         \measuredangle
    [0x02222] = 0x5E, -- sphericalangle        \sphericalangle
    --  [0x0] = 0x5F, -- proportional          \varpropto
    --  [0x0] = 0x60, -- smile                 \smallsmile
    --  [0x0] = 0x61, -- frown                 \smallfrown
    [0x022D0] = 0x62, -- subsetdbl             \Subset
    [0x022D1] = 0x63, -- supersetdbl           \Supset
    [0x022D3] = 0x64, -- uniondbl              \doublecup \Cup
    [0x00100] = 0x65, -- intersectiondbl       \doublecap \Cap
    [0x022CF] = 0x66, -- uprise                \curlywedge
    [0x022CE] = 0x67, -- downfall              \curlyvee
    [0x022CB] = 0x68, -- multiopenleft         \leftthreetimes
    [0x022CC] = 0x69, -- multiopenright        \rightthreetimes
    [0x02AC5] = 0x6A, -- subsetdblequal        \subseteqq
    [0x02AC6] = 0x6B, -- supersetdblequal      \supseteqq
    [0x0224F] = 0x6C, -- difference            \bumpeq
    [0x0224E] = 0x6D, -- geomequivalent        \Bumpeq
    [0x022D8] = 0x6E, -- muchless              \lll \llless
    [0x022D9] = 0x6F, -- muchgreater           \ggg \gggtr
    [0x0231C] = 0x70, -- rightanglenw          \ulcorner
    [0x0231D] = 0x71, -- rightanglene          \urcorner
    [0x024C7] = 0x72, -- circleR               \circledR
    [0x024C8] = 0x73, -- circleS               \circledS
    [0x022D4] = 0x74, -- fork                  \pitchfork
    [0x02245] = 0x75, -- dotplus               \dotplus
    [0x0223D] = 0x76, -- revsimilar            \backsim
    [0x022CD] = 0x77, -- revasymptequal        \backsimeq -- AM: Check this! I mapped it to simeq.
    [0x0231E] = 0x78, -- rightanglesw          \llcorner
    [0x0231F] = 0x79, -- rightanglese          \lrcorner
    [0x02720] = 0x7A, -- maltesecross          \maltese
    [0x02201] = 0x7B, -- complement            \complement
    [0x022BA] = 0x7C, -- intercal              \intercal
    [0x0229A] = 0x7D, -- circlering            \circledcirc
    [0x0229B] = 0x7E, -- circleasterisk        \circledast
    [0x0229D] = 0x7F, -- circleminus           \circleddash
}

fonts.enc.math["tex-mb"] = {
    --  [0x0] = 0x00, -- lessornotequal        \lvertneqq
    --  [0x0] = 0x01, -- greaterornotequal     \gvertneqq
    [0x02270] = 0x02, -- notlessequal          \nleq
    [0x02271] = 0x03, -- notgreaterequal       \ngeq
    [0x0226E] = 0x04, -- notless               \nless
    [0x0226F] = 0x05, -- notgreater            \ngtr
    [0x02280] = 0x06, -- notprecedes           \nprec
    [0x02281] = 0x07, -- notfollows            \nsucc
    [0x02268] = 0x08, -- lessornotdbleql       \lneqq
    [0x02269] = 0x09, -- greaterornotdbleql    \gneqq
    --  [0x0] = 0x0A, -- notlessorslnteql      \nleqslant
    --  [0x0] = 0x0B, -- notgreaterorslnteql   \ngeqslant
    [0x02A87] = 0x0C, -- lessnotequal          \lneq
    [0x02A88] = 0x0D, -- greaternotequal       \gneq
    --  [0x0] = 0x0E, -- notprecedesoreql      \npreceq
    --  [0x0] = 0x0F, -- notfollowsoreql       \nsucceq
    [0x022E8] = 0x10, -- precedeornoteqvlnt    \precnsim
    [0x022E9] = 0x11, -- followornoteqvlnt     \succnsim
    [0x022E6] = 0x12, -- lessornotsimilar      \lnsim
    [0x022E7] = 0x13, -- greaterornotsimilar   \gnsim
    --  [0x0] = 0x14, -- notlessdblequal       \nleqq
    --  [0x0] = 0x15, -- notgreaterdblequal    \ngeqq
    [0x02AB5] = 0x16, -- precedenotslnteql     \precneqq
    [0x02AB6] = 0x17, -- follownotslnteql      \succneqq
    [0x02AB9] = 0x18, -- precedenotdbleqv      \precnapprox
    [0x02ABA] = 0x19, -- follownotdbleqv       \succnapprox
    [0x02A89] = 0x1A, -- lessnotdblequal       \lnapprox
    [0x02A8A] = 0x1B, -- greaternotdblequal    \gnapprox
    [0x02241] = 0x1C, -- notsimilar            \nsim
    [0x02247] = 0x1D, -- notapproxequal        \ncong
    --  [0x0] = 0x1E, -- upslope               \diagup
    --  [0x0] = 0x1F, -- downslope             \diagdown
    --  [0x0] = 0x20, -- notsubsetoreql        \varsubsetneq
    --  [0x0] = 0x21, -- notsupersetoreql      \varsupsetneq
    --  [0x0] = 0x22, -- notsubsetordbleql     \nsubseteqq
    --  [0x0] = 0x23, -- notsupersetordbleql   \nsupseteqq
    [0x02ACB] = 0x24, -- subsetornotdbleql     \subsetneqq
    [0x02ACC] = 0x25, -- supersetornotdbleql   \supsetneqq
    --  [0x0] = 0x26, -- subsetornoteql        \varsubsetneqq
    --  [0x0] = 0x27, -- supersetornoteql      \varsupsetneqq
    [0x0228A] = 0x28, -- subsetnoteql          \subsetneq
    [0x0228B] = 0x29, -- supersetnoteql        \supsetneq
    [0x02288] = 0x2A, -- notsubseteql          \nsubseteq
    [0x02289] = 0x2B, -- notsuperseteql        \nsupseteq
    [0x02226] = 0x2C, -- notparallel           \nparallel
    [0x02224] = 0x2D, -- notbar                \nmid \ndivides
    --  [0x0] = 0x2E, -- notshortbar           \nshortmid
    --  [0x0] = 0x2F, -- notshortparallel      \nshortparallel
    [0x022AC] = 0x30, -- notturnstile          \nvdash
    [0x022AE] = 0x31, -- notforces             \nVdash
    [0x022AD] = 0x32, -- notsatisfies          \nvDash
    [0x022AF] = 0x33, -- notforcesextra        \nVDash
    [0x022ED] = 0x34, -- nottriangeqlright     \ntrianglerighteq
    [0x022EC] = 0x35, -- nottriangeqlleft      \ntrianglelefteq
    [0x022EA] = 0x36, -- nottriangleleft       \ntriangleleft
    [0x022EB] = 0x37, -- nottriangleright      \ntriangleright
    [0x0219A] = 0x38, -- notarrowleft          \nleftarrow
    [0x0219B] = 0x39, -- notarrowright         \nrightarrow
    [0x021CD] = 0x3A, -- notdblarrowleft       \nLeftarrow
    [0x021CF] = 0x3B, -- notdblarrowright      \nRightarrow
    [0x021CE] = 0x3C, -- notdblarrowboth       \nLeftrightarrow
    [0x021AE] = 0x3D, -- notarrowboth          \nleftrightarrow
    [0x022C7] = 0x3E, -- dividemultiply        \divideontimes
    [0x02300] = 0x3F, -- diametersign          \varnothing
    [0x02204] = 0x40, -- notexistential        \nexists
    [0x1D538] = 0x41, -- A                     (blackboard A)
    [0x1D539] = 0x42, -- B
    [0x02102] = 0x43, -- C
    [0x1D53B] = 0x44, -- D
    [0x1D53C] = 0x45, -- E
    [0x1D53D] = 0x46, -- F
    [0x1D53E] = 0x47, -- G
    [0x0210D] = 0x48, -- H
    [0x1D540] = 0x49, -- I
    [0x1D541] = 0x4A, -- J
    [0x1D542] = 0x4B, -- K
    [0x1D543] = 0x4C, -- L
    [0x1D544] = 0x4D, -- M
    [0x02115] = 0x4E, -- N
    [0x1D546] = 0x4F, -- O
    [0x02119] = 0x50, -- P
    [0x0211A] = 0x51, -- Q
    [0x0211D] = 0x52, -- R
    [0x1D54A] = 0x53, -- S
    [0x1D54B] = 0x54, -- T
    [0x1D54C] = 0x55, -- U
    [0x1D54D] = 0x56, -- V
    [0x1D54E] = 0x57, -- W
    [0x1D54F] = 0x58, -- X
    [0x1D550] = 0x59, -- Y
    [0x02124] = 0x5A, -- Z                     (blackboard Z)
    [0x02132] = 0x60, -- hatwide               \Finv
    [0x02141] = 0x61, -- hatwider              \Game
    --  [0x0] = 0x62,    tildewide
    --  [0x0] = 0x63,    tildewider
    --  [0x0] = 0x64,    Finv
    --  [0x0] = 0x65,    Gmir
    [0x02127] = 0x66, -- Omegainv              \mho
    [0x000F0] = 0x67, -- eth                   \eth
    [0x02242] = 0x68, -- equalorsimilar        \eqsim
    [0x02136] = 0x69, -- beth                  \beth
    [0x02137] = 0x6A, -- gimel                 \gimel
    [0x02138] = 0x6B, -- daleth                \daleth
    [0x022D6] = 0x6C, -- lessdot               \lessdot
    [0x022D7] = 0x6D, -- greaterdot            \gtrdot
    [0x022C9] = 0x6E, -- multicloseleft        \ltimes
    [0x022CA] = 0x6F, -- multicloseright       \rtimes
    --  [0x0] = 0x70, -- barshort              \shortmid
    --  [0x0] = 0x71, -- parallelshort         \shortparallel
    --  [0x02216] = 0x72, -- integerdivide         \smallsetminus (2216 already part of tex-sy
    --  [0x0] = 0x73, -- similar               \thicksim
    --  [0x0] = 0x74, -- approxequal           \thickapprox
    [0x0224A] = 0x75, -- approxorequal         \approxeq
    [0x02AB8] = 0x76, -- followsorequal        \succapprox
    [0x02AB7] = 0x77, -- precedesorequal       \precapprox
    [0x021B6] = 0x78, -- archleftdown          \curvearrowleft
    [0x021B7] = 0x79, -- archrightdown         \curvearrowright
    [0x003DC] = 0x7A, -- Digamma               \digamma
    [0x003F0] = 0x7B, -- kappa                 \varkappa
    [0x1D55C] = 0x7C, -- k                     \Bbbk (blackboard k)
    [0x0210F] = 0x7D, -- planckover2pi         \hslash
    [0x00127] = 0x7E, -- planckover2pi1        \hbar
    [0x003F6] = 0x7F, -- epsiloninv            \backepsilon
}

fonts.enc.math["tex-fraktur"] = {
--  [0x1D504] = 0x41, -- A                     (fraktur A)
--  [0x1D505] = 0x42, -- B
    [0x0212D] = 0x43, -- C
--  [0x1D507] = 0x44, -- D
--  [0x1D508] = 0x45, -- E
--  [0x1D509] = 0x46, -- F
--  [0x1D50A] = 0x47, -- G
    [0x0210C] = 0x48, -- H
    [0x02111] = 0x49, -- I
--  [0x1D50D] = 0x4A, -- J
--  [0x1D50E] = 0x4B, -- K
--  [0x1D50F] = 0x4C, -- L
--  [0x1D510] = 0x4D, -- M
--  [0x1D511] = 0x4E, -- N
--  [0x1D512] = 0x4F, -- O
--  [0x1D513] = 0x50, -- P
--  [0x1D514] = 0x51, -- Q
    [0x0211C] = 0x52, -- R
--  [0x1D516] = 0x53, -- S
--  [0x1D517] = 0x54, -- T
--  [0x1D518] = 0x55, -- U
--  [0x1D519] = 0x56, -- V
--  [0x1D51A] = 0x57, -- W
--  [0x1D51B] = 0x58, -- X
--  [0x1D51C] = 0x59, -- Y
    [0x02128] = 0x5A, -- Z                     (fraktur Z)
--  [0x1D51E] = 0x61, -- a                     (fraktur a)
--  [0x1D51F] = 0x62, -- b
--  [0x1D520] = 0x63, -- c
--  [0x1D521] = 0x64, -- d
--  [0x1D522] = 0x65, -- e
--  [0x1D523] = 0x66, -- f
--  [0x1D524] = 0x67, -- g
--  [0x1D525] = 0x68, -- h
--  [0x1D526] = 0x69, -- i
--  [0x1D527] = 0x6A, -- j
--  [0x1D528] = 0x6B, -- k
--  [0x1D529] = 0x6C, -- l
--  [0x1D52A] = 0x6D, -- m
--  [0x1D52B] = 0x6E, -- n
--  [0x1D52C] = 0x6F, -- o
--  [0x1D52D] = 0x70, -- p
--  [0x1D52E] = 0x71, -- q
--  [0x1D52F] = 0x72, -- r
--  [0x1D530] = 0x73, -- s
--  [0x1D531] = 0x74, -- t
--  [0x1D532] = 0x75, -- u
--  [0x1D533] = 0x76, -- v
--  [0x1D534] = 0x77, -- w
--  [0x1D535] = 0x78, -- x
--  [0x1D536] = 0x79, -- y
--  [0x1D537] = 0x7A, -- z
}

-- now that all other vectors are defined ...

fonts.vf.math.set_letters(fonts.enc.math, "tex-it", 0x1D434, 0x1D44E)
fonts.vf.math.set_letters(fonts.enc.math, "tex-ss", 0x1D5A0, 0x1D5BA)
fonts.vf.math.set_letters(fonts.enc.math, "tex-tt", 0x1D670, 0x1D68A)
fonts.vf.math.set_letters(fonts.enc.math, "tex-bf", 0x1D400, 0x1D41A)
fonts.vf.math.set_letters(fonts.enc.math, "tex-bi", 0x1D468, 0x1D482)
fonts.vf.math.set_letters(fonts.enc.math, "tex-fraktur", 0x1D504, 0x1D51E)
fonts.vf.math.set_letters(fonts.enc.math, "tex-fraktur-bold", 0x1D56C, 0x1D586)

fonts.vf.math.set_digits (fonts.enc.math, "tex-ss", 0x1D7E2)
fonts.vf.math.set_digits (fonts.enc.math, "tex-tt", 0x1D7F6)
fonts.vf.math.set_digits (fonts.enc.math, "tex-bf", 0x1D7CE)

-- fonts.vf.math.set_digits (fonts.enc.math, "tex-bi", 0x1D7CE)

-- todo: add ss, tt, bf etc vectors
-- we can make ss tt etc an option

-- rm-lmr5  : LMMathRoman5-Regular
-- rm-lmbx5 : LMMathRoman5-Bold          ]
-- lmbsy5   : LMMathSymbols5-BoldItalic
-- lmsy5    : LMMathSymbols5-Italic
-- lmmi5    : LMMathItalic5-Italic
-- lmmib5   : LMMathItalic5-BoldItalic

mathematics.make_font ( "lmroman5-math", {
    { name = "lmroman5-regular.otf", features = "virtualmath", main = true },
    { name = "rm-lmr5.tfm", vector = "tex-mr-missing" } ,
    { name = "lmmi5.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "lmmi5.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "lmsy5.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "lmex10.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam5.tfm", vector = "tex-ma" },
    { name = "msbm5.tfm", vector = "tex-mb" },
 -- { name = "rm-lmbx5.tfm", vector = "tex-bf" } ,
    { name = "lmroman5-bold", vector = "tex-bf" } ,
    { name = "lmmib5.tfm", vector = "tex-bi", skewchar=0x7F } ,
    { name = "lmsans8-regular.otf", vector = "tex-ss", optional=true },
    { name = "lmmono8-regular.otf", vector = "tex-tt", optional=true },
    { name = "eufm5.tfm", vector = "tex-fraktur", optional=true },
} )

-- rm-lmr6  : LMMathRoman6-Regular
-- rm-lmbx6 : LMMathRoman6-Bold
-- lmsy6    : LMMathSymbols6-Italic
-- lmmi6    : LMMathItalic6-Italic

mathematics.make_font ( "lmroman6-math", {
    { name = "lmroman6-regular.otf", features = "virtualmath", main = true },
    { name = "rm-lmr6.tfm", vector = "tex-mr-missing" } ,
    { name = "lmmi6.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "lmmi6.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "lmsy6.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "lmex10.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam5.tfm", vector = "tex-ma" },
    { name = "msbm5.tfm", vector = "tex-mb" },
 -- { name = "rm-lmbx6.tfm", vector = "tex-bf" } ,
    { name = "lmroman6-bold.otf", vector = "tex-bf" } ,
    { name = "lmmib5.tfm", vector = "tex-bi", skewchar=0x7F } ,
    { name = "lmsans8-regular.otf", vector = "tex-ss", optional=true },
    { name = "lmmono8-regular.otf", vector = "tex-tt", optional=true },
    { name = "eufm5.tfm", vector = "tex-fraktur", optional=true },
    { name = "eufb5.tfm", vector = "tex-fraktur-bold", optional=true },
} )

-- rm-lmr7  : LMMathRoman7-Regular
-- rm-lmbx7 : LMMathRoman7-Bold
-- lmbsy7   : LMMathSymbols7-BoldItalic
-- lmsy7    : LMMathSymbols7-Italic
-- lmmi7    : LMMathItalic7-Italic
-- lmmib7   : LMMathItalic7-BoldItalic

mathematics.make_font ( "lmroman7-math", {
    { name = "lmroman7-regular.otf", features = "virtualmath", main = true },
    { name = "rm-lmr7.tfm", vector = "tex-mr-missing" } ,
    { name = "lmmi7.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "lmmi7.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "lmsy7.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "lmex10.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam7.tfm", vector = "tex-ma" },
    { name = "msbm7.tfm", vector = "tex-mb" },
 -- { name = "rm-lmbx7.tfm", vector = "tex-bf" } ,
    { name = "lmroman7-bold.otf", vector = "tex-bf" } ,
    { name = "lmmib7.tfm", vector = "tex-bi", skewchar=0x7F } ,
    { name = "lmsans8-regular.otf", vector = "tex-ss", optional=true },
    { name = "lmmono8-regular.otf", vector = "tex-tt", optional=true },
    { name = "eufm7.tfm", vector = "tex-fraktur", optional=true },
    { name = "eufb7.tfm", vector = "tex-fraktur-bold", optional=true },
} )

-- rm-lmr8  : LMMathRoman8-Regular
-- rm-lmbx8 : LMMathRoman8-Bold
-- lmsy8    : LMMathSymbols8-Italic
-- lmmi8    : LMMathItalic8-Italic

mathematics.make_font ( "lmroman8-math", {
    { name = "lmroman8-regular.otf", features = "virtualmath", main = true },
    { name = "rm-lmr8.tfm", vector = "tex-mr-missing" } ,
    { name = "lmmi8.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "lmmi8.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "lmsy8.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "lmex10.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam7.tfm", vector = "tex-ma" },
    { name = "msbm7.tfm", vector = "tex-mb" },
 -- { name = "rm-lmbx8.tfm", vector = "tex-bf" } ,
    { name = "lmroman8-bold.otf", vector = "tex-bf" } ,
    { name = "lmmib7.tfm", vector = "tex-bi", skewchar=0x7F } ,
    { name = "lmsans8-regular.otf", vector = "tex-ss", optional=true },
    { name = "lmmono8-regular.otf", vector = "tex-tt", optional=true },
    { name = "eufm7.tfm", vector = "tex-fraktur", optional=true },
    { name = "eufb7.tfm", vector = "tex-fraktur-bold", optional=true },
} )

-- rm-lmr9  : LMMathRoman9-Regular
-- rm-lmbx9 : LMMathRoman9-Bold
-- lmsy9    : LMMathSymbols9-Italic
-- lmmi9    : LMMathItalic9-Italic

mathematics.make_font ( "lmroman9-math", {
    { name = "lmroman9-regular.otf", features = "virtualmath", main = true },
    { name = "rm-lmr9.tfm", vector = "tex-mr-missing" } ,
    { name = "lmmi9.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "lmmi9.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "lmsy9.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "lmex10.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
 -- { name = "rm-lmbx9.tfm", vector = "tex-bf" } ,
    { name = "lmroman9-bold.otf", vector = "tex-bf" } ,
    { name = "lmmib10.tfm", vector = "tex-bi", skewchar=0x7F } ,
    { name = "lmsans9-regular.otf", vector = "tex-ss", optional=true },
    { name = "lmmono9-regular.otf", vector = "tex-tt", optional=true },
    { name = "eufm10.tfm", vector = "tex-fraktur", optional=true },
    { name = "eufb10.tfm", vector = "tex-fraktur-bold", optional=true },
} )

-- rm-lmr10  : LMMathRoman10-Regular
-- rm-lmbx10 : LMMathRoman10-Bold
-- lmbsy10   : LMMathSymbols10-BoldItalic
-- lmsy10    : LMMathSymbols10-Italic
-- lmex10    : LMMathExtension10-Regular
-- lmmi10    : LMMathItalic10-Italic
-- lmmib10   : LMMathItalic10-BoldItalic

mathematics.make_font ( "lmroman10-math", {
    { name = "lmroman10-regular.otf", features = "virtualmath", main = true },
    { name = "rm-lmr10.tfm", vector = "tex-mr-missing" } ,
    { name = "lmmi10.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "lmmi10.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "lmsy10.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "lmex10.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
 -- { name = "rm-lmbx10.tfm", vector = "tex-bf" } ,
    { name = "lmroman10-bold.otf", vector = "tex-bf" } ,
    { name = "lmmib10.tfm", vector = "tex-bi", skewchar=0x7F } ,
    { name = "lmsans10-regular.otf", vector = "tex-ss", optional=true },
    { name = "lmmono10-regular.otf", vector = "tex-tt", optional=true },
    { name = "eufm10.tfm", vector = "tex-fraktur", optional=true },
    { name = "eufb10.tfm", vector = "tex-fraktur-bold", optional=true },
} )

mathematics.make_font ( "lmroman10-boldmath", {
    { name = "lmroman10-bold.otf", features = "virtualmath", main = true },
    { name = "rm-lmr10.tfm", vector = "tex-mr-missing" } ,
    { name = "lmmib10.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "lmmib10.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "lmbsy10.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "lmex10.tfm", vector = "tex-ex", extension = true } ,
-- copied from roman:
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
 -- { name = "rm-lmbx10.tfm", vector = "tex-bf" } ,
    { name = "lmroman10-bold.otf", vector = "tex-bf" } ,
    { name = "lmmib10.tfm", vector = "tex-bi", skewchar=0x7F } ,
    { name = "lmsans10-regular.otf", vector = "tex-ss", optional=true },
    { name = "lmmono10-regular.otf", vector = "tex-tt", optional=true },
    { name = "eufm10.tfm", vector = "tex-fraktur", optional=true },
    { name = "eufb10.tfm", vector = "tex-fraktur-bold", optional=true },
} )

-- rm-lmr12  : LMMathRoman12-Regular
-- rm-lmbx12 : LMMathRoman12-Bold
-- lmmi12    : LMMathItalic12-Italic

mathematics.make_font ( "lmroman12-math", {
    { name = "lmroman12-regular.otf", features = "virtualmath", main = true },
    { name = "rm-lmr12.tfm", vector = "tex-mr-missing" } ,
    { name = "lmmi12.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "lmmi12.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "lmsy10.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "lmex10.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
 -- { name = "rm-lmbx12.tfm", vector = "tex-bf" } ,
    { name = "lmroman12-bold.otf", vector = "tex-bf" } ,
    { name = "lmmib10.tfm", vector = "tex-bi", skewchar=0x7F } ,
    { name = "lmsans12-regular.otf", vector = "tex-ss", optional=true },
    { name = "lmmono12-regular.otf", vector = "tex-tt", optional=true },
    { name = "eufm10.tfm", vector = "tex-fraktur", optional=true },
    { name = "eufb10.tfm", vector = "tex-fraktur-bold", optional=true },
} )

-- rm-lmr17 : LMMathRoman17-Regular

mathematics.make_font ( "lmroman17-math", {
    { name = "lmroman17-regular.otf", features = "virtualmath", main = true },
    { name = "rm-lmr12.tfm", vector = "tex-mr-missing" } ,
    { name = "lmmi12.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "lmmi12.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "lmsy10.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "lmex10.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
 -- { name = "rm-lmbx12.tfm", vector = "tex-bf" } ,
    { name = "lmroman12-bold.otf", vector = "tex-bf" } ,
    { name = "lmmib10.tfm", vector = "tex-bi", skewchar=0x7F } ,
    { name = "lmsans17-regular.otf", vector = "tex-ss", optional=true },
    { name = "lmmono17-regular.otf", vector = "tex-tt", optional=true },
    { name = "eufm10.tfm", vector = "tex-fraktur", optional=true },
    { name = "eufb10.tfm", vector = "tex-fraktur-bold", optional=true },
} )

-- pxr/txr messes up the accents

mathematics.make_font ( "px-math", {
    { name = "texgyrepagella-regular.otf", features = "virtualmath", main = true },
    { name = "rpxr.tfm", vector = "tex-mr" } ,
    { name = "rpxmi.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "rpxpplri.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "pxsy.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "pxex.tfm", vector = "tex-ex", extension = true } ,
    { name = "pxsya.tfm", vector = "tex-ma" },
    { name = "pxsyb.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "tx-math", {
    { name = "texgyretermes-regular.otf", features = "virtualmath", main = true },
    { name = "rtxr.tfm", vector = "tex-mr" } ,
    { name = "rtxptmri.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "rtxmi.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "txsy.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "txex.tfm", vector = "tex-ex", extension = true } ,
    { name = "txsya.tfm", vector = "tex-ma" },
    { name = "txsyb.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "antykwa-math", {
    { name = "file:AntykwaTorunska-Regular", features = "virtualmath", main = true },
    { name = "mi-anttri.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "mi-anttri.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "sy-anttrz.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "ex-anttr.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "antykwa-light-math", {
    { name = "file:AntykwaTorunskaLight-Regular", features = "virtualmath", main = true },
    { name = "mi-anttli.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "mi-anttli.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "sy-anttlz.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "ex-anttl.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "antykwa-cond-math", {
    { name = "file:AntykwaTorunskaCond-Regular", features = "virtualmath", main = true },
    { name = "mi-anttcri.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "mi-anttcri.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "sy-anttcrz.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "ex-anttcr.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "antykwa-lightcond-math", {
    { name = "file:AntykwaTorunskaCondLight-Regular", features = "virtualmath", main = true },
    { name = "mi-anttcli.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "mi-anttcli.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "sy-anttclz.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "ex-anttcl.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "iwona-math", {
    { name = "file:Iwona-Regular", features = "virtualmath", main = true },
    { name = "mi-iwonari.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "mi-iwonari.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "sy-iwonarz.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "ex-iwonar.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "iwona-light-math", {
    { name = "file:IwonaLight-Regular", features = "virtualmath", main = true },
    { name = "mi-iwonali.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "mi-iwonali.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "sy-iwonalz.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "ex-iwonal.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "iwona-medium-math", {
    { name = "file:IwonaMedium-Regular", features = "virtualmath", main = true },
    { name = "mi-iwonami.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "mi-iwonami.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "sy-iwonamz.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "ex-iwonam.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "iwona-heavy-math", {
    { name = "file:IwonaHeavy-Regular", features = "virtualmath", main = true },
    { name = "mi-iwonahi.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "mi-iwonahi.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "sy-iwonahz.tfm", vector = "tex-sy", skewchar=0x30, parameters = true } ,
    { name = "ex-iwonah.tfm", vector = "tex-ex", extension = true } ,
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

-- not ok, we need adapted vectors !

mathematics.make_font ( "mathtimes-math", {
    { name = "file:texgyretermes-regular.otf", features = "virtualmath", main = true },
    { name = "mtmiz.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "mtmiz.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "mtsyn.tfm", vector = "tex-sy", skewchar=0x30, parameters = true },
    { name = "mtex.tfm", vector = "tex-ex", extension = true },
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "charter-math", {
    { name = "file:bchr8a", features = "virtualmath", main = true },
 -- { name = "md-chr7m.tfm", vector = "tex-mr" },
    { name = "md-chri7m.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "md-chri7m.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "md-chr7y.tfm", vector = "tex-sy", skewchar=0x30, parameters = true },
    { name = "md-chr7v.tfm", vector = "tex-ex", extension = true },
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "garamond-math", {
    { name = "file:ugmr8y", features = "virtualmath", main = true },
 -- { name = "md-gmr7m.tfm", vector = "tex-mr" },
    { name = "md-gmri7m.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "md-gmri7m.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "md-gmr7y.tfm", vector = "tex-sy", skewchar=0x30, parameters = true },
    { name = "md-gmr7v.tfm", vector = "tex-ex", extension = true },
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "utopia-math", {
    { name = "file:putr8y", features = "virtualmath", main = true },
 -- { name = "md-utr7m.tfm", vector = "tex-mr" },
    { name = "md-utri7m.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "md-utri7m.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "md-utr7y.tfm", vector = "tex-sy", skewchar=0x30, parameters = true },
    { name = "md-utr7v.tfm", vector = "tex-ex", extension = true },
    { name = "msam10.tfm", vector = "tex-ma" },
    { name = "msbm10.tfm", vector = "tex-mb" },
} )

mathematics.make_font ( "hvmath-math", {
    { name = "file:texgyreheros-regular.otf", features = "virtualmath", main = true },
    { name = "hvrm108r.tfm", vector="tex-mr" },
    { name = "hvmi10.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "hvmi10.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "hvsy10.tfm", vector = "tex-sy", skewchar=0x30, parameters = true },
    { name = "hvex10.tfm", vector = "tex-ex", extension = true },
    { name = "hvam10.tfm", vector = "tex-ma" },
    { name = "hvbm10.tfm", vector = "tex-mb" },
} )

-- the lucida mess

--~ fonts.enc.math["lbr-ma"] = {
--~     [0x000A5] = 0x03, -- yen
--~     [0x000B7] = 0xE1, -- centerdot
--~     [0x000F0] = 0x03, -- eth
--~     [0x00127] = 0x1B, -- hbar
--~     [0x003DC] = 0x03, -- digamma
--~     [0x003F6] = 0x03, -- backepsilon
--~     [0x0219A] = 0x32, -- nleftarrow
--~     [0x0219B] = 0x33, -- nrightarrow
--~     [0x0219E] = 0x23, -- twoheadleftarrow
--~     [0x021A0] = 0x25, -- twoheadrightarrow
--~     [0x021A2] = 0x28, -- leftarrowtail
--~     [0x021A3] = 0x29, -- rightarrowtail
--~     [0x021A6] = 0x2C, -- mapsto
--~     [0x021A9] = 0x3C, -- hookleftarrow
--~     [0x021AA] = 0x3E, -- hookrightarrow
--~     [0x021AB] = 0x3F, -- looparrowleft
--~     [0x021AC] = 0x40, -- looparrowright
--~     [0x021AD] = 0x91, -- leftrightsquigarrow
--~     [0x021AE] = 0x34, -- nleftrightarrow
--~     [0x021B0] = 0x7B, -- Lsh
--~     [0x021B1] = 0x7D, -- Rsh
--~     [0x021B6] = 0x87, -- curvearrowleft
--~     [0x021B7] = 0x88, -- curvearrowright
--~     [0x021BA] = 0x8C, -- circlearrowright
--~     [0x021BB] = 0x8B, -- circlearrowleft
--~     [0x021BF] = 0x76, -- upharpoonleft
--~     [0x021C2] = 0x77, -- downharpoonright
--~     [0x021C3] = 0x78, -- downharpoonleft
--~     [0x021C4] = 0x6D, -- rightleftarrows
--~     [0x021C6] = 0x6E, -- leftrightarrows
--~     [0x021C7] = 0x71, -- leftleftarrows
--~     [0x021C8] = 0x72, -- upuparrows
--~     [0x021C9] = 0x73, -- rightrightarrows
--~     [0x021CA] = 0x74, -- downdownarrows
--~     [0x021CB] = 0x79, -- leftrightharpoons
--~     [0x021CC] = 0x7A, -- rightleftharpoons
--~     [0x021CD] = 0x66, -- nLeftarrow
--~     [0x021CE] = 0x67, -- nLeftrightarrow
--~     [0x021CF] = 0x68, -- nRightarrow
--~     [0x021DA] = 0x6A, -- Lleftarrow
--~     [0x021DB] = 0x6C, -- Rrightarrow
--~     [0x021E0] = 0x38, -- dashleftarrow
--~     [0x02204] = 0x20, -- nexists
--~     [0x02226] = 0xF7, -- nparallel
--~     [0x02241] = 0x96, -- nsim
--~     [0x02268] = 0xDC, -- lneqq
--~     [0x02269] = 0xDE, -- gneqq
--~     [0x0226E] = 0x9A, -- nless
--~     [0x0226F] = 0x9B, -- ngtr
--~     [0x02270] = 0x9C, -- nleq
--~     [0x02271] = 0x9D, -- ngeq
--~     [0x02280] = 0xE5, -- nprec
--~     [0x02281] = 0xE6, -- nsucc
--~     [0x02288] = 0xC8, -- nsubseteq
--~     [0x02289] = 0xC9, -- nsupseteq
--~     [0x0228A] = 0xCC, -- subsetneq
--~     [0x0228B] = 0xCD, -- supsetneq
--~     [0x022AC] = 0xF8, -- nvdash
--~     [0x022AD] = 0xFA, -- nvDash
--~     [0x022AE] = 0xF9, -- nVdash
--~     [0x022AF] = 0xFB, -- nVDash
--~     [0x022BA] = 0x03, -- intercal
--~     [0x022D4] = 0xF3, -- pitchfork
--~     [0x022E6] = 0xE0, -- lnsim
--~     [0x022E7] = 0xE2, -- gnsim
--~     [0x022E8] = 0xEB, -- precnsim
--~     [0x022E9] = 0xEC, -- succnsim
--~     [0x022EA] = 0xF0, -- ntriangleright
--~     [0x022EB] = 0xEF, -- ntriangleleft
--~     [0x022EC] = 0xF1, -- ntrianglelefteq
--~     [0x022ED] = 0xF2, -- ntrianglerighteq
--~     [0x0231C] = 0x5B, -- ulcorner
--~     [0x0231D] = 0x5C, -- urcorner
--~     [0x0231E] = 0x5D, -- llcorner
--~     [0x0231F] = 0x5E, -- lrcorner
--~     [0x025A2] = 0x03, -- blacksquare
--~     [0x02605] = 0xAB, -- bigstar
--~     [0x02713] = 0xAC, -- checkmark
--~     [0x029EB] = 0x09, -- blacklozenge
--~     [0x02A87] = 0xDA, -- lneq
--~     [0x02A89] = 0xE4, -- lnapprox
--~     [0x02A8A] = 0xE3, -- gnapprox
--~     [0x02AB5] = 0xE9, -- precneqq
--~     [0x02AB6] = 0xEA, -- succneqq
--~     [0x02AB9] = 0xED, -- precnapprox
--~     [0x02ABA] = 0xEE, -- succnapprox
--~     [0x02ACB] = 0xCE, -- subsetneqq
--~     [0x02ACC] = 0xCF, -- supsetneqq
--~ }

fonts.enc.math["lbr-ma"] = {
    [0x025CB] = 0x00, -- circle
    [0x025CF] = 0x01, -- blackcircle
    [0x025A1] = 0x02, -- square
    [0x025A0] = 0x03, -- blacksquare
    [0x025B3] = 0x04, -- triangleup
    [0x025B2] = 0x05, -- blacktriangleup
    [0x025BD] = 0x06, -- triangledown
    [0x025BC] = 0x07, -- blacktriangledown
    [0x02B28] = 0x08, -- lozenge
    [0x02B27] = 0x09, -- blacklozenge
    [0x02B29] = 0x0A, -- blackdiamond
    [0x02571] = 0x0B, -- upright
    [0x02572] = 0x0C, -- downright
    [0x022E4] = 0x0D, -- squareimageofnoteq
    [0x022E5] = 0x0E, -- squareoriginalofnoteq
    [0x02A4F] = 0x0F, -- dblsquareunion
    [0x02A4E] = 0x10, -- dblsquareintersection
    [0x02A64] = 0x11, -- zdomainantirestriction
    [0x02A65] = 0x12, -- zrangeantirestriction
    [0x022EE] = 0x13, -- verticalellipsis
    [0x022EF] = 0x14, -- ellipsis
    [0x022F0] = 0x15, -- uprightellipsis
    [0x022F1] = 0x16, -- downrightellipsis
    [0x022D5] = 0x17, -- equalparallel

    [0x0225B] = 0x1A, -- stareq
    [0x00127] = 0x1B, -- hbar
    [0x022F6] = 0x1C, -- barelementof
    [0x02209] = 0x1D, -- notelementof
    [0x022FD] = 0x1E, -- barcontains
    [0x0220C] = 0x1F, -- notcontain
    [0x02204] = 0x20, -- nexists
    [0x02194] = 0x21, -- leftrightarrow
    [0x02195] = 0x22, -- updownarrow
    [0x0219E] = 0x23, -- leftleftarrow
    [0x0219F] = 0x24, -- upuparrow
    [0x021A0] = 0x25, -- rightrightarrow
--  [0x00026] = 0x26, -- amperand
    [0x021A1] = 0x27, -- downdownarrow
    [0x021A2] = 0x28, -- leftarrowtail
    [0x021A3] = 0x29, -- rightarrowtail
    [0x021A4] = 0x2A, -- leftarrowbar
    [0x021A6] = 0x2B, -- rightarrowbar
    [0x021A5] = 0x2C, -- uparrowbar
--  [0x02212] = 0x2D, -- minus
--  [0x0002D] = 0x2D, -- minus
    [0x021A7] = 0x2E, -- downarrowbar
    [0x021E4] = 0x2F, -- barleftarrow
    [0x021E5] = 0x30, -- barrightarrow

    [0x021E0] = 0x38, -- dashleftarrow
    [0x021E1] = 0x39, -- dashuparrow
    [0x021E2] = 0x3A, -- dashrightarrow
    [0x021E3] = 0x3B, -- dashdownarrow
    [0x021A9] = 0x3C, -- hookleftarrow
--  [0x0003D] = 0x3D, -- equalto
    [0x021AA] = 0x3E, -- hookrightarrow
    [0x021AB] = 0x3F, -- looparrowleft
    [0x021AC] = 0x40, -- looparrowright
    [0x1D538] = 0x41, -- A                     (blackboard A)
    [0x1D539] = 0x42, -- B
    [0x02102] = 0x43, -- C
    [0x1D53B] = 0x44, -- D
    [0x1D53C] = 0x45, -- E
    [0x1D53D] = 0x46, -- F
    [0x1D53E] = 0x47, -- G
    [0x0210D] = 0x48, -- H
    [0x1D540] = 0x49, -- I
    [0x1D541] = 0x4A, -- J
    [0x1D542] = 0x4B, -- K
    [0x1D543] = 0x4C, -- L
    [0x1D544] = 0x4D, -- M
    [0x02115] = 0x4E, -- N
    [0x1D546] = 0x4F, -- O
    [0x02119] = 0x50, -- P
    [0x0211A] = 0x51, -- Q
    [0x0211D] = 0x52, -- R
    [0x1D54A] = 0x53, -- S
    [0x1D54B] = 0x54, -- T
    [0x1D54C] = 0x55, -- U
    [0x1D54D] = 0x56, -- V
    [0x1D54E] = 0x57, -- W
    [0x1D54F] = 0x58, -- X
    [0x1D550] = 0x59, -- Y
    [0x02124] = 0x5A, -- Z                     (blackboard Z)
    [0x0231C] = 0x5B, -- ulcorner
    [0x0231D] = 0x5C, -- urcorner
    [0x0231E] = 0x5D, -- llcorner
    [0x0231F] = 0x5E, -- lrcorner
    [0x02225] = 0x5F, -- parallel, Vert, lVert, rVert, arrowvert
    [0x021D5] = 0x60, -- Updownarrow
    [0x021D4] = 0x61, -- Leftrightarrow
    [0x021D6] = 0x62, -- Upleftarrow
    [0x021D7] = 0x63, -- Uprightarrow
    [0x021D9] = 0x64, -- Downleftarrow
    [0x021D8] = 0x65, -- Downrightarrow
    [0x021CD] = 0x66, -- nLeftarrow
    [0x021CE] = 0x67, -- nLeftrightarrow
    [0x021CF] = 0x68, -- nRightarrow
--  [0x021CE] = 0x69, -- nLeftrightarrow -- what's the difference between this and 0x0067[0x021CE]
    [0x021DA] = 0x6A, -- Lleftarrow
    [0x1D55C] = 0x6B, -- k                     \Bbbk (blackboard k)
    [0x021DB] = 0x6C, -- Rrightarrow
    [0x021C4] = 0x6D, -- rlarrow
    [0x021C6] = 0x6E, -- lrarrow
    [0x021C5] = 0x6F, -- udarrow
--  [0x021C5] = 0x70, -- duarrow
    [0x021C7] = 0x71, -- llarrow
    [0x021C8] = 0x72, -- uuarrow
    [0x021C9] = 0x73, -- rrarrow
    [0x021CA] = 0x74, -- ddarrow
    [0x021BE] = 0x75, -- rupharpoon
    [0x021BF] = 0x76, -- lupharpoon
    [0x021C2] = 0x77, -- rdownharpoon
    [0x021C3] = 0x78, -- ldownharpoon
    [0x021CB] = 0x79, -- lrharpoon
    [0x021CC] = 0x7A, -- rlharpoon
    [0x021B0] = 0x7B, -- upthenleftarrow
--  [0x00000] = 0x7C, -- part
    [0x021B1] = 0x7D, -- upthenrightarrow
--  [0x00000] = 0x7E, -- part
    [0x02276] = 0x7F, -- ltgt
    [0x021B2] = 0x81, -- downthenleftarrow
    [0x021B3] = 0x82, -- downthenrightarrow
    [0x02B0E] = 0x83, -- rightthendownarrow
    [0x02B10] = 0x84, -- leftthendownarrow
    [0x02B0F] = 0x85, -- rightthenuparrow
    [0x02B11] = 0x86, -- leftthenuparrow
    [0x021B6] = 0x87, -- leftarcarrow
    [0x021B7] = 0x88, -- rightarcarrow
    [0x0293D] = 0x89, -- leftarcarrowplus
    [0x0293C] = 0x8A, -- rightarcarrowminus
    [0x021BA] = 0x8B, -- anticlockwise
    [0x021BB] = 0x8C, -- clockwise

    [0x02260] = 0x94, -- noteq
    [0x02262] = 0x95, -- notidentical
    [0x02241] = 0x96, -- nottilde
    [0x02244] = 0x97, -- notasymptoticallyequal
    [0x02249] = 0x98, -- notalmostequal
    [0x02247] = 0x99, -- notapproximatelyeq
    [0x0226E] = 0x9A, -- nless
    [0x0226F] = 0x9B, -- ngtr
    [0x02270] = 0x9C, -- nleq
    [0x02271] = 0x9D, -- ngeq
    [0x022E6] = 0x9E, -- lnsim
    [0x022E7] = 0x9F, -- gnsim
    [0x02605] = 0xAB, -- black star
    [0x02713] = 0xAC, -- check
    [0x02277] = 0xC5, -- gtlt
    [0x02284] = 0xC6, -- nsubsetof
    [0x02285] = 0xC7, -- nsupsetof
    [0x02288] = 0xC8, -- nsubseteq
    [0x02289] = 0xC9, -- nsupseteq

    [0x0228A] = 0xCC, -- subsetneq
    [0x0228B] = 0xCD, -- supsetneq

--  [0x0228A] = 0xD0, -- subsetneq
--  [0x0228B] = 0xD1, -- supsetneq

    [0x02270] = 0xD6, -- nleq
    [0x02271] = 0xD7, -- ngeq

    [0x02268] = 0xDC, -- lneqq
    [0x02269] = 0xDD, -- gneqq

    [0x022E6] = 0xE0, -- lnsim
    [0x02219] = 0xE1, -- bullet
    [0x022E7] = 0xE2, -- gnsim

    [0x02280] = 0xE5, -- nprec
    [0x02281] = 0xE6, -- nsucc

    [0x022E8] = 0xEB, -- precnsim
    [0x022E9] = 0xEC, -- succnsim

    [0x022EA] = 0xEF, -- nnormalsub
    [0x022EB] = 0xF0, -- ncontainnormalsub
    [0x022EC] = 0xF1, -- nnormalsubeq
    [0x022ED] = 0xF2, -- ncontainnormalsubeq

    [0x02226] = 0xF7, -- nparallel
    [0x022AC] = 0xF8, -- nvdash
    [0x022AE] = 0xF9, -- nVdash
    [0x022AD] = 0xFA, -- nvDash
    [0x022AF] = 0xFB, -- nVDash
}

fonts.enc.math["lbr-mb"] = {
    [0x00393] = 0x00, -- Gamma
    [0x00394] = 0x01, -- Delta
    [0x00398] = 0x02, -- Theta
    [0x0039B] = 0x03, -- Lambda
    [0x0039E] = 0x04, -- Xi
    [0x003A0] = 0x05, -- Pi
    [0x003A3] = 0x06, -- Sigma
    [0x003A5] = 0x07, -- Upsilon
    [0x003A6] = 0x08, -- Phi
    [0x003A8] = 0x09, -- Psi
    [0x003A9] = 0x0A, -- Omega
    [0x0210F] = 0x9D, -- hslash
    [0x02127] = 0x92, -- mho
    [0x02132] = 0x90, -- Finv
    [0x02136] = 0x95, -- beth
    [0x02137] = 0x96, -- gimel
    [0x02138] = 0x97, -- daleth
    [0x02141] = 0x91, -- Game
    [0x02201] = 0x94, -- complement
    [0x0226C] = 0xF2, -- between
    [0x0227C] = 0xE4, -- preccurlyeq
    [0x0227D] = 0xE5, -- succcurlyeq
    [0x0229D] = 0xCC, -- circleddash
    [0x022A8] = 0xD6, -- vDash
    [0x022AA] = 0xD3, -- Vvdash
    [0x022B8] = 0xC7, -- multimap
    [0x022BB] = 0xD2, -- veebar
    [0x022C7] = 0xF7, -- divideontimes
    [0x022C9] = 0xCF, -- ltimes
    [0x022CA] = 0xCE, -- rtimes
    [0x022CB] = 0xD0, -- leftthreetimes
    [0x022CC] = 0xD1, -- rightthreetimes
    [0x022D6] = 0xDC, -- lessdot
    [0x022D7] = 0xDD, -- gtrdot
    [0x022DA] = 0xE8, -- lesseqgtr
    [0x022DB] = 0xE9, -- gtreqless
    [0x022DE] = 0xE6, -- curlyeqprec
    [0x022DF] = 0xE7, -- curlyeqsucc
    [0x024C7] = 0xC9, -- circledR
    [0x024C8] = 0xCA, -- circledS
    [0x025B6] = 0xF1, -- blacktriangleright
    [0x025B8] = 0xF0, -- blacktriangleleft
    [0x02720] = 0xCB, -- maltese
    [0x02A7D] = 0xE0, -- leqslant
    [0x02A7E] = 0xE1, -- geqslant
    [0x02A85] = 0xDA, -- lessapprox
    [0x02A86] = 0xDB, -- gtrapprox
    [0x02A8B] = 0xEA, -- lesseqqgtr
    [0x02A8C] = 0xEB, -- gtreqqless
    [0x02A95] = 0xE2, -- eqslantless
    [0x02A96] = 0xE3, -- eqslantgtr
    [0x02AB7] = 0xEC, -- precapprox
    [0x02AB8] = 0xED, -- succapprox
    [0x02AC5] = 0xEE, -- subseteqq
    [0x02AC6] = 0xEF, -- supseteqq
    [0x12035] = 0xC8, -- backprime
    [0x1D718] = 0x9B, -- varkappa
}

--~ fonts.enc.math["lbr-mi"] = {
--~     ["0x00127"] = 0x9D, -- hbar
--~     ["0x003D1"] = 0x02, -- varTheta
--~     ["0x020D7"] = 0x7E, -- vec
--~ }

fonts.enc.math["lbr-sy"] = {
    [0x021CB] = 0x8D, -- leftrightharpoons
    [0x021CC] = 0x8E, -- rightleftharpoons
    [0x02214] = 0x89, -- dotplus
    [0x02220] = 0x8B, -- angle
    [0x02221] = 0x8C, -- measuredangle
    [0x02222] = 0x8D, -- sphericalangle
    [0x02234] = 0x90, -- therefore
    [0x02235] = 0x91, -- because
    [0x0223D] = 0x24, -- backsim
    [0x02242] = 0x99, -- eqsim
    [0x0224A] = 0x9D, -- approxeq
    [0x0224E] = 0xC7, -- Bumpeq
    [0x02252] = 0xCB, -- fallingdotseq
    [0x02253] = 0xCC, -- risingdotseq
    [0x02256] = 0xCF, -- eqcirc
    [0x02257] = 0xD0, -- circeq
    [0x0225C] = 0xD5, -- triangleq
    [0x02266] = 0xDA, -- leqq
    [0x02267] = 0xDB, -- geqq
    [0x02272] = 0xDC, -- lesssim
    [0x02273] = 0xDD, -- gtrsim
    [0x02276] = 0xDE, -- lessgtr
    [0x02277] = 0xDF, -- gtrless
    [0x0227E] = 0xE0, -- precsim
    [0x0227F] = 0xE1, -- succsim
    [0x0228F] = 0xE4, -- sqsubset
    [0x02290] = 0xE5, -- sqsupset
    [0x0229A] = 0xE6, -- circledcirc
    [0x0229B] = 0xE7, -- circledast
    [0x0229E] = 0xEA, -- boxplus
    [0x0229F] = 0xEB, -- boxminus
    [0x022A0] = 0xEC, -- boxtimes
    [0x022A1] = 0xED, -- boxdot
    [0x022A7] = 0xEE, -- models
    [0x022A9] = 0xF0, -- Vdash
    [0x022BC] = 0xF6, -- barwedge
    [0x022CE] = 0x85, -- curlyvee
    [0x022CF] = 0x84, -- curlywedge
    [0x022D0] = 0xF8, -- Subset
    [0x022D1] = 0xF9, -- Supset
    [0x02300] = 0x53, -- varnothing
    [0x025CA] = 0x05, -- lozenge
}

fonts.enc.math["lbr-sy"] = table.merged(fonts.enc.math["tex-sy"],fonts.enc.math["lbr-sy"])

--~ fonts.enc.math["lbr-rm"] = {
--~     [0x00060] = 0x12, -- grave
--~     [0x000A8] = 0x7F, -- ddot
--~     [0x000AF] = 0x16, -- bar
--~     [0x000B4] = 0x13, -- acute
--~     [0x002C6] = 0x5E, -- hat
--~     [0x002C7] = 0x14, -- check
--~     [0x002D8] = 0x15, -- breve
--~     [0x002D9] = 0x05, -- dot
--~     [0x002DC] = 0x7E, -- tilde
--~ }

mathematics.make_font ( "lucida-math", {
    { name = "file:lbr.afm", features = "virtualmath", main = true },
    { name = "hlcrim.tfm", vector = "tex-mi", skewchar=0x7F },
    { name = "hlcrim.tfm", vector = "tex-it", skewchar=0x7F },
    { name = "hlcry.tfm", vector = "lbr-sy", skewchar=0x30, parameters = true },
    { name = "hlcrv.tfm", vector = "tex-ex", extension = true },
    { name = "hlcra.tfm", vector = "lbr-ma" },
    { name = "hlcrm.tfm", vector = "lbr-mb" },
} )
