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
-- ascent descent

local utf = unicode.utf8

local utfbyte = utf.byte
local format, gmatch, gsub, find, match, lower, strip = string.format, string.gmatch, string.gsub, string.find, string.match, string.lower, string.strip
local type, next, tonumber, tostring = type, next, tonumber, tostring
local abs = math.abs
local getn = table.getn
local lpegmatch = lpeg.match
local reversed, concat, remove = table.reversed, table.concat, table.remove
local ioflush = io.flush
local fastcopy, tohash, derivetable = table.fastcopy, table.tohash, table.derive

local allocate           = utilities.storage.allocate
local registertracker    = trackers.register
local registerdirective  = directives.register
local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming
local elapsedtime        = statistics.elapsedtime
local findbinfile        = resolvers.findbinfile

local trace_private      = false  registertracker("otf.private",    function(v) trace_private   = v end)
local trace_loading      = false  registertracker("otf.loading",    function(v) trace_loading   = v end)
local trace_features     = false  registertracker("otf.features",   function(v) trace_features  = v end)
local trace_dynamics     = false  registertracker("otf.dynamics",   function(v) trace_dynamics  = v end)
local trace_sequences    = false  registertracker("otf.sequences",  function(v) trace_sequences = v end)
local trace_markwidth    = false  registertracker("otf.markwidth",  function(v) trace_markwidth = v end)
local trace_defining     = false  registertracker("fonts.defining", function(v) trace_defining  = v end)

local report_otf         = logs.reporter("fonts","otf loading")

local fonts              = fonts
local otf                = fonts.handlers.otf

otf.glists               = { "gsub", "gpos" }

otf.version              = 2.735 -- beware: also sync font-mis.lua
otf.cache                = containers.define("fonts", "otf", otf.version, true)

local fontdata           = fonts.hashes.identifiers
local chardata           = characters and characters.data -- not used

local otffeatures        = fonts.constructors.newfeatures("otf")
local registerotffeature = otffeatures.register

local enhancers          = allocate()
otf.enhancers            = enhancers
local patches            = { }
enhancers.patches        = patches

local definers           = fonts.definers
local readers            = fonts.readers
local constructors       = fonts.constructors

local forceload          = false
local cleanup            = 0     -- mk: 0=885M 1=765M 2=735M (regular run 730M)
local usemetatables      = false -- .4 slower on mk but 30 M less mem so we might change the default -- will be directive
local packdata           = true
local syncspace          = true
local forcenotdef        = false

local wildcard           = "*"
local default            = "dflt"

local fontloaderfields   = fontloader.fields
local mainfields         = nil
local glyphfields        = nil -- not used yet

registerdirective("fonts.otf.loader.cleanup",       function(v) cleanup       = tonumber(v) or (v and 1) or 0 end)
registerdirective("fonts.otf.loader.force",         function(v) forceload     = v end)
registerdirective("fonts.otf.loader.usemetatables", function(v) usemetatables = v end)
registerdirective("fonts.otf.loader.pack",          function(v) packdata      = v end)
registerdirective("fonts.otf.loader.syncspace",     function(v) syncspace     = v end)
registerdirective("fonts.otf.loader.forcenotdef",   function(v) forcenotdef   = v end)

local function load_featurefile(raw,featurefile)
    if featurefile and featurefile ~= "" then
        if trace_loading then
            report_otf("featurefile: %s", featurefile)
        end
        fontloader.apply_featurefile(raw, featurefile)
    end
end

local function showfeatureorder(rawdata,filename)
    local sequences = rawdata.resources.sequences
    if sequences and #sequences > 0 then
        if trace_loading then
            report_otf("font %s has %s sequences",filename,#sequences)
            report_otf(" ")
        end
        for nos=1,#sequences do
            local sequence  = sequences[nos]
            local typ       = sequence.type      or "no-type"
            local name      = sequence.name      or "no-name"
            local subtables = sequence.subtables or { "no-subtables" }
            local features  = sequence.features
            if trace_loading then
                report_otf("%3i  %-15s  %-20s  [%s]",nos,name,typ,concat(subtables,","))
            end
            if features then
                for feature, scripts in next, features do
                    local tt = { }
                    if type(scripts) == "table" then
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
                    else
                        if trace_loading then
                            report_otf("       %s: %s",feature,tostring(scripts))
                        end
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
    "fontname",
    "fontstyle_id",
    "fontstyle_name",
    "fullname",
 -- "glyphs",
    "hasvmetrics",
 -- "head_optimized_for_cleartype",
    "horiz_base",
    "issans",
    "isserif",
    "italicangle",
 -- "kerns",
 -- "lookups",
    "macstyle",
 -- "modificationtime",
    "onlybitmaps",
    "origname",
    "os2_version",
    "pfminfo",
 -- "private",
    "serifcheck",
    "sfd_version",
 -- "size",
    "strokedfont",
    "strokewidth",
 -- "subfonts",
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
    "version",
    "vert_base",
    "weight",
    "weight_width_slope_only",
 -- "xuid",
}

local ordered_enhancers = {
    "prepare tables",
    "prepare glyphs",
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

    "merge kern classes",

    "reorganize features",
    "reorganize subtables",

    "check glyphs",
    "check metadata",
    "check extra features", -- after metadata

    "add duplicates",
    "check encoding",

    "cleanup tables",
}

--[[ldx--
<p>Here we go.</p>
--ldx]]--

local actions  = allocate()
local before   = allocate()
local after    = allocate()

patches.before = before
patches.after  = after

local function enhance(name,data,filename,raw)
    local enhancer = actions[name]
    if enhancer then
        if trace_loading then
            report_otf("enhance: %s (%s)",name,filename)
            ioflush()
        end
        enhancer(data,filename,raw)
    elseif trace_loading then
     -- report_otf("enhance: %s is undefined",name)
    end
end

function enhancers.apply(data,filename,raw)
    local basename = file.basename(lower(filename))
    if trace_loading then
        report_otf("start enhancing: %s",filename)
    end
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
        enhance(enhancer,data,filename,raw)
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
    if trace_loading then
        report_otf("stop enhancing")
    end
    ioflush() -- we want instant messages
end

-- patches.register("before","migrate metadata","cambria",function() end)

function patches.register(what,where,pattern,action)
    local pw = patches[what]
    if pw then
        local ww = pw[where]
        if ww then
            ww[pattern] = action
        else
            pw[where] = { [pattern] = action}
        end
    end
end

function patches.report(fmt,...)
    if trace_loading then
        report_otf("patching: " ..fmt,...)
    end
end

function enhancers.register(what,action) -- only already registered can be overloaded
    actions[what] = action
end

function otf.load(filename,format,sub,featurefile)
    local name = file.basename(file.removesuffix(filename))
    local attr = lfs.attributes(filename)
    local size = attr and attr.size or 0
    local time = attr and attr.modification or 0
    if featurefile then
        name = name .. "@" .. file.removesuffix(file.basename(featurefile))
    end
    if sub == "" then
        sub = false
    end
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
                    size = attr and attr.size or 0,
                    time = attr and attr.modification or 0,
                }
            end
        end
        if #featurefiles == 0 then
            featurefiles = nil
        end
    end
    local data = containers.read(otf.cache,hash)
    local reload = not data or data.size ~= size or data.time ~= time
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
        local fontdata, messages
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
            local unicodes = {
                -- names to unicodes
            }
            local splitter = lpeg.splitter(" ",unicodes)
            data = {
                size        = size,
                time        = time,
                format      = format,
                featuredata = featurefiles,
                resources   = {
                    filename = resolvers.unresolve(filename), -- no shortcut
                    version  = otf.version,
                    creator  = "context mkiv",
                    unicodes = unicodes,
                    indices  = {
                        -- index to unicodes
                    },
                    duplicates = {
                        -- alternative unicodes
                    },
                    variants = {
                        -- alternative unicodes (variants)
                    },
                    lookuptypes = {
                    },
                },
                metadata    = {
                    -- raw metadata, not to be used
                },
                properties   = {
                    -- normalized metadata
                },
                descriptions = {
                },
                goodies = {
                },
                helpers = {
                    tounicodelist  = splitter,
                    tounicodetable = lpeg.Ct(splitter),
                },
            }
            starttiming(data)
            report_otf("file size: %s", size)
            enhancers.apply(data,filename,fontdata)
            if packdata then
                if cleanup > 0 then
                    collectgarbage("collect")
--~ lua.collectgarbage()
                end
                enhance("pack",data,filename,nil)
            end
            report_otf("saving in cache: %s",filename)
            data = containers.write(otf.cache, hash, data)
            if cleanup > 1 then
                collectgarbage("collect")
--~ lua.collectgarbage()
            end
            stoptiming(data)
            if elapsedtime then -- not in generic
                report_otf("preprocessing and caching took %s seconds",elapsedtime(data))
            end
            fontloader.close(fontdata) -- free memory
            if cleanup > 3 then
                collectgarbage("collect")
--~ lua.collectgarbage()
            end
            data = containers.read(otf.cache, hash) -- this frees the old table and load the sparse one
            if cleanup > 2 then
                collectgarbage("collect")
--~ lua.collectgarbage()
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

actions["prepare tables"] = function(data,filename,raw)
    data.properties.italic_correction = false
end

actions["add dimensions"] = function(data,filename)
    -- todo: forget about the width if it's the defaultwidth (saves mem)
    -- we could also build the marks hash here (instead of storing it)
    if data then
        local descriptions  = data.descriptions
        local resources     = data.resources
        local defaultwidth  = resources.defaultwidth  or 0
        local defaultheight = resources.defaultheight or 0
        local defaultdepth  = resources.defaultdepth  or 0
        if usemetatables then
            for _, d in next, descriptions do
                local wd = d.width
                if not wd then
                    d.width = defaultwidth
                elseif trace_markwidth and wd ~= 0 and d.class == "mark" then
                    report_otf("mark with width %s (%s) in %s",wd,d.name or "<noname>",file.basename(filename))
                 -- d.width  = -wd
                end
                setmetatable(d,mt)
            end
        else
            for _, d in next, descriptions do
                local bb, wd = d.boundingbox, d.width
                if not wd then
                    d.width = defaultwidth
                elseif trace_markwidth and wd ~= 0 and d.class == "mark" then
                    report_otf("mark with width %s (%s) in %s",wd,d.name or "<noname>",file.basename(filename))
                 -- d.width  = -wd
                end
             -- if forcenotdef and not d.name then
             --     d.name = ".notdef"
             -- end
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
    local rawglyphs    = raw.glyphs
    local rawsubfonts  = raw.subfonts
    local rawcidinfo   = raw.cidinfo
    local criterium    = constructors.privateoffset
    local private      = criterium
    local resources    = data.resources
    local metadata     = data.metadata
    local properties   = data.properties
    local descriptions = data.descriptions
    local unicodes     = resources.unicodes -- name to unicode
    local indices      = resources.indices  -- index to unicode
    local duplicates   = resources.duplicates
    local variants     = resources.variants

    if rawsubfonts then

        metadata.subfonts  = { }
        properties.cidinfo = rawcidinfo

        if rawcidinfo.registry then
            local cidmap = fonts.cid.getmap(rawcidinfo)
            if cidmap then
                rawcidinfo.usedname = cidmap.usedname
                local nofnames, nofunicodes = 0, 0
                local cidunicodes, cidnames = cidmap.unicodes, cidmap.names
                for cidindex=1,#rawsubfonts do
                    local subfont   = rawsubfonts[cidindex]
                    local cidglyphs = subfont.glyphs
                    metadata.subfonts[cidindex] = somecopy(subfont)
                    for index=0,subfont.glyphcnt-1 do -- we could take the previous glyphcnt instead of 0
                        local glyph = cidglyphs[index]
                        if glyph then
                            local unicode = glyph.unicode
                            local name    = glyph.name or cidnames[index]
                            if not unicode or unicode == -1 or unicode >= criterium then
                                unicode = cidunicodes[index]
                            end
                            if not unicode or unicode == -1 or unicode >= criterium then
                                if not name then
                                    name = format("u%06X",private)
                                end
                                unicode = private
                                unicodes[name] = private
                                if trace_private then
                                    report_otf("enhance: glyph %s at index 0x%04X is moved to private unicode slot U+%05X",name,index,private)
                                end
                                private = private + 1
                                nofnames = nofnames + 1
                            else
                                if not name then
                                    name = format("u%06X",unicode)
                                end
                                unicodes[name] = unicode
                                nofunicodes = nofunicodes + 1
                            end
                            indices[index] = unicode -- each index is unique (at least now)

                            local description = {
                             -- width       = glyph.width,
                                boundingbox = glyph.boundingbox,
                                name        = glyph.name or name or "unknown", -- uniXXXX
                                cidindex    = cidindex,
                                index       = index,
                                glyph       = glyph,
                            }

                            descriptions[unicode] = description
                        else
                         -- report_otf("potential problem: glyph 0x%04X is used but empty",index)
                        end
                    end
                end
                if trace_loading then
                    report_otf("cid font remapped, %s unicode points, %s symbolic names, %s glyphs",nofunicodes, nofnames, nofunicodes+nofnames)
                end
            elseif trace_loading then
                report_otf("unable to remap cid font, missing cid file for %s",filename)
            end
        elseif trace_loading then
            report_otf("font %s has no glyphs",filename)
        end

    else

        for index=0,raw.glyphcnt-1 do -- not raw.glyphmax-1 (as that will crash)
            local glyph = rawglyphs[index]
            if glyph then
                local unicode = glyph.unicode
                local name    = glyph.name
                if not unicode or unicode == -1 or unicode >= criterium then
                    unicode = private
                    unicodes[name] = private
                    if trace_private then
                        report_otf("enhance: glyph %s at index 0x%04X is moved to private unicode slot U+%05X",name,index,private)
                    end
                    private = private + 1
                else
                    unicodes[name] = unicode
                end
                indices[index] = unicode
                if not name then
                    name = format("u%06X",unicode)
                end
                descriptions[unicode] = {
                 -- width       = glyph.width,
                    boundingbox = glyph.boundingbox,
                    name        = name,
                    index       = index,
                    glyph       = glyph,
                }
                local altuni = glyph.altuni
                if altuni then
                    local d
                    for i=1,#altuni do
                        local a = altuni[i]
                        local u = a.unicode
                        local v = a.variant
                        if v then
                            local vv = variants[v]
                            if vv then
                                vv[u] = unicode
                            else -- xits-math has some:
                                vv = { [u] = unicode }
                                variants[v] = vv
                            end
                        elseif d then
                            d[#d+1] = u
                        else
                            d = { u }
                        end
                    end
                    if d then
                        duplicates[unicode] = d
                    end
                end
            else
                report_otf("potential problem: glyph 0x%04X is used but empty",index)
            end
        end

    end

    resources.private = private

end

-- the next one is still messy but will get better when we have
-- flattened map/enc tables in the font loader

actions["check encoding"] = function(data,filename,raw)
    local descriptions = data.descriptions
    local resources    = data.resources
    local properties   = data.properties
    local unicodes     = resources.unicodes -- name to unicode
    local indices      = resources.indices  -- index to unicodes

    -- begin of messy (not needed when cidmap)

    local mapdata        = raw.map or { }
    local unicodetoindex = mapdata and mapdata.map or { }
 -- local encname        = lower(data.enc_name or raw.enc_name or mapdata.enc_name or "")
    local encname        = lower(data.enc_name or mapdata.enc_name or "")
    local criterium      = 0xFFFF -- for instance cambria has a lot of mess up there

    -- end of messy

    if find(encname,"unicode") then -- unicodebmp, unicodefull, ...
        if trace_loading then
            report_otf("checking embedded unicode map '%s'",encname)
        end
        for unicode, index in next, unicodetoindex do -- altuni already covers this
            if unicode <= criterium and not descriptions[unicode] then
                local parent = indices[index] -- why nil?
                if parent then
                    report_otf("weird, unicode U+%05X points to U+%05X with index 0x%04X",unicode,parent,index)
                else
                    report_otf("weird, unicode U+%05X points to nowhere with index 0x%04X",unicode,index)
                end
            end
        end
    elseif properties.cidinfo then
        report_otf("warning: no unicode map, used cidmap '%s'",properties.cidinfo.usedname or "?")
    else
        report_otf("warning: non unicode map '%s', only using glyph unicode data",encname or "whatever")
    end

    if mapdata then
        mapdata.map = { } -- clear some memory
    end
end

-- for the moment we assume that a fotn with lookups will not use
-- altuni so we stick to kerns only

actions["add duplicates"] = function(data,filename,raw)
    local descriptions = data.descriptions
    local resources    = data.resources
    local properties   = data.properties
    local unicodes     = resources.unicodes -- name to unicode
    local indices      = resources.indices  -- index to unicodes
    local duplicates   = resources.duplicates

    for unicode, d in next, duplicates do
        for i=1,#d do
            local u = d[i]
            if not descriptions[u] then
                local description = descriptions[unicode]
                local duplicate = table.copy(description) -- else packing problem
                duplicate.comment = format("copy of U+%05X", unicode)
                descriptions[u] = duplicate
                local n = 0
                for _, description in next, descriptions do
                    if kerns then
                        local kerns = description.kerns
                        for _, k in next, kerns do
                            local ku = k[unicode]
                            if ku then
                                k[u] = ku
                                n = n + 1
                            end
                        end
                    end
                    -- todo: lookups etc
                end
                if trace_loading then
                    report_otf("duplicating U+%05X to U+%05X with index 0x%04X (%s kerns)",unicode,u,description.index,n)
                end
            end
        end
    end
end

-- class      : nil base mark ligature component (maybe we don't need it in description)
-- boundingbox: split into ht/dp takes more memory (larger tables and less sharing)

actions["analyze glyphs"] = function(data,filename,raw) -- maybe integrate this in the previous
    local descriptions      = data.descriptions
    local resources         = data.resources
    local metadata          = data.metadata
    local properties        = data.properties
    local italic_correction = false
    local widths            = { }
    local marks             = { }
    for unicode, description in next, descriptions do
        local glyph = description.glyph
        local italic = glyph.italic_correction
        if not italic then
            -- skip
        elseif italic == 0 then
            -- skip
        else
            description.italic = italic
            italic_correction  = true
        end
        local width = glyph.width
        widths[width] = (widths[width] or 0) + 1
        local class = glyph.class
        if class then
            if class == "mark" then
                marks[unicode] = true
            end
            description.class = class
        end
    end
    -- flag italic
    properties.italic_correction = italic_correction
    -- flag marks
    resources.marks = marks
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
        for unicode, description in next, descriptions do
            if description.width == wd then
             -- description.width = nil
            else
                description.width = description.glyph.width
            end
        end
        resources.defaultwidth = wd
    else
        for unicode, description in next, descriptions do
            description.width = description.glyph.width
        end
    end
end

actions["reorganize mark classes"] = function(data,filename,raw)
    local mark_classes = raw.mark_classes
    if mark_classes then
        local resources       = data.resources
        local unicodes        = resources.unicodes
        local markclasses     = { }
        resources.markclasses = markclasses -- reversed
        for name, class in next, mark_classes do
            local t = { }
            for s in gmatch(class,"[^ ]+") do
                t[unicodes[s]] = true
            end
            markclasses[name] = t
        end
    end
end

actions["reorganize features"] = function(data,filename,raw) -- combine with other
    local features = { }
    data.resources.features = features
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
                        local ft = f[tag]
                        if not ft then
                            ft = { }
                            f[tag] = ft
                        end
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
    local resources            = data.resources
    local anchor_to_lookup     = { }
    local lookup_to_anchor     = { }
    resources.anchor_to_lookup = anchor_to_lookup
    resources.lookup_to_anchor = lookup_to_anchor
    local classes              = raw.anchor_classes -- anchor classes not in final table
    if classes then
        for c=1,#classes do
            local class   = classes[c]
            local anchor  = class.name
            local lookups = class.lookup
            if type(lookups) ~= "table" then
                lookups = { lookups }
            end
            local a = anchor_to_lookup[anchor]
            if not a then
                a = { }
                anchor_to_lookup[anchor] = a
            end
            for l=1,#lookups do
                local lookup = lookups[l]
                local l = lookup_to_anchor[lookup]
                if l then
                    l[anchor] = true
                else
                    l = { [anchor] = true }
                    lookup_to_anchor[lookup] = l
                end
                a[lookup] = true
            end
        end
    end
end

actions["prepare tounicode"] = function(data,filename,raw)
    fonts.mappings.addtounicode(data,filename)
end

local g_directions = {
    gsub_contextchain        =  1,
    gpos_contextchain        =  1,
 -- gsub_context             =  1,
 -- gpos_context             =  1,
    gsub_reversecontextchain = -1,
    gpos_reversecontextchain = -1,
}

actions["reorganize subtables"] = function(data,filename,raw)
    local resources       = data.resources
    local sequences       = { }
    local lookups         = { }
    local chainedfeatures = { }
    resources.sequences   = sequences
    resources.lookups     = lookups
    for _, what in next, otf.glists do
        local dw = raw[what]
        if dw then
            for k=1,#dw do
                local gk = dw[k]
                local typ = gk.type
                local chain = g_directions[typ] or 0
                local subtables = gk.subtables
                if subtables then
                    local t = { }
                    for s=1,#subtables do
                        t[s] = subtables[s].name
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
                        markclass = resources.markclasses[markclass]
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

-- test this:
--
--    for _, what in next, otf.glists do
--        raw[what] = nil
--    end

actions["prepare lookups"] = function(data,filename,raw)
    local lookups = raw.lookups
    if lookups then
        data.lookups = lookups
    end
end

-- The reverse handler does a bit redundant splitting but it's seldom
-- seen so we don' tbother too much. We could store the replacement
-- in the current list (value instead of true) but it makes other code
-- uglier. Maybe some day.

local function t_uncover(splitter,cache,covers)
    local result = { }
    for n=1,#covers do
        local cover = covers[n]
        local uncovered = cache[cover]
        if not uncovered then
            uncovered = lpegmatch(splitter,cover)
            cache[cover] = uncovered
        end
        result[n] = uncovered
    end
    return result
end

local function t_hashed(t,cache)
    if t then
        local ht = { }
        for i=1,#t do
            local ti = t[i]
            local tih = cache[ti]
            if not tih then
                tih = { }
                for i=1,#ti do
                    tih[ti[i]] = true
                end
                cache[ti] = tih
            end
            ht[i] = tih
        end
        return ht
    else
        return nil
    end
end

local function s_uncover(splitter,cache,cover)
    if cover == "" then
        return nil
    else
        local uncovered = cache[cover]
        if not uncovered then
            uncovered = lpegmatch(splitter,cover)
            for i=1,#uncovered do
                uncovered[i] = { [uncovered[i]] = true }
            end
            cache[cover] = uncovered
        end
        return uncovered
    end
end

local s_hashed = t_hashed

local function r_uncover(splitter,cache,cover,replacements)
    if cover == "" then
        return nil
    else
        -- we always have current as { } even in the case of one
        local uncovered = cover[1]
        local replaced = cache[replacements]
        if not replaced then
            replaced = lpegmatch(splitter,replacements)
            cache[replacements] = replaced
        end
        local nu, nr = #uncovered, #replaced
        local r = { }
        if nu == nr then
            for i=1,nu do
                r[uncovered[i]] = replaced[i]
            end
        end
        return r
    end
end

actions["reorganize lookups"] = function(data,filename,raw)
    -- we prefer the before lookups in a normal order
    if data.lookups then
        local splitter = data.helpers.tounicodetable
        local cache, h_cache = { }, { }
        for _, lookup in next, data.lookups do
            local rules = lookup.rules
            if rules then
                local format = lookup.format
                if format == "class" then
                    local before_class = lookup.before_class
                    if before_class then
                        before_class = t_uncover(splitter,cache,reversed(before_class))
                    end
                    local current_class = lookup.current_class
                    if current_class then
                        current_class = t_uncover(splitter,cache,current_class)
                    end
                    local after_class = lookup.after_class
                    if after_class then
                        after_class = t_uncover(splitter,cache,after_class)
                    end
                    for i=1,#rules do
                        local rule = rules[i]
                        local class = rule.class
                        local before = class.before
                        if before then
                            for i=1,#before do
                                before[i] = before_class[before[i]] or { }
                            end
                            rule.before = t_hashed(before,h_cache)
                        end
                        local current = class.current
                        local lookups = rule.lookups
                        if current then
                            for i=1,#current do
                                current[i] = current_class[current[i]] or { }
                                if lookups and not lookups[i] then
                                    lookups[i] = false -- e.g. we can have two lookups and one replacement
                                end
                            end
                            rule.current = t_hashed(current,h_cache)
                        end
                        local after = class.after
                        if after then
                            for i=1,#after do
                                after[i] = after_class[after[i]] or { }
                            end
                            rule.after = t_hashed(after,h_cache)
                        end
                        rule.class = nil
                    end
                    lookup.before_class  = nil
                    lookup.current_class = nil
                    lookup.after_class   = nil
                    lookup.format        = "coverage"
                elseif format == "coverage" then
                    for i=1,#rules do
                        local rule = rules[i]
                        local coverage = rule.coverage
                        if coverage then
                            local before = coverage.before
                            if before then
                                before = t_uncover(splitter,cache,reversed(before))
                                rule.before = t_hashed(before,h_cache)
                            end
                            local current = coverage.current
                            if current then
                                current = t_uncover(splitter,cache,current)
                                rule.current = t_hashed(current,h_cache)
                            end
                            local after = coverage.after
                            if after then
                                after = t_uncover(splitter,cache,after)
                                rule.after = t_hashed(after,h_cache)
                            end
                            rule.coverage = nil
                        end
                    end
                elseif format == "reversecoverage" then -- special case, single substitution only
                    for i=1,#rules do
                        local rule = rules[i]
                        local reversecoverage = rule.reversecoverage
                        if reversecoverage then
                            local before = reversecoverage.before
                            if before then
                                before = t_uncover(splitter,cache,reversed(before))
                                rule.before = t_hashed(before,h_cache)
                            end
                            local current = reversecoverage.current
                            if current then
                                current = t_uncover(splitter,cache,current)
                                rule.current = t_hashed(current,h_cache)
                            end
                            local after = reversecoverage.after
                            if after then
                                after = t_uncover(splitter,cache,after)
                                rule.after = t_hashed(after,h_cache)
                            end
                            local replacements = reversecoverage.replacements
                            if replacements then
                                rule.replacements = r_uncover(splitter,cache,current,replacements)
                            end
                            rule.reversecoverage = nil
                        end
                    end
                elseif format == "glyphs" then
                    for i=1,#rules do
                        local rule = rules[i]
                        local glyphs = rule.glyphs
                        if glyphs then
                            local fore = glyphs.fore
                            if fore then
                                fore = s_uncover(splitter,cache,fore)
                                rule.before = s_hashed(fore,h_cache)
                            end
                            local back = glyphs.back
                            if back then
                                back = s_uncover(splitter,cache,back)
                                rule.after = s_hashed(back,h_cache)
                            end
                            local names = glyphs.names
                            if names then
                                names = s_uncover(splitter,cache,names)
                                rule.current = s_hashed(names,h_cache)
                            end
                            rule.glyphs = nil
                        end
                    end
                end
            end
        end
    end
end

-- to be checked italic_correction

local function check_variants(unicode,the_variants,splitter,unicodes)
    local variants = the_variants.variants
    if variants then -- use splitter
        local glyphs = lpegmatch(splitter,variants)
        local done   = { [unicode] = true }
        local n      = 0
        for i=1,#glyphs do
            local g = glyphs[i]
            if done[g] then
                report_otf("skipping cyclic reference U+%05X in math variant U+%05X",g,unicode)
            elseif n == 0 then
                n = 1
                variants = { g }
            else
                n = n + 1
                variants[n] = g
            end
        end
        if n == 0 then
            variants = nil
        end
    end
    local parts = the_variants.parts
    if parts then
        local p = #parts
        if p > 0 then
            for i=1,p do
                local pi = parts[i]
                pi.glyph = unicodes[pi.component] or 0
                pi.component = nil
            end
        else
            parts = nil
        end
    end
    local italic_correction = the_variants.italic_correction
    if italic_correction and italic_correction == 0 then
        italic_correction = nil
    end
    return variants, parts, italic_correction
end

actions["analyze math"] = function(data,filename,raw)
    if raw.math then
        data.metadata.math = raw.math
        local unicodes = data.resources.unicodes
        local splitter = data.helpers.tounicodetable
        for unicode, description in next, data.descriptions do
            local glyph          = description.glyph
            local mathkerns      = glyph.mathkern -- singular
            local horiz_variants = glyph.horiz_variants
            local vert_variants  = glyph.vert_variants
            local top_accent     = glyph.top_accent
            if mathkerns or horiz_variants or vert_variants or top_accent then
                local math = { }
                if top_accent then
                    math.top_accent = top_accent
                end
                if mathkerns then
                    for k, v in next, mathkerns do
                        if not next(v) then
                            mathkerns[k] = nil
                        else
                            for k, v in next, v do
                                if v == 0 then
                                    k[v] = nil -- height / kern can be zero
                                end
                            end
                        end
                    end
                    math.kerns = mathkerns
                end
                if horiz_variants then
                    math.horiz_variants, math.horiz_parts, math.horiz_italic_correction = check_variants(unicode,horiz_variants,splitter,unicodes)
                end
                if vert_variants then
                    math.vert_variants, math.vert_parts, math.vert_italic_correction = check_variants(unicode,vert_variants,splitter,unicodes)
                end
                local italic_correction = description.italic
                if italic_correction and italic_correction ~= 0 then
                    math.italic_correction = italic_correction
                end
                description.math = math
            end
        end
    end
end

actions["reorganize glyph kerns"] = function(data,filename,raw)
    local descriptions = data.descriptions
    local resources    = data.resources
    local unicodes     = resources.unicodes
    for unicode, description in next, descriptions do
        local kerns = description.glyph.kerns
        if kerns then
            local newkerns = { }
            for k, kern in next, kerns do
                local name   = kern.char
                local offset = kern.off
                local lookup = kern.lookup
                if name and offset and lookup then
                    local unicode = unicodes[name]
                    if unicode then
                        if type(lookup) == "table" then
                            for l=1,#lookup do
                                local lookup = lookup[l]
                                local lookupkerns = newkerns[lookup]
                                if lookupkerns then
                                    lookupkerns[unicode] = offset
                                else
                                    newkerns[lookup] = { [unicode] = offset }
                                end
                            end
                        else
                            local lookupkerns = newkerns[lookup]
                            if lookupkerns then
                                lookupkerns[unicode] = offset
                            else
                                newkerns[lookup] = { [unicode] = offset }
                            end
                        end
                    elseif trace_loading then
                        report_otf("problems with unicode %s of kern %s of glyph U+%05X",name,k,unicode)
                    end
                end
            end
            description.kerns = newkerns
        end
    end
end

actions["merge kern classes"] = function(data,filename,raw)
    local gposlist = raw.gpos
    if gposlist then
        local descriptions = data.descriptions
        local resources    = data.resources
        local unicodes     = resources.unicodes
        local splitter     = data.helpers.tounicodetable
        for gp=1,#gposlist do
            local gpos = gposlist[gp]
            local subtables = gpos.subtables
            if subtables then
                for s=1,#subtables do
                    local subtable = subtables[s]
                    local kernclass = subtable.kernclass -- name is inconsistent with anchor_classes
                    if kernclass then -- the next one is quite slow
                        local split = { } -- saves time
                        for k=1,#kernclass do
                            local kcl = kernclass[k]
                            local firsts  = kcl.firsts
                            local seconds = kcl.seconds
                            local offsets = kcl.offsets
                            local lookups = kcl.lookup  -- singular
                            if type(lookups) ~= "table" then
                                lookups = { lookups }
                            end
                            -- we can check the max in the loop
                         -- local maxseconds = getn(seconds)
                            for n, s in next, firsts do
                                split[s] = split[s] or lpegmatch(splitter,s)
                            end
                            local maxseconds = 0
                            for n, s in next, seconds do
                                if n > maxseconds then
                                    maxseconds = n
                                end
                                split[s] = split[s] or lpegmatch(splitter,s)
                            end
                            for l=1,#lookups do
                                local lookup = lookups[l]
                                for fk=1,#firsts do -- maxfirsts ?
                                    local fv = firsts[fk]
                                    local splt = split[fv]
                                    if splt then
                                        local extrakerns = { }
                                        local baseoffset = (fk-1) * maxseconds
                                     -- for sk=2,maxseconds do
                                     --     local sv = seconds[sk]
                                        for sk, sv in next, seconds do
                                            local splt = split[sv]
                                            if splt then -- redundant test
                                                local offset = offsets[baseoffset + sk]
                                                if offset then
                                                    for i=1,#splt do
                                                        extrakerns[splt[i]] = offset
                                                    end
                                                end
                                            end
                                        end
                                        for i=1,#splt do
                                            local first_unicode = splt[i]
                                            local description = descriptions[first_unicode]
                                            if description then
                                                local kerns = description.kerns
                                                if not kerns then
                                                    kerns = { } -- unicode indexed !
                                                    description.kerns = kerns
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
                                                report_otf("no glyph data for U+%05X", first_unicode)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        subtable.kernclass = { }
                    end
                end
            end
        end
    end
end

actions["check glyphs"] = function(data,filename,raw)
    for unicode, description in next, data.descriptions do
        description.glyph = nil
    end
end

-- future versions will remove _

actions["check metadata"] = function(data,filename,raw)
    local metadata = data.metadata
    for _, k in next, mainfields do
        if valid_fields[k] then
            local v = raw[k]
            if not metadata[k] then
                metadata[k] = v
            end
        end
    end
 -- metadata.pfminfo = raw.pfminfo -- not already done?
    local ttftables = metadata.ttf_tables
    if ttftables then
        for i=1,#ttftables do
            ttftables[i].data = "deleted"
        end
    end
end

actions["cleanup tables"] = function(data,filename,raw)
    data.resources.indices = nil -- not needed
    data.helpers = nil
end

-- kern: ttf has a table with kerns
--
-- Weird, as maxfirst and maxseconds can have holes, first seems to be indexed, but
-- seconds can start at 2 .. this need to be fixed as getn as well as # are sort of
-- unpredictable alternatively we could force an [1] if not set (maybe I will do that
-- anyway).

-- we can share { } as it is never set

--- ligatures have an extra specification.char entry that we don't use

actions["reorganize glyph lookups"] = function(data,filename,raw)
    local resources    = data.resources
    local unicodes     = resources.unicodes
    local descriptions = data.descriptions
    local splitter     = data.helpers.tounicodelist

    local lookuptypes  = resources.lookuptypes

    for unicode, description in next, descriptions do
        local lookups = description.glyph.lookups
        if lookups then
            for tag, lookuplist in next, lookups do
                for l=1,#lookuplist do
                    local lookup        = lookuplist[l]
                    local specification = lookup.specification
                    local lookuptype    = lookup.type
                    local lt = lookuptypes[tag]
                    if not lt then
                        lookuptypes[tag] = lookuptype
                    elseif lt ~= lookuptype then
                        report_otf("conflicting lookuptypes: %s => %s and %s",tag,lt,lookuptype)
                    end
                    if lookuptype == "ligature" then
                        lookuplist[l] = { lpegmatch(splitter,specification.components) }
                    elseif lookuptype == "alternate" then
                        lookuplist[l] = { lpegmatch(splitter,specification.components) }
                    elseif lookuptype == "substitution" then
                        lookuplist[l] = unicodes[specification.variant]
                    elseif lookuptype == "multiple" then
                        lookuplist[l] = { lpegmatch(splitter,specification.components) }
                    elseif lookuptype == "position" then
                        lookuplist[l] = {
                            specification.x or 0,
                            specification.y or 0,
                            specification.h or 0,
                            specification.v or 0
                        }
                    elseif lookuptype == "pair" then
                        local one    = specification.offsets[1]
                        local two    = specification.offsets[2]
                        local paired = unicodes[specification.paired]
                        if one then
                            if two then
                                lookuplist[l] = { paired, { one.x or 0, one.y or 0, one.h or 0, one.v or 0 }, { two.x or 0, two.y or 0, two.h or 0, two.v or 0 } }
                            else
                                lookuplist[l] = { paired, { one.x or 0, one.y or 0, one.h or 0, one.v or 0 } }
                            end
                        else
                            if two then
                                lookuplist[l] = { paired, { }, { two.x or 0, two.y or 0, two.h or 0, two.v or 0} } -- maybe nil instead of { }
                            else
                                lookuplist[l] = { paired }
                            end
                        end
                    end
                end
            end
            local slookups, mlookups
            for tag, lookuplist in next, lookups do
                if #lookuplist == 1 then
                    if slookups then
                        slookups[tag] = lookuplist[1]
                    else
                        slookups = { [tag] = lookuplist[1] }
                    end
                else
                    if mlookups then
                        mlookups[tag] = lookuplist
                    else
                        mlookups = { [tag] = lookuplist }
                    end
                end
            end
            if slookups then
                description.slookups = slookups
            end
            if mlookups then
                description.mlookups = mlookups
            end
        end
    end

end

actions["reorganize glyph anchors"] = function(data,filename,raw) -- when we replace inplace we safe entries
    local descriptions = data.descriptions
    for unicode, description in next, descriptions do
        local anchors = description.glyph.anchors
        if anchors then
            for class, data in next, anchors do
                if class == "baselig" then
                    for tag, specification in next, data do
                        for i=1,#specification do
                            local si = specification[i]
                            specification[i] = { si.x or 0, si.y or 0 }
                        end
                    end
                else
                    for tag, specification in next, data do
                        data[tag] = { specification.x or 0, specification.y or 0 }
                    end
                end
            end
            description.anchors = anchors
        end
    end
end

-- modes: node, base, none

function otf.setfeatures(tfmdata,features)
    local okay = constructors.initializefeatures("otf",tfmdata,features,trace_features,report_otf)
    if okay then
        return constructors.collectprocessors("otf",tfmdata,features,trace_features,report_otf)
    else
        return { } -- will become false
    end
end

-- the first version made a top/mid/not extensible table, now we just
-- pass on the variants data and deal with it in the tfm scaler (there
-- is no longer an extensible table anyway)
--
-- we cannot share descriptions as virtual fonts might extend them (ok,
-- we could use a cache with a hash
--
-- we already assing an empty tabel to characters as we can add for
-- instance protruding info and loop over characters; one is not supposed
-- to change descriptions and if one does so one should make a copy!

local function copytotfm(data,cache_id)
    if data then
        local metadata       = data.metadata
        local resources      = data.resources
        local properties     = derivetable(data.properties)
        local descriptions   = derivetable(data.descriptions)
        local goodies        = derivetable(data.goodies)
        local characters     = { }
        local parameters     = { }
        local mathparameters = { }
        --
        local pfminfo        = metadata.pfminfo  or { }
        local resources      = data.resources
        local unicodes       = resources.unicodes
     -- local mode           = data.mode or "base"
        local spaceunits     = 500
        local spacer         = "space"
        local designsize     = metadata.designsize or metadata.design_size or 100
        local mathspecs      = metadata.math
        --
        if designsize == 0 then
            designsize = 100
        end
        if mathspecs then
            for name, value in next, mathspecs do
                mathparameters[name] = value
            end
        end
        for unicode, _ in next, data.descriptions do -- use parent table
            characters[unicode] = { }
        end
        if mathspecs then
            -- we could move this to the scaler but not that much is saved
            -- and this is cleaner
            for unicode, character in next, characters do
                local d = descriptions[unicode]
                local m = d.math
                if m then
                    -- watch out: luatex uses horiz_variants for the parts
                    local variants = m.horiz_variants
                    local parts    = m.horiz_parts
                 -- local done     = { [unicode] = true }
                    if variants then
                        local c = character
                        for i=1,#variants do
                            local un = variants[i]
                         -- if done[un] then
                         --  -- report_otf("skipping cyclic reference U+%05X in math variant U+%05X",un,unicode)
                         -- else
                                c.next = un
                                c = characters[un]
                         --     done[un] = true
                         -- end
                        end -- c is now last in chain
                        c.horiz_variants = parts
                    elseif parts then
                        character.horiz_variants = parts
                    end
                    local variants = m.vert_variants
                    local parts    = m.vert_parts
                 -- local done     = { [unicode] = true }
                    if variants then
                        local c = character
                        for i=1,#variants do
                            local un = variants[i]
                         -- if done[un] then
                         --  -- report_otf("skipping cyclic reference U+%05X in math variant U+%05X",un,unicode)
                         -- else
                                c.next = un
                                c = characters[un]
                         --     done[un] = true
                         -- end
                        end -- c is now last in chain
                        c.vert_variants = parts
                    elseif parts then
                        character.vert_variants = parts
                    end
                    local italic_correction = m.vert_italic_correction
                    if italic_correction then
                        character.vert_italic_correction = italic_correction -- was c.
                    end
                    local top_accent = m.top_accent
                    if top_accent then
                        character.top_accent = top_accent
                    end
                    local kerns = m.kerns
                    if kerns then
                        character.mathkerns = kerns
                    end
                end
            end
        end
        -- end math
        local monospaced  = metadata.isfixedpitch or (pfminfo.panose and pfminfo.panose.proportion == "Monospaced")
        local charwidth   = pfminfo.avgwidth -- or unset
        local italicangle = metadata.italicangle
        local charxheight = pfminfo.os2_xheight and pfminfo.os2_xheight > 0 and pfminfo.os2_xheight
        properties.monospaced  = monospaced
        parameters.italicangle = italicangle
        parameters.charwidth   = charwidth
        parameters.charxheight = charxheight
        --
        local space  = 0x0020 -- unicodes['space'], unicodes['emdash']
        local emdash = 0x2014 -- unicodes['space'], unicodes['emdash']
        if monospaced then
            if descriptions[space] then
                spaceunits, spacer = descriptions[space].width, "space"
            end
            if not spaceunits and descriptions[emdash] then
                spaceunits, spacer = descriptions[emdash].width, "emdash"
            end
            if not spaceunits and charwidth then
                spaceunits, spacer = charwidth, "charwidth"
            end
        else
            if descriptions[space] then
                spaceunits, spacer = descriptions[space].width, "space"
            end
            if not spaceunits and descriptions[emdash] then
                spaceunits, spacer = descriptions[emdash].width/2, "emdash/2"
            end
            if not spaceunits and charwidth then
                spaceunits, spacer = charwidth, "charwidth"
            end
        end
        spaceunits = tonumber(spaceunits) or 500 -- brrr
        -- we need a runtime lookup because of running from cdrom or zip, brrr (shouldn't we use the basename then?)
        local filename = constructors.checkedfilename(resources)
        local fontname = metadata.fontname
        local fullname = metadata.fullname or fontname
        local units    = metadata.units_per_em or 1000
        --
        if units == 0 then -- catch bugs in fonts
            units = 1000
            metadata.units_per_em = 1000
        end
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
        if italicangle then
            parameters.italicangle  = italicangle
            parameters.italicfactor = math.cos(math.rad(90+italicangle))
            parameters.slant        = - math.round(math.tan(italicangle*math.pi/180))
        end
        if monospaced then
            parameters.space_stretch = 0
            parameters.space_shrink  = 0
        elseif syncspace then --
            parameters.space_stretch = spaceunits/2
            parameters.space_shrink  = spaceunits/3
        end
        parameters.extra_space = parameters.space_shrink -- 1.111 (cmr10)
        if charxheight then
            parameters.x_height = charxheight
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
        parameters.designsize = (designsize/10)*65536
        parameters.ascender   = abs(metadata.ascent  or 0)
        parameters.descender  = abs(metadata.descent or 0)
        parameters.units      = units
        --
        properties.space         = spacer
        properties.encodingbytes = 2
        properties.format        = data.format or fonts.formats[filename] or "opentype"
        properties.noglyphnames  = true
        properties.filename      = filename
        properties.fontname      = fontname
        properties.fullname      = fullname
        properties.psname        = fontname or fullname
        properties.name          = filename or fullname
        --
     -- properties.name          = specification.name
     -- properties.sub           = specification.sub
        return {
            characters     = characters,
            descriptions   = descriptions,
            parameters     = parameters,
            mathparameters = mathparameters,
            resources      = resources,
            properties     = properties,
            goodies        = goodies,
        }
    end
end

local function otftotfm(specification)
    local cache_id = specification.hash
    local tfmdata  = containers.read(constructors.cache,cache_id)
    if not tfmdata then
        local name     = specification.name
        local sub      = specification.sub
        local filename = specification.filename
        local format   = specification.format
        local features = specification.features.normal
        local rawdata  = otf.load(filename,format,sub,features and features.featurefile)
        if rawdata and next(rawdata) then
            rawdata.lookuphash = { }
            tfmdata = copytotfm(rawdata,cache_id)
            if tfmdata and next(tfmdata) then
                -- at this moment no characters are assigned yet, only empty slots
                local features     = constructors.checkedfeatures("otf",features)
                local shared       = tfmdata.shared
                if not shared then
                    shared         = { }
                    tfmdata.shared = shared
                end
                shared.rawdata     = rawdata
                shared.features    = features -- default
                shared.dynamics    = { }
                shared.processes   = { }
                tfmdata.changed    = { }
                shared.features    = features
                shared.processes   = otf.setfeatures(tfmdata,features)
            end
        end
        containers.write(constructors.cache,cache_id,tfmdata)
    end
    return tfmdata
end

local function read_from_otf(specification)
    local tfmdata = otftotfm(specification)
    if tfmdata then
        -- this late ? .. needs checking
        tfmdata.properties.name = specification.name
        tfmdata.properties.sub  = specification.sub
        --
        tfmdata = constructors.scale(tfmdata,specification)
        constructors.applymanipulators("otf",tfmdata,specification.features.normal,trace_features,report_otf)
        constructors.setname(tfmdata,specification) -- only otf?
        fonts.loggers.register(tfmdata,file.extname(specification.filename),specification)
    end
    return tfmdata
end

local function checkmathsize(tfmdata,mathsize)
    local mathdata = tfmdata.shared.rawdata.metadata.math
    local mathsize = tonumber(mathsize)
    if mathdata then -- we cannot use mathparameters as luatex will complain
        local parameters = tfmdata.parameters
        parameters.scriptpercentage       = mathdata.ScriptPercentScaleDown
        parameters.scriptscriptpercentage = mathdata.ScriptScriptPercentScaleDown
        parameters.mathsize               = mathsize
    end
end

registerotffeature {
    name         = "mathsize",
    description  = "apply mathsize as specified in the font",
    initializers = {
        base = checkmathsize,
        node = checkmathsize,
    }
}

-- helpers

function otf.collectlookups(rawdata,kind,script,language)
    local sequences = rawdata.resources.sequences
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

-- readers

local function check_otf(forced,specification,suffix,what)
    local name = specification.name
    if forced then
        name = file.addsuffix(name,suffix,true)
    end
    local fullname = findbinfile(name,suffix) or ""
    if fullname == "" then
        fullname = fonts.names.getfilename(name,suffix) or ""
    end
    if fullname ~= "" then
        specification.filename = fullname
        specification.format   = what
        return read_from_otf(specification)
    end
end

local function opentypereader(specification,suffix,what)
    local forced = specification.forced or ""
    if forced == "otf" then
        return check_otf(true,specification,forced,"opentype")
    elseif forced == "ttf" or forced == "ttc" or forced == "dfont" then
        return check_otf(true,specification,forced,"truetype")
    else
        return check_otf(false,specification,suffix,what)
    end
end

readers.opentype = opentypereader

local formats = fonts.formats

formats.otf   = "opentype"
formats.ttf   = "truetype"
formats.ttc   = "truetype"
formats.dfont = "truetype"

function readers.otf  (specification) return opentypereader(specification,"otf",formats.otf  ) end
function readers.ttf  (specification) return opentypereader(specification,"ttf",formats.ttf  ) end
function readers.ttc  (specification) return opentypereader(specification,"ttf",formats.ttc  ) end
function readers.dfont(specification) return opentypereader(specification,"ttf",formats.dfont) end

-- this will be overloaded

function otf.scriptandlanguage(tfmdata,attr)
    local properties = tfmdata.properties
    return properties.script or "dflt", properties.language or "dflt"
end
