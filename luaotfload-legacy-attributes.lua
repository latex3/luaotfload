-----------------------------------------------------------------------
--         FILE:  otfl-luat-att.lua
--        USAGE:  with old luaotfload
--  DESCRIPTION:  setting attributes abide luatexbase rules
-- REQUIREMENTS:  some old luatex
--       AUTHOR:  Philipp Gesang (Phg), <phg42.2a@gmail.com>
--      CREATED:  2013-05-10 20:37:19+0200
-----------------------------------------------------------------------
--

if not modules then modules = { } end modules ['otfl-luat-att'] = {
    version   = math.pi/42,
    comment   = "companion to luaotfload.lua",
    author    = "Philipp Gesang",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2"
}

function attributes.private(name)
    local attr   = "otfl@" .. name
    local number = luatexbase.attributes[attr]
    if not number then
        number = luatexbase.new_attribute(attr)
    end
    return number
end

