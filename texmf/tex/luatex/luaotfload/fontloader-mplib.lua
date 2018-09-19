if not modules then modules = { } end modules ['luatex-mplib'] = {
    version   = 1.001,
    comment   = "companion to luatex-mplib.tex",
    author    = "Hans Hagen & Taco Hoekwater",
    copyright = "ConTeXt Development Team",
    license   = "public domain",
}

--[[ldx--
<p>This module is a stripped down version of libraries that are used
by <l n='context'/>. It can be used in other macro packages and/or
serve as an example. Embedding in a macro package is upto others and
normally boils down to inputting <t>supp-mpl.tex</t>.</p>
--ldx]]--

if metapost and metapost.version then

    --[[ldx--
    <p>Let's silently quit and make sure that no one loads it
    manually in <l n='context'/>.</p>
    --ldx]]--

else

    local format, match, gsub = string.format, string.match, string.gsub
    local concat = table.concat
    local abs = math.abs

    local mplib = require ('mplib')
    local kpse  = require ('kpse')

    --[[ldx--
    <p>We create a namespace and some variables to it. If a namespace is
    already defined it wil not be initialized. This permits hooking
    in code beforehand.</p>

    <p>We don't make a format automatically. After all, distributions
    might have their own preferences and normally a format (mem) file will
    have some special place in the <l n='tex'/> tree. Also, there can already
    be format files, different memort settings and other nasty pitfalls that
    we don't want to interfere with. If you want, you can define a function
    <t>metapost.make(name,mem_name) that does the job.</t></p>
    --ldx]]--

    metapost          = metapost or { }
    metapost.version  = 1.00
    metapost.showlog  = metapost.showlog or false
    metapost.lastlog  = ""

    --[[ldx--
    <p>A few helpers, taken from <t>l-file.lua</t>.</p>
    --ldx]]--

    local file = file or { }

    function file.replacesuffix(filename, suffix)
        return (string.gsub(filename,"%.[%a%d]+$","")) .. "." .. suffix
    end

    function file.stripsuffix(filename)
        return (string.gsub(filename,"%.[%a%d]+$",""))
    end

    --[[ldx--
    <p>We use the <l n='kpse'/> library unless a finder is already
    defined.</p>
    --ldx]]--

    local mpkpse = kpse.new("luatex","mpost")

    metapost.finder = metapost.finder or function(name, mode, ftype)
        if mode == "w" then
            return name
        else
            return mpkpse:find_file(name,ftype)
        end
    end

    --[[ldx--
    <p>You can use your own reported if needed, as long as it handles multiple
    arguments and formatted strings.</p>
    --ldx]]--

    metapost.report = metapost.report or function(...)
        if logs.report then
            logs.report("metapost",...)
        else
            texio.write(format("<mplib: %s>",format(...)))
        end
    end

    --[[ldx--
    <p>The rest of this module is not documented. More info can be found in the
    <l n='luatex'/> manual, articles in user group journals and the files that
    ship with <l n='context'/>.</p>
    --ldx]]--

    function metapost.resetlastlog()
        metapost.lastlog = ""
    end

    local mplibone = tonumber(mplib.version()) <= 1.50

    if mplibone then

        metapost.make = metapost.make or function(name,mem_name,dump)
            local t = os.clock()
            local mpx = mplib.new {
                ini_version = true,
                find_file = metapost.finder,
                job_name = file.stripsuffix(name)
            }
            mpx:execute(string.format("input %s ;",name))
            if dump then
                mpx:execute("dump ;")
                metapost.report("format %s made and dumped for %s in %0.3f seconds",mem_name,name,os.clock()-t)
            else
                metapost.report("%s read in %0.3f seconds",name,os.clock()-t)
            end
            return mpx
        end

        function metapost.load(name)
            local mem_name = file.replacesuffix(name,"mem")
            local mpx = mplib.new {
                ini_version = false,
                mem_name = mem_name,
                find_file = metapost.finder
            }
            if not mpx and type(metapost.make) == "function" then
                -- when i have time i'll locate the format and dump
                mpx = metapost.make(name,mem_name)
            end
            if mpx then
                metapost.report("using format %s",mem_name,false)
                return mpx, nil
            else
                return nil, { status = 99, error = "out of memory or invalid format" }
            end
        end

    else

        local preamble = [[
            boolean mplib ; mplib := true ;
            let dump = endinput ;
            input %s ;
        ]]

        metapost.make = metapost.make or function()
        end

        local template = [[
            \pdfoutput=1
            \pdfpkresolution600
            \pdfcompresslevel=9
            %s\relax
            \hsize=100in
            \vsize=\hsize
            \hoffset=-1in
            \voffset=\hoffset
            \topskip=0pt
            \setbox0=\hbox{%s}\relax
            \pageheight=\ht0
            \pagewidth=\wd0
            \box0
            \bye
        ]]

        metapost.texrunner = "mtxrun --script plain"

        local texruns = 0   -- per document
        local texhash = { } -- per document

        function metapost.maketext(mpd,str,what)
            -- inefficient but one can always use metafun .. it's more a test
            -- feature
            local verbatimtex = mpd.verbatimtex
            if not verbatimtex then
                verbatimtex = { }
                mpd.verbatimtex = verbatimtex
            end
            if what == 1 then
                table.insert(verbatimtex,str)
            else
                local texcode = format(template,concat(verbatimtex,"\n"),str)
                local texdone = texhash[texcode]
                local jobname = tex.jobname
                if not texdone then
                    texruns = texruns + 1
                    texdone = texruns
                    texhash[texcode] = texdone
                    local texname = format("%s-mplib-%s.tmp",jobname,texdone)
                    local logname = format("%s-mplib-%s.log",jobname,texdone)
                    local pdfname = format("%s-mplib-%s.pdf",jobname,texdone)
                    io.savedata(texname,texcode)
                    os.execute(format("%s %s",metapost.texrunner,texname))
                    os.remove(texname)
                    os.remove(logname)
                end
                return format('"image::%s-mplib-%s.pdf" infont defaultfont',jobname,texdone)
            end
        end

        local function mpprint(buffer,...)
            for i=1,select("#",...) do
                local value = select(i,...)
                if value ~= nil then
                    local t = type(value)
                    if t == "number" then
                        buffer[#buffer+1] = format("%.16f",value)
                    elseif t == "string" then
                        buffer[#buffer+1] = value
                    elseif t == "table" then
                        buffer[#buffer+1] = "(" .. concat(value,",") .. ")"
                    else -- boolean or whatever
                        buffer[#buffer+1] = tostring(value)
                    end
                end
            end
        end

        function metapost.runscript(mpd,code)
            local code = loadstring(code)
            if type(code) == "function" then
                local buffer = { }
                function metapost.print(...)
                    mpprint(buffer,...)
                end
                code()
             -- mpd.buffer = buffer -- for tracing
                return concat(buffer,"")
            end
            return ""
        end

        local modes = {
            scaled  = true,
            decimal = true,
            binary  = true,
            double  = true,
        }

        function metapost.load(name,mode)
            local mpd = {
                buffer   = { },
                verbatim = { }
            }
            local mpx = mplib.new {
                ini_version = true,
                find_file   = metapost.finder,
                make_text   = function(...) return metapost.maketext (mpd,...) end,
                run_script  = function(...) return metapost.runscript(mpd,...) end,
                extensions  = 1,
                math_mode   = mode and modes[mode] and mode or "scaled",
            }
            local result
            if not mpx then
                result = { status = 99, error = "out of memory"}
            else
                result = mpx:execute(format(preamble, file.replacesuffix(name,"mp")))
            end
            metapost.reporterror(result)
            return mpx, result
        end

    end

    function metapost.unload(mpx)
        if mpx then
            mpx:finish()
        end
    end

    function metapost.reporterror(result)
        if not result then
            metapost.report("mp error: no result object returned")
        elseif result.status > 0 then
            local t, e, l = result.term, result.error, result.log
            if t then
                metapost.report("mp terminal: %s",t)
            end
            if e then
                metapost.report("mp error: %s", e)
            end
            if not t and not e and l then
                metapost.lastlog = metapost.lastlog .. "\n " .. l
                metapost.report("mp log: %s",l)
            else
                metapost.report("mp error: unknown, no error, terminal or log messages")
            end
        else
            return false
        end
        return true
    end

    function metapost.process(format,data,mode)
        local converted, result = false, {}
        local mpx = metapost.load(format,mode)
        if mpx and data then
            local result = mpx:execute(data)
            if not result then
                metapost.report("mp error: no result object returned")
            elseif result.status > 0 then
                metapost.report("mp error: %s",(result.term or "no-term") .. "\n" .. (result.error or "no-error"))
            elseif metapost.showlog then
                metapost.lastlog = metapost.lastlog .. "\n" .. result.term
                metapost.report("mp info: %s",result.term or "no-term")
            elseif result.fig then
                converted = metapost.convert(result)
            else
                metapost.report("mp error: unknown error, maybe no beginfig/endfig")
            end
--             mpx:finish()
--             mpx = nil
        else
           metapost.report("mp error: mem file not found")
        end
        return converted, result
    end

    local function getobjects(result,figure,f)
        return figure:objects()
    end

    function metapost.convert(result,flusher)
        metapost.flush(result,flusher)
        return true -- done
    end

    --[[ldx--
    <p>We removed some message and tracing code. We might even remove the flusher</p>
    --ldx]]--

    local function pdf_startfigure(n,llx,lly,urx,ury)
        tex.sprint(format("\\startMPLIBtoPDF{%s}{%s}{%s}{%s}",llx,lly,urx,ury))
    end

    local function pdf_stopfigure()
        tex.sprint("\\stopMPLIBtoPDF")
    end

    function pdf_literalcode(fmt,...) -- table
        tex.sprint(format("\\MPLIBtoPDF{%s}",format(fmt,...)))
    end

    function pdf_textfigure(font,size,text,width,height,depth)
        local how, what = match(text,"^(.-)::(.+)$")
        if how == "image" then
            tex.sprint(format("\\MPLIBpdftext{%s}{%s}",what,depth))
        else
            text = gsub(text,".","\\hbox{%1}") -- kerning happens in metapost
            tex.sprint(format("\\MPLIBtextext{%s}{%s}{%s}{%s}",font,size,text,depth))
        end
    end

    local bend_tolerance = 131/65536

    local rx, sx, sy, ry, tx, ty, divider = 1, 0, 0, 1, 0, 0, 1

    local function pen_characteristics(object)
        local t = mplib.pen_info(object)
        rx, ry, sx, sy, tx, ty = t.rx, t.ry, t.sx, t.sy, t.tx, t.ty
        divider = sx*sy - rx*ry
        return not (sx==1 and rx==0 and ry==0 and sy==1 and tx==0 and ty==0), t.width
    end

    local function concatinated(px, py) -- no tx, ty here
        return (sy*px-ry*py)/divider,(sx*py-rx*px)/divider
    end

    local function curved(ith,pth)
        local d = pth.left_x - ith.right_x
        if abs(ith.right_x - ith.x_coord - d) <= bend_tolerance and abs(pth.x_coord - pth.left_x - d) <= bend_tolerance then
            d = pth.left_y - ith.right_y
            if abs(ith.right_y - ith.y_coord - d) <= bend_tolerance and abs(pth.y_coord - pth.left_y - d) <= bend_tolerance then
                return false
            end
        end
        return true
    end

    local function flushnormalpath(path,open)
        local pth, ith
        for i=1,#path do
            pth = path[i]
            if not ith then
                pdf_literalcode("%f %f m",pth.x_coord,pth.y_coord)
            elseif curved(ith,pth) then
                pdf_literalcode("%f %f %f %f %f %f c",ith.right_x,ith.right_y,pth.left_x,pth.left_y,pth.x_coord,pth.y_coord)
            else
                pdf_literalcode("%f %f l",pth.x_coord,pth.y_coord)
            end
            ith = pth
        end
        if not open then
            local one = path[1]
            if curved(pth,one) then
                pdf_literalcode("%f %f %f %f %f %f c",pth.right_x,pth.right_y,one.left_x,one.left_y,one.x_coord,one.y_coord )
            else
                pdf_literalcode("%f %f l",one.x_coord,one.y_coord)
            end
        elseif #path == 1 then
            -- special case .. draw point
            local one = path[1]
            pdf_literalcode("%f %f l",one.x_coord,one.y_coord)
        end
        return t
    end

    local function flushconcatpath(path,open)
        pdf_literalcode("%f %f %f %f %f %f cm", sx, rx, ry, sy, tx ,ty)
        local pth, ith
        for i=1,#path do
            pth = path[i]
            if not ith then
               pdf_literalcode("%f %f m",concatinated(pth.x_coord,pth.y_coord))
            elseif curved(ith,pth) then
                local a, b = concatinated(ith.right_x,ith.right_y)
                local c, d = concatinated(pth.left_x,pth.left_y)
                pdf_literalcode("%f %f %f %f %f %f c",a,b,c,d,concatinated(pth.x_coord, pth.y_coord))
            else
               pdf_literalcode("%f %f l",concatinated(pth.x_coord, pth.y_coord))
            end
            ith = pth
        end
        if not open then
            local one = path[1]
            if curved(pth,one) then
                local a, b = concatinated(pth.right_x,pth.right_y)
                local c, d = concatinated(one.left_x,one.left_y)
                pdf_literalcode("%f %f %f %f %f %f c",a,b,c,d,concatinated(one.x_coord, one.y_coord))
            else
                pdf_literalcode("%f %f l",concatinated(one.x_coord,one.y_coord))
            end
        elseif #path == 1 then
            -- special case .. draw point
            local one = path[1]
            pdf_literalcode("%f %f l",concatinated(one.x_coord,one.y_coord))
        end
        return t
    end

    --[[ldx--
    <p>Support for specials has been removed.</p>
    --ldx]]--

    function metapost.flush(result,flusher)
        if result then
            local figures = result.fig
            if figures then
                for f=1, #figures do
                    metapost.report("flushing figure %s",f)
                    local figure = figures[f]
                    local objects = getobjects(result,figure,f)
                    local fignum = tonumber(match(figure:filename(),"([%d]+)$") or figure:charcode() or 0)
                    local miterlimit, linecap, linejoin, dashed = -1, -1, -1, false
                    local bbox = figure:boundingbox()
                    local llx, lly, urx, ury = bbox[1], bbox[2], bbox[3], bbox[4] -- faster than unpack
                    if urx < llx then
                        -- invalid
                        pdf_startfigure(fignum,0,0,0,0)
                        pdf_stopfigure()
                    else
                        pdf_startfigure(fignum,llx,lly,urx,ury)
                        pdf_literalcode("q")
                        if objects then
                            local savedpath = nil
                            local savedhtap = nil
                            for o=1,#objects do
                                local object = objects[o]
                                local objecttype = object.type
                                if objecttype == "start_bounds" or objecttype == "stop_bounds" then
                                    -- skip
                                elseif objecttype == "start_clip" then
                                    local evenodd = not object.istext and object.postscript == "evenodd"
                                    pdf_literalcode("q")
                                    flushnormalpath(object.path,t,false)
                                    pdf_literalcode("W n")
                                    pdf_literalcode(evenodd and "W* n" or "W n")
                                elseif objecttype == "stop_clip" then
                                    pdf_literalcode("Q")
                                    miterlimit, linecap, linejoin, dashed = -1, -1, -1, false
                                elseif objecttype == "special" then
                                    -- not supported
                                elseif objecttype == "text" then
                                    local ot = object.transform -- 3,4,5,6,1,2
                                    pdf_literalcode("q %f %f %f %f %f %f cm",ot[3],ot[4],ot[5],ot[6],ot[1],ot[2])
                                    pdf_textfigure(object.font,object.dsize,object.text,object.width,object.height,object.depth)
                                    pdf_literalcode("Q")
                                else
                                    local evenodd, collect, both = false, false, false
                                    local postscript = object.postscript
                                    if not object.istext then
                                        if postscript == "evenodd" then
                                            evenodd = true
                                        elseif postscript == "collect" then
                                            collect = true
                                        elseif postscript == "both" then
                                            both = true
                                        elseif postscript == "eoboth" then
                                            evenodd = true
                                            both    = true
                                        end
                                    end
                                    if collect then
                                        if not savedpath then
                                            savedpath = { object.path or false }
                                            savedhtap = { object.htap or false }
                                        else
                                            savedpath[#savedpath+1] = object.path or false
                                            savedhtap[#savedhtap+1] = object.htap or false
                                        end
                                    else
                                        local cs = object.color
                                        local cr = false
                                        if cs and #cs > 0 then
                                            cs, cr = metapost.colorconverter(cs)
                                            pdf_literalcode(cs)
                                        end
                                        local ml = object.miterlimit
                                        if ml and ml ~= miterlimit then
                                            miterlimit = ml
                                            pdf_literalcode("%f M",ml)
                                        end
                                        local lj = object.linejoin
                                        if lj and lj ~= linejoin then
                                            linejoin = lj
                                            pdf_literalcode("%i j",lj)
                                        end
                                        local lc = object.linecap
                                        if lc and lc ~= linecap then
                                            linecap = lc
                                            pdf_literalcode("%i J",lc)
                                        end
                                        local dl = object.dash
                                        if dl then
                                            local d = format("[%s] %i d",concat(dl.dashes or {}," "),dl.offset)
                                            if d ~= dashed then
                                                dashed = d
                                                pdf_literalcode(dashed)
                                            end
                                        elseif dashed then
                                           pdf_literalcode("[] 0 d")
                                           dashed = false
                                        end
                                        local path = object.path
                                        local transformed, penwidth = false, 1
                                        local open = path and path[1].left_type and path[#path].right_type
                                        local pen = object.pen
                                        if pen then
                                           if pen.type == 'elliptical' then
                                                transformed, penwidth = pen_characteristics(object) -- boolean, value
                                                pdf_literalcode("%f w",penwidth)
                                                if objecttype == 'fill' then
                                                    objecttype = 'both'
                                                end
                                           else -- calculated by mplib itself
                                                objecttype = 'fill'
                                           end
                                        end
                                        if transformed then
                                            pdf_literalcode("q")
                                        end
                                        if path then
                                            if savedpath then
                                                for i=1,#savedpath do
                                                    local path = savedpath[i]
                                                    if transformed then
                                                        flushconcatpath(path,open)
                                                    else
                                                        flushnormalpath(path,open)
                                                    end
                                                end
                                                savedpath = nil
                                            end
                                            if transformed then
                                                flushconcatpath(path,open)
                                            else
                                                flushnormalpath(path,open)
                                            end
                                            if objecttype == "fill" then
                                                pdf_literalcode("h f")
                                            elseif objecttype == "outline" then
                                            if both then
                                                pdf_literalcode(evenodd and "h B*" or "h B")
                                            else
                                                pdf_literalcode(open and "S" or "h S")
                                            end
                                            elseif objecttype == "both" then
                                                pdf_literalcode(evenodd and "h B*" or "h B")
                                            end
                                        end
                                        if transformed then
                                            pdf_literalcode("Q")
                                        end
                                        local path = object.htap
                                        if path then
                                            if transformed then
                                                pdf_literalcode("q")
                                            end
                                            if savedhtap then
                                                for i=1,#savedhtap do
                                                    local path = savedhtap[i]
                                                    if transformed then
                                                        flushconcatpath(path,open)
                                                    else
                                                        flushnormalpath(path,open)
                                                    end
                                                end
                                                savedhtap = nil
                                                evenodd   = true
                                            end
                                            if transformed then
                                                flushconcatpath(path,open)
                                            else
                                                flushnormalpath(path,open)
                                            end
                                            if objecttype == "fill" then
                                                pdf_literalcode("h f")
                                            elseif objecttype == "outline" then
                                                pdf_literalcode(evenodd and "h f*" or "h f")
                                            elseif objecttype == "both" then
                                                pdf_literalcode(evenodd and "h B*" or "h B")
                                            end
                                            if transformed then
                                                pdf_literalcode("Q")
                                            end
                                        end
                                        if cr then
                                            pdf_literalcode(cr)
                                        end
                                    end
                                end
                           end
                        end
                        pdf_literalcode("Q")
                        pdf_stopfigure()
                    end
                end
            end
        end
    end

    function metapost.colorconverter(cr)
        local n = #cr
        if n == 4 then
            local c, m, y, k = cr[1], cr[2], cr[3], cr[4]
            return format("%.3f %.3f %.3f %.3f k %.3f %.3f %.3f %.3f K",c,m,y,k,c,m,y,k), "0 g 0 G"
        elseif n == 3 then
            local r, g, b = cr[1], cr[2], cr[3]
            return format("%.3f %.3f %.3f rg %.3f %.3f %.3f RG",r,g,b,r,g,b), "0 g 0 G"
        else
            local s = cr[1]
            return format("%.3f g %.3f G",s,s), "0 g 0 G"
        end
    end

end
