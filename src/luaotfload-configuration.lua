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
config                        = config or { }
config.luaotfload             = { }

local status_file             = "luaotfload-status"
local luaotfloadstatus        = require (status_file)

local string                  = string
local stringsub               = string.sub
local stringexplode           = string.explode

local table                   = table
local tableappend             = table.append
local tablecopy               = table.copy

local math                    = math
local mathfloor               = math.floor

local io                      = io
local ioloaddata              = io.loaddata
local iopopen                 = io.popen

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
local filereplacesuffix       = file.replacesuffix


local parsers                 = luaotfload.parsers

local log                     = luaotfload.log
local logreport               = log.report

local config_parser           = parsers.config
local stripslashes            = parsers.stripslashes

local getwritablepath         = caches.getwritablepath

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
---                                DEFAULTS
-------------------------------------------------------------------------------

local default_config = {
  db = {
    formats     = "otf,ttf,ttc,dfont",
    reload      = false,
    scan_local  = false,
    skip_read   = false,
    strip       = true,
    update_live = true,
    compress    = true,
    max_fonts   = 2^51,
  },
  run = {
    resolver       = "cached",
    definer        = "patch",
    log_level      = 0,
    color_callback = "pre_linebreak_filter",
  },
  misc = {
    bisect         = false,
    version        = luaotfload.version,
    statistics     = false,
    termwidth      = nil,
  },
  paths = {
    names_dir           = "names",
    cache_dir           = "fonts",
    index_file          = "luaotfload-names.lua",
    lookups_file        = "luaotfload-lookup-cache.lua",
    lookup_path_lua     = nil,
    lookup_path_luc     = nil,
    index_path_lua      = nil,
    index_path_luc      = nil,
  },
}

-------------------------------------------------------------------------------
---                          RECONFIGURATION TASKS
-------------------------------------------------------------------------------

--[[doc--

    Procedures to be executed in order to put the new configuration into effect.

--doc]]--

local reconf_tasks = nil

local min_terminal_width = 40

--- The “termwidth” value is only considered when printing
--- short status messages, e.g. when building the database
--- online.
local check_termwidth = function ()
  if config.luaotfload.misc.termwidth == nil then
      local tw = 79
      if not (   os.type == "windows" --- Assume broken terminal.
              or osgetenv "TERM" == "dumb")
      then
          local p = iopopen "tput cols"
          if p then
              result = tonumber (p:read "*all")
              p:close ()
              if result then
                  tw = result
              else
                  logreport ("log", 2, "db", "tput returned non-number.")
              end
          else
              logreport ("log", 2, "db", "Shell escape disabled or tput executable missing.")
              logreport ("log", 2, "db", "Assuming 79 cols terminal width.")
          end
      end
      config.luaotfload.misc.termwidth = tw
  end
  return true
end

local set_font_filter = function ()
  local names = fonts.names
  if names and names.set_font_filter then
    local formats = config.luaotfload.db.formats
    if not formats or formats == "" then
      formats = default_config.db.formats
    end
    names.set_font_filter (formats)
  end
  return true
end

local set_name_resolver = function ()
  local names = fonts.names
  if names and names.resolve_cached then
    --- replace the resolver from luatex-fonts
    if config.luaotfload.db.resolver == "cached" then
        logreport ("both", 2, "cache", "Caching of name: lookups active.")
        names.resolvespec  = names.resolve_cached
    else
        names.resolvespec  = names.resolve_name
    end
  end
  return true
end

local set_loglevel = function ()
  log.set_loglevel (config.luaotfload.run.log_level)
  return true
end

local build_cache_paths = function ()
  local paths  = config.luaotfload.paths
  local prefix = getwritablepath (paths.names_dir, "")

  if not prefix then
    luaotfload.error ("Impossible to find a suitable writeable cache...")
    return false
  end

  prefix = lpegmatch (stripslashes, prefix)
  logreport ("log", 0, "conf", "Root cache directory is %s.", prefix)

  local index_file      = filejoin (prefix, paths.index_file)
  local lookups_file    = filejoin (prefix, paths.lookups_file)

  paths.prefix          = prefix
  paths.index_path_lua  = filereplacesuffix (index_file,   "lua")
  paths.index_path_luc  = filereplacesuffix (index_file,   "luc")
  paths.lookup_path_lua = filereplacesuffix (lookups_file, "lua")
  paths.lookup_path_luc = filereplacesuffix (lookups_file, "luc")
  return true
end

reconf_tasks = {
  { "Set the log level"         , set_loglevel      },
  { "Build cache paths"         , build_cache_paths },
  { "Check terminal dimensions" , check_termwidth   },
  { "Set the font filter"       , set_font_filter   },
  { "Install font name resolver", set_name_resolver },
}

-------------------------------------------------------------------------------
---                          OPTION SPECIFICATION
-------------------------------------------------------------------------------

local string_t    = "string"
local table_t     = "table"
local number_t    = "number"
local boolean_t   = "boolean"
local function_t  = "function"

local tointeger = function (n)
  n = tonumber (n)
  if n then
    return mathfloor (n + 0.5)
  end
end

local option_spec = {
  db = {
    formats      = { in_t = string_t,  },
    reload       = { in_t = boolean_t, },
    scan_local   = { in_t = boolean_t, },
    skip_read    = { in_t = boolean_t, },
    strip        = { in_t = boolean_t, },
    update_live  = { in_t = boolean_t, },
    compress     = { in_t = boolean_t, },
    max_fonts    = {
      in_t      = number_t,
      out_t     = number_t, --- TODO int_t from 5.3.x on
      transform = tointeger,
    },
  },
  run = {
    resolver = {
      in_t      = string_t,
      out_t     = string_t,
      transform = function (r) return r == "normal" and r or "cached" end,
    },
    definer = {
      in_t      = string_t,
      out_t     = string_t,
      transform = function (d) return d == "generic" and d or "patch" end,
    },
    log_level = {
      in_t      = number_t,
      out_t     = number_t, --- TODO int_t from 5.3.x on
      transform = tointeger,
    },
    color_callback = {
      in_t      = string_t,
      out_t     = string_t,
      transform = function (cb)
        --- These are the two that make sense.
        return cb == "pre_output_filter" and cb or "pre_linebreak_filter"
      end,
    },
  },
  misc = {
    bisect          = { in_t = boolean_t, }, --- doesn’t make sense in a config file
    version         = { in_t = string_t,  },
    statistics      = { in_t = boolean_t, },
    termwidth       = {
      in_t      = number_t,
      out_t     = number_t,
      transform = function (w)
        w = tointeger (w)
        if w < min_terminal_width then
          return min_terminal_width
        end
        return w
      end,
    },
  },
  paths = {
    names_dir           = { in_t = string_t, },
    cache_dir           = { in_t = string_t, },
    index_file          = { in_t = string_t, },
    lookups_file        = { in_t = string_t, },
    lookup_path_lua     = { in_t = string_t, },
    lookup_path_luc     = { in_t = string_t, },
    index_path_lua      = { in_t = string_t, },
    index_path_luc      = { in_t = string_t, },
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
  config_paths = tableappend (result, config_paths)
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

local apply
apply = function (old, new)
  if not new then
    if not old then
      return false
    end
    return tablecopy (old)
  elseif not old then
    return tablecopy (new)
  end
  local result = tablecopy (old)
  for name, section in next, new do
    local t_section = type (section)
    if t_section ~= table_t then
      logreport ("both", 1, "conf",
                 "Error applying configuration: entry %s is %s, expected table.",
                 section, t_section)
      --- ignore
    else
      local currentsection = result[name]
      for var, val in next, section do
        currentsection[var] = val
      end
    end
  end
  result.status = luaotfloadstatus
  return result
end

local reconfigure = function ()
  for i = 1, #reconf_tasks do
    local name, task = unpack (reconf_tasks[i])
    logreport ("both", 3, "conf", "Launch post-configuration task %q.", name)
    if not task () then
      logreport ("both", 0, "conf", "Post-configuration task %q failed.", name)
      return false
    end
  end
  return true
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

local apply_defaults = function ()
  local defaults      = default_config
  local vars          = read ()
  --- Side-effects galore ...
  config.luaotfload   = apply (defaults, vars)
  return reconfigure ()
end

-------------------------------------------------------------------------------
---                                 EXPORTS
-------------------------------------------------------------------------------

luaotfload.default_config = default_config

config.actions = {
  read             = read,
  apply            = apply,
  apply_defaults   = apply_defaults,
  reconfigure      = reconfigure,
}

