if not modules then modules = { } end modules ['luaotfload-colors'] = {
    version   = 2.200,
    comment   = "companion to luaotfload.lua (font color)",
    author    = "Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2"
}

local newnode               = node.new
local nodetype              = node.id
local traverse_nodes        = node.traverse
local insert_node_before    = node.insert_before
local insert_node_after     = node.insert_after

local stringformat          = string.format
local stringgsub            = string.gsub
local stringfind            = string.find
local stringsub             = string.sub

local otffeatures           = fonts.constructors.newfeatures("otf")
local identifiers           = fonts.hashes.identifiers
local registerotffeature    = otffeatures.register

local add_color_callback --[[ this used to be a global‽ ]]

--[[doc--
Color string validator / parser.
--doc]]--

local lpeg           = require"lpeg"
local lpegmatch      = lpeg.match
local C, Cg, Ct, P, R, S = lpeg.C, lpeg.Cg, lpeg.Ct, lpeg.P, lpeg.R, lpeg.S

local digit16        = R("09", "af", "AF")
local octet          = C(digit16 * digit16)

local p_rgb          = octet * octet * octet
local p_rgba         = p_rgb * octet
local valid_digits   = C(p_rgba + p_rgb) -- matches eight or six hex digits

local p_Crgb         = Cg(octet, "red") --- for captures
                     * Cg(octet, "green")
                     * Cg(octet, "blue")
local p_Crgba        = p_Crgb * Cg(octet, "alpha")
local extract_color  = Ct(p_Crgba + p_Crgb)

--- string -> (string | nil)
local sanitize_color_expression = function (digits)
    digits = tostring(digits)
    local sanitized = lpegmatch(valid_digits, digits)
    if not sanitized then
        luaotfload.warning(
            "“%s” is not a valid rgb[a] color expression", digits)
        return nil
    end
    return sanitized
end

--[[doc--
``setcolor`` modifies tfmdata.properties.color in place
--doc]]--

--- fontobj -> string -> unit
---
---         (where “string” is a rgb value as three octet
---         hexadecimal, with an optional fourth transparency
---         value)
---
local function setcolor (tfmdata, value)
    local sanitized  = sanitize_color_expression(value)
    local properties = tfmdata.properties

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


--[[doc--
This converts a single octet into a decimal with three digits of
precision. The optional second argument limits precision to a single
digit.
--doc]]--

--- string -> bool? -> float
local function hex_to_dec(hex,one)
    if one then
        return stringformat("%.1g", tonumber(hex, 16)/255)
    else
        return stringformat("%.3g", tonumber(hex, 16)/255)
    end
end

--- something is carried around in ``res``
--- for later use by color_handler() --- but what?

local res --- <- state of what?

--- float -> unit
local function pageresources(a)
    local res2
    if not res then
       res = "/TransGs1<</ca 1/CA 1>>"
    end
    res2 = stringformat("/TransGs%s<</ca %s/CA %s>>", a, a, a)
    res  = stringformat("%s%s",
                        res,
                        stringfind(res, res2) and "" or res2)
end

--- string -> (string * string)
local function hex_to_rgba(hex)
    local r, g, b, a, push, pop, res3
    if hex then
        --- TODO lpeg this mess
        if #hex == 6 then
            _, _, r, g, b    = stringfind(hex, '(..)(..)(..)')
        elseif #hex == 8 then
            _, _, r, g, b, a = stringfind(hex, '(..)(..)(..)(..)')
            a                = hex_to_dec(a,true)
            pageresources(a)
        end
    else
        return nil
    end
    r = hex_to_dec(r)
    g = hex_to_dec(g)
    b = hex_to_dec(b)
    if a then
        push = stringformat('/TransGs%g gs %s %s %s rg', a, r, g, b)
        pop  = '0 g /TransGs1 gs'
    else
        push = stringformat('%s %s %s rg', r, g, b)
        pop  = '0 g'
    end
    return push, pop
end

--- Luatex internal types

local glyph_t           = nodetype("glyph")
local hlist_t           = nodetype("hlist")
local vlist_t           = nodetype("vlist")
local whatsit_t         = nodetype("whatsit")
local page_insert_t     = nodetype("page_insert")
local sub_box_t         = nodetype("sub_box")

--- node -> nil | -1 | color‽
local function lookup_next_color(head)
    for n in traverse_nodes(head) do
        local n_id = n.id
        if n_id == glyph_t then
            local n_font
            if  identifiers[n_font]
            and identifiers[n_font].properties
            and identifiers[n_font].properties.color
            then
                return identifiers[n.font].properties.color
            else
                return -1
            end

        elseif n_id == vlist_t or n_id == hlist_t or n_id == sub_box_t then
            local r = lookup_next_color(n.list)
            if r then
                return r
            end

        elseif n_id == whatsit_t or n_id == page_insert_t then
            return -1
        end
    end
    return nil
end

--[[doc--
While the second argument and second returned value are apparently
always nil when the function is called, they temporarily take string
values during the node list traversal.
--doc]]--

--- node -> string -> int -> (node * string)
local function node_colorize(head, current_color, next_color)
    for n in traverse_nodes(head) do
        local n_id = n.id

        if n_id == hlist_t or n_id == vlist_t or n_id == sub_box_t then
            local next_color_in = lookup_next_color(n.next) or next_color
            n.list, current_color = node_colorize(n.list, current_color, next_color_in)

        elseif n_id == glyph_t then
            local tfmdata = identifiers[n.font]
            if tfmdata and tfmdata.properties  and tfmdata.properties.color then
                if tfmdata.properties.color ~= current_color then
                    local pushcolor = hex_to_rgba(tfmdata.properties.color)
                    local push = newnode(whatsit_t, 8)
                    push.mode  = 1
                    push.data  = pushcolor
                    head       = insert_node_before(head, n, push)
                    current_color = tfmdata.properties.color
                end
                local next_color_in = lookup_next_color (n.next) or next_color
                if next_color_in ~= tfmdata.properties.color then
                    local _, popcolor = hex_to_rgba(tfmdata.properties.color)
                    local pop  = newnode(whatsit_t, 8)
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

--- node -> node
local function color_handler (head)
    -- check if our page resources existed in the previous run
    -- and remove it to avoid duplicating it later
    if res then
        local r = "/ExtGState<<"..res..">>"
        tex.pdfpageresources = stringgsub(tex.pdfpageresources, r, "")
    end
    local new_head = node_colorize(head, nil, nil)
    -- now append our page resources
    if res and stringfind(res, "%S") then -- test for non-empty string
        local r = "/ExtGState<<"..res..">>"
        tex.pdfpageresources = tex.pdfpageresources..r
    end
    return new_head
end

local color_callback_activated = 0

--- unit -> unit
function add_color_callback ()
    if color_callback_activated == 0 then
        luatexbase.add_to_callback("pre_output_filter",
                                   color_handler,
                                   "luaotfload.color_handler")
        color_callback_activated = 1
    end
end

-- vim:tw=71:sw=4:ts=4:expandtab

