if not modules then modules = { } end modules ['node-dum'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

nodes = nodes or { }

function nodes.simple_font_dummy(head,tail)
    return tail
end

function nodes.simple_font_handler(head)
    local tail = node.slide(head)
--  lang.hyphenate(head,tail)
    head = nodes.process_characters(head,tail)
    nodes.inject_kerns(head)
    nodes.protect_glyphs(head)
    tail = node.ligaturing(head,tail)
    tail = node.kerning(head,tail)
    return head
end
