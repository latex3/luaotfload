-----------------------------------------------------------------------
--         FILE:  luaotfload-fontloader-base.lua
--  DESCRIPTION:  part of luaotfload / font loader initialization -- generic
-- REQUIREMENTS:  luatex v.0.80 or later; packages lualibs
--       AUTHOR:  Philipp Gesang (Phg), <phg@phi-gamma.net>, Marcel Krüger
-----------------------------------------------------------------------

local ProvidesLuaModule = {
    name          = "luaotfload-fontloader-base",
    version       = "3.14",       --TAGVERSION
    date          = "2020-05-06", --TAGDATE
    description   = "luaotfload submodule / pre-initialization",
    license       = "GPL v2.0"
}

if luatexbase and luatexbase.provides_module then
  luatexbase.provides_module (ProvidesLuaModule)
end
-----------------------------------------------------------------------


local kpsefind_file   = kpse.find_file

local log = require'luaotfload-log'

local context_environment = setmetatable({}, {__index = _G})

require "lualibs"

--[[doc--

  The logger needs to be in place prior to loading the fontloader due
  to order of initialization being crucial for the logger functions
  that are swapped.

--doc]]--
log.set_loglevel (default_log_level)

assert(loadfile(kpsefind_file("fontloader-basics-gen", "lua"), nil, context_environment))()

return context_environment
-- vim:tw=79:sw=2:ts=2:expandtab
