if not modules then modules = { } end modules ['luaotfload-colors'] = {
    version   = "2.5",
    comment   = "companion to luaotfload-main.lua (font color)",
    author    = "Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2.0"
}

--[[doc--

buggy coloring with the pre_output_filter when expansion is enabled
    · tfmdata for different expansion values is split over different objects
    · in ``initializeexpansion()``, chr.expansion_factor is set, and only
      those characters that have it are affected
    · in constructors.scale: chr.expansion_factor = ve*1000 if commented out
      makes the bug vanish

explanation: http://tug.org/pipermail/luatex/2013-May/004305.html

--doc]]--


local color_callback = config.luaotfload.run.color_callback
if not color_callback then
    --- maybe this would be better as a method: "early" | "late"
    color_callback = "pre_linebreak_filter"
--  color_callback = "pre_output_filter" --- old behavior, breaks expansion
end


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
This converts a single octet into a decimal with three digits of
precision. The optional second argument limits precision to a single
digit.
--doc]]--

--- string -> bool? -> string
local hex_to_dec = function (hex,one) --- one isn’t actually used anywhere ...
    if one then
        return stringformat("%.1g", tonumber(hex, 16)/255)
    else
        return stringformat("%.3g", tonumber(hex, 16)/255)
    end
end

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

local p_Crgb         = Cg(octet/hex_to_dec, "red") --- for captures
                     * Cg(octet/hex_to_dec, "green")
                     * Cg(octet/hex_to_dec, "blue")
local p_Crgba        = p_Crgb * Cg(octet/hex_to_dec, "alpha")
local extract_color  = Ct(p_Crgba + p_Crgb)

--- string -> (string | nil)
local sanitize_color_expression = function (digits)
    digits = tostring(digits)
    local sanitized = lpegmatch(valid_digits, digits)
    if not sanitized then
        luaotfload.warning(
            "%q is not a valid rgb[a] color expression", digits)
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
local setcolor = function (tfmdata, value)
    local sanitized  = sanitize_color_expression(value)
    local properties = tfmdata.properties

    if sanitized then
        properties.color = sanitized
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


--- something is carried around in ``res``
--- for later use by color_handler() --- but what?

local res = nil

--- float -> unit
local function pageresources(alpha)
    res = res or {}
    res[alpha] = true
end

--- we store results of below color handler as tuples of
--- push/pop strings
local color_cache = { } --- (string, (string * string)) hash_t

--- string -> (string * string)
local hex_to_rgba = function (digits)
    if not digits then
        return
    end

    --- this is called like a thousand times, so some
    --- memoizing is in order.
    local cached = color_cache[digits]
    if not cached then
        local push, pop
        local rgb = lpegmatch(extract_color, digits)
        if rgb.alpha then
            pageresources(rgb.alpha)
            push = stringformat(
                        "/TransGs%g gs %s %s %s rg",
                        rgb.alpha,
                        rgb.red,
                        rgb.green,
                        rgb.blue)
            pop  = "0 g /TransGs1 gs"
        else
            push = stringformat(
                        "%s %s %s rg",
                        rgb.red,
                        rgb.green,
                        rgb.blue)
            pop  = "0 g"
        end
        color_cache[digits] = { push, pop }
        return push, pop
    end

    return cached[1], cached[2]
end

--- Luatex internal types

local glyph_t           = nodetype("glyph")
local hlist_t           = nodetype("hlist")
local vlist_t           = nodetype("vlist")
local whatsit_t         = nodetype("whatsit")
local page_insert_t     = nodetype("page_insert")
local sub_box_t         = nodetype("sub_box")

--- node -> nil | -1 | color‽
local lookup_next_color
lookup_next_color = function (head) --- paragraph material
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

local cnt = 0
--- node -> string -> int -> (node * string)
local node_colorize
node_colorize = function (head, current_color, next_color)
    for n in traverse_nodes(head) do
        local n_id      = n.id
        local nextnode  = n.next

        if n_id == hlist_t or n_id == vlist_t or n_id == sub_box_t then
            local next_color_in = lookup_next_color(nextnode) or next_color
            n.list, current_color = node_colorize(n.list, current_color, next_color_in)

        elseif n_id == glyph_t then
            cnt = cnt + 1
            local tfmdata = identifiers[n.font]

            --- colorization is restricted to those fonts
            --- that received the “color” property upon
            --- loading (see ``setcolor()`` above)
            if tfmdata and tfmdata.properties  and tfmdata.properties.color then
                local font_color = tfmdata.properties.color
--                luaotfload.info(
--                    "n: %d; %s; %d %s, %s",
--                    cnt, utf.char(n.char), n.font, "<TRUE>", font_color)
                if font_color ~= current_color then
                    local pushcolor = hex_to_rgba(font_color)
                    local push      = newnode(whatsit_t, 8)
                    push.mode       = 1
                    push.data       = pushcolor
                    head            = insert_node_before(head, n, push)
                    current_color   = font_color
                end
                local next_color_in = lookup_next_color (nextnode) or next_color
                if next_color_in ~= font_color then
                    local _, popcolor = hex_to_rgba(font_color)
                    local pop         = newnode(whatsit_t, 8)
                    pop.mode          = 1
                    pop.data          = popcolor
                    head              = insert_node_after(head, n, pop)
                    current_color     = nil
                end

--            else
--                luaotfload.info(
--                    "n: %d; %s; %d %s",
--                    cnt, utf.char(n.char), n.font, "<FALSE>")
            end
        end
    end
    return head, current_color
end

--- node -> node
local color_handler = function (head)
    local new_head = node_colorize(head, nil, nil)
    -- now append our page resources
    if res then
        res["1"] = true
        local tpr, t = tex.pdfpageresources, ""
        for k in pairs(res) do
            local str = stringformat("/TransGs%s<</ca %s/CA %s>>", k, k, k)
            if not stringfind(tpr,str) then
                t = t .. str
            end
        end
        if t ~= "" then
            if not stringfind(tpr,"/ExtGState<<.*>>") then
                tpr = tpr.."/ExtGState<<>>"
            end
            tpr = stringgsub(tpr,"/ExtGState<<","%1"..t)
            tex.pdfpageresources = tpr
        end
        res = nil -- reset res
    end
    return new_head
end

local color_callback_activated = 0

--- unit -> unit
add_color_callback = function ( )
    if color_callback_activated == 0 then
        luatexbase.add_to_callback(color_callback,
                                   color_handler,
                                   "luaotfload.color_handler")
        color_callback_activated = 1
    end
end

-- vim:tw=71:sw=4:ts=4:expandtab

