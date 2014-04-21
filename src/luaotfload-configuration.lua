#!/usr/bin/env texlua
-------------------------------------------------------------------------------
--         FILE:  luaotfload-configuration.lua
--  DESCRIPTION:  config file reader
-- REQUIREMENTS:  Luaotfload > 2.4
--       AUTHOR:  Philipp Gesang (Phg), <phg42.2a@gmail.com>
--      VERSION:  same as Luaotfload
--      CREATED:  2014-04-21 14:03:52+0200
-------------------------------------------------------------------------------
--

if not modules then modules = { } end modules ["luaotfload-configuration"] = {
  version   = "2.5",
  comment   = "part of Luaotfload",
  author    = "Philipp Gesang",
  copyright = "Luaotfload Development Team",
  license   = "GNU GPL v2.0"
}

luaotfload                    = luaotfload or { }
luaotfload.config             = luaotfload.config or { }

local string                  = string
local stringsub               = string.sub
local stringexplode           = string.explode

local io                      = io
local ioloaddata              = io.loaddata

local os                      = os
local osgetenv                = os.getenv

local lpeg                    = require "lpeg"
local lpegmatch               = lpeg.match

local kpse                    = kpse
local kpselookup              = kpse.lookup

local lfs                     = lfs
local lfsisfile               = lfs.isfile
local lfsisdir                = lfs.isdir

local file                    = file
local filejoin                = file.join

local parsers                 = luaotfload.parsers
local config                  = luaotfload.config
local log                     = luaotfload.log
local logreport               = log.report

local config_parser           = parsers.config

-------------------------------------------------------------------------------
---                                SETTINGS
-------------------------------------------------------------------------------

local path_t = 0
local kpse_t = 1

local config_paths = {
  --- needs adapting for those other OS
  { path_t, "./luaotfloadrc" },
  { path_t, "~/.config/luaotfload/luaotfloadrc" },
  { path_t, "~/.luaotfloadrc" },
  { kpse_t, "luaotfloadrc" },
  { kpse_t, "luaotfload.conf" },
}

-------------------------------------------------------------------------------
---                          OPTION SPECIFICATION
-------------------------------------------------------------------------------

local string_t    = "string"
local table_t     = "table"
local boolean_t   = "boolean"
local function_t  = "function"

local option_spec = {
  db = {
    formats = {
      --- e.g. "otf ttf" -> { "otf", "ttf" }
      in_t        = string_t,
      out_t       = table_t,
      transform   = function (str) return stringexplode (str, " +") end
    },
    reload = {
      in_t        = boolean_t,
    },
  },
}

-------------------------------------------------------------------------------
---                           MAIN FUNCTIONALITY
-------------------------------------------------------------------------------

--[[doc--

  tilde_expand -- Rudimentary tilde expansion; covers just the “substitute ‘~’
  by the current users’s $HOME” part.

--doc]]--

local tilde_expand = function (p)
  if #p > 2 then
    if stringsub (p, 1, 2) == "~/" then
      local homedir = osgetenv "HOME"
      if homedir and lfsisdir (homedir) then
        p = filejoin (homedir, stringsub (p, 3))
      end
    end
  end
  return p
end

local resolve_config_path = function ()
  inspect (config_paths)
  for i = 1, #config_paths do
    local t, p = unpack (config_paths[i])
    local fullname
    if t == kpse_t then
      fullname = kpse.lookup (p)
      logreport ("both", 6, "conf", "kpse lookup: %s -> %s.", p, fullname)
    elseif t == path_t then
      local expanded = tilde_expand (p)
      if lfsisfile (expanded) then
        fullname = expanded
      end
      logreport ("both", 6, "conf", "path lookup: %s -> %s.", p, fullname)
    end
    if fullname then
      logreport ("both", 3, "conf", "Reading configuration file at %q.", fullname)
      return fullname
    end
  end
  logreport ("both", 2, "conf", "No configuration file found.")
  return false
end

local add_config_paths = function (t)
  if not next (t) then
    return
  end
  local result = { }
  for i = 1, #t do
    local path = t[i]
    result[#result + 1] = { path_t, path }
  end
  config_paths = table.append (result, config_paths)
end

local process_options = function (opts)
  local new = { }
  for i = 1, #opts do
    local section = opts[i]
    local title = section.section.title
    local vars  = section.variables

    if not title then --- trigger warning: arrow code ahead
      logreport ("both", 2, "conf", "Section %d lacks a title; skipping.", i)
    elseif not vars then
      logreport ("both", 2, "conf", "Section %d (%s) lacks a variable section; skipping.", i, title)
    else
      local spec = option_spec[title]
      if not spec then
        logreport ("both", 2, "conf", "Section %d (%s) unknown; skipping.", i, title)
      else
        local newsection = new[title]
        if not newsection then
          newsection = { }
          new[title] = newsection
        end

        for var, val in next, vars do
          local vspec = spec[var]
          local t_val = type (val)
          if t_val ~= vspec.in_t then
            logreport ("both", 2, "conf",
                       "Section %d (%s): type mismatch of input value %q (%q, %s != %s); ignoring.",
                       i, title,
                       var, tostring (val), t_val, vspec.in_t)
          else --- type matches
            local transform = vspec.transform
            if transform then
              local dval
              local t_transform = type (transform)
              if t_transform == function_t then
                dval = transform (val)
              elseif t_transform == table_t then
                dval = transform[val]
              end
              if dval then
                local out_t = vspec.out_t
                if out_t then
                  local t_dval = type (dval)
                  if t_dval == out_t then
                    newsection[var] = dval
                  else
                    logreport ("both", 2, "conf",
                               "Section %d (%s): type mismatch of derived value of %q (%q, %s != %s); ignoring.",
                               i, title,
                               var, tostring (dval), t_dval, out_t)
                  end
                else
                  newsection[var] = dval
                end
              else
                logreport ("both", 2, "conf",
                           "Section %d (%s): value of %q could not be derived via %s from input %q; ignoring.",
                           i, title, var, t_transform, tostring (val))
              end
            else --- insert as is
              newsection[var] = val
            end
          end
        end
      end
    end
  end
  return new
end

local read = function (extra)
  if extra then
    add_config_paths (extra)
  end

  local readme = resolve_config_path ()
  if readme == false then
    logreport ("both", 2, "conf", "No configuration file.")
    return false
  end

  local raw = ioloaddata (readme)
  if not raw then
    logreport ("both", 2, "conf", "Error reading the configuration file %q.", readme)
    return false
  end

  local parsed = lpegmatch (parsers.config, raw)
  if not parsed then
    logreport ("both", 2, "conf", "Error parsing configuration file %q.", readme)
    return false
  end

  local ret, msg = process_options (parsed)
  if not ret then
    logreport ("both", 2, "conf", "File %q is not a valid configuration file.", readme)
    logreport ("both", 2, "conf", "Error: %s", msg)
    return false
  end
  return ret
end

config.read = read

