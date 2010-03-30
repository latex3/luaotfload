#!/usr/bin/env texlua
--[[
This file is copyright 2010 Elie Roux and Khaled Hosny and is under CC0
license (see http://creativecommons.org/publicdomain/zero/1.0/legalcode).

This file is a wrapper for the luaotfload's font names module. It is part of the
luaotfload bundle, please see the luaotfload documentation for more info.
--]]

kpse.set_program_name("luatex")

require("luaextra")
require("otfl-font-nms")
require("alt_getopt")

local name = 'mkluatexfontdb'
local version = '1.07' -- same version number as luaotfload

mkluatexfontdb = { } -- just for now, elie is rewriting it anyway
local names    = fonts.names

-- the directory in which the database will be saved, can be overwritten
mkluatexfontdb.directory = names.path.localdir

local log      = logs.report

local function help_msg()
    texio.write(string.format([[
Usage: %s [OPTION]...
    
Rebuild the LuaTeX font database.

Valid options:
  -d --database-dir=DIRECTORY  install the database in the specified directory
  -f --force                   force re-indexing all fonts
  -q --quiet                   don't output anything
  -v --verbose=LEVEL           be more verbose (print the searched directories)
  -vv                          print the loaded fonts
  -vvv                         print all steps of directory searching
  --fc-cache                   run fc-cache before updating database
  --sys                        install the database system-wide
                               (default is only for the current user)
  -V --version                 print version and exit
  -h --help                    print this message

The output database file is named otfl-fonts.lua. By default it is placed
in $TEXMFVAR/luatex-cache/latex/names/.
]], name))
end

local function version_msg()
    texio.write(string.format(
        "%s version %s, database version %s.\n", name, version, names.version))
end

--[[
Command-line processing.
Here we fill cmdargs with the good values, and then analyze it.
--]]

local long_opts = {
    ['database-dir'] = "d",
    force            = "f",
    quiet            = "q",
    help             = "h",
    ['fc-cache']     = 0  ,
    sys              = 0  ,
    verbose          = 1  ,
    version          = "V",
}

local short_opts = "d:fqpvVh"

local function do_run_fc_cache(c)
    --[[
    Function running fc-cache if needed.
    The argument is nil for default, 0 for no fc-cache and 1 for fc-cache.
    Default behaviour is to run fc-cache if available.
    --]]
    if c == 0 then return end
    if not c then
      -- TODO: detect if fc-cache is available
    end
    local toexec = 'fc-cache'
    if os.type == 'windows' then
        toexec = 'fc-cache.exe' -- TODO: to test on a non-cygwin Windows
    end
    log('executing %s...\n', toexec)
    os.execute(toexec)
end

-- a temporary variable, containing the command line option concerning fc-cache
local run_fc_cache = 0
local force_reload = nil

local function process_cmdline()
    local opts, optind, optarg = alt_getopt.get_ordered_opts (arg, short_opts, long_opts)
    local log_level = 1
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
            mkluatexfontdb.directory = optarg [i]
        elseif v == "f" then
            force_reload = 1
        elseif v == "fc-cache" then
            run_fc_cache = 1
        elseif v == "sys" then
            mkluatexfontdb.directory = names.path.systemdir
        end
    end
    if string.match(arg[0], '-sys') then
        mkluatexfontdb.directory = names.path.systemdir
    end
    mkluatexfontdb.directory = fonts.path_normalize(mkluatexfontdb.directory)
    names.set_log_level(log_level)
end

process_cmdline()
do_run_fc_cache(run_fc_cache)

-- the status table is containing correspondances between absolute path and last modification
-- timestamp, it's uses to save time during update, by not reparsing unchanged fonts.
local status = nil
local status_file = mkluatexfontdb.directory .. "/otfl-names-status.lua"
if not force_reload and file.isreadable(status_file) then
    status = dofile(status_file)
end

local function generate(force)
    log("generating font names database.")
    local savepath = mkluatexfontdb.directory
    if not lfs.isdir(savepath) then
        log("creating directory %s", savepath)
        dir.mkdirs(savepath)
        if not lfs.isdir(savepath) then
            texio.write_nl(string.format("Error: cannot create directory '%s', exiting.\n", savepath))
            os.exit(1)
        end
    end
    savepath = savepath .. '/' .. names.path.basename
    local fh = io.open(savepath, 'a+')
    if not fh then
        texio.write_nl(string.format("Error: cannot write file '%s', exiting.\n", savepath))
        os.exit(1)
    end
    fh:close()
    local fontnames
    if not force_reload and file.isreadable(savepath) then
        fontnames = dofile(savepath)
    else
        fontnames = nil
    end
    fontnames, status = names.update(fontnames, status, force)
    log("%s fonts in %s families in the database",
        #fontnames.mappings, #table.keys(fontnames.families))
    io.savedata(savepath, table.serialize(fontnames, true))
    log("saved font names database in %s\n", savepath)
    io.savedata(status_file, table.serialize(status, true))
end

generate(force_reload)
