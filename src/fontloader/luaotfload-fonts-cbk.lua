if not modules then modules = { } end modules ['luatex-fonts-cbk'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if context then
    texio.write_nl("fatal error: this module is not for context")
    os.exit()
end

local fonts = fonts
local nodes = nodes

-- Fonts: (might move to node-gef.lua)

local traverse_id = node.traverse_id
local glyph_code  = nodes.nodecodes.glyph

function nodes.handlers.characters(head)
    local fontdata = fonts.hashes.identifiers
    if fontdata then
        local usedfonts, done, prevfont = { }, false, nil
        for n in traverse_id(glyph_code,head) do
            local font = n.font
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
                                done = true
                            end
                        end
                    end
                end
            end
        end
        if done then
            for font, processors in next, usedfonts do
                for i=1,#processors do
                    local h, d = processors[i](head,font,0)
                    head, done = h or head, done or d
                end
            end
        end
        return head, true
    else
        return head, false
    end
end

function nodes.simple_font_handler(head)
--  lang.hyphenate(head)
    head = nodes.handlers.characters(head)
    nodes.injections.handler(head)
    nodes.handlers.protectglyphs(head)
    head = node.ligaturing(head)
    head = node.kerning(head)
    return head
end
