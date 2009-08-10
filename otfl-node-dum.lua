if not modules then modules = { } end modules ['node-dum'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

nodes = nodes or { }

function nodes.simple_font_handler(head)
--  lang.hyphenate(head)
    head = nodes.process_characters(head)
    nodes.inject_kerns(head)
    nodes.protect_glyphs(head)
    head = node.ligaturing(head)
    head = node.kerning(head)
    return head
end
