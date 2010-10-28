if not modules then modules = { } end modules ['font-otf'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- langs -> languages enz
-- anchor_classes vs kernclasses
-- modification/creationtime in subfont is runtime dus zinloos
-- to_table -> totable

local utf = unicode.utf8

local concat, utfbyte = table.concat, utf.byte
local format, gmatch, gsub, find, match, lower, strip = string.format, string.gmatch, string.gsub, string.find, string.match, string.lower, string.strip
local type, next, tonumber, tostring = type, next, tonumber, tostring
local abs = math.abs
local getn = table.getn
local lpegmatch = lpeg.match
local reverse = table.reverse
local ioflush = io.flush

local allocate = utilities.storage.allocate

local trace_private    = false  trackers.register("otf.private",    function(v) trace_private      = v end)
local trace_loading    = false  trackers.register("otf.loading",    function(v) trace_loading      = v end)
local trace_features   = false  trackers.register("otf.features",   function(v) trace_features     = v end)
local trace_dynamics   = false  trackers.register("otf.dynamics",   function(v) trace_dynamics     = v end)
local trace_sequences  = false  trackers.register("otf.sequences",  function(v) trace_sequences    = v end)
local trace_math       = false  trackers.register("otf.math",       function(v) trace_math         = v end)
local trace_defining   = false  trackers.register("fonts.defining", function(v) trace_defining     = v end)

local report_otf = logs.new("load otf")

local starttiming, stoptiming, elapsedtime = statistics.starttiming, statistics.stoptiming, statistics.elapsedtime

local fonts          = fonts

fonts.otf            = fonts.otf or { }
local otf            = fonts.otf
local tfm            = fonts.tfm

local fontdata       = fonts.ids
local chardata       = characters.data

otf.features         = otf.features         or { }
otf.features.list    = otf.features.list    or { }
otf.features.default = otf.features.default or { }

otf.enhancers        = allocate()
local enhancers      = otf.enhancers
enhancers.patches    = { }

local definers       = fonts.definers

otf.glists           = { "gsub", "gpos" }

otf.version          = 2.705 -- beware: also sync font-mis.lua
otf.cache            = containers.define("fonts", "otf", otf.version, true)

local loadmethod     = "table" -- table, mixed, sparse
local forceload      = false
local cleanup        = 0
local usemetatables  = false -- .4 slower on mk but 30 M less mem so we might change the default -- will be directive
local packdata       = true
local syncspace      = true
local forcenotdef    = false

local wildcard       = "*"
local default        = "dflt"

local fontloaderfields = fontloader.fields
local mainfields       = nil
local glyphfields      = nil -- not used yet

directives.register("fonts.otf.loader.method", function(v)
    if v == "sparse" and fontloaderfields then
        loadmethod = "sparse"
    elseif v == "mixed" then
        loadmethod = "mixed"
    elseif v == "table" then
        loadmethod = "table"
    else
        loadmethod = "table"
        report_otf("no loader method '%s', using '%s' instead",v,loadmethod)
    end
end)

directives.register("fonts.otf.loader.cleanup",function(v)
    cleanup = tonumber(v) or (v and 1) or 0
end)

directives.register("fonts.otf.loader.force",          function(v) forceload     = v end)
directives.register("fonts.otf.loader.usemetatables",  function(v) usemetatables = v end)
directives.register("fonts.otf.loader.pack",           function(v) packdata      = v end)
directives.register("fonts.otf.loader.syncspace",      function(v) syncspace     = v end)
directives.register("fonts.otf.loader.forcenotdef",    function(v) forcenotdef   = v end)

local function load_featurefile(raw,featurefile)
    if featurefile and featurefile ~= "" then
        if trace_loading then
            report_otf("featurefile: %s", featurefile)
        end
        fontloader.apply_featurefile(raw, featurefile)
    end
end

local function showfeatureorder(otfdata,filename)
    local sequences = otfdata.luatex.sequences
    if sequences and #sequences > 0 then
        if trace_loading then
            report_otf("font %s has %s sequences",filename,#sequences)
            report_otf(" ")
        end
        for nos=1,#sequences do
            local sequence = sequences[nos]
            local typ = sequence.type or "no-type"
            local name = sequence.name or "no-name"
            local subtables = sequence.subtables or { "no-subtables" }
            local features = sequence.features
            if trace_loading then
                report_otf("%3i  %-15s  %-20s  [%s]",nos,name,typ,concat(subtables,","))
            end
            if features then
                for feature, scripts in next, features do
                    local tt = { }
                    for script, languages in next, scripts do
                        local ttt = { }
                        for language, _ in next, languages do
                            ttt[#ttt+1] = language
                        end
                        tt[#tt+1] = format("[%s: %s]",script,concat(ttt," "))
                    end
                    if trace_loading then
                        report_otf("       %s: %s",feature,concat(tt," "))
                    end
                end
            end
        end
        if trace_loading then
            report_otf("\n")
        end
    elseif trace_loading then
        report_otf("font %s has no sequences",filename)
    end
end

--[[ldx--
<p>We start with a lot of tables and related functions.</p>
--ldx]]--

local global_fields = table.tohash {
    "metadata",
    "lookups",
    "glyphs",
    "subfonts",
    "luatex",
    "pfminfo",
    "cidinfo",
    "tables",
    "names",
    "unicodes",
    "names",
 -- "math",
    "anchor_classes",
    "kern_classes",
    "gpos",
    "gsub"
}

local valid_fields = table.tohash {
 -- "anchor_classes",
    "ascent",
 -- "cache_version",
    "cidinfo",
    "copyright",
 -- "creationtime",
    "descent",
    "design_range_bottom",
    "design_range_top",
    "design_size",
    "encodingchanged",
    "extrema_bound",
    "familyname",
    "fontname",
    "fontstyle_id",
    "fontstyle_name",
    "fullname",
 -- "glyphs",
    "hasvmetrics",
    "head_optimized_for_cleartype",
    "horiz_base",
    "issans",
    "isserif",
    "italicangle",
 -- "kerns",
 -- "lookups",
 -- "luatex",
    "macstyle",
 -- "modificationtime",
    "onlybitmaps",
    "origname",
    "os2_version",
 -- "pfminfo",
 -- "private",
    "serifcheck",
    "sfd_version",
 -- "size",
    "strokedfont",
    "strokewidth",
    "subfonts",
    "table_version",
 -- "tables",
 -- "ttf_tab_saved",
    "ttf_tables",
    "uni_interp",
    "uniqueid",
    "units_per_em",
    "upos",
    "use_typo_metrics",
    "uwidth",
 -- "validation_state",
    "verbose",
    "version",
    "vert_base",
    "weight",
    "weight_width_slope_only",
 -- "xuid",
}

local ordered_enhancers = {
    "prepare tables",
    "prepare glyphs",
    "prepare unicodes",
    "prepare lookups",

    "analyze glyphs",
    "analyze math",

    "prepare tounicode", -- maybe merge with prepare

    "reorganize lookups",
    "reorganize mark classes",
    "reorganize anchor classes",

    "reorganize glyph kerns",
    "reorganize glyph lookups",
    "reorganize glyph anchors",

    "reorganize features",
    "reorganize subtables",

    "check glyphs",
    "check metadata",
    "check math parameters",
    "check extra features", -- after metadata
}

--[[ldx--
<p>Here we go.</p>
--ldx]]--

local actions = { }

enhancers.patches.before = allocate()
enhancers.patches.after  = allocate()

local before = enhancers.patches.before
local after  = enhancers.patches.after

local function enhance(name,data,filename,raw,verbose)
    local enhancer = actions[name]
    if enhancer then
        if verbose then
            report_otf("enhance: %s (%s)",name,filename)
            ioflush()
        end
        enhancer(data,filename,raw)
    else
        report_otf("enhance: %s is undefined",name)
    end
end

function enhancers.apply(data,filename,raw,verbose)
    local basename = file.basename(lower(filename))
    report_otf("start enhancing: %s",filename)
    ioflush() -- we want instant messages
    for e=1,#ordered_enhancers do
        local enhancer = ordered_enhancers[e]
        local b = before[enhancer]
        if b then
            for pattern, action in next, b do
                if find(basename,pattern) then
                    action(data,filename,raw)
                end
            end
        end
        enhance(enhancer,data,filename,raw,verbose)
        local a = after[enhancer]
        if a then
            for pattern, action in next, a do
                if find(basename,pattern) then
                    action(data,filename,raw)
                end
            end
        end
        ioflush() -- we want instant messages
    end
    report_otf("stop enhancing")
    ioflush() -- we want instant messages
end

-- enhancers.patches.register("before","migrate metadata","cambria",function() end)

function enhancers.patches.register(what,where,pattern,action)
    local ww = what[where]
    if ww then
        ww[pattern] = action
    else
        ww = { [pattern] = action}
    end
end

function enhancers.register(what,action) -- only already registered can be overloaded
    actions[what] = action
end

function otf.load(filename,format,sub,featurefile)
    local name = file.basename(file.removesuffix(filename))
    local attr = lfs.attributes(filename)
    local size, time = attr and attr.size or 0, attr and attr.modification or 0
    if featurefile then
        name = name .. "@" .. file.removesuffix(file.basename(featurefile))
    end
    if sub == "" then sub = false end
    local hash = name
    if sub then
        hash = hash .. "-" .. sub
    end
    hash = containers.cleanname(hash)
    local featurefiles
    if featurefile then
        featurefiles = { }
        for s in gmatch(featurefile,"[^,]+") do
            local name = resolvers.findfile(file.addsuffix(s,'fea'),'fea') or ""
            if name == "" then
                report_otf("loading: no featurefile '%s'",s)
            else
                local attr = lfs.attributes(name)
                featurefiles[#featurefiles+1] = {
                    name = name,
                    size = attr.size or 0,
                    time = attr.modification or 0,
                }
            end
        end
        if #featurefiles == 0 then
            featurefiles = nil
        end
    end
    local data = containers.read(otf.cache,hash)
    local reload = not data or data.verbose ~= fonts.verbose or data.size ~= size or data.time ~= time
    if forceload then
        report_otf("loading: forced reload due to hard coded flag")
        reload = true
    end
    if not reload then
        local featuredata = data.featuredata
        if featurefiles then
            if not featuredata or #featuredata ~= #featurefiles then
                reload = true
            else
                for i=1,#featurefiles do
                    local fi, fd = featurefiles[i], featuredata[i]
                    if fi.name ~= fd.name or fi.size ~= fd.size or fi.time ~= fd.time then
                        reload = true
                        break
                    end
                end
            end
        elseif featuredata then
            reload = true
        end
        if reload then
           report_otf("loading: forced reload due to changed featurefile specification: %s",featurefile or "--")
        end
     end
     if reload then
        report_otf("loading: %s (hash: %s)",filename,hash)
        local fontdata, messages, rawdata
        if sub then
            fontdata, messages = fontloader.open(filename,sub)
        else
            fontdata, messages = fontloader.open(filename)
        end
        if fontdata then
            mainfields = mainfields or (fontloaderfields and fontloaderfields(fontdata))
        end
        if trace_loading and messages and #messages > 0 then
            if type(messages) == "string" then
                report_otf("warning: %s",messages)
            else
                for m=1,#messages do
                    report_otf("warning: %s",tostring(messages[m]))
                end
            end
        else
            report_otf("font loaded okay")
        end
        if fontdata then
            if featurefiles then
                for i=1,#featurefiles do
                    load_featurefile(fontdata,featurefiles[i].name)
                end
            end
            report_otf("loading method: %s",loadmethod)
            if loadmethod == "sparse" then
                rawdata = fontdata
            else
                rawdata = fontloader.to_table(fontdata)
                fontloader.close(fontdata)
            end
            if rawdata then
                data = { }
                starttiming(data)
                local verboseindeed = verbose ~= nil and verbose or trace_loading
                report_otf("file size: %s", size)
                enhancers.apply(data,filename,rawdata,verboseindeed)
                if packdata and not fonts.verbose then
                    enhance("pack",data,filename,nil,verboseindeed)
                end
                data.size = size
                data.time = time
                if featurefiles then
                    data.featuredata = featurefiles
                end
                data.verbose = fonts.verbose
                report_otf("saving in cache: %s",filename)
                data = containers.write(otf.cache, hash, data)
                if cleanup > 0 then
                    collectgarbage("collect")
                end
                stoptiming(data)
                if elapsedtime then -- not in generic
                    report_otf("preprocessing and caching took %s seconds",elapsedtime(data))
                end
                data = containers.read(otf.cache, hash) -- this frees the old table and load the sparse one
                if cleanup > 1 then
                    collectgarbage("collect")
                end
            else
                data = nil
                report_otf("loading failed (table conversion error)")
            end
            if loadmethod == "sparse" then
                fontloader.close(fontdata)
                if cleanup > 2 then
                 -- collectgarbage("collect")
                end
            end
        else
            data = nil
            report_otf("loading failed (file read error)")
        end
    end
    if data then
        if trace_defining then
            report_otf("loading from cache: %s",hash)
        end
        enhance("unpack",data,filename,nil,false)
        enhance("add dimensions",data,filename,nil,false)
        if trace_sequences then
            showfeatureorder(data,filename)
        end
    end
    return data
end

local mt = {
    __index = function(t,k) -- maybe set it
        if k == "height" then
            local ht = t.boundingbox[4]
            return ht < 0 and 0 or ht
        elseif k == "depth" then
            local dp = -t.boundingbox[2]
            return dp < 0 and 0 or dp
        elseif k == "width" then
            return 0
        elseif k == "name" then -- or maybe uni*
            return forcenotdef and ".notdef"
        end
    end
}

actions["add dimensions"] = function(data,filename)
    -- todo: forget about the width if it's the defaultwidth (saves mem)
    -- we could also build the marks hash here (instead of storing it)
    if data then
        local luatex = data.luatex
        local defaultwidth  = luatex.defaultwidth  or 0
        local defaultheight = luatex.defaultheight or 0
        local defaultdepth  = luatex.defaultdepth  or 0
        if usemetatables then
            for _, d in next, data.glyphs do
                local wd = d.width
                if not wd then
                    d.width = defaultwidth
                elseif wd ~= 0 and d.class == "mark" then
                    d.width  = -wd
                end
                setmetatable(d,mt)
            end
        else
            for _, d in next, data.glyphs do
                local bb, wd = d.boundingbox, d.width
                if not wd then
                    d.width = defaultwidth
                elseif wd ~= 0 and d.class == "mark" then
                    d.width  = -wd
                end
                if forcenotdef and not d.name then
                    d.name = ".notdef"
                end
                if bb then
                    local ht, dp = bb[4], -bb[2]
                    if ht == 0 or ht < 0 then
                        -- not set
                    else
                        d.height = ht
                    end
                    if dp == 0 or dp < 0 then
                        -- not set
                    else
                        d.depth  = dp
                    end
                end
            end
        end
    end
end

actions["prepare tables"] = function(data,filename,raw)
    local luatex = {
        filename = filename,
        version  = otf.version,
        creator  = "context mkiv",
    }
    data.luatex = luatex
    data.metadata = { }
end

local function somecopy(old) -- fast one
    if old then
        local new = { }
        if type(old) == "table" then
            for k, v in next, old do
                if k == "glyphs" then
                    -- skip
                elseif type(v) == "table" then
                    new[k] = somecopy(v)
                else
                    new[k] = v
                end
            end
        else
            for i=1,#mainfields do
                local k = mainfields[i]
                local v = old[k]
                if k == "glyphs" then
                    -- skip
                elseif type(v) == "table" then
                    new[k] = somecopy(v)
                else
                    new[k] = v
                end
            end
        end
        return new
    else
        return { }
    end
end

-- not setting italic_correction and class (when nil) during
-- table cronstruction can save some mem

actions["prepare glyphs"] = function(data,filename,raw)
    -- we can also move the names to data.luatex.names which might
    -- save us some more memory (at the cost of harder tracing)
    local rawglyphs = raw.glyphs
    local glyphs, udglyphs
    if loadmethod == "sparse" then
        glyphs, udglyphs = { }, { }
    elseif loadmethod == "mixed" then
        glyphs, udglyphs = { }, rawglyphs
    else
        glyphs, udglyphs = rawglyphs, rawglyphs
    end
    data.glyphs, data.udglyphs = glyphs, udglyphs
    local subfonts = raw.subfonts
    if subfonts then
        if data.glyphs and next(data.glyphs) then
            report_otf("replacing existing glyph table due to subfonts")
        end
        local cidinfo = raw.cidinfo
        if cidinfo.registry then
            local cidmap, cidname = fonts.cid.getmap(cidinfo.registry,cidinfo.ordering,cidinfo.supplement)
            if cidmap then
                cidinfo.usedname = cidmap.usedname
                local uni_to_int, int_to_uni, nofnames, nofunicodes = { }, { }, 0, 0
                local unicodes, names = cidmap.unicodes, cidmap.names
                for cidindex=1,#subfonts do
                    local subfont = subfonts[cidindex]
                    if loadmethod == "sparse" then
                        local rawglyphs = subfont.glyphs
                        for index=0,subfont.glyphmax - 1 do
                            local g = rawglyphs[index]
                            if g then
                                local unicode, name = unicodes[index], names[index]
                                if unicode then
                                    uni_to_int[unicode] = index
                                    int_to_uni[index] = unicode
                                    nofunicodes = nofunicodes + 1
                                elseif name then
                                    nofnames = nofnames + 1
                                end
                                udglyphs[index] = g
                                glyphs[index] = {
                                    width       = g.width,
                                    italic      = g.italic_correction,
                                    boundingbox = g.boundingbox,
                                    class       = g.class,
                                    name        = g.name or name or "unknown", -- uniXXXX
                                    cidindex    = cidindex,
                                    unicode     = unicode,
                                }
                            end
                        end
                        -- If we had more userdata, we would need more of this
                        -- and it would start working against us in terms of
                        -- convenience and speed.
                        subfont = somecopy(subfont)
                        subfont.glyphs = nil
                        subfont[cidindex] = subfont
                    elseif loadmethod == "mixed" then
                        for index, g in next, subfont.glyphs do
                            local unicode, name = unicodes[index], names[index]
                            if unicode then
                                uni_to_int[unicode] = index
                                int_to_uni[index] = unicode
                                nofunicodes = nofunicodes + 1
                            elseif name then
                                nofnames = nofnames + 1
                            end
                            udglyphs[index] = g
                            glyphs[index] = {
                                width       = g.width,
                                italic      = g.italic_correction,
                                boundingbox = g.boundingbox,
                                class       = g.class,
                                name        = g.name or name or "unknown", -- uniXXXX
                                cidindex    = cidindex,
                                unicode     = unicode,
                            }
                        end
                        subfont.glyphs = nil
                    else
                        for index, g in next, subfont.glyphs do
                            local unicode, name = unicodes[index], names[index]
                            if unicode then
                                uni_to_int[unicode] = index
                                int_to_uni[index] = unicode
                                nofunicodes = nofunicodes + 1
                                g.unicode = unicode
                            elseif name then
                                nofnames = nofnames + 1
                            end
                            g.cidindex = cidindex
                            glyphs[index] = g
                        end
                        subfont.glyphs = nil
                    end
                end
                if trace_loading then
                    report_otf("cid font remapped, %s unicode points, %s symbolic names, %s glyphs",nofunicodes, nofnames, nofunicodes+nofnames)
                end
                data.map = data.map or { }
                data.map.map = uni_to_int
                data.map.backmap = int_to_uni
            elseif trace_loading then
                report_otf("unable to remap cid font, missing cid file for %s",filename)
            end
            data.subfonts = subfonts
        elseif trace_loading then
            report_otf("font %s has no glyphs",filename)
        end
    else
        if loadmethod == "sparse" then
            -- we get fields from the userdata glyph table and create
            -- a minimal entry first
            for index=0,raw.glyphmax - 1 do
                local g = rawglyphs[index]
                if g then
                    udglyphs[index] = g
                    glyphs[index] = {
                        width       = g.width,
                        italic      = g.italic_correction,
                        boundingbox = g.boundingbox,
                        class       = g.class,
                        name        = g.name,
                        unicode     = g.unicode,
                    }
                end
            end
        elseif loadmethod == "mixed" then
            -- we get fields from the totable glyph table and copy to the
            -- final glyph table so first we create a minimal entry
            for index, g in next, rawglyphs do
                udglyphs[index] = g
                glyphs[index] = {
                    width       = g.width,
                    italic      = g.italic_correction,
                    boundingbox = g.boundingbox,
                    class       = g.class,
                    name        = g.name,
                    unicode     = g.unicode,
                }
            end
        else
            -- we use the totable glyph table directly and manipulate the
            -- entries in this (also final) table
        end
        data.map = raw.map
    end
    data.cidinfo = raw.cidinfo -- hack
end

-- watch copy of cidinfo: we can best make some more copies to data

actions["analyze glyphs"] = function(data,filename,raw) -- maybe integrate this in the previous
    local glyphs = data.glyphs
    -- collect info
    local has_italic, widths, marks = false, { }, { }
    for index, glyph in next, glyphs do
        local italic = glyph.italic_correction
        if not italic then
            -- skip
        elseif italic == 0 then
            glyph.italic_correction = nil
            glyph.italic = nil
        else
            glyph.italic_correction = nil
            glyph.italic = italic
            has_italic = true
        end
        local width = glyph.width
        widths[width] = (widths[width] or 0) + 1
        local class = glyph.class
        local unicode = glyph.unicode
        if class == "mark" then
            marks[unicode] = true
     -- elseif chardata[unicode].category == "mn" then
     --     marks[unicode] = true
     --     glyph.class = "mark"
        end
        local a = glyph.altuni     if a then glyph.altuni     = nil end
        local d = glyph.dependents if d then glyph.dependents = nil end
        local v = glyph.vwidth     if v then glyph.vwidth     = nil end
    end
    -- flag italic
    data.metadata.has_italic = has_italic
    -- flag marks
    data.luatex.marks = marks
    -- share most common width for cjk fonts
    local wd, most = 0, 1
    for k,v in next, widths do
        if v > most then
            wd, most = k, v
        end
    end
    if most > 1000 then -- maybe 500
        if trace_loading then
            report_otf("most common width: %s (%s times), sharing (cjk font)",wd,most)
        end
        for index, glyph in next, glyphs do
            if glyph.width == wd then
                glyph.width = nil
            end
        end
        data.luatex.defaultwidth = wd
    end
end

actions["reorganize mark classes"] = function(data,filename,raw)
    local mark_classes = raw.mark_classes
    if mark_classes then
        local luatex = data.luatex
        local unicodes = luatex.unicodes
        local reverse = { }
        luatex.markclasses = reverse
        for name, class in next, mark_classes do
            local t = { }
            for s in gmatch(class,"[^ ]+") do
                local us = unicodes[s]
                if type(us) == "table" then
                    for u=1,#us do
                        t[us[u]] = true
                    end
                else
                    t[us] = true
                end
            end
            reverse[name] = t
        end
        data.mark_classes = nil -- when using table
    end
end

actions["reorganize features"] = function(data,filename,raw) -- combine with other
    local features = { }
    data.luatex.features = features
    for k, what in next, otf.glists do
        local dw = raw[what]
        if dw then
            local f = { }
            features[what] = f
            for i=1,#dw do
                local d= dw[i]
                local dfeatures = d.features
                if dfeatures then
                    for i=1,#dfeatures do
                        local df = dfeatures[i]
                        local tag = strip(lower(df.tag))
                        local ft = f[tag] if not ft then ft = {} f[tag] = ft end
                        local dscripts = df.scripts
                        for i=1,#dscripts do
                            local d = dscripts[i]
                            local languages = d.langs
                            local script = strip(lower(d.script))
                            local fts = ft[script] if not fts then fts = {} ft[script] = fts end
                            for i=1,#languages do
                                fts[strip(lower(languages[i]))] = true
                            end
                        end
                    end
                end
            end
        end
    end
end

actions["reorganize anchor classes"] = function(data,filename,raw)
    local classes = raw.anchor_classes -- anchor classes not in final table
    local luatex = data.luatex
    local anchor_to_lookup, lookup_to_anchor = { }, { }
    luatex.anchor_to_lookup, luatex.lookup_to_anchor = anchor_to_lookup, lookup_to_anchor
    if classes then
        for c=1,#classes do
            local class = classes[c]
            local anchor = class.name
            local lookups = class.lookup
            if type(lookups) ~= "table" then
                lookups = { lookups }
            end
            local a = anchor_to_lookup[anchor]
            if not a then a = { } anchor_to_lookup[anchor] = a end
            for l=1,#lookups do
                local lookup = lookups[l]
                local l = lookup_to_anchor[lookup]
                if not l then l = { } lookup_to_anchor[lookup] = l end
                l[anchor] = true
                a[lookup] = true
            end
        end
    end
end

actions["prepare tounicode"] = function(data,filename,raw)
    fonts.map.addtounicode(data,filename)
end

actions["reorganize subtables"] = function(data,filename,raw)
    local luatex = data.luatex
    local sequences, lookups = { }, { }
    luatex.sequences, luatex.lookups = sequences, lookups
    for _, what in next, otf.glists do
        local dw = raw[what]
        if dw then
            for k=1,#dw do
                local gk = dw[k]
                local typ = gk.type
                local chain =
                    (typ == "gsub_contextchain"        or typ == "gpos_contextchain")        and  1 or
                    (typ == "gsub_reversecontextchain" or typ == "gpos_reversecontextchain") and -1 or 0
                --
                local subtables = gk.subtables
                if subtables then
                    local t = { }
                    for s=1,#subtables do
                        local subtable = subtables[s]
                        local name = subtable.name
                        t[#t+1] = name
                    end
                    subtables = t
                end
                local flags, markclass = gk.flags, nil
                if flags then
                    local t = { -- forcing false packs nicer
                        (flags.ignorecombiningmarks and "mark")     or false,
                        (flags.ignoreligatures      and "ligature") or false,
                        (flags.ignorebaseglyphs     and "base")     or false,
                         flags.r2l                                  or false,
                    }
                    markclass = flags.mark_class
                    if markclass then
                        markclass = luatex.markclasses[markclass]
                    end
                    flags = t
                end
                --
                local name = gk.name
                --
                local features = gk.features
                if features then
                    -- scripts, tag, ismac
                    local f = { }
                    for i=1,#features do
                        local df = features[i]
                        local tag = strip(lower(df.tag))
                        local ft = f[tag] if not ft then ft = {} f[tag] = ft end
                        local dscripts = df.scripts
                        for i=1,#dscripts do
                            local d = dscripts[i]
                            local languages = d.langs
                            local script = strip(lower(d.script))
                            local fts = ft[script] if not fts then fts = {} ft[script] = fts end
                            for i=1,#languages do
                                fts[strip(lower(languages[i]))] = true
                            end
                        end
                    end
                    sequences[#sequences+1] = {
                        type      = typ,
                        chain     = chain,
                        flags     = flags,
                        name      = name,
                        subtables = subtables,
                        markclass = markclass,
                        features  = f,
                    }
                else
                    lookups[name] = {
                        type      = typ,
                        chain     = chain,
                        flags     = flags,
                        subtables = subtables,
                        markclass = markclass,
                    }
                end
            end
        end
    end
end

actions["prepare unicodes"] = function(data,filename,raw)
    local luatex = data.luatex
    local indices, unicodes, multiples, internals = { }, { }, { }, { }
    local mapmap = data.map or raw.map
    if not mapmap then
        report_otf("no map in %s",filename)
        mapmap = { }
        data.map = { map = mapmap }
    elseif not mapmap.map then
        report_otf("no unicode map in %s",filename)
        mapmap = { }
        data.map.map = mapmap
    else
        mapmap = mapmap.map
    end
    local criterium = fonts.privateoffset
    local private = criterium
    local glyphs = data.glyphs
    for index, glyph in next, glyphs do
        if index > 0 then
            local name = glyph.name -- really needed ?
            if name then
                local unicode = glyph.unicode
                if not unicode or unicode == -1 or unicode >= criterium then
                    glyph.unicode = private
                    indices[private] = index
                    unicodes[name] = private
                    internals[index] = true
                    if trace_private then
                        report_otf("enhance: glyph %s at index U+%04X is moved to private unicode slot U+%04X",name,index,private)
                    end
                    private = private + 1
                else
                    indices[unicode] = index
                    unicodes[name] = unicode
                end
            else
                -- message that something is wrong
            end
        end
    end
    -- beware: the indices table is used to initialize the tfm table
    for unicode, index in next, mapmap do
        if not internals[index] then
            local name = glyphs[index].name
            if name then
                local un = unicodes[name]
                if not un then
                    unicodes[name] = unicode -- or 0
                elseif type(un) == "number" then -- tonumber(un)
                    if un ~= unicode then
                        multiples[#multiples+1] = name
                        unicodes[name] = { un, unicode }
                        indices[unicode] = index
                    end
                else
                    local ok = false
                    for u=1,#un do
                        if un[u] == unicode then
                            ok = true
                            break
                        end
                    end
                    if not ok then
                        multiples[#multiples+1] = name
                        un[#un+1] = unicode
                        indices[unicode] = index
                    end
                end
            end
        end
    end
    if trace_loading then
        if #multiples > 0 then
            report_otf("%s glyphs are reused: %s",#multiples, concat(multiples," "))
        else
            report_otf("no glyphs are reused")
        end
    end
    luatex.indices = indices
    luatex.unicodes = unicodes
    luatex.private = private
end

actions["prepare lookups"] = function(data,filename,raw)
    local lookups = raw.lookups
    if lookups then
        data.lookups = lookups
    end
end

actions["reorganize lookups"] = function(data,filename,raw)
    -- we prefer the before lookups in a normal order
    if data.lookups then
        for _, v in next, data.lookups do
            if v.rules then
                for _, vv in next, v.rules do
                    local c = vv.coverage
                    if c and c.before then
                        c.before = reverse(c.before)
                    end
                end
            end
        end
    end
end

actions["analyze math"] = function(data,filename,raw)
    if raw.math then
data.metadata.math = raw.math
        -- we move the math stuff into a math subtable because we then can
        -- test faster in the tfm copy
        local glyphs, udglyphs = data.glyphs, data.udglyphs
        local unicodes = data.luatex.unicodes
        for index, udglyph in next, udglyphs do
            local mk = udglyph.mathkern
            local hv = udglyph.horiz_variants
            local vv = udglyph.vert_variants
            if mk or hv or vv then
                local glyph = glyphs[index]
                local math = { }
                glyph.math = math
                if mk then
                    for k, v in next, mk do
                        if not next(v) then
                            mk[k] = nil
                        end
                    end
                    math.kerns = mk
                end
                if hv then
                    math.horiz_variants = hv.variants
                    local p = hv.parts
                    if p and #p > 0 then
                        for i=1,#p do
                            local pi = p[i]
                            pi.glyph = unicodes[pi.component] or 0
                        end
                        math.horiz_parts = p
                    end
                    local ic = hv.italic_correction
                    if ic and ic ~= 0 then
                        math.horiz_italic_correction = ic
                    end
                end
                if vv then
                    local uc = unicodes[index]
                    math.vert_variants = vv.variants
                    local p = vv.parts
                    if p and #p > 0 then
                        for i=1,#p do
                            local pi = p[i]
                            pi.glyph = unicodes[pi.component] or 0
                        end
                        math.vert_parts = p
                    end
                    local ic = vv.italic_correction
                    if ic and ic ~= 0 then
                        math.vert_italic_correction = ic
                    end
                end
                local ic = glyph.italic_correction
                if ic then
                    if ic ~= 0 then
                        math.italic_correction = ic
                    end
                end
            end
        end
    end
end

actions["reorganize glyph kerns"] = function(data,filename,raw)
    local luatex = data.luatex
    local udglyphs, glyphs, mapmap, unicodes = data.udglyphs, data.glyphs, luatex.indices, luatex.unicodes
    local mkdone = false
    local function do_it(lookup,first_unicode,extrakerns) -- can be moved inline but seldom used
        local glyph = glyphs[mapmap[first_unicode]]
        if glyph then
            local kerns = glyph.kerns
            if not kerns then
                kerns = { } -- unicode indexed !
                glyph.kerns = kerns
            end
            local lookupkerns = kerns[lookup]
            if not lookupkerns then
                lookupkerns = { }
                kerns[lookup] = lookupkerns
            end
            for second_unicode, kern in next, extrakerns do
                lookupkerns[second_unicode] = kern
            end
        elseif trace_loading then
            report_otf("no glyph data for U+%04X", first_unicode)
        end
    end
    for index, udglyph in next, data.udglyphs do
        local kerns = udglyph.kerns
        if kerns then
            local glyph = glyphs[index]
            local newkerns = { }
            for k,v in next, kerns do
                local vc, vo, vl = v.char, v.off, v.lookup
                if vc and vo and vl then -- brrr, wrong! we miss the non unicode ones
                    local uvc = unicodes[vc]
                    if not uvc then
                        if trace_loading then
                            report_otf("problems with unicode %s of kern %s at glyph %s",vc,k,index)
                        end
                    else
                        if type(vl) ~= "table" then
                            vl = { vl }
                        end
                        for l=1,#vl do
                            local vll = vl[l]
                            local mkl = newkerns[vll]
                            if not mkl then
                                mkl = { }
                                newkerns[vll] = mkl
                            end
                            if type(uvc) == "table" then
                                for u=1,#uvc do
                                    mkl[uvc[u]] = vo
                                end
                            else
                                mkl[uvc] = vo
                            end
                        end
                    end
                end
            end
            glyph.kerns = newkerns -- udglyph.kerns = nil when in mixed mode
            mkdone = true
        end
    end
    if trace_loading and mkdone then
        report_otf("replacing 'kerns' tables by a new 'kerns' tables")
    end
    local dgpos = raw.gpos
    if dgpos then
        local separator = lpeg.P(" ")
        local other = ((1 - separator)^0) / unicodes
        local splitter = lpeg.Ct(other * (separator * other)^0)
        for gp=1,#dgpos do
            local gpos = dgpos[gp]
            local subtables = gpos.subtables
            if subtables then
                for s=1,#subtables do
                    local subtable = subtables[s]
                    local kernclass = subtable.kernclass -- name is inconsistent with anchor_classes
                    if kernclass then -- the next one is quite slow
                        local split = { } -- saves time
                        for k=1,#kernclass do
                            local kcl = kernclass[k]
                            local firsts, seconds, offsets, lookups = kcl.firsts, kcl.seconds, kcl.offsets, kcl.lookup -- singular
                            if type(lookups) ~= "table" then
                                lookups = { lookups }
                            end
                            local maxfirsts, maxseconds = getn(firsts), getn(seconds)
                            -- here we could convert split into a list of unicodes which is a bit
                            -- faster but as this is only done when caching it does not save us much
                            for _, s in next, firsts do
                                split[s] = split[s] or lpegmatch(splitter,s)
                            end
                            for _, s in next, seconds do
                                split[s] = split[s] or lpegmatch(splitter,s)
                            end
                            for l=1,#lookups do
                                local lookup = lookups[l]
                                for fk=1,#firsts do
                                    local fv = firsts[fk]
                                    local splt = split[fv]
                                    if splt then
                                        local kerns, baseoffset = { }, (fk-1) * maxseconds
                                        for sk=2,maxseconds do
                                            local sv = seconds[sk]
                                            local splt = split[sv]
                                            if splt then
                                                local offset = offsets[baseoffset + sk]
                                                if offset then
                                                    for i=1,#splt do
                                                        local second_unicode = splt[i]
                                                        if tonumber(second_unicode) then
                                                            kerns[second_unicode] = offset
                                                        else for s=1,#second_unicode do
                                                            kerns[second_unicode[s]] = offset
                                                        end end
                                                    end
                                                end
                                            end
                                        end
                                        for i=1,#splt do
                                            local first_unicode = splt[i]
                                            if tonumber(first_unicode) then
                                                do_it(lookup,first_unicode,kerns)
                                            else for f=1,#first_unicode do
                                                do_it(lookup,first_unicode[f],kerns)
                                            end end
                                        end
                                    end
                                end
                            end
                        end
                        subtable.comment = "The kernclass table is merged into kerns in the indexed glyph tables."
                        subtable.kernclass = { }
                    end
                end
            end
        end
    end
end

actions["check glyphs"] = function(data,filename,raw)
    local verbose = fonts.verbose
    local int_to_uni = data.luatex.unicodes
    for k, v in next, data.glyphs do
        if verbose then
            local code = int_to_uni[k]
            -- looks like this is done twice ... bug?
            if code then
                local vu = v.unicode
                if not vu then
                    v.unicode = code
                elseif type(vu) == "table" then
                    if vu[#vu] == code then
                        -- weird
                    else
                        vu[#vu+1] = code
                    end
                elseif vu ~= code then
                    v.unicode = { vu, code }
                end
            end
        else
            v.unicode = nil
            v.index = nil
        end
        -- only needed on non sparse/mixed mode
        if v.math then
            if v.mathkern      then v.mathkern      = nil end
            if v.horiz_variant then v.horiz_variant = nil end
            if v.vert_variants then v.vert_variants = nil end
        end
        --
    end
    data.luatex.comment = "Glyph tables have their original index. When present, kern tables are indexed by unicode."
end

actions["check metadata"] = function(data,filename,raw)
    local metadata = data.metadata
    metadata.method = loadmethod
    if loadmethod == "sparse" then
        for _, k in next, mainfields do
            if valid_fields[k] then
                local v = raw[k]
                if global_fields[k] then
                    if not data[k] then
                        data[k] = v
                    end
                else
                    if not metadata[k] then
                        metadata[k] = v
                    end
                end
            end
        end
    else
        for k, v in next, raw do
            if valid_fields[k] then
                if global_fields[k] then
                    if not data[k] then
                        data[v] = v
                    end
                else
                    if not metadata[k] then
                        metadata[k] = v
                    end
                end
            end
        end
    end
    local pfminfo = raw.pfminfo
    if pfminfo then
        data.pfminfo = pfminfo
        metadata.isfixedpitch = metadata.isfixedpitch or (pfminfo.panose and pfminfo.panose.proportion == "Monospaced")
        metadata.charwidth    = pfminfo and pfminfo.avgwidth
    end
    local ttftables = metadata.ttf_tables
    if ttftables then
        for i=1,#ttftables do
            ttftables[i].data = "deleted"
        end
    end
    metadata.xuid = nil
    data.udglyphs = nil
    data.map = nil
end

local private_math_parameters = {
    "FractionDelimiterSize",
    "FractionDelimiterDisplayStyleSize",
}

actions["check math parameters"] = function(data,filename,raw)
    local mathdata = data.metadata.math
    if mathdata then
        for m=1,#private_math_parameters do
            local pmp = private_math_parameters[m]
            if not mathdata[pmp] then
                if trace_loading then
                    report_otf("setting math parameter '%s' to 0", pmp)
                end
                mathdata[pmp] = 0
            end
        end
    end
end


-- kern: ttf has a table with kerns
--
-- Weird, as maxfirst and maxseconds can have holes, first seems to be indexed, but
-- seconds can start at 2 .. this need to be fixed as getn as well as # are sort of
-- unpredictable alternatively we could force an [1] if not set (maybe I will do that
-- anyway).

actions["reorganize glyph lookups"] = function(data,filename,raw)
    local glyphs = data.glyphs
    for index, udglyph in next, data.udglyphs do
        local lookups = udglyph.lookups
        if lookups then
            local glyph = glyphs[index]
            local l = { }
            for kk, vv in next, lookups do
                local aa = { }
                l[kk] = aa
                for kkk=1,#vv do
                    local vvv = vv[kkk]
                    local s = vvv.specification
                    local t = vvv.type
                    -- #aa+1
                    if t == "ligature" then
                        aa[kkk] = { "ligature", s.components, s.char }
                    elseif t == "alternate" then
                        aa[kkk] = { "alternate", s.components }
                    elseif t == "substitution" then
                        aa[kkk] = { "substitution", s.variant }
                    elseif t == "multiple" then
                        aa[kkk] = { "multiple", s.components }
                    elseif t == "position" then
                        aa[kkk] = { "position", { s.x or 0, s.y or 0, s.h or 0, s.v or 0 } }
                    elseif t == "pair" then
                        -- maybe flatten this one
                        local one, two, paired = s.offsets[1], s.offsets[2], s.paired or ""
                        if one then
                            if two then
                                aa[kkk] = { "pair", paired, { one.x or 0, one.y or 0, one.h or 0, one.v or 0 }, { two.x or 0, two.y or 0, two.h or 0, two.v or 0 } }
                            else
                                aa[kkk] = { "pair", paired, { one.x or 0, one.y or 0, one.h or 0, one.v or 0 } }
                            end
                        else
                            if two then
                                aa[kkk] = { "pair", paired, { }, { two.x or 0, two.y or 0, two.h or 0, two.v or 0} } -- maybe nil instead of { }
                            else
                                aa[kkk] = { "pair", paired }
                            end
                        end
                    end
                end
            end
            -- we could combine this
            local slookups, mlookups
            for kk, vv in next, l do
                if #vv == 1 then
                    if not slookups then
                        slookups = { }
                        glyph.slookups = slookups
                    end
                    slookups[kk] = vv[1]
                else
                    if not mlookups then
                        mlookups = { }
                        glyph.mlookups = mlookups
                    end
                    mlookups[kk] = vv
                end
            end
            glyph.lookups = nil -- when using table
        end
    end
end

actions["reorganize glyph anchors"] = function(data,filename,raw)
    local glyphs = data.glyphs
    for index, udglyph in next, data.udglyphs do
        local anchors = udglyph.anchors
        if anchors then
            local glyph = glyphs[index]
            local a = { }
            glyph.anchors = a
            for kk, vv in next, anchors do
                local aa = { }
                a[kk] = aa
                for kkk, vvv in next, vv do
                    if vvv.x or vvv.y then
                        aa[kkk] = { vvv.x , vvv.y }
                    else
                        local aaa = { }
                        aa[kkk] = aaa
                        for kkkk=1,#vvv do
                            local vvvv = vvv[kkkk]
                            aaa[kkkk] = { vvvv.x, vvvv.y }
                        end
                    end
                end
            end
        end
    end
end

--~ actions["check extra features"] = function(data,filename,raw)
--~     -- later, ctx only
--~ end

-- -- -- -- -- --
-- -- -- -- -- --

function otf.features.register(name,default)
    otf.features.list[#otf.features.list+1] = name
    otf.features.default[name] = default
end

-- for context this will become a task handler

local lists = { -- why local
    fonts.triggers,
    fonts.processors,
    fonts.manipulators,
}

function otf.setfeatures(tfmdata,features)
    local processes = { }
    if features and next(features) then
        local mode = tfmdata.mode or features.mode or "base"
        local initializers = fonts.initializers
        local fi = initializers[mode]
        if fi then
            local fiotf = fi.otf
            if fiotf then
                local done = { }
                for l=1,#lists do
                    local list = lists[l]
                    if list then
                        for i=1,#list do
                            local f = list[i]
                            local value = features[f]
                            if value and fiotf[f] then -- brr
                                if not done[f] then -- so, we can move some to triggers
                                    if trace_features then
                                        report_otf("initializing feature %s to %s for mode %s for font %s",f,tostring(value),mode or 'unknown', tfmdata.fullname or 'unknown')
                                    end
                                    fiotf[f](tfmdata,value) -- can set mode (no need to pass otf)
                                    mode = tfmdata.mode or features.mode or "base"
                                    local im = initializers[mode]
                                    if im then
                                        fiotf = initializers[mode].otf
                                    end
                                    done[f] = true
                                end
                            end
                        end
                    end
                end
            end
        end
tfmdata.mode = mode
        local fm = fonts.methods[mode] -- todo: zonder node/mode otf/...
        if fm then
            local fmotf = fm.otf
            if fmotf then
                for l=1,#lists do
                    local list = lists[l]
                    if list then
                        for i=1,#list do
                            local f = list[i]
                            if fmotf[f] then -- brr
                                if trace_features then
                                    report_otf("installing feature handler %s for mode %s for font %s",f,mode or 'unknown', tfmdata.fullname or 'unknown')
                                end
                                processes[#processes+1] = fmotf[f]
                            end
                        end
                    end
                end
            end
        else
            -- message
        end
    end
    return processes, features
end

-- the first version made a top/mid/not extensible table, now we just pass on the variants data
-- and deal with it in the tfm scaler (there is no longer an extensible table anyway)

-- we cannot share descriptions as virtual fonts might extend them (ok, we could
-- use a cache with a hash

fonts.formats.dfont = "truetype"
fonts.formats.ttc   = "truetype"
fonts.formats.ttf   = "truetype"
fonts.formats.otf   = "opentype"

local function copytotfm(data,cache_id) -- we can save a copy when we reorder the tma to unicode (nasty due to one->many)
    if data then
        local glyphs, pfminfo, metadata = data.glyphs or { }, data.pfminfo or { }, data.metadata or { }
        local luatex = data.luatex
        local unicodes = luatex.unicodes -- names to unicodes
        local indices = luatex.indices        local mode = data.mode or "base"

        local characters, parameters, math_parameters, descriptions = { }, { }, { }, { }
        local designsize = metadata.designsize or metadata.design_size or 100
        if designsize == 0 then
            designsize = 100
        end
        local spaceunits, spacer = 500, "space"
        -- indices maps from unicodes to indices
        for u, i in next, indices do
            characters[u] = { } -- we need this because for instance we add protruding info and loop over characters
            descriptions[u] = glyphs[i]
        end
        -- math
        if metadata.math then
            -- parameters
            for name, value in next, metadata.math do
                math_parameters[name] = value
            end
            -- we could use a subset
            for u, char in next, characters do
                local d = descriptions[u]
                local m = d.math
                -- we have them shared because that packs nicer
                -- we could prepare the variants and keep 'm in descriptions
                if m then
                    local variants, parts, c = m.horiz_variants, m.horiz_parts, char
                    if variants then
                        for n in gmatch(variants,"[^ ]+") do
                            local un = unicodes[n]
                            if un and u ~= un then
                                c.next = un
                                c = characters[un]
                            end
                        end
                        c.horiz_variants = parts
                    elseif parts then
                        c.horiz_variants = parts
                    end
                    local variants, parts, c = m.vert_variants, m.vert_parts, char
                    if variants then
                        for n in gmatch(variants,"[^ ]+") do
                            local un = unicodes[n]
                            if un and u ~= un then
                                c.next = un
                                c = characters[un]
                            end
                        end -- c is now last in chain
                        c.vert_variants = parts
                    elseif parts then
                        c.vert_variants = parts
                    end
                    local italic_correction = m.vert_italic_correction
                    if italic_correction then
                        c.vert_italic_correction = italic_correction
                    end
                    local kerns = m.kerns
                    if kerns then
                        char.mathkerns = kerns
                    end
                end
            end
        end
        -- end math
        local endash, emdash, space = 0x20, 0x2014, "space" -- unicodes['space'], unicodes['emdash']
        if metadata.isfixedpitch then
            if descriptions[endash] then
                spaceunits, spacer = descriptions[endash].width, "space"
            end
            if not spaceunits and descriptions[emdash] then
                spaceunits, spacer = descriptions[emdash].width, "emdash"
            end
            if not spaceunits and metadata.charwidth then
                spaceunits, spacer = metadata.charwidth, "charwidth"
            end
        else
            if descriptions[endash] then
                spaceunits, spacer = descriptions[endash].width, "space"
            end
            if not spaceunits and descriptions[emdash] then
                spaceunits, spacer = descriptions[emdash].width/2, "emdash/2"
            end
            if not spaceunits and metadata.charwidth then
                spaceunits, spacer = metadata.charwidth, "charwidth"
            end
        end
        spaceunits = tonumber(spaceunits) or tfm.units/2 -- 500 -- brrr
        -- we need a runtime lookup because of running from cdrom or zip, brrr (shouldn't we use the basename then?)
        local filename = fonts.tfm.checkedfilename(luatex)
        local fontname = metadata.fontname
        local fullname = metadata.fullname or fontname
        local cidinfo  = data.cidinfo -- or { }
        local units    = metadata.units_per_em or 1000
        --
        cidinfo.registry = cidinfo and cidinfo.registry or "" -- weird here, fix upstream
        --
        parameters.slant         = 0
        parameters.space         = spaceunits          -- 3.333 (cmr10)
        parameters.space_stretch = units/2   --  500   -- 1.666 (cmr10)
        parameters.space_shrink  = 1*units/3 --  333   -- 1.111 (cmr10)
        parameters.x_height      = 2*units/5 --  400
        parameters.quad          = units     -- 1000
        if spaceunits < 2*units/5 then
            -- todo: warning
        end
        local italicangle = metadata.italicangle
        if italicangle then -- maybe also in afm _
            parameters.slant = parameters.slant - math.round(math.tan(italicangle*math.pi/180))
        end
        if metadata.isfixedpitch then
            parameters.space_stretch = 0
            parameters.space_shrink  = 0
        elseif syncspace then --
            parameters.space_stretch = spaceunits/2
            parameters.space_shrink  = spaceunits/3
        end
        parameters.extra_space = parameters.space_shrink -- 1.111 (cmr10)
        if pfminfo.os2_xheight and pfminfo.os2_xheight > 0 then
            parameters.x_height = pfminfo.os2_xheight
        else
            local x = 0x78 -- unicodes['x']
            if x then
                local x = descriptions[x]
                if x then
                    parameters.x_height = x.height
                end
            end
        end
        --
        return {
            characters         = characters,
            parameters         = parameters,
            math_parameters    = math_parameters,
            descriptions       = descriptions,
            indices            = indices,
            unicodes           = unicodes,
            type               = "real",
            direction          = 0,
            boundarychar_label = 0,
            boundarychar       = 65536,
            designsize         = (designsize/10)*65536,
            spacer             = "500 units",
            encodingbytes      = 2,
            mode               = mode,
            filename           = filename,
            fontname           = fontname,
            fullname           = fullname,
            psname             = fontname or fullname,
            name               = filename or fullname,
            units              = units,
            format             = fonts.fontformat(filename,"opentype"),
            cidinfo            = cidinfo,
            ascender           = abs(metadata.ascent  or 0),
            descender          = abs(metadata.descent or 0),
            spacer             = spacer,
            italicangle        = italicangle,
        }
    else
        return nil
    end
end

local function otftotfm(specification)
    local name     = specification.name
    local sub      = specification.sub
    local filename = specification.filename
    local format   = specification.format
    local features = specification.features.normal
    local cache_id = specification.hash
    local tfmdata  = containers.read(tfm.cache,cache_id)
--~ print(cache_id)
    if not tfmdata then
        local otfdata = otf.load(filename,format,sub,features and features.featurefile)
        if otfdata and next(otfdata) then
            otfdata.shared = otfdata.shared or {
                featuredata = { },
                anchorhash  = { },
                initialized = false,
            }
            tfmdata = copytotfm(otfdata,cache_id)
            if tfmdata and next(tfmdata) then
                tfmdata.unique = tfmdata.unique or { }
                tfmdata.shared = tfmdata.shared or { } -- combine
                local shared = tfmdata.shared
                shared.otfdata = otfdata
                shared.features = features -- default
                shared.dynamics = { }
                shared.processes = { }
                shared.setdynamics = otf.setdynamics -- fast access and makes other modules independent
                -- this will be done later anyway, but it's convenient to have
                -- them already for fast access
                tfmdata.luatex = otfdata.luatex
                tfmdata.indices = otfdata.luatex.indices
                tfmdata.unicodes = otfdata.luatex.unicodes
                tfmdata.marks = otfdata.luatex.marks
                tfmdata.originals = otfdata.luatex.originals
                tfmdata.changed = { }
                tfmdata.has_italic = otfdata.metadata.has_italic
                if not tfmdata.language then tfmdata.language = 'dflt' end
                if not tfmdata.script   then tfmdata.script   = 'dflt' end
                shared.processes, shared.features = otf.setfeatures(tfmdata,definers.check(features,otf.features.default))
            end
        end
        containers.write(tfm.cache,cache_id,tfmdata)
    end
    return tfmdata
end

otf.features.register('mathsize')

function tfm.read_from_otf(specification) -- wrong namespace
    local tfmtable = otftotfm(specification)
    if tfmtable then
        local otfdata = tfmtable.shared.otfdata
        tfmtable.name = specification.name
        tfmtable.sub = specification.sub
        local s = specification.size
        local m = otfdata.metadata.math
        if m then
            -- this will move to a function
            local f = specification.features
            if f then
                local f = f.normal
                if f and f.mathsize then
                    local mathsize = specification.mathsize or 0
                    if mathsize == 2 then
                        local p = m.ScriptPercentScaleDown
                        if p then
                            local ps = p * specification.textsize / 100
                            if trace_math then
                                report_otf("asked script size: %s, used: %s (%2.2f %%)",s,ps,(ps/s)*100)
                            end
                            s = ps
                        end
                    elseif mathsize == 3 then
                        local p = m.ScriptScriptPercentScaleDown
                        if p then
                            local ps = p * specification.textsize / 100
                            if trace_math then
                                report_otf("asked scriptscript size: %s, used: %s (%2.2f %%)",s,ps,(ps/s)*100)
                            end
                            s = ps
                        end
                    end
                end
            end
        end
        tfmtable = tfm.scale(tfmtable,s,specification.relativeid)
        if tfm.fontnamemode == "specification" then
            -- not to be used in context !
            local specname = specification.specification
            if specname then
                tfmtable.name = specname
                if trace_defining then
                    report_otf("overloaded fontname: '%s'",specname)
                end
            end
        end
        fonts.logger.save(tfmtable,file.extname(specification.filename),specification)
    end
--~ print(tfmtable.fullname)
    return tfmtable
end

-- helpers

function otf.collectlookups(otfdata,kind,script,language)
    -- maybe store this in the font
    local sequences = otfdata.luatex.sequences
    if sequences then
        local featuremap, featurelist = { }, { }
        for s=1,#sequences do
            local sequence = sequences[s]
            local features = sequence.features
            features = features and features[kind]
            features = features and (features[script]   or features[default] or features[wildcard])
            features = features and (features[language] or features[default] or features[wildcard])
            if features then
                local subtables = sequence.subtables
                if subtables then
                    for s=1,#subtables do
                        local ss = subtables[s]
                        if not featuremap[s] then
                            featuremap[ss] = true
                            featurelist[#featurelist+1] = ss
                        end
                    end
                end
            end
        end
        if #featurelist > 0 then
            return featuremap, featurelist
        end
    end
    return nil, nil
end
