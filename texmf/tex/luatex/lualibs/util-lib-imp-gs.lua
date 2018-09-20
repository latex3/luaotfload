if not modules then modules = { } end modules ['util-lib-imp-gs'] = {
    version   = 1.001,
    comment   = "a mkiv swiglib module",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local insert = table.insert
local formatters = string.formatters

local ghostscript     = utilities.ghostscript or { }
utilities.ghostscript = ghostscript

local report_gs = logs.reporter("swiglib ghostscript")

local gs      = swiglib("ghostscript.core")
local helpers = swiglib("helpers.core")

if gs then
    report_gs("library loaded")
    -- inspect(table.sortedkeys(gs))
else
    return
end

-- these could be generic helpers

local function luatable_to_c_array(t)
    local gsargv = helpers.new_char_p_array(#t)
    for i=1,#t do
        helpers.char_p_array_setitem(gsargv,i-1,t[i])
    end
    return gsargv
end

-- the more abstract interface

local interface       = { }
ghostscript.interface = interface

function interface.new()

    local instance = helpers.new_void_p_p()
    local result   = gs.gsapi_new_instance(instance,nil)
    local buffer   = nil
    local object   = { }

    local function reader(instance,str,len)
        return 0
    end

    local function writer(instance,str,len)
        if buffer then
            str = buffer .. str
            buffer = nil
        end
        if not string.find(str,"[\n\r]$") then
            str, buffer = string.match(str,"(.-)([^\n\r]+)$")
        end
        local log = object.log
        for s in string.gmatch(str,"[^\n\r]+") do
            insert(log,s)
            report_gs(s)
        end
        return len
    end

    if result < 0 then
        return nil
    else
        local job = helpers.void_p_p_value(instance)
        gs.gsapi_set_stdio_callback(job,reader,writer,writer) -- could be option
        object.instance = instance
        object.job      = job
        object.result   = 0
        object.log      = { }
        return object
    end
end

function interface.dispose(run)
    if run.job then
        gs.gsapi_delete_instance(run.job)
        run.job = nil
    end
    if run.instance then
        helpers.delete_void_p_p(run.instance)
        run.instance = nil
    end
end

function interface.init(run,options)
    if run.job then
        if not options then
            options = { "ps2pdf" }
        else
          insert(options,1,"ps2pdf") -- a dummy
        end
        run.log = { }
        local ct = luatable_to_c_array(options)
        local result = gs.gsapi_init_with_args(run.job,#options,ct)
        helpers.delete_char_p_array(ct)
        run.initresult = result
        return result >= 0
    end
end

function interface.exit(run)
    if run.job then
        local result = gs.gsapi_exit(run.job)
        if run.initresult == 0 or run.initresult == gs.e_Quit then
            run.result = result
        end
        run.exitresult = result
        return run.result >= 0
    end
end

function interface.process(run,options)
    interface.init(run,options)
    return interface.exit(run)
end

-- end of more abstract interface

local nofruns = 0

function ghostscript.convert(specification)
    --
    nofruns = nofruns + 1
    statistics.starttiming(ghostscript)
    --
    local inputname = specification.inputname
    if not inputname or inputname == "" then
        report_gs("invalid run %s, no inputname specified",nofruns)
        statistics.stoptiming(ghostscript)
        return false
    end
    local outputname = specification.outputname
    if not outputname or outputname == "" then
        outputname = file.replacesuffix(inputname,"pdf")
    end
    --
    if not lfs.isfile(inputname) then
        report_gs("invalid run %s, input file %a is not found",nofruns,inputname)
        statistics.stoptiming(ghostscript)
        return false
    end
    --
    local device = specification.device
    if not device or device == "" then
        device = "pdfwrite"
    end
    --
    local code = specification.code
    if not code or code == "" then
        code = ".setpdfwrite"
    end
    --
    local run = interface.new()
    if gsinstance then
        report_gs("invalid run %s, initialization error",nofruns)
        statistics.stoptiming(ghostscript)
        return false
    end
    --
    local options = specification.options or { }
    --
    insert(options,"-dNOPAUSE")
    insert(options,"-dBATCH")
    insert(options,"-dSAFER")
    insert(options,formatters["-sDEVICE=%s"](device))
    insert(options,formatters["-sOutputFile=%s"](outputname))
    insert(options,"-c")
    insert(options,code)
    insert(options,"-f")
    insert(options,inputname)
    --
    report_gs("run %s, input file %a, outputfile %a",nofruns,inputname,outputname)
    report_gs("")
    local okay = interface.process(run,options)
    report_gs("")
    --
    interface.dispose(run)
    --
    statistics.stoptiming(ghostscript)
    if okay then
        return outputname
    else
        report_gs("run %s quit with errors",nofruns)
        return false
    end
end

function ghostscript.statistics(report)
    local runtime = statistics.elapsedtime(ghostscript)
    if report then
        report_gs("nofruns %s, runtime %s",nofruns,runtime)
    else
        return {
            runtime = runtime,
            nofruns = nofruns,
        }
    end
end

-- for i=1,100 do
--     ghostscript.convert { inputname = "temp.eps" }
--     ghostscript.convert { inputname = "t:/escrito/tiger.eps" }
-- end
-- ghostscript.statistics(true)
