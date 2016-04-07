if not modules then modules = { } end modules ['font-ttf'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next, type, unpack = next, type, unpack
local bittest = bit32.btest
local sqrt = math.sqrt

local report      = logs.reporter("otf reader","ttf")

local readers      = fonts.handlers.otf.readers
local streamreader = readers.streamreader

local setposition  = streamreader.setposition
local getposition  = streamreader.getposition
local skipbytes    = streamreader.skip
local readbyte     = streamreader.readcardinal1  --  8-bit unsigned integer
local readushort   = streamreader.readcardinal2  -- 16-bit unsigned integer
local readulong    = streamreader.readcardinal4  -- 24-bit unsigned integer
local readchar     = streamreader.readinteger1   --  8-bit   signed integer
local readshort    = streamreader.readinteger2   -- 16-bit   signed integer
local read2dot14   = streamreader.read2dot14     -- 16-bit signed fixed number with the low 14 bits of fraction (2.14) (F2DOT14)

local function mergecomposites(glyphs,shapes)

    local function merge(index,shape,components)
        local contours    = { }
        local nofcontours = 0
        for i=1,#components do
            local component   = components[i]
            local subindex    = component.index
            local subshape    = shapes[subindex]
            local subcontours = subshape.contours
            if not subcontours then
                local subcomponents = subshape.components
                if subcomponents then
                    subcontours = merge(subindex,subshape,subcomponents)
                end
            end
            if subcontours then
                local matrix  = component.matrix
                local xscale  = matrix[1]
                local xrotate = matrix[2]
                local yrotate = matrix[3]
                local yscale  = matrix[4]
                local xoffset = matrix[5]
                local yoffset = matrix[6]
                for i=1,#subcontours do
                    local points = subcontours[i]
                    local result = { }
                    for i=1,#points do
                        local p = points[i]
                        local x = p[1]
                        local y = p[2]
                        result[i] = {
                            xscale * x + xrotate * y + xoffset,
                            yscale * y + yrotate * x + yoffset,
                            p[3]
                        }
                    end
                    nofcontours = nofcontours + 1
                    contours[nofcontours] = result
                end
            else
                report("missing contours composite %s, component %s of %s, glyph %s",index,i,#components,subindex)
            end
        end
        shape.contours   = contours
        shape.components = nil
        return contours
    end

    for index=1,#glyphs do
        local shape      = shapes[index]
        local components = shape.components
        if components then
            merge(index,shape,components)
        end
    end

end

local function readnothing(f,nofcontours)
    return {
        type = "nothing",
    }
end

-- begin of converter

-- make paths: the ff code is quite complex but it looks like we need to deal
-- with all kind of on curve border cases

local function curveto(m_x,m_y,l_x,l_y,r_x,r_y) -- todo: inline this
    return {
        l_x + 2/3 *(m_x-l_x), l_y + 2/3 *(m_y-l_y),
        r_x + 2/3 *(m_x-r_x), r_y + 2/3 *(m_y-r_y),
        r_x, r_y, "c" -- "curveto"
    }
end

-- We could omit the operator which saves some 10%:
--
-- #2=lineto  #4=quadratic  #6=cubic #3=moveto (with "m")
--
-- For the moment we keep the original outlines but that default might change
-- in the future. In any case, a backend should support both.
--
-- The code is a bit messy. I looked at the ff code but it's messy too. It has
-- to do with the fact that we need to look at points on the curve and control
-- points in between. This also means that we start at point 2 and have to look at
-- point 1 when we're at the end. We still use a ps like storage with the operator
-- last in an entry. It's typical code that evolves stepwise till a point of no
-- comprehension.

local function contours2outlines(glyphs,shapes)
    local quadratic = true
 -- local quadratic = false
    for index=1,#glyphs do
        local glyph    = glyphs[index]
        local shape    = shapes[index]
        local contours = shape.contours
        if contours then
            local nofcontours = #contours
            local segments    = { }
            local nofsegments = 0
            glyph.segments    = segments
            if nofcontours > 0 then
                for i=1,nofcontours do
                    local contour    = contours[i]
                    local nofcontour = #contour
                    if nofcontour > 0 then
                        local first_pt = contour[1]
                        local first_on = first_pt[3]
                        -- todo no new tables but reuse lineto and quadratic
                        if nofcontour == 1 then
                            -- this can influence the boundingbox
                            first_pt[3] = "m" -- "moveto"
                            nofsegments = nofsegments + 1
                            segments[nofsegments] = first_pt
                        else -- maybe also treat n == 2 special
                            local first_on     = first_pt[3]
                            local last_pt      = contour[nofcontour]
                            local last_on      = last_pt[3]
                            local start        = 1
                            local control_pt   = false
                            if first_on then
                                start = 2
                            else
                                if last_on then
                                    first_pt = last_pt
                                else
                                    first_pt = { (first_pt[1]+last_pt[1])/2, (first_pt[2]+last_pt[2])/2, false }
                                end
                                control_pt = first_pt
                            end
                            nofsegments = nofsegments + 1
                            segments[nofsegments] = { first_pt[1], first_pt[2], "m" } -- "moveto"
                            local previous_pt = first_pt
                            for i=start,nofcontour do
                                local current_pt  = contour[i]
                                local current_on  = current_pt[3]
                                local previous_on = previous_pt[3]
                                if previous_on then
                                    if current_on then
                                        -- both normal points
                                        nofsegments = nofsegments + 1
                                        segments[nofsegments] = { current_pt[1], current_pt[2], "l" } -- "lineto"
                                    else
                                        control_pt = current_pt
                                    end
                                elseif current_on then
                                    local ps = segments[nofsegments]
                                    nofsegments = nofsegments + 1
                                    if quadratic then
                                        segments[nofsegments] = { control_pt[1], control_pt[2], current_pt[1], current_pt[2], "q" } -- "quadraticto"
                                    else
                                        local p = segments[nofsegments-1]  local n = #p
                                        segments[nofsegments] = curveto(control_pt[1],control_pt[2],p[n-2],p[n-1],current_pt[1],current_pt[2])
                                    end
                                    control_pt = false
                                else
                                    nofsegments = nofsegments + 1
                                    local halfway_x = (previous_pt[1]+current_pt[1])/2
                                    local halfway_y = (previous_pt[2]+current_pt[2])/2
                                    if quadratic then
                                        segments[nofsegments] = { control_pt[1], control_pt[2], halfway_x, halfway_y, "q" } -- "quadraticto"
                                    else
                                        local p = segments[nofsegments-1]  local n = #p
                                        segments[nofsegments] = curveto(control_pt[1],control_pt[2],p[n-2],p[n-1],halfway_x,halfway_y)
                                    end
                                    control_pt = current_pt
                                end
                                previous_pt = current_pt
                            end
                            if first_pt == last_pt then
                                -- we're already done, probably a simple curve
                            else
                                nofsegments = nofsegments + 1
                                if not control_pt then
                                    segments[nofsegments] = { first_pt[1], first_pt[2], "l" } -- "lineto"
                                elseif quadratic then
                                    segments[nofsegments] = { control_pt[1], control_pt[2], first_pt[1], first_pt[2], "q" } -- "quadraticto"
                                else
                                    local p = last_pt  local n = #p
                                    segments[nofsegments] = curveto(control_pt[1],control_pt[2],p[n-2],p[n-1],first_pt[1],first_pt[2])
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- end of converter

local function readglyph(f,nofcontours)
    local points       = { }
    local endpoints    = { }
    local instructions = { }
    local flags        = { }
    for i=1,nofcontours do
        endpoints[i] = readshort(f) + 1
    end
    local nofpoints       = endpoints[nofcontours]
    local nofinstructions = readushort(f)
--     f:seek("set",f:seek()+nofinstructions)
    skipbytes(f,nofinstructions)
    -- because flags can repeat we don't know the amount ... in fact this is
    -- not that efficient (small files but more mem)
    local i = 1
    while i <= nofpoints do
        local flag = readbyte(f)
        flags[i] = flag
        if bittest(flag,0x0008) then
            for j=1,readbyte(f) do
                i = i + 1
                flags[i] = flag
            end
        end
        i = i + 1
    end
    -- first come the x coordinates, and next the y coordinates and they
    -- can be repeated
    local x = 0
    for i=1,nofpoints do
        local flag  = flags[i]
        local short = bittest(flag,0x0002)
        local same  = bittest(flag,0x0010)
        if short then
            if same then
                x = x + readbyte(f)
            else
                x = x - readbyte(f)
            end
        elseif same then
            -- copy
        else
            x = x + readshort(f)
        end
        points[i] = { x, y, bittest(flag,0x0001) }
    end
    local y = 0
    for i=1,nofpoints do
        local flag  = flags[i]
        local short = bittest(flag,0x0004)
        local same  = bittest(flag,0x0020)
        if short then
            if same then
                y = y + readbyte(f)
            else
                y = y - readbyte(f)
            end
        elseif same then
         -- copy
        else
            y = y + readshort(f)
        end
        points[i][2] = y
    end
    -- we could integrate this if needed
    local first = 1
    for i=1,#endpoints do
        local last = endpoints[i]
        endpoints[i] = { unpack(points,first,last) }
        first = last + 1
    end
    return {
        type     = "glyph",
     -- points   = points,
        contours = endpoints,
    }
end

local function readcomposite(f)
    local components    = { }
    local nofcomponents = 0
    local instructions  = false
    while true do
        local flags      = readushort(f)
        local index      = readushort(f)
        ----- f_words    = bittest(flags,0x0001)
        local f_xyarg    = bittest(flags,0x0002)
        ----- f_round    = bittest(flags,0x0004+0x0002)
        ----- f_scale    = bittest(flags,0x0008)
        ----- f_reserved = bittest(flags,0x0010)
        ----- f_more     = bittest(flags,0x0020)
        ----- f_xyscale  = bittest(flags,0x0040)
        ----- f_matrix   = bittest(flags,0x0080)
        ----- f_instruct = bittest(flags,0x0100)
        ----- f_usemine  = bittest(flags,0x0200)
        ----- f_overlap  = bittest(flags,0x0400)
        local f_offset   = bittest(flags,0x0800)
        ----- f_uoffset  = bittest(flags,0x1000)
        local xscale     = 1
        local xrotate    = 0
        local yrotate    = 0
        local yscale     = 1
        local xoffset    = 0
        local yoffset    = 0
        local base       = false
        local reference  = false
        if f_xyarg then
            if bittest(flags,0x0001) then -- f_words
                xoffset = readshort(f)
                yoffset = readshort(f)
            else
                xoffset = readchar(f) -- signed byte, stupid name
                yoffset = readchar(f) -- signed byte, stupid name
            end
        else
            if bittest(flags,0x0001) then -- f_words
                base      = readshort(f)
                reference = readshort(f)
            else
                base      = readchar(f) -- signed byte, stupid name
                reference = readchar(f) -- signed byte, stupid name
            end
        end
        if bittest(flags,0x0008) then -- f_scale
            xscale = read2dot14(f)
            yscale = xscale
            if f_xyarg and f_offset then
                xoffset = xoffset * xscale
                yoffset = yoffset * yscale
            end
        elseif bittest(flags,0x0040) then -- f_xyscale
            xscale = read2dot14(f)
            yscale = read2dot14(f)
            if f_xyarg and f_offset then
                xoffset = xoffset * xscale
                yoffset = yoffset * yscale
            end
        elseif bittest(flags,0x0080) then -- f_matrix
            xscale  = read2dot14(f)
            xrotate = read2dot14(f)
            yrotate = read2dot14(f)
            yscale  = read2dot14(f)
            if f_xyarg and f_offset then
                xoffset = xoffset * sqrt(xscale ^2 + xrotate^2)
                yoffset = yoffset * sqrt(yrotate^2 + yscale ^2)
            end
        end
        nofcomponents = nofcomponents + 1
        components[nofcomponents] = {
            index      = index,
            usemine    = bittest(flags,0x0200), -- f_usemine
            round      = bittest(flags,0x0006), -- f_round,
            base       = base,
            reference  = reference,
            matrix     = { xscale, xrotate, yrotate, yscale, xoffset, yoffset },
        }
        if bittest(flags,0x0100) then
            instructions = true
        end
        if not bittest(flags,0x0020) then -- f_more
            break
        end
    end
    return {
        type         = "composite",
        components   = components,
    }
end

-- function readers.cff(f,offset,glyphs,doshapes) -- false == no shapes (nil or true otherwise)

-- The glyf table depends on the loca table. We have one entry to much
-- in the locations table (the last one is a dummy) because we need to
-- calculate the size of a glyph blob from the delta, although we not
-- need it in our usage (yet). We can remove the locations table when
-- we're done (todo: cleanup finalizer).

function readers.loca(f,fontdata,specification)
    if specification.glyphs then
        local datatable = fontdata.tables.loca
        if datatable then
            -- locations are relative to the glypdata table (glyf)
            local offset    = fontdata.tables.glyf.offset
            local format    = fontdata.fontheader.indextolocformat
            local locations = { }
            setposition(f,datatable.offset)
            if format == 1 then
                local nofglyphs = datatable.length/4 - 1
            -1
                for i=0,nofglyphs do
                    locations[i] = offset + readulong(f)
                end
                fontdata.nofglyphs = nofglyphs
            else
                local nofglyphs = datatable.length/2 - 1
            -1
                for i=0,nofglyphs do
                    locations[i] = offset + readushort(f) * 2
                end
                fontdata.nofglyphs = nofglyphs
            end
            fontdata.locations = locations
        end
    end
end

function readers.glyf(f,fontdata,specification) -- part goes to cff module
    if specification.glyphs then
        local datatable = fontdata.tables.glyf
        if datatable then
            local locations = fontdata.locations
            if locations then
                local glyphs     = fontdata.glyphs
                local nofglyphs  = fontdata.nofglyphs
                local filesize   = fontdata.filesize
                local nothing    = { 0, 0, 0, 0 }
                local shapes     = { }
                local loadshapes = specification.shapes
                for index=0,nofglyphs do
                    local location = locations[index]
                    if location >= filesize then
                        report("discarding %s glyphs due to glyph location bug",nofglyphs-index+1)
                        fontdata.nofglyphs = index - 1
                        fontdata.badfont   = true
                        break
                    elseif location > 0 then
                        setposition(f,location)
                        local nofcontours = readshort(f)
                        glyphs[index].boundingbox = {
                            readshort(f), -- xmin
                            readshort(f), -- ymin
                            readshort(f), -- xmax
                            readshort(f), -- ymax
                        }
                        if not loadshapes then
                            -- save space
                        elseif nofcontours == 0 then
                            shapes[index] = readnothing(f,nofcontours)
                        elseif nofcontours > 0 then
                            shapes[index] = readglyph(f,nofcontours)
                        else
                            shapes[index] = readcomposite(f,nofcontours)
                        end
                    else
                        if loadshapes then
                            shapes[index] = { }
                        end
                        glyphs[index].boundingbox = nothing
                    end
                end
                if loadshapes then
                    mergecomposites(glyphs,shapes)
                    contours2outlines(glyphs,shapes)
                end
            end
        end
    end
end
