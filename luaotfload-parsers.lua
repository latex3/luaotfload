#!/usr/bin/env texlua
-----------------------------------------------------------------------
--         FILE:  luaotfload-parsers.lua
--  DESCRIPTION:  various lpeg-based parsers used in Luaotfload
-- REQUIREMENTS:  Luaotfload > 2.4
--       AUTHOR:  Philipp Gesang (Phg), <phg42.2a@gmail.com>
--      VERSION:  same as Luaotfload
--      CREATED:  2014-01-14 10:15:20+0100
-----------------------------------------------------------------------
--

if not modules then modules = { } end modules ['luaotfload-parsers'] = {
    version   = "2.5",
    comment   = "companion to luaotfload.lua",
    author    = "Philipp Gesang",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2.0"
}



