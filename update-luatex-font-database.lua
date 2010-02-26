#!/usr/bin/env texlua
-- This file is copyright 2010 Elie Roux and Khaled Hosny and is under CC0
-- license (see http://creativecommons.org/publicdomain/zero/1.0/legalcode).
--
-- This file is a wrapper for the luaotfload-fonts.lua script.
-- It is part of the luaotfload bundle, please see the luaotfload documentation
-- for more info.

kpse.set_program_name("luatex")

local name = 'update-luatex-font-database'
local version = '1.07' -- same version number as luaotfload

--[[
 first we import luaotfload-fonts.lua.
 Basically it 'exports' three usefult things: the two overwritable variables
 - luaotfload.fonts.basename: the filename of the database
 - luaotfload.fonts.directory: the directory of the database
 and the function
 - luaotfload.fonts.generate: the function to generate the database
]]

require("luaotfload-fonts")
require("alt_getopt")

local function help_msg()
    texio.write_nl(string.format([[Usage: %s [OPTION]...
    
Rebuild the LuaTeX font database.

Valid options:
  -d --dbdir DIRECTORY       writes the database in the specified directory
  -q --quiet                 don't output anything
  -v --verbose=LEVEL         be more verbose (print the searched directories)
  -vv                        print the loaded fonts
  -vvv                       print all steps of directory searching
  -V --version               prints the version and exits
  -h --help                  prints this message
  --sys                      writes the database for the whole system
                             (default is only for the user)

The output database file is named otfl-fonts.lua.
]], name))
end

local function version_msg()
    texio.write_nl(string.format(
        "%s version %s, database version %s.\n", name, version, luaotfload.fonts.version))
end

--[[
 Command-line processing.
 Here we fill cmdargs with the good values, and then analyze it, setting
 luaotfload.fonts.log_level luaotfload.fonts.directory if necessary.
]]

local long_opts = {
    dbdir   = "d",
    quiet   = "q",
    verbose = 1,
    version = "V",
    help    = "h",
    sys     = 0,
}

local short_opts = "d:qvVh"

local log_level = 1

local function process_cmdline()
    local opts, optind, optarg = alt_getopt.get_ordered_opts (arg, short_opts, long_opts)
    for i,v in ipairs(opts) do
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
        elseif v == "d" then
            luaotfload.fonts.directory = optarg [i]
        elseif v == "sys" then
            luaotfload.fonts.directory = kpse.expand_var("$TEXMFSYSVAR") .. "/tex/"
        end
    end
    luaotfload.fonts.log_level = log_level
end

process_cmdline()
luaotfload.fonts.generate()
