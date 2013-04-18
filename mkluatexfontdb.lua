#!/usr/bin/env texlua
--[[
This file was originally written by Elie Roux and Khaled Hosny and is under CC0
license (see http://creativecommons.org/publicdomain/zero/1.0/legalcode).

This file is a wrapper for the luaotfload's font names module. It is part of the
luaotfload bundle, please see the luaotfload documentation for more info.
--]]

kpse.set_program_name"luatex"

local stringformat  = string.format
local texiowrite_nl = texio.write_nl

-- First we need to be able to load module (code copied from
-- luatexbase-loader.sty):
local loader_file = "luatexbase.loader.lua"
local loader_path = assert(kpse.find_file(loader_file, "lua"),
                           "File '"..loader_file.."' not found")

--texiowrite_nl("("..loader_path..")")
dofile(loader_path) -- FIXME this pollutes stdout with filenames

_G.config      = _G.config or { }
local config   = _G.config

config.lualibs                  = config.lualibs or { }
config.lualibs.prefer_merged    = false
config.lualibs.load_extended    = false

require"lualibs"
require"otfl-basics-gen.lua"
require"otfl-luat-ovr.lua"  --- this populates the logs.* namespace
require"otfl-font-nms"
require"alt_getopt"

local name    = "mkluatexfontdb"
local version = "2.2" -- same version number as luaotfload
local names    = fonts.names

local db_src_out = names.path.dir.."/"..names.path.basename
local db_bin_out = file.replacesuffix(db_src_out, "luc")
local function help_msg()
    texiowrite_nl(stringformat([[

Usage: %s [OPTION]...
    
Rebuild the LuaTeX font database.

Valid options:
  -f --force                   force re-indexing all fonts
  -q --quiet                   don't output anything
  -v --verbose=LEVEL           be more verbose (print the searched directories)
  -vv                          print the loaded fonts
  -vvv                         print all steps of directory searching
  -V --version                 print version and exit
  -h --help                    print this message
  --find="font name"           query the database for a font name
  -F --fuzzy                   look for approximate matches if --find fails

  --log=stdout                 redirect log output to stdout

The font database will be saved to
   %s
   %s

]], name, db_src_out, db_bin_out))
end

local function version_msg()
    texiowrite_nl(stringformat(
        "%s version %s, database version %s.\n",
        name, version, names.version))
end

--[[--
Running the scripts triggers one or more actions that have to be
executed in the correct order. To avoid duplication we track them in a
set.
--]]--

local action_sequence = { "loglevel", "help", "version", "generate", "query" }
local action_pending  = table.tohash(action_sequence, false)

action_pending.loglevel = true --- always set the loglevel
action_pending.generate = true --- this is the default action

local actions = { } --- (jobspec -> (bool * bool)) list

actions.loglevel = function (job)
    logs.set_loglevel(job.log_level)
    logs.names_report("log", 2,
                      "setting log level", "%d", job.log_level)
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

actions.generate = function (job)
    local fontnames, savedname
    fontnames = names.update(fontnames, job.force_reload)
    logs.names_report("log", 0, "fonts in the database",
                      "%i", #fontnames.mappings)
    savedname = names.save(fontnames)
    if savedname then --- FIXME have names.save return bool
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

    local foundname, _whatever, success =
        fonts.names.resolve(nil, nil, tmpspec)

    if success then
        logs.names_report(false, 0,
            "resolve", "Font “%s” found!", query)
        logs.names_report(false, 0,
            "resolve", "Resolved file name “%s”:", foundname)
    else
        logs.names_report(false, 0,
            "resolve", "Cannot find “%s”.", query)
        if job.fuzzy == true then
            logs.names_report(false, 2,
                "resolve", "Looking for close matches, this may take a while ...")
            local success = fonts.names.find_closest(query, job.fuzzy_limit)
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
        query        = "",
        log_level    = 1,
    }

    local long_options = {
        force            = "f",
        help             = "h",
        log              = 1,
        quiet            = "q",
        verbose          = 1  ,
        version          = "V",
        find             = 1,
        fuzzy            = "F",
        limit            = 1,
    }

    local short_options = "fFqvVh"

    local options, _, optarg =
        alt_getopt.get_ordered_opts (arg, short_options, long_options)

    local nopts = #options
    for n=1, nopts do
        local v = options[n]
        if     v == "q" then
            result.log_level = 0
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
            result.force_reload = 1
        elseif v == "verbose" then
            local lvl = optarg[n]
            if lvl then
                result.log_level = tonumber(lvl)
            end
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
        end
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
            logs.names_report("log", 3, "preparing for task",
                              "%s", actionname)

            local action             = actions[actionname]
            local success, continue  = action(job)

            if not success then
                logs.names_report(false, 0, "could not finish task",
                                  "%s", actionname)
                retval = -1
                exit   = true
            elseif not continue then
                logs.names_report(false, 3, "task completed, exiting",
                                  "%s", actionname)
                exit   = true
            else
                logs.names_report(false, 3, "task completed successfully",
                                  "%s", actionname)
            end
        end
        if exit then break end
    end

    texiowrite_nl""
    return retval
end

return main()

-- vim:tw=71:sw=4:ts=4:expandtab
