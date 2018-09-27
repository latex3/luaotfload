if not modules then modules = { } end modules ['luatex-fonts-nod'] = {
    version   = 1.001,
    comment   = "companion to luatex-fonts.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if context then
    os.exit()
end

-- Don't depend on code here as it is only needed to complement the font handler
-- code. I will move some to another namespace as I don't see other macro packages
-- use the context logic. It's a subset anyway.

-- Attributes:

if tex.attribute[0] ~= 0 then

    texio.write_nl("log","!")
    texio.write_nl("log","! Attribute 0 is reserved for ConTeXt's font feature management and has to be")
    texio.write_nl("log","! set to zero. Also, some attributes in the range 1-255 are used for special")
    texio.write_nl("log","! purposes so setting them at the TeX end might break the font handler.")
    texio.write_nl("log","!")

    tex.attribute[0] = 0 -- else no features

end

attributes            = attributes or { }
attributes.unsetvalue = -0x7FFFFFFF

local numbers, last = { }, 127

attributes.private = attributes.private or function(name)
    local number = numbers[name]
    if not number then
        if last < 255 then
            last = last + 1
        end
        number = last
        numbers[name] = number
    end
    return number
end

-- Nodes (a subset of context so that we don't get too much unused code):

nodes              = { }
nodes.handlers     = { }

local nodecodes    = { }
local glyphcodes   = node.subtypes("glyph")
local disccodes    = node.subtypes("disc")

for k, v in next, node.types() do
    v = string.gsub(v,"_","")
    nodecodes[k] = v
    nodecodes[v] = k
end
for k, v in next, glyphcodes do
    glyphcodes[v] = k
end
for k, v in next, glyphcodes do
    disccodes[v] = k
end

nodes.nodecodes    = nodecodes
nodes.glyphcodes   = glyphcodes
nodes.disccodes    = disccodes

local flush_node   = node.flush_node
local remove_node  = node.remove
local traverse_id  = node.traverse_id

nodes.handlers.protectglyphs   = node.protect_glyphs   -- beware: nodes!
nodes.handlers.unprotectglyphs = node.unprotect_glyphs -- beware: nodes!

local math_code   = nodecodes.math
local end_of_math = node.end_of_math

function node.end_of_math(n)
    if n.id == math_code and n.subtype == 1 then
        return n
    else
        return end_of_math(n)
    end
end

function nodes.remove(head, current, free_too)
   local t = current
   head, current = remove_node(head,current)
   if t then
        if free_too then
            flush_node(t)
            t = nil
        else
            t.next, t.prev = nil, nil
        end
   end
   return head, current, t
end

function nodes.delete(head,current)
    return nodes.remove(head,current,true)
end

local getfield = node.getfield
local setfield = node.setfield

nodes.getfield = getfield
nodes.setfield = setfield

nodes.getattr  = getfield
nodes.setattr  = setfield

-- being lazy ... just copy a bunch ... not all needed in generic but we assume
-- nodes to be kind of private anyway

nodes.tostring             = node.tostring or tostring
nodes.copy                 = node.copy
nodes.copy_node            = node.copy
nodes.copy_list            = node.copy_list
nodes.delete               = node.delete
nodes.dimensions           = node.dimensions
nodes.end_of_math          = node.end_of_math
nodes.flush_list           = node.flush_list
nodes.flush_node           = node.flush_node
nodes.flush                = node.flush_node
nodes.free                 = node.free
nodes.insert_after         = node.insert_after
nodes.insert_before        = node.insert_before
nodes.hpack                = node.hpack
nodes.new                  = node.new
nodes.tail                 = node.tail
nodes.traverse             = node.traverse
nodes.traverse_id          = node.traverse_id
nodes.slide                = node.slide
nodes.vpack                = node.vpack

nodes.first_glyph          = node.first_glyph
nodes.has_glyph            = node.has_glyph or node.first_glyph

nodes.current_attr         = node.current_attr
nodes.has_field            = node.has_field
nodes.last_node            = node.last_node
nodes.usedlist             = node.usedlist
nodes.protrusion_skippable = node.protrusion_skippable
nodes.write                = node.write

nodes.has_attribute        = node.has_attribute
nodes.set_attribute        = node.set_attribute
nodes.unset_attribute      = node.unset_attribute

nodes.protect_glyphs       = node.protect_glyphs
nodes.unprotect_glyphs     = node.unprotect_glyphs
-----.kerning              = node.kerning
-----.ligaturing           = node.ligaturing
nodes.mlist_to_hlist       = node.mlist_to_hlist

-- in generic code, at least for some time, we stay nodes, while in context
-- we can go nuts (e.g. experimental); this split permits us us keep code
-- used elsewhere stable but at the same time play around in context

-- much of this will go away

local direct             = node.direct
local nuts               = { }
nodes.nuts               = nuts

local tonode             = direct.tonode
local tonut              = direct.todirect

nodes.tonode             = tonode
nodes.tonut              = tonut

nuts.tonode              = tonode
nuts.tonut               = tonut

local getfield           = direct.getfield
local setfield           = direct.setfield

nuts.getfield            = getfield
nuts.setfield            = setfield
nuts.getnext             = direct.getnext
nuts.setnext             = direct.setnext
nuts.getprev             = direct.getprev
nuts.setprev             = direct.setprev
nuts.getboth             = direct.getboth
nuts.setboth             = direct.setboth
nuts.getid               = direct.getid
nuts.getattr             = direct.get_attribute or direct.has_attribute or getfield
nuts.setattr             = setfield
nuts.getfont             = direct.getfont
nuts.setfont             = direct.setfont
nuts.getsubtype          = direct.getsubtype
nuts.setsubtype          = direct.setsubtype
nuts.getchar             = direct.getchar
nuts.setchar             = direct.setchar
nuts.getdisc             = direct.getdisc
nuts.setdisc             = direct.setdisc
nuts.setlink             = direct.setlink
nuts.setsplit            = direct.setsplit
nuts.getlist             = direct.getlist
nuts.setlist             = direct.setlist

nuts.getoffsets          = direct.getoffsets or
    function(n)
        return getfield(n,"xoffset"), getfield(n,"yoffset")
    end
nuts.setoffsets          = direct.setoffsets or
    function(n,x,y)
        if x then setfield(n,"xoffset",x) end
        if y then setfield(n,"xoffset",y) end
    end

nuts.getleader     = direct.getleader     or function(n)   return getfield(n,"leader")       end
nuts.setleader     = direct.setleader     or function(n,l)        setfield(n,"leader",l)     end
nuts.getcomponents = direct.getcomponents or function(n)   return getfield(n,"components")   end
nuts.setcomponents = direct.setcomponents or function(n,c)        setfield(n,"components",c) end
nuts.getkern       = direct.getkern       or function(n)   return getfield(n,"kern")         end
nuts.setkern       = direct.setkern       or function(n,k)        setfield(n,"kern",k)       end
nuts.getdir        = direct.getdir        or function(n)   return getfield(n,"dir")          end
nuts.setdir        = direct.setdir        or function(n,d)        setfield(n,"dir",d)        end
nuts.getwidth      = direct.getwidth      or function(n)   return getfield(n,"width")        end
nuts.setwidth      = direct.setwidth      or function(n,w) return setfield(n,"width",w)      end
nuts.getheight     = direct.getheight     or function(n)   return getfield(n,"height")       end
nuts.setheight     = direct.setheight     or function(n,h) return setfield(n,"height",h)     end
nuts.getdepth      = direct.getdepth      or function(n)   return getfield(n,"depth")        end
nuts.setdepth      = direct.setdepth      or function(n,d) return setfield(n,"depth",d)      end

if not direct.is_glyph then
    local getchar    = direct.getchar
    local getid      = direct.getid
    local getfont    = direct.getfont
    local glyph_code = nodes.nodecodes.glyph
    function direct.is_glyph(n,f)
        local id   = getid(n)
        if id == glyph_code then
            if f and getfont(n) == f then
                return getchar(n)
            else
                return false
            end
        else
            return nil, id
        end
    end
    function direct.is_char(n,f)
        local id = getid(n)
        if id == glyph_code then
            if getsubtype(n) >= 256 then
                return false
            elseif f and getfont(n) == f then
                return getchar(n)
            else
                return false
            end
        else
            return nil, id
        end
    end
end

nuts.ischar              = direct.is_char
nuts.is_char             = direct.is_char
nuts.isglyph             = direct.is_glyph
nuts.is_glyph            = direct.is_glyph

nuts.insert_before       = direct.insert_before
nuts.insert_after        = direct.insert_after
nuts.delete              = direct.delete
nuts.copy                = direct.copy
nuts.copy_node           = direct.copy
nuts.copy_list           = direct.copy_list
nuts.tail                = direct.tail
nuts.flush_list          = direct.flush_list
nuts.flush_node          = direct.flush_node
nuts.flush               = direct.flush
nuts.free                = direct.free
nuts.remove              = direct.remove
nuts.is_node             = direct.is_node
nuts.end_of_math         = direct.end_of_math
nuts.traverse            = direct.traverse
nuts.traverse_id         = direct.traverse_id
nuts.traverse_char       = direct.traverse_char
nuts.traverse_glyph      = direct.traverse_glyph
nuts.ligaturing          = direct.ligaturing
nuts.kerning             = direct.kerning
nuts.new                 = direct.new

nuts.getprop             = nuts.getattr
nuts.setprop             = nuts.setattr

-- properties as used in the (new) injector:

local propertydata = direct.get_properties_table()
nodes.properties   = { data = propertydata }

direct.set_properties_mode(true,true)     -- needed for injection

function direct.set_properties_mode() end -- we really need the set modes

nuts.getprop = function(n,k)
    local p = propertydata[n]
    if p then
        return p[k]
    end
end

nuts.setprop = function(n,k,v)
    if v then
        local p = propertydata[n]
        if p then
            p[k] = v
        else
            propertydata[n] = { [k] = v }
        end
    end
end

nodes.setprop = nodes.setproperty
nodes.getprop = nodes.getproperty

-- a few helpers (we need to keep 'm in sync with context) .. some day components
-- might go so here we isolate them

local setprev       = nuts.setprev
local setnext       = nuts.setnext
local getnext       = nuts.getnext
local setlink       = nuts.setlink
local getfield      = nuts.getfield
local setfield      = nuts.setfield
local getcomponents = nuts.getcomponents
local setcomponents = nuts.setcomponents

local find_tail     = nuts.tail
local flush_list    = nuts.flush_list
local flush_node    = nuts.flush_node
local traverse_id   = nuts.traverse_id
local copy_node     = nuts.copy_node

local glyph_code    = nodes.nodecodes.glyph

function nuts.set_components(target,start,stop)
    local head = getcomponents(target)
    if head then
        flush_list(head)
        head = nil
    end
    if start then
        setprev(start)
    else
        return nil
    end
    if stop then
        setnext(stop)
    end
    local tail = nil
    while start do
        local c = getcomponents(start)
        local n = getnext(start)
        if c then
            if head then
                setlink(tail,c)
            else
                head = c
            end
            tail = find_tail(c)
            setcomponents(start)
            flush_node(start)
        else
            if head then
                setlink(tail,start)
            else
                head = start
            end
            tail = start
        end
        start = n
    end
    setcomponents(target,head)
    -- maybe also upgrade the subtype but we don't use it anyway
    return head
end

nuts.get_components = nuts.getcomponents

function nuts.take_components(target)
    local c = getcomponents(target)
    setcomponents(target)
    -- maybe also upgrade the subtype but we don't use it anyway
    return c
end

function nuts.count_components(n,marks)
    local components = getcomponents(n)
    if components then
        if marks then
            local i = 0
            for g in traverse_id(glyph_code,components) do
                if not marks[getchar(g)] then
                    i = i + 1
                end
            end
            return i
        else
            return count(glyph_code,components)
        end
    else
        return 0
    end
end

function nuts.copy_no_components(g,copyinjection)
    local components = getcomponents(g)
    if components then
        setcomponents(g)
        local n = copy_node(g)
        if copyinjection then
            copyinjection(n,g)
        end
        setcomponents(g,components)
        -- maybe also upgrade the subtype but we don't use it anyway
        return n
    else
        local n = copy_node(g)
        if copyinjection then
            copyinjection(n,g)
        end
        return n
    end
end

function nuts.copy_only_glyphs(current)
    local head     = nil
    local previous = nil
    for n in traverse_id(glyph_code,current) do
        n = copy_node(n)
        if head then
            setlink(previous,n)
        else
            head = n
        end
        previous = n
    end
    return head
end

nuts.uses_font = direct.uses_font

if not nuts.uses_font then
    local getdisc = nuts.getdisc
    local getfont = nuts.getfont
    function nuts.uses_font(n,font)
        local pre, post, replace = getdisc(n)
        if pre then
            -- traverse_char
            for n in traverse_id(glyph_code,pre) do
                if getfont(n) == font then
                    return true
                end
            end
        end
        if post then
            for n in traverse_id(glyph_code,post) do
                if getfont(n) == font then
                    return true
                end
            end
        end
        if replace then
            for n in traverse_id(glyph_code,replace) do
                if getfont(n) == font then
                    return true
                end
            end
        end
        return false
    end
end

--
do

    -- another poor mans substitute ... i will move these to a more protected
    -- namespace .. experimental hack

    local dummy = tonut(node.new("glyph"))

    nuts.traversers = {
        glyph    = nuts.traverse_id(nodecodes.glyph,dummy),
        glue     = nuts.traverse_id(nodecodes.glue,dummy),
        disc     = nuts.traverse_id(nodecodes.disc,dummy),
        boundary = nuts.traverse_id(nodecodes.boundary,dummy),

        char     = nuts.traverse_char(dummy),

        node     = nuts.traverse(dummy),
    }

end
