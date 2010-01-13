if not modules then modules = { } end modules ['font-msc'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (miscellaneous)",
    author    = "Khaled Hosny",
    copyright = "Khaled Hosny",
    license   = "GPL"
}

--[[
 Support for font slanting and extending.
--]]

fonts.triggers            = fonts.triggers            or { }
fonts.initializers        = fonts.initializers        or { }
fonts.initializers.common = fonts.initializers.common or { }

local initializers, format = fonts.initializers, string.format

table.insert(fonts.triggers,"slant")

function fonts.initializers.common.slant(tfmdata,value)
    value = tonumber(value)
    if not value then
        value =  0
    elseif value >  1 then
        value =  1
    elseif value < -1 then
        value = -1
    end
    tfmdata.slant_factor = value
end

initializers.base.otf.slant = initializers.common.slant
initializers.node.otf.slant = initializers.common.slant

table.insert(fonts.triggers,"extend")

function initializers.common.extend(tfmdata,value)
    value = tonumber(value)
    if not value then
        value =  0
    elseif value >  10 then
        value =  10
    elseif value < -10 then
        value = -10
    end
    tfmdata.extend_factor = value
end

initializers.base.otf.extend = initializers.common.extend
initializers.node.otf.extend = initializers.common.extend

--[[
  Support for font color.
--]]

table.insert(fonts.triggers,"color")

function initializers.common.color(tfmdata,value)
    if value then
        tfmdata.color = value
    end
end

initializers.base.otf.color = initializers.common.color
initializers.node.otf.color = initializers.common.color

local function hex2dec(hex,one)
    if one then
        return format("%.1g", tonumber(hex, 16)/255)
    else
        return format("%.3g", tonumber(hex, 16)/255)
    end
end

local res

local function pageresources(a)
    local res2
    if not res then
       res = "/TransGs1<</ca 1/CA 1>>"
    end
    res2 = format("/TransGs%s<</ca %s/CA %s>>", a, a, a)
    res  = format("%s%s", res, res:find(res2) and "" or res2)
end

local function hex_to_rgba(hex)
    local r, g, b, a, push, pop, res3
    if hex then
        if #hex == 6 then
            _, _, r, g, b    = hex:find('(..)(..)(..)')
        elseif #hex == 8 then
            _, _, r, g, b, a = hex:find('(..)(..)(..)(..)')
            a                = hex2dec(a,true)
            pageresources(a)
        end
    else
        return nil
    end
    r = hex2dec(r)
    g = hex2dec(g)
    b = hex2dec(b)
    if a then
        push = format('/TransGs%g gs %s %s %s rg', a, r, g, b)
        pop  = '0 g /TransGs1 gs'
    else
        push = format('%s %s %s rg', r, g, b)
        pop  = '0 g'
    end
    return push, pop
end

local glyph   = node.id('glyph')
local hlist   = node.id('hlist')
local vlist   = node.id('vlist')
local whatsit = node.id('whatsit')

local function colorize(head)
   for n in node.traverse(head) do
       if n.id == hlist or n.id == vlist then
           colorize(n.list)
       end
       if n.id == glyph then
           local tfmdata = fonts.ids[n.font]
           if tfmdata and tfmdata.color then
               local prev = n.prev
               local next = n.next
               local pushcolor, popcolor = hex_to_rgba(tfmdata.color)
               if prev.id == glyph and fonts.ids[prev.font].color == tfmdata.color then
               else
                   local push = node.new(whatsit, 8)
                   push.mode  = 1
                   push.data  = pushcolor
                   head       = node.insert_before(head, n, push)
               end
               if next.id == glyph and fonts.ids[next.font].color == tfmdata.color then
               else
                   local pop  = node.new(whatsit, 8)
                   pop.mode   = 1
                   pop.data   = popcolor
                   head       = node.insert_after(head, n, pop)
               end
           end
       end
   end
   return head
end

local function finalize(head)
    if res then
        tex.pdfpageresources = format("%s\n/ExtGState<<%s>>", tex.pdfpageresources, res)
    end
    return head
end

callback.add("hpack_filter",         colorize, "luaotfload.colorize")
callback.add("pre_linebreak_filter", colorize, "luaotfload.colorize")
callback.add("pre_output_filter",    finalize, "loaotfload.finalize")

