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

luaotfload              = luaotfload or { }
luaotfload.parsers      = luaotfload.parsers or { }
local parsers           = luaotfload.parsers

local lpeg              = require "lpeg"
local P, R, S           = lpeg.P, lpeg.R, lpeg.S
local lpegmatch         = lpeg.match
local C, Cc, Cf         = lpeg.C, lpeg.Cc, lpeg.Cf
local Cg, Cs, Ct        = lpeg.Cg, lpeg.Cs, lpeg.Ct

local kpse              = kpse
local kpseexpand_path   = kpse.expand_path
local kpsereadable_file = kpse.readable_file

local file              = file
local filejoin          = file.join
local filedirname       = file.dirname

local io                = io
local ioopen            = io.open

local logs              = logs
local report            = logs.report

local string            = string
local stringsub         = string.sub
local stringfind        = string.find

local lfs               = lfs
local lfsisfile         = lfs.isfile
local lfsisdir          = lfs.isdir

--[[doc--

  For fonts installed on the operating system, there are several
  options to make Luaotfload index them:

   - If OSFONTDIR is set (which is the case under windows by default
     but not on the other OSs), it scans it at the same time as the
     texmf tree, in the function scan_texmf_fonts().

   - Otherwise
     - under Windows and Mac OSX, we take a look at some hardcoded
       directories,
     - under Unix, it reads /etc/fonts/fonts.conf and processes the
       directories specified there.

  This means that if you have fonts in fancy directories, you need to
  set them in OSFONTDIR.

  Beware: OSFONTDIR is a kpathsea variable, so fonts found in these
  paths, though technically system fonts, are registered in the
  category “texmf”, not “system”. This may have consequences for the
  lookup order when a font file (or a font with the same name
  information) is located in both the system and the texmf tree.

--doc]]--

local alpha             = R("az", "AZ")
local digit             = R"09"
local tag_name          = C(alpha^1)
local whitespace        = S" \n\r\t\v"
local ws                = whitespace^1
local comment           = P"<!--" * (1 - P"--")^0 * P"-->"

---> header specifica
local xml_declaration   = P"<?xml" * (1 - P"?>")^0 * P"?>"
local xml_doctype       = P"<!DOCTYPE" * ws
                        * "fontconfig" * (1 - P">")^0 * P">"
local header            = xml_declaration^-1
                        * (xml_doctype + comment + ws)^0

---> enforce root node
local root_start        = P"<"  * ws^-1 * P"fontconfig" * ws^-1 * P">"
local root_stop         = P"</" * ws^-1 * P"fontconfig" * ws^-1 * P">"

local dquote, squote    = P[["]], P"'"
local xml_namestartchar = S":_" + alpha --- ascii only, funk the rest
local xml_namechar      = S":._" + alpha + digit
local xml_name          = ws^-1
                        * C(xml_namestartchar * xml_namechar^0)
local xml_attvalue      = dquote * C((1 - S[[%&"]])^1) * dquote * ws^-1
                        + squote * C((1 - S[[%&']])^1) * squote * ws^-1
local xml_attr          = Cg(xml_name * P"=" * xml_attvalue)
local xml_attr_list     = Cf(Ct"" * xml_attr^1, rawset)

--[[doc--
      scan_node creates a parser for a given xml tag.
--doc]]--
--- string -> bool -> lpeg_t
local scan_node = function (tag)
    --- Node attributes go into a table with the index “attributes”
    --- (relevant for “prefix="xdg"” and the likes).
    local p_tag = P(tag)
    local with_attributes   = P"<" * p_tag
                            * Cg(xml_attr_list, "attributes")^-1
                            * ws^-1
                            * P">"
    local plain             = P"<" * p_tag * ws^-1 * P">"
    local node_start        = plain + with_attributes
    local node_stop         = P"</" * p_tag * ws^-1 * P">"
    --- there is no nesting, the earth is flat ...
    local node              = node_start
                            * Cc(tag) * C(comment + (1 - node_stop)^1)
                            * node_stop
    return Ct(node) -- returns {string, string [, attributes = { key = val }] }
end

--[[doc--
      At the moment, the interesting tags are “dir” for
      directory declarations, and “include” for including
      further configuration files.

      spec: http://freedesktop.org/software/fontconfig/fontconfig-user.html
--doc]]--
local include_node        = scan_node"include"
local dir_node            = scan_node"dir"

local element             = dir_node
                          + include_node
                          + comment         --> ignore
                          + P(1-root_stop)  --> skip byte

local root                = root_start * Ct(element^0) * root_stop
local p_cheapxml          = header * root

--lpeg.print(p_cheapxml) ---> 757 rules with v0.10

--[[doc--
      fonts_conf_scanner() handles configuration files.
      It is called on an abolute path to a config file (e.g.
      /home/luser/.config/fontconfig/fonts.conf) and returns a list
      of the nodes it managed to extract from the file.
--doc]]--
--- string -> path list
local fonts_conf_scanner = function (path)
  local fh = ioopen(path, "r")
  if not fh then
    report("both", 3, "db", "Cannot open fontconfig file %s.", path)
    return
  end
  local raw = fh:read"*all"
  fh:close()

  local confdata = lpegmatch(p_cheapxml, raw)
  if not confdata then
    report("both", 3, "db", "Cannot scan fontconfig file %s.", path)
    return
  end
  return confdata
end

local p_conf   = P".conf" * P(-1)
local p_filter = (1 - p_conf)^1 * p_conf

local conf_filter = function (path)
  if lpegmatch (p_filter, path) then
    return true
  end
  return false
end

--[[doc--
      read_fonts_conf_indeed() is called with six arguments; the
      latter three are tables that represent the state and are
      always returned.
      The first three are
          · the path to the file
          · the expanded $HOME
          · the expanded $XDG_CONFIG_DIR
--doc]]--
--- string -> string -> string -> tab -> tab -> (tab * tab * tab)
local read_fonts_conf_indeed
read_fonts_conf_indeed = function (start, home, xdg_home,
                                   acc, done, dirs_done,
                                   find_files)

  local paths = fonts_conf_scanner(start)
  if not paths then --- nothing to do
    return acc, done, dirs_done
  end

  for i=1, #paths do
    local pathobj = paths[i]
    local kind, path = pathobj[1], pathobj[2]
    local attributes = pathobj.attributes
    if attributes and attributes.prefix == "xdg" then
      --- this prepends the xdg root (usually ~/.config)
      path = filejoin(xdg_home, path)
    end

    if kind == "dir" then
      if stringsub(path, 1, 1) == "~" then
        path = filejoin(home, stringsub(path, 2))
      end
      --- We exclude paths with texmf in them, as they should be
      --- found anyway; also duplicates are ignored by checking
      --- if they are elements of dirs_done.
      ---
      --- FIXME does this mean we cannot access paths from
      --- distributions (e.g. Context minimals) installed
      --- separately?
      if not (stringfind(path, "texmf") or dirs_done[path]) then
        acc[#acc+1] = path
        dirs_done[path] = true
      end

    elseif kind == "include" then
      --- here the path can be four things: a directory or a file,
      --- in absolute or relative path.
      if stringsub(path, 1, 1) == "~" then
        path = filejoin(home, stringsub(path, 2))
      elseif --- if the path is relative, we make it absolute
        not ( lfsisfile(path) or lfsisdir(path) )
        then
          path = filejoin(filedirname(start), path)
        end
        if  lfsisfile(path)
          and kpsereadable_file(path)
          and not done[path]
          then
            --- we exclude path with texmf in them, as they should
            --- be found otherwise
            acc = read_fonts_conf_indeed(
            path, home, xdg_home,
            acc,  done, dirs_done)
          elseif lfsisdir(path) then --- arrow code ahead
            local config_files = find_files (path, conf_filter)
            for _, filename in next, config_files do
              if not done[filename] then
                acc = read_fonts_conf_indeed(
                filename, home, xdg_home,
                acc,      done, dirs_done)
              end
            end
          end --- match “kind”
        end --- iterate paths
      end

      --inspect(acc)
      --inspect(done)
      return acc, done, dirs_done
    end --- read_fonts_conf_indeed()

--[[doc--
      read_fonts_conf() sets up an accumulator and two sets
      for tracking what’s been done.

      Also, the environment variables HOME and XDG_CONFIG_HOME --
      which are constants anyways -- are expanded so don’t have to
      repeat that over and over again as with the old parser.
      Now they’re just passed on to every call of
      read_fonts_conf_indeed().

      read_fonts_conf() is also the only reference visible outside
      the closure.
--doc]]--

--- list -> (string -> function option -> string list) -> list

local read_fonts_conf = function (path_list, find_files)
  local home      = kpseexpand_path"~" --- could be os.getenv"HOME"
  local xdg_home  = kpseexpand_path"$XDG_CONFIG_HOME"
  if xdg_home == "" then xdg_home = filejoin(home, ".config") end
  local acc       = { } ---> list: paths collected
  local done      = { } ---> set:  files inspected
  local dirs_done = { } ---> set:  dirs in list
  for i=1, #path_list do --- we keep the state between files
    acc, done, dirs_done = read_fonts_conf_indeed(
                                path_list[i], home, xdg_home,
                                acc, done, dirs_done,
                                find_files)
  end
  return acc
end

luaotfload.parsers.read_fonts_conf = read_fonts_conf


