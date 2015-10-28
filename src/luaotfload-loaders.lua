#!/usr/bin/env texlua
-----------------------------------------------------------------------
--         FILE:  luaotfload-loaders.lua
--  DESCRIPTION:  Luaotfload callback handling
-- REQUIREMENTS:  luatex v.0.80 or later; packages lualibs, luatexbase
--       AUTHOR:  Philipp Gesang (Phg), <phg@phi-gamma.net>, Hans Hagen, Khaled Hosny, Elie Roux
--      VERSION:  just consult Git, okay?
-----------------------------------------------------------------------
--
--- Contains parts of the earlier main script.

if not lualibs    then error "this module requires Luaotfload" end
if not luaotfload then error "this module requires Luaotfload" end

local logreport = luaotfload.log and luaotfload.log.report or print

local install_formats = function ()
  local fonts = fonts
  if not fonts then return false end

  local readers  = fonts.readers
  local handlers = fonts.handlers
  local formats  = fonts.formats
  if not readers or not handlers or not formats then return false end

  local aux = function (which, reader)
    if   not which  or type (which) ~= "string"
      or not reader or type (reader) ~= "function" then
      logreport ("both", 2, "loaders", "Error installing reader for “%s”.", which)
      return false
    end
    formats  [which] = "type1"
    readers  [which] = reader
    handlers [which] = { }
    return true
  end

  return aux ("pfa", function (spec) return readers.opentype (spec, "pfa", "type1") end)
     and aux ("pfb", function (spec) return readers.opentype (spec, "pfb", "type1") end)
     and aux ("ofm", readers.tfm)
end

--[[doc--

    \subsection{\CONTEXT override}
    \label{define-font}
    We provide a simplified version of the original font definition
    callback.

--doc]]--


local definers --- (string, spec -> size -> id -> tmfdata) hash_t
do
  local read = fonts.definers.read

  local patch = function (specification, size, id)
    local fontdata = read (specification, size, id)
    if type (fontdata) == "table" and fontdata.shared then
      --- We need to test for the “shared” field here
      --- or else the fontspec capheight callback will
      --- operate on tfm fonts.
      luatexbase.call_callback ("luaotfload.patch_font", fontdata, specification)
    else
      luatexbase.call_callback ("luaotfload.patch_font_unsafe", fontdata, specification)
    end
    return fontdata
  end

  local mk_info = function (name)
    local definer = name == "patch" and patch or read
    return function (specification, size, id)
      logreport ("both", 0, "loaders", "defining font no. %d", id)
      logreport ("both", 0, "loaders", "   > active font definer: %q", name)
      logreport ("both", 0, "loaders", "   > spec %q", specification)
      logreport ("both", 0, "loaders", "   > at size %.2f pt", size / 2^16)
      local result = definer (specification, size, id)
      if not result then
        logreport ("both", 0, "loaders", "   > font definition failed")
        return
      elseif type (result) == "number" then
        logreport ("both", 0, "loaders", "   > font definition yielded id %d", result)
        return result
      end
      logreport ("both", 0, "loaders", "   > font definition successful")
      logreport ("both", 0, "loaders", "   > name %q",     result.name     or "<nil>")
      logreport ("both", 0, "loaders", "   > fontname %q", result.fontname or "<nil>")
      logreport ("both", 0, "loaders", "   > fullname %q", result.fullname or "<nil>")
      return result
    end
  end

  definers = {
    patch          = patch,
    generic        = read,
    info_patch     = mk_info "patch",
    info_generic   = mk_info "generic",
  }
end

--[[doc--

  We create callbacks for patching fonts on the fly, to be used by
  other packages. In addition to the regular \identifier{patch_font}
  callback there is an unsafe variant \identifier{patch_font_unsafe}
  that will be invoked even if the target font lacks certain essential
  tfmdata tables.

  The callbacks initially contain the empty function that we are going
  to override below.

--doc]]--

local install_callbacks = function ()
  local create_callback  = luatexbase.create_callback
  local dummy_function   = function () end
  create_callback ("luaotfload.patch_font",        "simple", dummy_function)
  create_callback ("luaotfload.patch_font_unsafe", "simple", dummy_function)
  luatexbase.reset_callback "define_font"
  local definer = config.luaotfload.run.definer
  luatexbase.add_to_callback ("define_font",
                              definers[definer or "patch"],
                              "luaotfload.define_font",
                              1)
  return true
end

return {
  init = function ()
    local ret = true
    if not install_formats () then
      logreport ("log", 0, "loaders", "Error initializing OFM/PF{A,B} loaders.")
      ret = false
    end
    if not install_callbacks () then
      logreport ("log", 0, "loaders", "Error installing font loader callbacks.")
      ret = false
    end
    return ret
  end
}
-- vim:tw=79:sw=2:ts=2:expandtab
