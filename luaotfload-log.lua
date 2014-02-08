if not modules then modules = { } end modules ["luaotfload-log"] = {
    version   = "2.5",
    comment   = "companion to Luaotfload",
    author    = "Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "Luaotfload Development Team",
    license   = "GNU GPL v2.0"
}

--[[doc--
The logging system is slow in general, as we always have the function
call overhead even if we aren’t going to output anything. On the other
hand, the more efficient approach followed by Context isn’t an option
because we lack a user interface to toggle per-subsystem tracing.
--doc]]--

local module_name       = "luaotfload" --- prefix for messages

local ioopen            = io.open
local iowrite           = io.write
local lfsisdir          = lfs.isdir
local lfsisfile         = lfs.isfile
local md5sumhexa        = md5.sumhexa
local osdate            = os.date
local ostime            = os.time
local select            = select
local stringformat      = string.format
local stringsub         = string.sub
local tableconcat       = table.concat
local texiowrite_nl     = texio.write_nl
local texiowrite        = texio.write
local type              = type

local dummyfunction     = function () end

local texjob = false
if tex and (tex.jobname or tex.formatname) then
    --- TeX
    texjob = true
end

local loglevel = 0 --- default
local logout   = "log"

--- int -> bool
local set_loglevel = function (n)
    if type(n) == "number" then
        loglevel = n
    end
    return true
end
logs.setloglevel    = set_loglevel
logs.set_loglevel   = set_loglevel
logs.set_log_level  = set_loglevel --- accomodating lazy typists

--- unit -> int
local get_loglevel = function ( )
    return loglevel
end
logs.getloglevel    = get_loglevel
logs.get_loglevel   = get_loglevel
logs.get_log_level  = get_loglevel

local writeln  --- pointer to terminal/log writer
local statusln --- terminal writer that reuses the current line
local first_status = true --- indicate the begin of a status region

local log_msg = [[
logging output redirected to %s
to monitor the progress run "tail -f %s" in another terminal
]]

local tmppath = os.getenv "TMPDIR" or "/tmp"

local choose_logfile = function ( )
    if lfsisdir (tmppath) then
        local fname
        repeat --- ensure that file of that name doesn’t exist
            --- TODO this could use os.uuid() instead of md5
            fname = tmppath .. "/luaotfload-log-"
                            .. stringsub (md5sumhexa (ostime ()), 1, 8)
        until not lfsisfile (fname)
        iowrite (stringformat (log_msg, fname, fname))
        return ioopen (fname, "w")
    end
    --- missing /tmp
    return false
end

local set_logout = function (s, finalizers)
    if s == "stdout" then
        logout = "redirect"
    elseif s == "file" then --- inject custom logger
        logout = "redirect"
        local chan = choose_logfile ()
        chan:write (stringformat ("logging initiated at %s",
                                  osdate ("%F %T", ostime ())))
        local writefile = function (...)
            if select ("#", ...) == 2 then
                chan:write (select (2, ...))
            else
                chan:write (select (1, ...))
            end
        end
        local writefile_nl= function (...)
            chan:write "\n"
            if select ("#", ...) == 2 then
                chan:write (select (2, ...))
            else
                chan:write (select (1, ...))
            end
        end

        local writeln_orig = writeln

        texiowrite    = writefile
        texiowrite_nl = writefile_nl
        writeln       = writefile_nl
        statusln      = dummyfunction

        finalizers[#finalizers+1] = function ()
            chan:write (stringformat ("\nlogging finished at %s\n",
                                      osdate ("%F %T", ostime ())))
            chan:close ()
            texiowrite    = texio.write
            texiowrite_nl = texio.write_nl
            writeln       = writeln_orig
        end
    --else --- remains “log”
    end
    return finalizers
end

logs.set_logout = set_logout

local log = function (category, fmt, ...)
    local res = { module_name, "|", category, ":" }
    if fmt then
        res [#res + 1] = stringformat (fmt, ...)
    end
    texiowrite_nl (logout, tableconcat(res, " "))
end

--- with faux db update with maximum verbosity:
---
---     ---------   --------
---     buffering   time (s)
---     ---------   --------
---     full        4.12
---     line        4.20
---     none        4.39
---     ---------   --------
---

io.stdout:setvbuf "no"
io.stderr:setvbuf "no"

local kill_line = "\r\x1b[K"

if texjob == true then
    --- We imitate the texio.* functions so the output is consistent.
    writeln = function (str)
        iowrite "\n"
        iowrite(str)
    end
    statusln = function (str)
        if first_status == false then
            iowrite (kill_line)
        else
            iowrite "\n"
        end
        iowrite (str)
    end
else
    writeln = function (str)
        iowrite(str)
        iowrite "\n"
    end
    statusln = function (str)
        if first_status == false then
            iowrite (kill_line)
        end
        iowrite (str)
    end
end

stdout = function (writer, category, ...)
    local res = { module_name, "|", category, ":" }
    local nargs = select("#", ...)
    if nargs == 0 then
        --writeln tableconcat(res, " ")
        --return
    elseif nargs == 1 then
        res[#res+1] = select(1, ...) -- around 30% faster than unpack()
    else
        res[#res+1] = stringformat(...)
    end
    writer (tableconcat(res, " "))
end

--- at default (zero), we aim to be quiet
local level_ids = { common  = 1, loading = 2, search  = 3 }

--[[doc--

    The names_report logger is used more or less all over luaotfload.
    Its requirements are twofold:

    1) Provide two logging channels, the terminal and the log file;
    2) Allow for control over verbosity levels.

    The first part is addressed by specifying the log *mode* as the
    first argument that can be either “log”, meaning the log file, or
    “both”: log file and stdout. Anything else is taken as referring to
    stdout only.

    Verbosity levels, though not as fine-grained as e.g. Context’s
    system of tracers, allow keeping the logging spam caused by
    different subsystems manageable. By default, luaotfload will not
    emit anything if things are running smoothly on level zero. Only
    warning messages are relayed, while the other messages are skipped
    over. (This is a little sub-optimal performance-wise since the
    function calls to the logger are executed regardless.) The log
    level during a Luatex run can be adjusted by setting the “loglevel”
    field in config.luaotfload, or by calling logs.set_loglevel() as
    defined above.

--doc]]--

local names_report = function (mode, lvl, ...)
    if type(lvl) == "string" then
        lvl = level_ids[lvl]
    end
    if not lvl then lvl = 0 end

    if loglevel >= lvl then
        if mode == "log" then
            log (...)
        elseif mode == "both" and logout ~= "redirect" then
            log (...)
            stdout (writeln, ...)
        else
            stdout (writeln, ...)
        end
    end
end

logs.names_report = names_report

--[[doc--

    status_logger -- Overwrites the most recently printed line of the
    terminal. Its purpose is to provide feedback without spamming
    stdout with irrelevant messages, i.e. when building the database.

    Status logging must be initialized by calling status_start() and
    properly reset via status_stop().

    The arguments low and high indicate the loglevel threshold at which
    linewise and full logging is triggered, respectively. E.g.

            names_status (1, 4, "term", "Hello, world!")

    will print nothing if the loglevel is less than one, reuse the
    current line if the loglevel ranges from one to three inclusively,
    and output the message on a separate line otherwise.

--doc]]--

local status_logger = function (mode, ...)
    if mode == "log" then
        log (...)
    else
        if mode == "both" and logout ~= "redirect" then
            log (...)
            stdout (statusln, ...)
        else
            stdout (statusln, ...)
        end
        first_status = false
    end
end

--[[doc--

    status_start -- Initialize status logging. This installs the status
        logger if the loglevel is in the specified range, and the normal
        logger otherwise.  It also resets the first line state which
        causing the next line printed using the status logger to not kill
        the current line.

--doc]]--

local status_writer
local status_low  = 99
local status_high = 99

local status_start = function (low, high)
    first_status = true
    status_low   = low
    status_high  = high

    if os.type == "windows" --- Assume broken terminal.
    or os.getenv "TERM" == "dumb"
    then
        status_writer = function (mode, ...)
            names_report (mode, high, ...)
        end
        return
    end

    if low <= loglevel and loglevel < high then
        status_writer = status_logger
    else
        status_writer = function (mode, ...)
            names_report (mode, high, ...)
        end
    end
end

--[[doc--

    status_stop -- Finalize a status region by outputting a newline and
    printing a message.

--doc]]--

local status_stop = function (...)
    if first_status == false then
        status_writer(...)
        if texjob == false then
            writeln ""
        end
    end
end

logs.names_status = function (...) status_writer (...) end
logs.names_status_start = status_start
logs.names_status_stop  = status_stop

--[[doc--

    The fontloader comes with the Context logging mechanisms
    inaccessible. Instead, it provides dumb fallbacks based
    on the functions in texio.write*() that can be overridden
    by providing a function texio.reporter().

    The fontloader output can be quite verbose, so we disable
    it entirely by default.

--doc]]--

local texioreporter = function (message)
    names_report("log", 2, message)
end

texio.reporter = texioreporter

--[[doc--

    Adobe Glyph List.
    -------------------------------------------------------------------

    Context provides a somewhat different font-age.lua from an unclear
    origin. Unfortunately, the file name it reads from is hard-coded
    in font-enc.lua, so we have to replace the entire table.

    This shouldn’t cause any complications. Due to its implementation
    the glyph list will be loaded upon loading a OTF or TTF for the
    first time during a TeX run. (If one sticks to TFM/OFM then it is
    never read at all.) For this reason we can install a metatable that
    looks up the file of our choosing and only falls back to the
    Context one in case it cannot be found.

--doc]]--

if fonts then --- need to be running TeX
    if next(fonts.encodings.agl) then
        --- unnecessary because the file shouldn’t be loaded at this time
        --- but we’re just making sure
        fonts.encodings.agl = nil
        collectgarbage"collect"
    end


    fonts.encodings.agl = { }

    setmetatable(fonts.encodings.agl, { __index = function (t, k)
        if k == "unicodes" then
            local glyphlist = resolvers.findfile"luaotfload-glyphlist.lua"
            if glyphlist then
                names_report("log", 1, "load", "loading the Adobe glyph list")
            else
                glyphlist = resolvers.findfile"font-age.lua"
                names_report("both", 0, "load",
                    "loading the extended glyph list from ConTeXt")
            end
            local unicodes      = dofile(glyphlist)
            fonts.encodings.agl = { unicodes = unicodes }
            return unicodes
        else
            return nil
        end
    end })
end

-- vim:tw=71:sw=4:ts=4:expandtab
