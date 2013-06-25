#!/usr/bin/env texlua
-----------------------------------------------------------------------
--         FILE:  luaotfload-tool.lua
--  DESCRIPTION:  database functionality
-- REQUIREMENTS:  luaotfload 2.2
--       AUTHOR:  Khaled Hosny, Élie Roux, Philipp Gesang
--      VERSION:  2.3
--      LICENSE:  GPL v2
--     MODIFIED:  2013-06-02 19:23:54+0200
-----------------------------------------------------------------------

--[[doc--

This file was originally written (as \fileent{mkluatexfontdb.lua}) by
Elie Roux and Khaled Hosny and, as a derived work of ConTeXt, is
provided under the terms of the GPL v2.0 license as printed in full
text in the manual (luaotfload.pdf).

    \url{http://www.gnu.org/licenses/old-licenses/gpl-2.0.html}.

This file is a wrapper for the luaotfload font names module
(luaotfload-database.lua). It is part of the luaotfload bundle, please
see the luaotfload documentation for more info. Report bugs to

    \url{https://github.com/lualatex/luaotfload/issues}.

--doc]]--

--[[doc--

    We test for Lua 5.1 by means of capability detection to see if
    we’re running an outdated Luatex.  If so, we hand over control to
    the legacy db runner.

    \url{http://lua-users.org/wiki/LuaVersionCompatibility}

--doc]]--

kpse.set_program_name"luatex"

if _G.getfenv then
    local oldscript = kpse.find_file"luaotfload-legacy-tool.lua"
    return require(oldscript)
end

local stringexplode   = string.explode
local stringformat    = string.format
local stringlower     = string.lower
local tableconcat     = table.concat
local texiowrite      = texio.write
local texiowrite_nl   = texio.write_nl


local C, Ct, P, S  = lpeg.C, lpeg.Ct, lpeg.P, lpeg.S
local lpegmatch    = lpeg.match

local loader_file = "luatexbase.loader.lua"
local loader_path = assert(kpse.find_file(loader_file, "lua"),
                           "File '"..loader_file.."' not found")


string.quoted = string.quoted or function (str)
  return string.format("%q",str) 
end

require(loader_path)

--[[doc--
Depending on how the script is called we change its behavior.
For backwards compatibility, moving or symlinking the script to a
file name starting with \fileent{mkluatexfontdb} will cause it to
trigger a database update on every run.
Running as \fileent{luaotfload-tool} -- the new name -- will do this upon
request only.

There are two naming conventions followed here: firstly that of
utilities such as \fileent{mktexpk}, \fileent{mktexlsr} and the likes,
and secondly that of \fileent{fmtutil}.
After support for querying the database was added, the latter appeared
to be the more appropriate.
--doc]]--

config              = config or { }
local config        = config
config.luaotfload   = config.luaotfload or { }

do -- we don’t have file.basename and the likes yet, so inline parser ftw
    local slash        = P"/"
    local dot          = P"."
    local noslash      = 1 - slash
    local slashes      = slash^1
    local path         =  slashes^-1 * (noslash^1 * slashes)^1
    local thename      = (1 - slash - dot)^1
    local extension    = dot * (1 - slash - dot)^1
    local p_basename   = path^-1 * C(thename) * extension^-1 * P(-1)

    local self = lpegmatch(p_basename, stringlower(arg[0]))
    if self == "luaotfload-tool" then
        config.luaotfload.self = "luaotfload-tool"
    else
        config.luaotfload.self = "mkluatexfontdb"
    end
end

config.lualibs                  = config.lualibs or { }
config.lualibs.verbose          = false
config.lualibs.prefer_merged    = true
config.lualibs.load_extended    = false

require "lualibs"

--- prepare directories: the cache function in Luatex-Fonts
--- checks for writable directory only on startup, so everything
--- has to be laid out before we load basics-gen

local cachepath = kpse.expand_var "$TEXMFVAR"
if not lfs.isdir(cachepath) then
    dir.mkdirs(cachepath)
    if not lfs.isdir(cachepath) then
        texiowrite_nl(stringformat(
            "ERROR could not create directory %s", cachepath))
    end
end

--[[doc--
\fileent{luatex-basics-gen.lua} calls functions from the
\luafunction{texio.*} library; too much for our taste.
We intercept them with dummies.
--doc]]--

local dummy_function = function ( ) end
local backup_write, backup_write_nl  = texio.write, texio.write_nl

texio.write, texio.write_nl          = dummy_function, dummy_function
require"luaotfload-basics-gen.lua"
texio.write, texio.write_nl          = backup_write, backup_write_nl

require"luaotfload-override.lua"  --- this populates the logs.* namespace
require"luaotfload-database"
require"alt_getopt"

local version  = "2.3" -- same version number as luaotfload
local names    = fonts.names

local sanitize_string = names.sanitize_string

local db_src_out = names.path.dir.."/"..names.path.basename
local db_bin_out = file.replacesuffix(db_src_out, "luc")

local help_messages = {
    ["luaotfload-tool"] = [[

Usage: %s [OPTION]...
    
Operations on the LuaTeX font database.

This tool is part of the luaotfload package. Valid options are:

-------------------------------------------------------------------------------
                             VERBOSITY AND LOGGING

  -q --quiet                   don't output anything
  -v --verbose=LEVEL           be more verbose (print the searched directories)
  -vv                          print the loaded fonts
  -vvv                         print all steps of directory searching
  --log=stdout                 redirect log output to stdout

  -V --version                 print version and exit
  -h --help                    print this message

  --alias=<name>               force behavior of “luaotfload-tool” or legacy
                               “mkluatexfontdb”

-------------------------------------------------------------------------------
                                   DATABASE

  -u --update                  update the database
  -f --force                   force re-indexing all fonts
  -l --flush-lookups           empty lookup cache of font requests
  -D --dry-run                 skip loading of fonts, just scan
  -p --prefer-texmf            prefer fonts in the TEXMF over system fonts

  --find="font name"           query the database for a font name
  -F --fuzzy                   look for approximate matches if --find fails
  --limit=n                    limit display of fuzzy matches to <n>
                               (default: n = 1)
  -i --info                    display font metadata

  --list=<criterion>           output list of entries by field <criterion>
  --list=<criterion>:<value>   restrict to entries with <criterion>=<value>
  --fields=<f1>,<f2>,…,<fn>    which fields <f> to print with --list
  -b --show-blacklist          show blacklisted files

The font database will be saved to
   %s
   %s

-------------------------------------------------------------------------------
                                   FONT CACHE

  --cache=<directive>          operate on font cache, where <directive> is
                               “show”, “purge”, or “erase”

]],
    mkluatexfontdb = [[

Usage: %s [OPTION]...
    
Rebuild or update the LuaTeX font database.

Valid options:
  -f --force                   force re-indexing all fonts
  -q --quiet                   don't output anything
  -v --verbose=LEVEL           be more verbose (print the searched directories)
  -vv                          print the loaded fonts
  -vvv                         print all steps of directory searching
  -V --version                 print version and exit
  -h --help                    print this message
  --alias=<name>               force behavior of “luaotfload-tool” or legacy
                               “mkluatexfontdb”

The font database will be saved to
   %s
   %s

]],
}

local help_msg = function ( )
    local template = help_messages[config.luaotfload.self]
                  or help_messages["luaotfload-tool"]
    texiowrite_nl(stringformat(template,
                               config.luaotfload.self,
                               db_src_out,
                               db_bin_out))
end

local version_msg = function ( )
    texiowrite_nl(stringformat(
        "%s version %s, database version %s.\n",
        config.luaotfload.self, version, names.version))
end

local tw = 80
local print_font_name = function (name)
    local s = "-- " .. name .. " "
    s = s .. string.rep("-", tw-string.len(s))
    texiowrite_nl (s)
    texiowrite_nl ""
end

local info_fmt = [[%13s:  %s]]
local warn_fmt = [[(%d %s)]]

local show_info_items = function (fontinfo)
    local items    = table.sortedkeys(fontinfo)
    print_font_name(fontinfo.fullname)
    for n = 1, #items do
        local item = items[n]
        texiowrite_nl(stringformat(
            info_fmt, item, fontinfo[item]))
    end
    texiowrite_nl ""
end

local p_eol     = S"\n\r"^1
local p_space   = S" \t\v"^0
local p_line    = p_space * C((1 - p_eol)^1)^-1
local p_lines   = Ct(p_line * (p_eol^1 * p_line^-1)^0)

local show_fontloader_warnings = function (ws)
    local nws = #ws
    texiowrite_nl(stringformat(
        [[* the fontloader emitted %d warnings *]],
        nws, name))
    for i=1, nws do
        local w = ws[i]
        texiowrite_nl (stringformat("%d:", i))
        local lines = lpegmatch(p_lines, w)
        for i=1, #lines do
            local line = lines[i]
            texiowrite_nl("  · " .. line)
        end
        texiowrite_nl ""
    end
end

local show_full_info = function (path, subfont, warnings)
    local rawinfo, warn = fontloader.open(path, subfont)
    if warnings then
        show_fontloader_warnings(warn)
    end
    if not rawinfo then
        texiowrite_nl(stringformat([[cannot open font %s]], path))
        return
    end
    local fullinfo = fontloader.to_table(rawinfo)
    fontloader.close(rawinfo)
end

--- Subfonts returned by fontloader.info() do not correspond
--- to the actual indices required by fontloader.open(), so
--- we try and locate the correct one by matching the request
--- against the full name.

local subfont_by_name
subfont_by_name = function (lst, askedname, n)
    if not n then
        return subfont_by_name (lst, askedname, 1)
    end

    local font = lst[n]
    if font then
        if sanitize_string(font.fullname) == askedname then
            return font
        end
        return subfont_by_name (lst, askedname, n+1)
    end
    return false
end

--[[doc--
The font info knows two levels of detail:

    a)  basic information returned by fontloader.info(); and
    b)  detailed information that is a subset of the font table
        returned by fontloader.open().
--doc]]--

local show_font_info = function (basename, askedname, detail, warnings)
    local filenames = names.data.filenames
    local index     = filenames.base[basename]
    local fullname  = filenames.full[index]
    askedname = sanitize_string(askedname)
    if not fullname then -- texmf
        fullname = resolvers.findfile(basename)
    end
    if fullname then
        local shortinfo = fontloader.info(fullname)
        local nfonts   = #shortinfo
        if nfonts > 0 then -- true type collection
            local subfont
            if askedname then
                logs.names_report(true, 1, "resolve",
                    [[%s is part of the font collection %s]],
                    askedname, basename)
                subfont = subfont_by_name(shortinfo, askedname)
            end
            if subfont then
                show_info_items(subfont)
                if detail == true then
                    show_full_info(fullname, subfont, warnings)
                end
            else -- list all subfonts
                logs.names_report(true, 1, "resolve",
                    [[%s is a font collection]], basename)
                for subfont = 1, nfonts do
                    logs.names_report(true, 1, "resolve",
                        [[showing info for font no. %d]], n)
                    show_info_items(shortinfo[subfont])
                    if detail == true then
                        show_full_info(fullname, subfont, warnings)
                    end
                end
            end
        else
            show_info_items(shortinfo)
            if detail == true then
                show_full_info(fullname, subfont, warnings)
            end
        end
    else
        logs.names_report(true, 1, "resolve",
            "font %s not found", filename)
    end
end

--[[--
Running the scripts triggers one or more actions that have to be
executed in the correct order. To avoid duplication we track them in a
set.
--]]--

local action_sequence = {
    "loglevel", "help",     "version", "blacklist", "cache",
    "flush",    "generate", "list",    "query",
}
local action_pending  = table.tohash(action_sequence, false)

action_pending.loglevel = true  --- always set the loglevel
action_pending.generate = false --- this is the default action

local actions = { } --- (jobspec -> (bool * bool)) list

actions.loglevel = function (job)
    logs.set_loglevel(job.log_level)
    logs.names_report("info", 3, "util",
                      "setting log level", "%d", job.log_level)
    logs.names_report("log", 0, "util", "lua=%s", _VERSION)
    return true, true
end

actions.version = function (job)
    version_msg()
    return true, false
end

actions.help = function (job)
    help_msg()
    return true, false
end

actions.blacklist = function (job)
    names.read_blacklist()
    local n = 0
    for n, entry in next, table.sortedkeys(fonts.names.blacklist) do
        texiowrite_nl(stringformat("(%d %s)", n, entry))
    end
    return true, false
end

actions.generate = function (job)
    local fontnames, savedname
    fontnames = names.update(fontnames, job.force_reload, job.dry_run)
    logs.names_report("info", 2, "db",
        "Fonts in the database: %i", #fontnames.mappings)
    local success = names.save(fontnames)
    if success then
        return true, true
    end
    return false, false
end

actions.flush = function (job)
    local success, lookups = names.flush_lookup_cache()
    if success then
        local success = names.save_lookups()
        if success then
            logs.names_report("info", 2, "cache", "Lookup cache emptied")
            return true, true
        end
    end
    return false, false
end

local cache_directives = {
    ["purge"] = names.purge_cache,
    ["erase"] = names.erase_cache,
    ["show"]  = names.show_cache,
}

actions.cache = function (job)
    local directive = cache_directives[job.cache]
    if not directive or type(directive) ~= "function" then
        logs.names_report("info", 2, "cache",
                          "Invalid font cache directive %s.", job.cache)
        return false, false
    end
    if directive() then
        return true, true
    end
    return false, false
end

actions.query = function (job)

    local query = job.query
    local tmpspec = {
        name          = query,
        lookup        = "name",
        specification = "name:" .. query,
        optsize       = 0,
    }

    local foundname, subfont, success =
        fonts.names.resolve(nil, nil, tmpspec)

    if success then
        logs.names_report(false, 0,
            "resolve", "Font “%s” found!", query)
        if subfont then
            logs.names_report(false, 0, "resolve",
                "Resolved file name “%s”, subfont nr. “%s”",
                foundname, subfont)
        else
            logs.names_report(false, 0,
                "resolve", "Resolved file name “%s”", foundname)
        end
        if job.show_info then
            show_font_info(foundname, query, job.full_info, job.warnings)
        end
    else
        logs.names_report(false, 0,
            "resolve", "Cannot find “%s”.", query)
        if job.fuzzy == true then
            logs.names_report(false, 0,
                "resolve", "Looking for close matches, this may take a while ...")
            local success = fonts.names.find_closest(query, job.fuzzy_limit)
        end
    end
    return true, true
end

---         --list=<criterion>
---         --list=<criterion>:<value>
---
---         --list=<criterion>          --fields=<f1>,<f2>,<f3>,...<fn>

local get_fields get_fields = function (entry, fields, acc, n)
    if not acc then
        return get_fields(entry, fields, { }, 1)
    end

    local field = fields[n]
    if field then
        local value = entry[field]
        acc[#acc+1] = value or false
        return get_fields(entry, fields, acc, n+1)
    end
    return acc
end

local comma       = P","
local noncomma    = 1-comma
local split_comma = Ct((C(noncomma^1) + comma)^1)

local separator = "\t" --- could be “,” for csv

local format_fields format_fields = function (fields, acc, n)
    if not acc then
        return format_fields(fields, { }, 1)
    end

    local field = fields[n]
    if field ~= nil then
        if field == false then
            acc[#acc+1] = "<none>"
        else
            acc[#acc+1] = tostring(field)
        end
        return format_fields(fields, acc, n+1)
    end
    return tableconcat(acc, separator)
end

local set_primary_field
set_primary_field = function (fields, addme, acc, n)
    if not acc then
        return set_primary_field(fields, addme, { addme }, 1)
    end

    local field = fields[n]
    if field then
        if field ~= addme then
            acc[#acc+1] = field
        end
        return set_primary_field(fields, addme, acc, n+1)
    end
    return acc
end

actions.list = function (job)
    local criterion     = job.criterion

    local asked_fields  = job.asked_fields
    if asked_fields then
        asked_fields = lpegmatch(split_comma, asked_fields)
    else
        --- some defaults
        asked_fields = { "fullname", "version", }
    end

    if not names.data then
        names.data = names.load()
    end

    local mappings  = names.data.mappings
    local nmappings = #mappings

    if criterion == "*" then
        logs.names_report(false, 1, "list", "all %d entries", nmappings)
        for i=1, nmappings do
            local entry     = mappings[i]
            local fields    = get_fields(entry, asked_fields)
            --- we could collect these instead ...
            local formatted = format_fields(fields)
            texiowrite_nl(formatted)
        end

    else
        criterion = stringexplode(criterion, ":") --> { field, value }
        local asked_value  = criterion[2]
        criterion          = criterion[1]
        asked_fields       = set_primary_field(asked_fields, criterion)

        logs.names_report(false, 1, "list", "by %s", criterion)

        --- firstly, build a list of fonts to operate on
        local targets = { }
        if asked_value then --- only those whose value matches
            logs.names_report(false, 2, "list", "restricting to value %s", asked_value)
            for i=1, nmappings do
                local entry = mappings[i]
                if  entry[criterion]
                and tostring(entry[criterion]) == asked_value
                then
                    targets[#targets+1] = entry
                end
            end

        else --- whichever have the field, sorted
            local categories, by_category = { }, { }
            for i=1, nmappings do
                local entry = mappings[i]
                local value = entry[criterion]
                if value then
                    --value = tostring(value)
                    local entries = by_category[value]
                    if not entries then
                        entries = { entry }
                        categories[#categories+1] = value
                    else
                        entries[#entries+1] = entry
                    end
                    by_category[value] = entries
                end
            end
            table.sort(categories)

            for i=1, #categories do
                local entries = by_category[categories[i]]
                for j=1, #entries do
                    targets[#targets+1] = entries[j]
                end
            end
        end
        local ntargets = #targets
        logs.names_report(false, 2, "list", "%d entries", ntargets)

        --- now, output the collection
        for i=1, ntargets do
            local entry         = targets[i]
            local fields        = get_fields(entry, asked_fields)
            local formatted     = format_fields(fields)
            texiowrite_nl(formatted)
        end
    end

    return true, true
end

--[[--
Command-line processing.
mkluatexfontdb.lua relies on the script alt_getopt to process argv and
analyzes its output.

TODO with extended lualibs we have the functionality from the
environment.* namespace that could eliminate the dependency on
alt_getopt.
--]]--

local process_cmdline = function ( ) -- unit -> jobspec
    local result = { -- jobspec
        force_reload = nil,
        full_info    = false,
        warnings     = false,
        criterion    = "",
        query        = "",
        log_level    = 0, --- 2 is approx. the old behavior
    }

    local long_options = {
        alias              = 1,
        cache              = 1,
        ["dry-run"]        = "D",
        ["flush-lookups"]  = "l",
        fields             = 1,
        find               = 1,
        force              = "f",
        fuzzy              = "F",
        help               = "h",
        info               = "i",
        inspect            = "I",
        limit              = 1,
        list               = 1,
        log                = 1,
        ["prefer-texmf"]   = "p",
        quiet              = "q",
        ["show-blacklist"] = "b",
        update             = "u",
        verbose            = 1  ,
        version            = "V",
        warnings           = "w",
    }

    local short_options = "bDfFiIlpquvVhw"

    local options, _, optarg =
        alt_getopt.get_ordered_opts (arg, short_options, long_options)

    local nopts = #options
    for n=1, nopts do
        local v = options[n]
        if     v == "q" then
            result.log_level = 0
        elseif v == "u" then
            action_pending["generate"] = true
        elseif v == "v" then
            if result.log_level > 0 then
                result.log_level = result.log_level + 1
            else
                result.log_level = 2
            end
        elseif v == "V" then
            action_pending["version"] = true
        elseif v == "h" then
            action_pending["help"] = true
        elseif v == "f" then
            result.update       = true
            result.force_reload = 1
        elseif v == "verbose" then
            local lvl = optarg[n]
            if lvl then
                lvl = tonumber(lvl)
                result.log_level = lvl
                if lvl > 2 then
                    result.warnings = true
                end
            end
        elseif v == "w" then
            result.warnings = true
        elseif v == "log" then
            local str = optarg[n]
            if str then
                logs.set_logout(str)
            end
        elseif v == "find" then
            action_pending["query"] = true
            result.query = optarg[n]
        elseif v == "F" then
            result.fuzzy = true
        elseif v == "limit" then
            local lim = optarg[n]
            if lim then
                result.fuzzy_limit = tonumber(lim)
            end
        elseif v == "i" then
            result.show_info = true
        elseif v == "I" then
            result.show_info = true
            result.full_info = true
        elseif v == "alias" then
            config.luaotfload.self = optarg[n]
        elseif v == "l" then
            action_pending["flush"] = true
        elseif v == "list" then
            action_pending["list"] = true
            result.criterion = optarg[n]
        elseif v == "fields" then
            result.asked_fields = optarg[n]
        elseif v == "cache" then
            action_pending["cache"] = true
            result.cache = optarg[n]
        elseif v == "D" then
            result.dry_run = true
        elseif v == "p" then
            config.luaotfload.prioritize = "texmf"
        elseif v == "b" then
            action_pending["blacklist"] = true
        end
    end

    if config.luaotfload.self == "mkluatexfontdb" then
        action_pending["generate"] = true
        result.log_level = math.max(2, result.log_level)
        logs.set_logout"stdout"
    end
    return result
end

local main = function ( ) -- unit -> int
    local retval    = 0
    local job       = process_cmdline()

--    inspect(action_pending)
--    inspect(job)

    for i=1, #action_sequence do
        local actionname = action_sequence[i]
        local exit       = false
        if action_pending[actionname] then
            logs.names_report("log", 3, "util", "preparing for task",
                              "%s", actionname)

            local action             = actions[actionname]
            local success, continue  = action(job)

            if not success then
                logs.names_report(false, 0, "util",
                    "could not finish task", "%s", actionname)
                retval = -1
                exit   = true
            elseif not continue then
                logs.names_report(false, 3, "util",
                    "task completed, exiting", "%s", actionname)
                exit   = true
            else
                logs.names_report(false, 3, "util",
                    "task completed successfully", "%s", actionname)
            end
        end
        if exit then break end
    end

    texiowrite_nl""
    return retval
end

return main()

-- vim:tw=71:sw=4:ts=4:expandtab
