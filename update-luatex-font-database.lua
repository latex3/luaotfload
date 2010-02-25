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

-- first we import luaotfload-fonts.lua.
-- Basically it 'exports' three usefult things: the two overwritable variables
-- - luaotfload.fonts.basename: the filename of the database
-- - luaotfload.fonts.directory: the directory of the database
-- and the function
-- - luaotfload.fonts.generate: the function to generate the database

local luaotfload_file = kpse.find_file("luaotfload-fonts.lua")
if not luaotfload_file then
    texio.write_nl("Error: cannot find 'luaotfload-fonts.lua', exiting.")
    os.exit(1)
end
dofile(luaotfload_file)

local function help_msg()
    texio.write_nl(string.format([[Usage: %s [OPTION]... 
    
Rebuild the LuaTeX font database.

Valid options:
  -d --dbdir DIRECTORY       writes the database in the specified directory
  -q --quiet                 don't output anything
  -v --verbose               be more verbose (print the searched directories)
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

-- Command-line processing.
-- Here we fill cmdargs with the good values, and then analyze it, setting
-- luaotfload.fonts.log_level luaotfload.fonts.directory if necessary. 
local function process_cmdline()
    local waiting_for_dir = false
    local cmdargs = {}
    for _, varg in ipairs(arg) do
        if varg == "-v" or varg == "--verbose" then
            cmdargs.loglvl = 2
        elseif varg == "-vv" then
            cmdargs.loglvl = 3
        elseif varg == "-vvv" then
            cmdargs.loglvl = 4
        elseif varg == "-q" or varg == "--quiet" then
            cmdargs.loglvl = 0
        elseif varg == "--version" or varg == "-V" then
            cmdargs.version = true
        elseif varg == "--help" or varg == "-h" then
            cmdargs.help = true
        elseif varg == "--sys" then
            cmdargs.sys = true
        elseif varg == '-d' or varg == '--dbdir' then
            waiting_for_dir = true
        elseif string.match(varg, '--dbdir=.+') then
            cmdargs.dbdir = string.match(varg, '--dbdir=(.+)')
        elseif string.match(varg, '-d.+') then
            cmdargs.dbdir = string.match(varg, '-d(.+)')
        elseif waiting_for_dir == true then
            cmdargs.dbdir = string.gsub(varg, '^( *= *)', '')
        else
            texio.write_nl(string.format("Unknown option '%s', ignoring.", varg))
        end
    end
    if cmdargs.help then
        help_msg()
        os.exit(0)
    elseif cmdargs.version then
        version_msg()
        os.exit(0)
    elseif cmdargs.loglvl then
        luaotfload.fonts.log_level = cmdargs.loglvl
    end
    if cmdargs.sys then
        luaotfload.fonts.directory = kpse.expand_var("$TEXMFSYSVAR") .. "/tex/"
    elseif cmdargs.dbdir then
        luaotfload.fonts.directory = cmdargs.dbdir
    end
end

process_cmdline()
luaotfload.fonts.generate()
