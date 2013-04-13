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
local loader_path = assert(kpse.find_file(loader_file, 'tex'),
                           "File '"..loader_file.."' not found")
--texiowrite_nl("("..loader_path..")")
dofile(loader_path) -- FIXME this pollutes stdout with filenames

local config   = config or { }
config.lualibs = config.lualibs or { }
config.lualibs.prefer_merged = false
config.lualibs.load_extended = true

require"lualibs"
require"otfl-basics-gen.lua"
require"otfl-luat-ovr.lua"
require"otfl-font-nms"
require"alt_getopt"

local name    = 'mkluatexfontdb'
local version = '2.1' -- same version number as luaotfload
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

The font database will be saved to
   %s
   %s

]], name, db_src_out, db_bin_out))
end

local function version_msg()
    texiowrite_nl(stringformat(
        "%s version %s, database version %s.\n", name, version, names.version))
end

--[[
Command-line processing.
Here we fill cmdargs with the good values, and then analyze it.
--]]

local long_options = {
    force            = "f",
    quiet            = "q",
    help             = "h",
    verbose          = 1  ,
    version          = "V",
}

local short_options = "fqpvVh"

local force_reload = nil

local function process_cmdline()
    local options, _, _ = alt_getopt.get_ordered_opts (arg, short_options, long_options)
    local log_level = 1
    for _,v in next, options do
        if     v == "q" then
            log_level = 0
        elseif v == "v" then
            if log_level > 0 then
                log_level = log_level + 1
            else
                log_level = 2
            end
        elseif v == "V" then
            version_msg()
            os.exit(0)
        elseif v == "h" then
            help_msg()
            os.exit(0)
        elseif v == "f" then
            force_reload = 1
        end
    end
    names.set_log_level(log_level)
end

local function generate(force)
    local fontnames, saved
    fontnames = names.update(fontnames, force)
    logs.report("fonts in the database", "%i", #fontnames.mappings)
    saved = names.save(fontnames)
    texiowrite_nl("")
end

process_cmdline()
generate(force_reload)
-- vim:tw=71:sw=4:ts=4:expandtab
