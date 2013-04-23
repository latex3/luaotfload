if not modules then modules = { } end modules ['luaotfload-colors'] = {
    version   = 1.001,
    comment   = "companion to luaotfload.lua (font color)",
    author    = "Khaled Hosny and Elie Roux",
    copyright = "Luaotfload Development Team",
    license   = "GPL"
}

local newnode            = node.new
local nodetype           = node.id
local traverse_nodes     = node.traverse
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after

local stringformat = string.format
local stringgsub   = string.gsub
local stringfind   = string.find

local otffeatures        = fonts.constructors.newfeatures("otf")
local ids                = fonts.hashes.identifiers
local registerotffeature = otffeatures.register

local function setcolor(tfmdata,value)
    local sanitized
    local properties = tfmdata.properties

    if value then
        value = tostring(value)
        if #value == 6 or #value == 8 then
            sanitized = value
        elseif #value == 7 then
            _, _, sanitized = stringfind(value, "(......)")
        elseif #value > 8 then
            _, _, sanitized = stringfind(value, "(........)")
        else
            -- broken color code ignored, issue a warning?
        end
    end

    if sanitized then
        tfmdata.properties.color = sanitized
        add_color_callback()
    end
end

registerotffeature {
    name        = "color",
    description = "color",
    initializers = {
        base = setcolor,
        node = setcolor,
    }
}

local function hex2dec(hex,one)
    if one then
        return stringformat("%.1g", tonumber(hex, 16)/255)
    else
        return stringformat("%.3g", tonumber(hex, 16)/255)
    end
end

local res

local function pageresources(a)
    local res2
    if not res then
       res = "/TransGs1<</ca 1/CA 1>>"
    end
    res2 = stringformat("/TransGs%s<</ca %s/CA %s>>", a, a, a)
    res  = stringformat("%s%s", res, stringfind(res, res2) and "" or res2)
end

local function hex_to_rgba(hex)
    local r, g, b, a, push, pop, res3
    if hex then
        if #hex == 6 then
            _, _, r, g, b    = stringfind(hex, '(..)(..)(..)')
        elseif #hex == 8 then
            _, _, r, g, b, a = stringfind(hex, '(..)(..)(..)(..)')
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
        push = stringformat('/TransGs%g gs %s %s %s rg', a, r, g, b)
        pop  = '0 g /TransGs1 gs'
    else
        push = stringformat('%s %s %s rg', r, g, b)
        pop  = '0 g'
    end
    return push, pop
end

local glyph   = nodetype('glyph')
local hlist   = nodetype('hlist')
local vlist   = nodetype('vlist')
local whatsit = nodetype('whatsit')
local pgi     = nodetype('page_insert')
local sbox    = nodetype('sub_box')

local function lookup_next_color(head)
    for n in traverse_nodes(head) do
        if n.id == glyph then
            if ids[n.font] and ids[n.font].properties and ids[n.font].properties.color then
                return ids[n.font].properties.color
            else
                return -1
            end
        elseif n.id == vlist or n.id == hlist or n.id == sbox then
            local r = lookup_next_color(n.list)
            if r == -1 then
                return -1
            elseif r then
                return r
            end
        elseif n.id == whatsit or n.id == pgi then
            return -1
        end
    end
    return nil
end

local function node_colorize(head, current_color, next_color)
    for n in traverse_nodes(head) do
        if n.id == hlist or n.id == vlist or n.id == sbox then
            local next_color_in = lookup_next_color(n.next) or next_color
            n.list, current_color = node_colorize(n.list, current_color, next_color_in)
        elseif n.id == glyph then
            local tfmdata = ids[n.font]
            if tfmdata and tfmdata.properties  and tfmdata.properties.color then
                if tfmdata.properties.color ~= current_color then
                    local pushcolor = hex_to_rgba(tfmdata.properties.color)
                    local push = newnode(whatsit, 8)
                    push.mode  = 1
                    push.data  = pushcolor
                    head       = insert_node_before(head, n, push)
                    current_color = tfmdata.properties.color
                end
                local next_color_in = lookup_next_color (n.next) or next_color
                if next_color_in ~= tfmdata.properties.color then
                    local _, popcolor = hex_to_rgba(tfmdata.properties.color)
                    local pop  = newnode(whatsit, 8)
                    pop.mode   = 1
                    pop.data   = popcolor
                    head       = insert_node_after(head, n, pop)
                    current_color = nil
                end
            end
        end
    end
    return head, current_color
end

local function font_colorize(head)
   -- check if our page resources existed in the previous run
   -- and remove it to avoid duplicating it later
   if res then
      local r = "/ExtGState<<"..res..">>"
      tex.pdfpageresources = stringgsub(tex.pdfpageresources, r, "")
   end
   local h = node_colorize(head, nil, nil)
   -- now append our page resources
   if res and stringfind(res, "%S") then -- test for non-empty string
      local r = "/ExtGState<<"..res..">>"
      tex.pdfpageresources = tex.pdfpageresources..r
   end
   return h
end

local color_callback_activated = 0

function add_color_callback()
    if color_callback_activated == 0 then
        luatexbase.add_to_callback(
          "pre_output_filter", font_colorize, "luaotfload.colorize")
        color_callback_activated = 1
    end
end

-- vim:tw=71:sw=4:ts=4:expandtab

