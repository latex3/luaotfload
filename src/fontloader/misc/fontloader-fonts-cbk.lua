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

-- from now on we apply ligaturing and kerning here because it might interfere with complex
-- opentype discretionary handling where the base ligature pass expect some weird extra
-- pointers (which then confuse the tail slider that has some checking built in)

local ligaturing  = node.ligaturing
local kerning     = node.kerning

function node.ligaturing() texio.write_nl("warning: node.ligaturing is already applied") end
function node.kerning   () texio.write_nl("warning: node.kerning is already applied")    end

function nodes.handlers.characters(head)
    local fontdata = fonts.hashes.identifiers
    if fontdata then
        local usedfonts, basefonts, prevfont, basefont = { }, { }, nil, nil
        for n in traverse_id(glyph_code,head) do
            local font = n.font
            if font ~= prevfont then
                if basefont then
                    basefont[2] = n.prev
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
                            else
                                basefont = { n, nil }
                                basefonts[#basefonts+1] = basefont
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
        if #basefonts > 0 then
            for i=1,#basefonts do
                local range = basefonts[i]
                local start, stop = range[1], range[2]
                if stop then
                    ligaturing(start,stop)
                    kerning(start,stop)
                else
                    ligaturing(start)
                    kerning(start)
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
 -- head = node.ligaturing(head)
 -- head = node.kerning(head)
    return head
end
