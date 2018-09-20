if not modules then modules = { } end modules ['util-lib-imp-gm'] = {
    version   = 1.001,
    comment   = "a mkiv swiglib module",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

local graphicmagick     = utilities.graphicmagick or { }
utilities.graphicmagick = graphicmagick

local report_gm = logs.reporter("swiglib graphicsmagick")

local gm = swiglib("graphicsmagick.core")

if gm then
    report_gm("library loaded")
    -- inspect(table.sortedkeys(gm))
else
    return
end

local nofruns = 0

function graphicmagick.convert(specification)
    --
    nofruns = nofruns + 1
    statistics.starttiming(graphicmagick)
    --
    local inputname  = specification.inputname
    if not inputname or inputname == "" then
        report_gm("invalid run %s, no inputname specified",nofruns)
        statistics.stoptiming(graphicmagick)
        return false
    end
    local outputname = specification.outputname
    if not outputname or outputname == "" then
        outputname = file.replacesuffix(inputname,"pdf")
    end
    --
    if not lfs.isfile(inputname) then
        report_gm("invalid run %s, input file %a is not found",nofruns,inputname)
        statistics.stoptiming(graphicmagick)
        return false
    end
    --
    report_gm("run %s, input file %a, outputfile %a",nofruns,inputname,outputname)
    local magick_wand = gm.NewMagickWand()
    gm.MagickReadImage(magick_wand,inputname)
    gm.MagickWriteImage(magick_wand,outputname)
    gm.DestroyMagickWand(magick_wand)
    --
    statistics.stoptiming(graphicmagick)
end

function graphicmagick.statistics(report)
    local runtime = statistics.elapsedtime(graphicmagick)
    if report then
        report_gm("nofruns %s, runtime %s",nofruns,runtime)
    else
        return {
            runtime = runtime,
            nofruns = nofruns,
        }
    end
end

-- graphicmagick.convert { inputname = "t:/sources/hacker.jpg", outputname = "e:/tmp/hacker.png" }
-- graphicmagick.statistics(true)
