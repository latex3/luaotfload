if not modules then modules = { } end modules ['luatex-fonts-nod'] = {
    version   = 1.001,
    comment   = "companion to luatex-fonts.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if context then
    texio.write_nl("fatal error: this module is not for context")
    os.exit()
end

-- Don't depend on code here as it is only needed to complement the
-- font handler code.

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
nodes.pool         = { }
nodes.handlers     = { }

local nodecodes    = { }
local glyphcodes   = node.subtypes("glyph")
local disccodes    = node.subtypes("disc")

for k, v in next, node.types() do
    v = string.gsub(v,"_","")
    nodecodes[k] = v
    nodecodes[v] = k
end
for i=0,#glyphcodes do
    glyphcodes[glyphcodes[i]] = i
end
for i=0,#disccodes do
    disccodes[disccodes[i]] = i
end

nodes.nodecodes    = nodecodes
nodes.glyphcodes   = glyphcodes
nodes.disccodes    = disccodes

local flush_node   = node.flush_node
local remove_node  = node.remove
local new_node     = node.new
local traverse_id  = node.traverse_id

nodes.handlers.protectglyphs   = node.protect_glyphs
nodes.handlers.unprotectglyphs = node.unprotect_glyphs

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

function nodes.pool.kern(k)
    local n = new_node("kern",1)
    n.kern = k
    return n
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
nuts.setsubtype          = direct.setsubtype or function(n,s) setfield(n,"subtype",s) end
nuts.getchar             = direct.getchar
nuts.setchar             = direct.setchar
nuts.getdisc             = direct.getdisc
nuts.setdisc             = direct.setdisc
nuts.setlink             = direct.setlink
nuts.getlist             = direct.getlist
nuts.setlist             = direct.setlist    or function(n,l) setfield(n,"list",l) end
nuts.getleader           = direct.getleader
nuts.setleader           = direct.setleader  or function(n,l) setfield(n,"leader",l) end

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
nuts.ligaturing          = direct.ligaturing
nuts.kerning             = direct.kerning

nuts.getprop             = nuts.getattr
nuts.setprop             = nuts.setattr

local new_nut            = direct.new
nuts.new                 = new_nut
nuts.pool                = { }

function nuts.pool.kern(k)
    local n = new_nut("kern",1)
    setfield(n,"kern",k)
    return n
end

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
