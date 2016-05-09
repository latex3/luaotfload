if not modules then modules = { } end modules ['font-gbn'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- generic [base|node] mode handler

if context then
    texio.write_nl("fatal error: this module is not for context")
    os.exit()
end

local fonts = fonts
local nodes = nodes

local nuts        = nodes.nuts -- context abstraction of direct nodes

local traverse_id = nuts.traverse_id
local remove_node = nuts.remove
local free_node   = nuts.free

local glyph_code  = nodes.nodecodes.glyph
local disc_code   = nodes.nodecodes.disc

local tonode      = nuts.tonode
local tonut       = nuts.tonut

local getfont     = nuts.getfont
local getchar     = nuts.getchar
local getid       = nuts.getid
local getboth     = nuts.getboth
local getprev     = nuts.getprev
local getnext     = nuts.getnext
local getdisc     = nuts.getdisc
local setchar     = nuts.setchar
local setlink     = nuts.setlink
local setprev     = nuts.setprev

-- from now on we apply ligaturing and kerning here because it might interfere with complex
-- opentype discretionary handling where the base ligature pass expect some weird extra
-- pointers (which then confuse the tail slider that has some checking built in)

local n_ligaturing = node.ligaturing
local n_kerning    = node.kerning

local ligaturing   = nuts.ligaturing
local kerning      = nuts.kerning

local basemodepass = true

local function l_warning() texio.write_nl("warning: node.ligaturing called directly") l_warning = nil end
local function k_warning() texio.write_nl("warning: node.kerning called directly")    k_warning = nil end

function node.ligaturing(...)
    if basemodepass and l_warning then
        l_warning()
    end
    return n_ligaturing(...)
end

function node.kerning(...)
    if basemodepass and k_warning then
        k_warning()
    end
    return n_kerning(...)
end

function nodes.handlers.setbasemodepass(v)
    basemodepass = v
end

function nodes.handlers.nodepass(head)
    local fontdata = fonts.hashes.identifiers
    if fontdata then
        local nuthead   = tonut(head)
        local usedfonts = { }
        local basefonts = { }
        local prevfont  = nil
        local basefont  = nil
        local variants  = nil
        local redundant = nil
        for n in traverse_id(glyph_code,nuthead) do
            local font = getfont(n)
            if font ~= prevfont then
                if basefont then
                    basefont[2] = getprev(n)
                end
                prevfont = font
                local used = usedfonts[font]
                if not used then
                    local tfmdata = fontdata[font] --
                    if tfmdata then
                        local shared = tfmdata.shared -- we need to check shared, only when same features
                        if shared then
                            local processors = shared.processes
                            if processors and #processors > 0 then
                                usedfonts[font] = processors
                            elseif basemodepass then
                                basefont = { n, nil }
                                basefonts[#basefonts+1] = basefont
                            end
                        end
                        local resources = tfmdata.resources
                        variants = resources and resources.variants
                        variants = variants and next(variants) and variants or false
                    end
                else
                    local tfmdata = fontdata[prevfont]
                    if tfmdata then
                        local resources = tfmdata.resources
                        variants = resources and resources.variants
                        variants = variants and next(variants) and variants or false
                    end
                end
            end
            if variants then
                local char = getchar(n)
                if char >= 0xFE00 and (char <= 0xFE0F or (char >= 0xE0100 and char <= 0xE01EF)) then
                    local hash = variants[char]
                    if hash then
                        local p = getprev(n)
                        if p and getid(p) == glyph_code then
                            local variant = hash[getchar(p)]
                            if variant then
                                setchar(p,variant)
                            end
                        end
                    end
                    -- per generic user request we always remove selectors
                    if not redundant then
                        redundant = { n }
                    else
                        redundant[#redundant+1] = n
                    end
                end
            end
        end
        local nofbasefonts = #basefonts
        if redundant then
            for i=1,#redundant do
                local r = redundant[i]
                local p, n = getboth(r)
                if r == nuthead then
                    nuthead = n
                    setprev(n)
                else
                    setlink(p,n)
                end
                if nofbasefonts > 0 then
                    for i=1,nofbasefonts do
                        local bi = basefonts[i]
                        if r == bi[1] then
                            bi[1] = n
                        end
                        if r == bi[2] then
                            bi[2] = n
                        end
                    end
                end
                free_node(r)
            end
        end
        for d in traverse_id(disc_code,nuthead) do
            local _, _, r = getdisc(d)
            if r then
                for n in traverse_id(glyph_code,r) do
                    local font = getfont(n)
                    if font ~= prevfont then
                        prevfont = font
                        local used = usedfonts[font]
                        if not used then
                            local tfmdata = fontdata[font] --
                            if tfmdata then
                                local shared = tfmdata.shared -- we need to check shared, only when same features
                                if shared then
                                    local processors = shared.processes
                                    if processors and #processors > 0 then
                                        usedfonts[font] = processors
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if next(usedfonts) then
            for font, processors in next, usedfonts do
                for i=1,#processors do
                    head = processors[i](head,font,0) or head
                end
            end
        end
        if basemodepass and nofbasefonts > 0 then
            for i=1,nofbasefonts do
                local range = basefonts[i]
                local start = range[1]
                local stop  = range[2]
                if start then
                    local front = nuthead == start
                    local prev, next
                    if stop then
                        next = getnext(stop)
                        start, stop = ligaturing(start,stop)
                        start, stop = kerning(start,stop)
                    else
                        prev  = getprev(start)
                        start = ligaturing(start)
                        start = kerning(start)
                    end
                    if prev then
                        setlink(prev,start)
                    end
                    if next then
                        setlink(stop,next)
                    end
                    if front and nuthead ~= start then
                        head = tonode(start)
                    end
                end
            end
        end
        return head, true
    else
        return head, false
    end
end

function nodes.handlers.basepass(head)
    if not basemodepass then
        head = n_ligaturing(head)
        head = n_kerning(head)
    end
    return head, true
end

local nodepass    = nodes.handlers.nodepass
local basepass    = nodes.handlers.basepass
local injectpass  = nodes.injections.handler
local protectpass = nodes.handlers.protectglyphs

function nodes.simple_font_handler(head)
    if head then
        head = nodepass(head)
        head = injectpass(head)
        if not basemodepass then
            head = basepass(head)
        end
        protectpass(head)
        return head, true
    else
        return head, false
    end
end
