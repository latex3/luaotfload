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

-- Nodes:

nodes              = { }
nodes.pool         = { }
nodes.handlers     = { }

local nodecodes    = { } for k,v in next, node.types   () do nodecodes[string.gsub(v,"_","")] = k end
local whatcodes    = { } for k,v in next, node.whatsits() do whatcodes[string.gsub(v,"_","")] = k end
local glyphcodes   = { [0] = "character", "glyph", "ligature", "ghost", "left", "right" }
local disccodes    = { [0] = "discretionary", "explicit", "automatic", "regular", "first", "second" }

nodes.nodecodes    = nodecodes
nodes.whatcodes    = whatcodes
nodes.whatsitcodes = whatcodes
nodes.glyphcodes   = glyphcodes
nodes.disccodes    = disccodes

local free_node    = node.free
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
            free_node(t)
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

-- experimental

local getfield = node.getfield or function(n,tag)       return n[tag]  end
local setfield = node.setfield or function(n,tag,value) n[tag] = value end

nodes.getfield = getfield
nodes.setfield = setfield

nodes.getattr  = getfield
nodes.setattr  = setfield

if node.getid      then nodes.getid      = node.getid      else function nodes.getid     (n) return getfield(n,"id")      end end
if node.getsubtype then nodes.getsubtype = node.getsubtype else function nodes.getsubtype(n) return getfield(n,"subtype") end end
if node.getnext    then nodes.getnext    = node.getnext    else function nodes.getnext   (n) return getfield(n,"next")    end end
if node.getprev    then nodes.getprev    = node.getprev    else function nodes.getprev   (n) return getfield(n,"prev")    end end
if node.getchar    then nodes.getchar    = node.getchar    else function nodes.getchar   (n) return getfield(n,"char")    end end
if node.getfont    then nodes.getfont    = node.getfont    else function nodes.getfont   (n) return getfield(n,"font")    end end
if node.getlist    then nodes.getlist    = node.getlist    else function nodes.getlist   (n) return getfield(n,"list")    end end

function nodes.tonut (n) return n end
function nodes.tonode(n) return n end

-- being lazy ... just copy a bunch ... not all needed in generic but we assume
-- nodes to be kind of private anyway

nodes.tostring             = node.tostring or tostring
nodes.copy                 = node.copy
nodes.copy_list            = node.copy_list
nodes.delete               = node.delete
nodes.dimensions           = node.dimensions
nodes.end_of_math          = node.end_of_math
nodes.flush_list           = node.flush_list
nodes.flush_node           = node.flush_node
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
nodes.first_character      = node.first_character
nodes.has_glyph            = node.has_glyph or node.first_glyph

nodes.current_attr         = node.current_attr
nodes.do_ligature_n        = node.do_ligature_n
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
nodes.kerning              = node.kerning
nodes.ligaturing           = node.ligaturing
nodes.mlist_to_hlist       = node.mlist_to_hlist

-- in generic code, at least for some time, we stay nodes, while in context
-- we can go nuts (e.g. experimental); this split permits us us keep code
-- used elsewhere stable but at the same time play around in context

nodes.nuts = nodes
