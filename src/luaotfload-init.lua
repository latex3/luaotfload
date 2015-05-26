#!/usr/bin/env texlua
-----------------------------------------------------------------------
--         FILE:  luaotfload-init.lua
--  DESCRIPTION:  Luaotfload font loader initialization
-- REQUIREMENTS:  luatex v.0.80 or later; packages lualibs, luatexbase
--       AUTHOR:  Philipp Gesang (Phg), <phg@phi-gamma.net>
--      VERSION:  1.0
--      CREATED:  2015-05-26 07:50:54+0200
-----------------------------------------------------------------------
--

--[[doc--

  Initialization phases:

      - Load Lualibs from package
      - Load Fontloader
          - as package specified in configuration
          - from Context install
          - (optional: from raw unpackaged files distributed with
            Luaotfload)

  The initialization of the Lualibs may be made configurable in the
  future as well allowing to load both the files and the merged package
  depending on a configuration setting. However, this would require
  separating out the configuration parser into a self-contained
  package, which might be problematic due to its current dependency on
  the Lualibs itself.

--doc]]--

if not luaotfload then error("this module requires Luaotfload") end

local load_luaotfload_module = luaotfload.loaders.luaotfload
local load_fontloader_module = luaotfload.loaders.fontloader



