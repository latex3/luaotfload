#!/usr/bin/env texlua
-------------------------------------------------------------------------------
--         FILE:  luaotfload-parsers.lua
--  DESCRIPTION:  various lpeg-based parsers used in Luaotfload
-- REQUIREMENTS:  Luaotfload > 2.4
--       AUTHOR:  Philipp Gesang (Phg), <phg42.2a@gmail.com>
--      VERSION:  same as Luaotfload
--      CREATED:  2014-01-14 10:15:20+0100
-------------------------------------------------------------------------------
--

if not modules then modules = { } end modules ['luaotfload-parsers'] = {
  version   = "2.5",
  comment   = "companion to luaotfload-main.lua",
  author    = "Philipp Gesang",
  copyright = "Luaotfload Development Team",
  license   = "GNU GPL v2.0"
}

luaotfload              = luaotfload or { }
luaotfload.parsers      = luaotfload.parsers or { }
local parsers           = luaotfload.parsers

local rawset            = rawset

local lpeg              = require "lpeg"
local P, R, S           = lpeg.P, lpeg.R, lpeg.S
local lpegmatch         = lpeg.match
local C, Cc, Cf         = lpeg.C, lpeg.Cc, lpeg.Cf
local Cg, Cmt, Cs, Ct   = lpeg.Cg, lpeg.Cmt, lpeg.Cs, lpeg.Ct

local kpse              = kpse
local kpseexpand_path   = kpse.expand_path
local kpsereadable_file = kpse.readable_file

local file              = file
local filejoin          = file.join
local filedirname       = file.dirname

local io                = io
local ioopen            = io.open

local log               = luaotfload.log
local logreport         = log.report

local string            = string
local stringsub         = string.sub
local stringfind        = string.find
local stringlower       = string.lower

local mathceil          = math.ceil

local lfs               = lfs
local lfsisfile         = lfs.isfile
local lfsisdir          = lfs.isdir

-------------------------------------------------------------------------------
---                         COMMON PATTERNS
-------------------------------------------------------------------------------

local dot               = P"."
local colon             = P":"
local semicolon         = P";"
local comma             = P","
local noncomma          = 1 - comma
local slash             = P"/"
local backslash         = P"\\"
local equals            = P"="
local dash              = P"-"
local gartenzaun        = P"#"
local lbrk, rbrk        = P"[", P"]"
local squote            = P"'"
local dquote            = P"\""

local newline           = P"\n"
local returnchar        = P"\r"
local spacing           = S" \t\v"
local linebreak         = S"\n\r"
local whitespace        = spacing + linebreak
local ws                = spacing^0
local xmlws             = whitespace^1
local eol               = P"\n\r" + P"\r\n" + linebreak

local digit             = R"09"
local alpha             = R("az", "AZ")
local anum              = alpha + digit
local decimal           = digit^1 * (dot * digit^0)^-1

-------------------------------------------------------------------------------
---                                FONTCONFIG
-------------------------------------------------------------------------------

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

local tag_name          = C(alpha^1)
local comment           = P"<!--" * (1 - P"--")^0 * P"-->"

---> header specifica
local xml_declaration   = P"<?xml" * (1 - P"?>")^0 * P"?>"
local xml_doctype       = P"<!DOCTYPE" * xmlws
                        * "fontconfig" * (1 - P">")^0 * P">"
local header            = xml_declaration^-1
                        * (xml_doctype + comment + xmlws)^0

---> enforce root node
local root_start        = P"<"  * xmlws^-1 * P"fontconfig" * xmlws^-1 * P">"
local root_stop         = P"</" * xmlws^-1 * P"fontconfig" * xmlws^-1 * P">"

local dquote, squote    = P[["]], P"'"
local xml_namestartchar = S":_" + alpha --- ascii only, funk the rest
local xml_namechar      = S":._" + alpha + digit
local xml_name          = xmlws^-1
                        * C(xml_namestartchar * xml_namechar^0)
local xml_attvalue      = dquote * C((1 - S[[%&"]])^1) * dquote * xmlws^-1
                        + squote * C((1 - S[[%&']])^1) * squote * xmlws^-1
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
                            * xmlws^-1
                            * P">"
    local plain             = P"<" * p_tag * xmlws^-1 * P">"
    local node_start        = plain + with_attributes
    local node_stop         = P"</" * p_tag * xmlws^-1 * P">"
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
    logreport("both", 3, "db", "Cannot open fontconfig file %s.", path)
    return
  end
  local raw = fh:read"*all"
  fh:close()

  local confdata = lpegmatch(p_cheapxml, raw)
  if not confdata then
    logreport("both", 3, "db", "Cannot scan fontconfig file %s.", path)
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
      read_fonts_conf_indeed() is called with seven arguments; the
      latter three are tables that represent the state and are
      always returned.
      The first four are
          · the path to the file
          · the expanded $HOME
          · the expanded $XDG_CONFIG_HOME
          · the expanded $XDG_DATA_HOME
--doc]]--
--- string -> string -> string -> tab -> tab -> (tab * tab * tab)
local read_fonts_conf_indeed
read_fonts_conf_indeed = function (start, home, xdg_config_home,
                                   xdg_data_home,
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

    if kind == "dir" then
      if attributes and attributes.prefix == "xdg" then
        path = filejoin(xdg_data_home, path)
      end
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
      if attributes and attributes.prefix == "xdg" then
        path = filejoin(xdg_config_home, path)
      end
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
            path, home, xdg_config_home, xdg_data_home,
            acc,  done, dirs_done)
          elseif lfsisdir(path) then --- arrow code ahead
            local config_files = find_files (path, conf_filter)
            for _, filename in next, config_files do
              if not done[filename] then
                acc = read_fonts_conf_indeed(
                filename, home, xdg_config_home, xdg_data_home,
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

      Also, the environment variables HOME, XDG_DATA_HOME and
      XDG_CONFIG_HOME -- which are constants anyways -- are expanded
      so we don’t have to repeat that over and over again as with the
      old parser. Now they’re just passed on to every call of
      read_fonts_conf_indeed().
--doc]]--

--- list -> (string -> function option -> string list) -> list

local read_fonts_conf = function (path_list, find_files)
  local home      = kpseexpand_path"~" --- could be os.getenv"HOME"
  local xdg_config_home  = kpseexpand_path"$XDG_CONFIG_HOME"
  if xdg_config_home == "" then xdg_config_home = filejoin(home, ".config") end
  local xdg_data_home  = kpseexpand_path"$XDG_DATA_HOME"
  if xdg_data_home == "" then xdg_data_home = filejoin(home, ".local/share") end
  local acc       = { } ---> list: paths collected
  local done      = { } ---> set:  files inspected
  local dirs_done = { } ---> set:  dirs in list
  for i=1, #path_list do --- we keep the state between files
    acc, done, dirs_done = read_fonts_conf_indeed(
                                path_list[i], home, xdg_config_home,
                                xdg_data_home,
                                acc, done, dirs_done,
                                find_files)
  end
  return acc
end

luaotfload.parsers.read_fonts_conf = read_fonts_conf



-------------------------------------------------------------------------------
---                               MISC PARSERS
-------------------------------------------------------------------------------


local trailingslashes   = slash^1 * P(-1)
local stripslashes      = C((1 - trailingslashes)^0)
parsers.stripslashes    = stripslashes

local splitcomma        = Ct((C(noncomma^1) + comma)^1)
parsers.splitcomma      = splitcomma



-------------------------------------------------------------------------------
---                              FONT REQUEST
-------------------------------------------------------------------------------


--[[doc------------------------------------------------------------------------

    The luaotfload font request syntax (see manual)
    has a canonical form:

        \font<csname>=<prefix>:<identifier>:<features>

    where
      <csname> is the control sequence that activates the font
      <prefix> is either “file” or “name”, determining the lookup
      <identifer> is either a file name (no path) or a font
                  name, depending on the lookup
      <features> is a list of switches or options, separated by
                 semicolons or commas; a switch is of the form “+” foo
                 or “-” foo, options are of the form lhs “=” rhs

    however, to ensure backward compatibility we also have
    support for Xetex-style requests.

    for the Xetex emulation see:
    · The XeTeX Reference Guide by Will Robertson, 2011
    · The XeTeX Companion by Michel Goosens, 2010
    · About XeTeX by Jonathan Kew, 2005


    caueat emptor.

        the request is parsed into one of **four** different lookup
        categories: the regular ones, file and name, as well as the
        Xetex compatibility ones, path and anon. (maybe a better choice
        of identifier would be “ambig”.)

        according to my reconstruction, the correct chaining of the
        lookups for each category is as follows:

        | File -> ( db/filename lookup )

        | Name -> ( db/name lookup,
                    db/filename lookup )

        | Path -> ( db/filename lookup,
                    fullpath lookup )

        | Anon -> ( kpse.find_file(),     // <- for tfm, ofm
                    db/name lookup,
                    db/filename lookup,
                    fullpath lookup )

        caching of successful lookups is essential. we now as of v2.2
        have a lookup cache that is stored in a separate file. it
        pertains only to name: lookups, and is described in more detail
        in luaotfload-database.lua.

-------------------------------------------------------------------------------

    One further incompatibility between Xetex and Luatex-Fonts consists
    in their option list syntax: apparently, Xetex requires key-value
    options to be prefixed by a "+" (ascii “plus”) character. We
    silently accept this as well, dropping the first byte if it is a
    plus or minus character.

    Reference: https://github.com/lualatex/luaotfload/issues/79#issuecomment-18104483

--doc]]------------------------------------------------------------------------


local handle_normal_option = function (key, val)
    val = stringlower(val)
    --- the former “toboolean()” handler
    if val == "true"  then
        val = true
    elseif val == "false" then
        val = false
    end
    return key, val
end

--[[doc--

    Xetex style indexing begins at zero which we just increment before
    passing it along to the font loader.  Ymmv.

--doc]]--

local handle_xetex_option = function (key, val)
    val = stringlower(val)
    local numeric = tonumber(val) --- decimal only; keeps colors intact
    if numeric then --- ugh
        if  mathceil(numeric) == numeric then -- integer, possible index
            val = tostring(numeric + 1)
        end
    elseif val == "true"  then
        val = true
    elseif val == "false" then
        val = false
    end
    return key, val
end

--[[doc--

    Instead of silently ignoring invalid options we emit a warning to
    the log.

    Note that we have to return a pair to please rawset(). This creates
    an entry on the resulting features hash which will later be removed
    during set_default_features().

--doc]]--

local handle_invalid_option = function (opt)
    logreport("log", 0, "load", "font option %q unknown.", opt)
    return "", false
end

--[[doc--

    Dirty test if a file: request is actually a path: lookup; don’t
    ask! Note this fails on Windows-style absolute paths. These will
    *really* have to use the correct request.

--doc]]--

local check_garbage = function (_,i, garbage)
    if stringfind(garbage, "/") then
        logreport("log", 0, "load",  --- ffs use path!
                  "warning: path in file: lookups is deprecated; ")
        logreport("log", 0, "load", "use bracket syntax instead!")
        logreport("log", 0, "load",
                  "position: %d; full match: %q",
                  i, garbage)
        return true
    end
    return false
end

local featuresep = comma + semicolon

--- modifiers ---------------------------------------------------------
--[[doc--
    The slash notation: called “modifiers” (Kew) or “font options”
    (Robertson, Goosens)
    we only support the shorthands for italic / bold / bold italic
    shapes, as well as setting optical size, the rest is ignored.
--doc]]--
local style_modifier    = (P"BI" + P"IB" + P"bi" + P"ib" + S"biBI")
                        / stringlower
local size_modifier     = S"Ss" * P"="    --- optical size
                        * Cc"optsize" * C(decimal)
local other_modifier    = P"AAT" + P"aat" --- apple stuff;  unsupported
                        + P"ICU" + P"icu" --- not applicable
                        + P"GR"  + P"gr"  --- sil stuff;    unsupported
local garbage_modifier  = ((1 - colon - slash)^0 * Cc(false))
local modifier          = slash * (other_modifier      --> ignore
                                 + Cs(style_modifier)  --> collect
                                 + Ct(size_modifier)   --> collect
                                 + garbage_modifier)   --> warn
local modifier_list     = Cg(Ct(modifier^0), "modifiers")

--- lookups -----------------------------------------------------------
local fontname          = C((1-S":(/")^1)  --- like luatex-fonts
local unsupported       = Cmt((1-S":(")^1, check_garbage)
local prefixed          = P"name:" * ws * Cg(fontname, "name")
--- initially we intended file: to emulate the behavior of
--- luatex-fonts, i.e. no paths allowed. after all, we do have XeTeX
--- emulation with the path lookup and it interferes with db lookups.
--- turns out fontspec and other widely used packages rely on file:
--- with paths already, so we’ll add a less strict rule here.  anyways,
--- we’ll emit a warning.
                        + P"file:" * ws * Cg(unsupported, "path")
                        + P"file:" * ws * Cg(fontname, "file")
--- EXPERIMENTAL: kpse lookup
                        + P"kpse:" * ws * Cg(fontname, "kpse")
--- EXPERIMENTAL: custom lookup
                        + P"my:" * ws * Cg(fontname, "my")
local unprefixed        = Cg(fontname, "anon")
local path_lookup       = lbrk * Cg(C((1-rbrk)^1), "path") * rbrk

--- features ----------------------------------------------------------
local field_char        = anum + S"+-." --- sic!
local field             = field_char^1
--- assignments are “lhs=rhs”
---              or “+lhs=rhs” (Xetex-style)
--- switches    are “+key” | “-key”
local normal_option     = C(field) * ws * equals * ws * C(field) * ws
local xetex_option      = P"+" * ws * normal_option
local ignore_option     = (1 - equals - featuresep)^1
                        * equals
                        * (1 - featuresep)^1
local assignment        = xetex_option  / handle_xetex_option
                        + normal_option / handle_normal_option
                        + ignore_option / handle_invalid_option
local switch            = P"+" * ws * C(field) * Cc(true)
                        + P"-" * ws * C(field) * Cc(false)
                        +             C(field) * Cc(true)   --- default
local feature_expr      = ws * Cg(assignment + switch) * ws
local option            = feature_expr
local feature_list      = Cf(Ct""
                           * option
                           * (featuresep * option^-1)^0
                           , rawset)
                        * featuresep^-1

--- other -------------------------------------------------------------
--- This rule is present in the original parser. It sets the “sub”
--- field of the specification which allows addressing a specific
--- font inside a TTC container. Neither in Luatex-Fonts nor in
--- Luaotfload is this documented, so we might as well silently drop
--- it. However, as backward compatibility is one of our prime goals we
--- just insert it here and leave it undocumented until someone cares
--- to ask. (Note: afair subfonts are numbered, but this rule matches a
--- string; I won’t mess with it though until someone reports a
--- problem.)
--- local subvalue   = P("(") * (C(P(1-S("()"))^1)/issub) * P(")") -- for Kim
--- Note to self: subfonts apparently start at index 0. Tested with
--- Cambria.ttc that includes “Cambria Math” at 0 and “Cambria” at 1.
--- Other values cause luatex to segfault.
local subfont           = P"(" * Cg((1 - S"()")^1, "sub") * P")"
--- top-level rules ---------------------------------------------------
--- \font\foo=<specification>:<features>
local features          = Cg(feature_list, "features")
local specification     = (prefixed + unprefixed)
                        * subfont^-1
                        * modifier_list^-1
local font_request      = Ct(path_lookup   * (colon^-1 * features)^-1
                           + specification * (colon    * features)^-1)

--  lpeg.print(font_request)
--- v2.5 parser: 1065 rules
--- v1.2 parser:  230 rules

luaotfload.parsers.font_request = font_request

-------------------------------------------------------------------------------
---                                INI FILES
-------------------------------------------------------------------------------

--[[doc--

    Luaotfload uses the pervasive flavor of the INI files that allows '#' in
    addition to ';' to indicate comment lines (see git-config(1) for a
    description of the syntax we’re targeting).

--doc]]--

local truth_ids = {
  ["true"]  = true,
  ["1"]     = true,
  yes       = true,
  on        = true,
  ["false"] = false,
  ["2"]     = false,
  no        = false,
  off       = false,
}

local maybe_cast = function (var)
  local bool = truth_ids[var]
  if bool ~= nil then
    return bool
  end
  return tonumber (var) or var
end
local escape = function (chr, repl)
  return (backslash * P(chr) / (repl or chr))
end
local valid_escapes     = escape "\""
                        + escape "\\"
                        + escape ("n", "\n")
                        + escape ("t", "\t")
                        + escape ("b", "\b")
local comment_char      = semicolon + gartenzaun
local comment_line      = ws * comment_char * (1 - eol)^0 * eol
local blank_line        = ws * eol
local skip_line         = comment_line + blank_line
local ini_id_char       = alpha + (dash / "_")
local ini_id            = Cs(alpha * ini_id_char^0) / stringlower
local ini_value_char    = (valid_escapes + (1 - newline - backslash - comment_char))
local ini_value         = (Cs (ini_value_char^0) / string.strip)
                        * (comment_char * (1 - eol)^0)^-1
local ini_string_char   = (valid_escapes + (1 - newline - dquote - backslash))
local ini_string        = dquote
                        * Cs (ini_string_char^0)
                        * dquote

local ini_heading_title = Ct (Cg (ini_id, "title")
                            * (ws * Cg (ini_string / stringlower, "subtitle"))^-1)
local ini_heading       = lbrk * ws
                        * Cg (ini_heading_title, "section")
                        * ws * rbrk * ws * eol

local ini_variable_full = Cg (ws
                            * ini_id
                            * ws
                            * equals
                            * ws
                            * (ini_string + (ini_value / maybe_cast))
                            * ws
                            * eol)
local ini_variable_true = Cg (ws * ini_id * ws * eol * Cc (true))
local ini_variable      = ini_variable_full
                        + ini_variable_true
                        + skip_line
local ini_variables     = Cg (Cf (Ct "" * ini_variable^0, rawset), "variables")

local ini_section       = Ct (ini_heading * ini_variables)
local ini_sections      = skip_line^0 * ini_section^0
local config            = Ct (ini_sections)

--[=[doc--

    The INI parser converts an input of the form

            [==[
              [foo]
              bar = baz
              xyzzy = no
              buzz

              [lavernica "brutalitops"]
              # It’s a locomotive that runs on us.
                laan-ev = zip zop zooey   ; jib-jab
              Crouton = "Fibrosis \"\\ # "

            ]==]

    to a Lua table of the form

            { { section = { title = "foo" },
                variables = { bar = "baz",
                              xyzzy = false,
                              buzz = true } },
              { section = { title = "boing",
                            subtitle = "brutalitops" },
                variables = { ["laan-ev"] = "zip zop zooey",
                              crouton = "Fibrosis \"\\ # " } } }

--doc]=]--

luaotfload.parsers.config = config

-- vim:ft=lua:tw=71:et:sts=4:ts=8
