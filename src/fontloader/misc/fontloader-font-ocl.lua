if not modules then modules = { } end modules ['font-ocl'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (context)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo : user list of colors

local tostring, next, format = tostring, next, string.format

local formatters = string.formatters

local otf = fonts.handlers.otf

local f_color_start = formatters["pdf:direct: %f %f %f rg"]
local s_color_stop  = "pdf:direct:"

if context then

    local startactualtext = nil
    local stopactualtext  = nil

    function otf.getactualtext(n)
        if not startactualtext then
            startactualtext = backends.codeinjections.startunicodetoactualtext
            stopactualtext  = backends.codeinjections.stopunicodetoactualtext
        end
        return startactualtext(n), stopactualtext()
    end

else

    local tounicode = fonts.mappings.tounicode16

    function otf.getactualtext(n)
        return "/Span << /ActualText <feff" .. tounicode(n) .. "> >> BDC", "EMC"
    end

end

local function initializecolr(tfmdata,kind,value) -- hm, always value
    if value then
        local palettes = tfmdata.resources.colorpalettes
        if palettes then
            --
            local palette = palettes[tonumber(value) or 1] or palettes[1] or { }
            local classes = #palette
            if classes == 0 then
                return
            end
            --
            local characters   = tfmdata.characters
            local descriptions = tfmdata.descriptions
            local properties   = tfmdata.properties
            local colorvalues  = { }
            --
            properties.virtualized = true
            tfmdata.fonts = {
                { id = 0 }
            }
            --
            for i=1,classes do
                local p = palette[i]
                colorvalues[i] = { "special", f_color_start(p[1]/255,p[2]/255,p[3]/255) }
            end
            --
            local getactualtext = otf.getactualtext
            --
            for unicode, character in next, characters do
                local description = descriptions[unicode]
                if description then
                    local colorlist = description.colors
                    if colorlist then
                        local b, e = getactualtext(unicode)
                        local w = character.width or 0
                        local s = #colorlist
                        local n = 1
                        local t = {
                            { "special", "pdf:direct: q " .. b }
                        }
                        for i=1,s do
                            local entry = colorlist[i]
                            n = n + 1 t[n] = colorvalues[entry.class]
                            n = n + 1 t[n] = { "char", entry.slot }
                            if s > 1 and i < s and w ~= 0 then
                                n = n + 1 t[n] = { "right", -w }
                            end
                        end
                        n = n + 1 t[n] = { "special", "pdf:direct:" .. e .. " Q" }
                        character.commands = t
                    end
                end
            end
        end
    end
end

fonts.handlers.otf.features.register {
    name         = "colr",
    description  = "color glyphs",
    manipulators = {
        base = initializecolr,
        node = initializecolr,
    }
}

local otfsvg   = otf.svg or { }
otf.svg        = otfsvg
otf.svgenabled = true

do

    local nofstreams = 0

 -- local f_setstream = formatters[ [[io.savedata("svg-glyph-%05i",%q)]] ]
 -- local f_getstream = formatters[ [[svg-glyph-%05i]] ]

 -- function otfsvg.storepdfdata(pdf)
 --     nofstreams = nofstreams + 1
 --     storepdfdata = function(pdf)
 --         nofstreams = nofstreams + 1
 --         return f_setstream(nofstreams,pdf), f_getstream(nofstreams)
 --     end
 -- end

    local f_name = formatters[ [[svg-glyph-%05i]] ]
    local f_used = context and formatters[ [[original:///%s]] ] or formatters[ [[%s]] ]

    local cache = { }

    function otfsvg.storepdfdata(pdf)
        nofstreams = nofstreams + 1
        local o, n = epdf.openMemStream(pdf,#pdf,f_name(nofstreams))
        cache[n] = o -- we need to keep in mem
        return nil, f_used(n), nil
    end

    if context then

        local storepdfdata = otfsvg.storepdfdata
        local initialized  = false

        function otfsvg.storepdfdata(pdf)
            if not initialized then
                if resolvers.setmemstream then
                    local f_setstream = formatters[ [[resolvers.setmemstream("svg-glyph-%05i",%q,true)]] ]
                    local f_getstream = formatters[ [[memstream:///svg-glyph-%05i]] ]
                    local f_nilstream = formatters[ [[resolvers.resetmemstream("svg-glyph-%05i",true)]] ]
                    storepdfdata = function(pdf)
                        nofstreams = nofstreams + 1
                        return
                            f_setstream(nofstreams,pdf),
                            f_getstream(nofstreams),
                            f_nilstream(nofstreams)
                    end
                    otfsvg.storepdfdata = storepdfdata
                end
                initialized = true
            end
            return storepdfdata(pdf)
        end

    end

end


do

    local report_svg = logs.reporter("fonts","svg conversion")

    local loaddata   = io.loaddata
    local savedata   = io.savedata
    local remove     = os.remove

    if context and xml.convert then

        local xmlconvert = xml.convert
        local xmlfirst   = xml.first

        function otfsvg.filterglyph(entry,index)
            local svg  = xmlconvert(entry.data)
            local root = svg and xmlfirst(svg,"/svg[@id='glyph"..index.."']")
            local data = root and tostring(root)
         -- report_svg("data for glyph %04X: %s",index,data)
            return data
        end

    else

        function otfsvg.filterglyph(entry,index) -- can be overloaded
            return entry.data
        end

    end

 -- function otfsvg.topdf(svgshapes)
 --     local svgfile     = "temp-otf-svg-shape.svg"
 --     local pdffile     = "temp-otf-svg-shape.pdf"
 --     local command     = "inkscape " .. svgfile .. " --export-pdf=" .. pdffile
 --     local testrun     = false
 --     local pdfshapes   = { }
 --     local nofshapes   = #svgshapes
 --     local filterglyph = otfsvg.filterglyph
 --     report_svg("processing %i svg containers",nofshapes)
 --     statistics.starttiming()
 --     for i=1,nofshapes do
 --         local entry = svgshapes[i]
 --         for index=entry.first,entry.last do
 --             local data = filterglyph(entry,index)
 --             savedata(svgfile,tostring(data))
 --             if data and data ~= "" then
 --                 report_svg("processing svg shape of glyph %i in container %i",index,i)
 --                 os.execute(command)
 --                 pdfshapes[index] = loaddata(pdffile)
 --             end
 --         end
 --         if testrun and i > testrun then
 --             report_svg("quiting test run")
 --             break
 --         end
 --     end
 --     remove(svgfile)
 --     statistics.stoptiming()
 --     report_svg("conversion time: %0.3f",statistics.elapsedtime())
 --     return pdfshapes
 -- end

    function otfsvg.topdf(svgshapes)
        local inkscape    = io.popen("inkscape --shell > temp-otf-svg-shape.log","w")
        local pdfshapes   = { }
        local nofshapes   = #svgshapes
        local f_svgfile   = formatters["temp-otf-svg-shape-%i.svg"]
        local f_pdffile   = formatters["temp-otf-svg-shape-%i.pdf"]
        local f_convert   = formatters["%s --export-pdf=%s\n"]
        local filterglyph = otfsvg.filterglyph
        report_svg("processing %i svg containers",nofshapes)
        statistics.starttiming()
        for i=1,nofshapes do
            local entry = svgshapes[i]
            for index=entry.first,entry.last do
                local data = filterglyph(entry,index)
                if data and data ~= "" then
                    local svgfile = f_svgfile(index)
                    local pdffile = f_pdffile(index)
                    savedata(svgfile,data)
                    inkscape:write(f_convert(svgfile,pdffile))
                    pdfshapes[index] = true
                end
            end
        end
        inkscape:write("quit\n")
     -- while inkscape:read("*a") do
     --     os.sleep(0.1)
     -- end
        inkscape:close()
        report_svg("processing %i pdf results",nofshapes)
        for index in next, pdfshapes do
            local svgfile = f_svgfile(index)
            local pdffile = f_pdffile(index)
            pdfshapes[index] = loaddata(pdffile)
            remove(svgfile)
            remove(pdffile)
        end
        statistics.stoptiming()
        if statistics.elapsedseconds then
            report_svg("svg conversion time %s",statistics.elapsedseconds())
        end
        return pdfshapes
    end

end

local function initializesvg(tfmdata,kind,value) -- hm, always value
    if value and otf.svgenabled then
        local characters   = tfmdata.characters
        local descriptions = tfmdata.descriptions
        local properties   = tfmdata.properties
        --
        local svg       = properties.svg
        local hash      = svg and svg.hash
        local timestamp = svg and svg.timestamp
        if not hash then
            return
        end
        --
        local pdffile   = containers.read(otf.pdfcache,hash)
        local pdfshapes = pdffile and pdffile.pdfshapes
        if not pdfshapes or pdffile.timestamp ~= timestamp then
            local svgfile   = containers.read(otf.svgcache,hash)
            local svgshapes = svgfile and svgfile.svgshapes
            pdfshapes = svgshapes and otfsvg.topdf(svgshapes) or { }
            containers.write(otf.pdfcache, hash, {
                pdfshapes = pdfshapes,
                timestamp = timestamp,
            })
        end
        if not pdfshapes or not next(pdfshapes) then
            return
        end
        --
        properties.virtualized = true
        tfmdata.fonts = {
            { id = 0 }
        }
        --
        local getactualtext = otf.getactualtext
        local storepdfdata  = otfsvg.storepdfdata
        --
        local nop = { "nop" }
        --
        for unicode, character in next, characters do
            local index = character.index
            if index then
                local pdf = pdfshapes[index]
                if pdf then
                    local setcode, name, nilcode = storepdfdata(pdf)
                    if name then
                        local bt, et = getactualtext(unicode)
                        local wd = character.width  or 0
                        local ht = character.height or 0
                        local dp = character.depth  or 0
                        character.commands = {
                            { "special", "pdf:direct:" .. bt },
                            { "down", dp },
                            setcode and { "lua", setcode } or nop,
                            { "image", { filename = name, width = wd, height = ht, depth = dp } },
                            nilcode and { "lua", nilcode } or nop,
                            { "special", "pdf:direct:" .. et },
                        }
                        character.svg = true
                    end
                end
            end
        end
    end
end

fonts.handlers.otf.features.register {
    name         = "svg",
    description  = "svg glyphs",
    manipulators = {
        base = initializesvg,
        node = initializesvg,
    }
}
