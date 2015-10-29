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

-- to be checked: combinations like:
--
-- current="ABCD" with [A]=nothing, [BC]=ligature, [D]=single (applied to result of BC so funny index)
--
-- unlikely but possible

-- more checking against low level calls of functions

local utfbyte = utf.byte
local gmatch, gsub, find, match, lower, strip = string.gmatch, string.gsub, string.find, string.match, string.lower, string.strip
local type, next, tonumber, tostring = type, next, tonumber, tostring
local abs = math.abs
local reversed, concat, insert, remove, sortedkeys = table.reversed, table.concat, table.insert, table.remove, table.sortedkeys
local ioflush = io.flush
local fastcopy, tohash, derivetable = table.fastcopy, table.tohash, table.derive
local formatters = string.formatters
local P, R, S, C, Ct, lpegmatch = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Ct, lpeg.match

local setmetatableindex  = table.setmetatableindex
local allocate           = utilities.storage.allocate
local registertracker    = trackers.register
local registerdirective  = directives.register
local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming
local elapsedtime        = statistics.elapsedtime
local findbinfile        = resolvers.findbinfile

local trace_private      = false  registertracker("otf.private",        function(v) trace_private   = v end)
local trace_subfonts     = false  registertracker("otf.subfonts",       function(v) trace_subfonts  = v end)
local trace_loading      = false  registertracker("otf.loading",        function(v) trace_loading   = v end)
local trace_features     = false  registertracker("otf.features",       function(v) trace_features  = v end)
local trace_dynamics     = false  registertracker("otf.dynamics",       function(v) trace_dynamics  = v end)
local trace_sequences    = false  registertracker("otf.sequences",      function(v) trace_sequences = v end)
local trace_markwidth    = false  registertracker("otf.markwidth",      function(v) trace_markwidth = v end)
local trace_defining     = false  registertracker("fonts.defining",     function(v) trace_defining  = v end)

local compact_lookups    = true   registertracker("otf.compactlookups", function(v) compact_lookups = v end)
local purge_names        = true   registertracker("otf.purgenames",     function(v) purge_names     = v end)

local report_otf         = logs.reporter("fonts","otf loading")

local fonts              = fonts
local otf                = fonts.handlers.otf

otf.glists               = { "gsub", "gpos" }

otf.version              = 2.819 -- beware: also sync font-mis.lua and in mtx-fonts
otf.cache                = containers.define("fonts", "otf", otf.version, true)

local hashes             = fonts.hashes
local definers           = fonts.definers
local readers            = fonts.readers
local constructors       = fonts.constructors

local fontdata           = hashes     and hashes.identifiers
local chardata           = characters and characters.data -- not used

local otffeatures        = constructors.newfeatures("otf")
local registerotffeature = otffeatures.register

local enhancers          = allocate()
otf.enhancers            = enhancers
local patches            = { }
enhancers.patches        = patches

local forceload          = false
local cleanup            = 0     -- mk: 0=885M 1=765M 2=735M (regular run 730M)
local packdata           = true
local syncspace          = true
local forcenotdef        = false
local includesubfonts    = false
local overloadkerns      = false -- experiment

local applyruntimefixes  = fonts.treatments and fonts.treatments.applyfixes

local wildcard           = "*"
local default            = "dflt"

local fontloader         = fontloader
local open_font          = fontloader.open
local close_font         = fontloader.close
local font_fields        = fontloader.fields
local apply_featurefile  = fontloader.apply_featurefile

local mainfields         = nil
local glyphfields        = nil -- not used yet

local formats            = fonts.formats

formats.otf              = "opentype"
formats.ttf              = "truetype"
formats.ttc              = "truetype"
formats.dfont            = "truetype"

registerdirective("fonts.otf.loader.cleanup",       function(v) cleanup       = tonumber(v) or (v and 1) or 0 end)
registerdirective("fonts.otf.loader.force",         function(v) forceload     = v end)
registerdirective("fonts.otf.loader.pack",          function(v) packdata      = v end)
registerdirective("fonts.otf.loader.syncspace",     function(v) syncspace     = v end)
registerdirective("fonts.otf.loader.forcenotdef",   function(v) forcenotdef   = v end)
registerdirective("fonts.otf.loader.overloadkerns", function(v) overloadkerns = v end)
-----------------("fonts.otf.loader.alldimensions", function(v) alldimensions = v end)

function otf.fileformat(filename)
    local leader = lower(io.loadchunk(filename,4))
    local suffix = lower(file.suffix(filename))
    if leader == "otto" then
        return formats.otf, suffix == "otf"
    elseif leader == "ttcf" then
        return formats.ttc, suffix == "ttc"
 -- elseif leader == "true" then
 --     return formats.ttf, suffix == "ttf"
    elseif suffix == "ttc" then
        return formats.ttc, true
    elseif suffix == "dfont" then
        return formats.dfont, true
    else
        return formats.ttf, suffix == "ttf"
    end
end

-- local function otf_format(filename)
--  -- return formats[lower(file.suffix(filename))]
-- end

local function otf_format(filename)
    local format, okay = otf.fileformat(filename)
    if not okay then
        report_otf("font %a is actually an %a file",filename,format)
    end
    return format
end

local function load_featurefile(raw,featurefile)
    if featurefile and featurefile ~= "" then
        if trace_loading then
            report_otf("using featurefile %a", featurefile)
        end
        apply_featurefile(raw, featurefile)
    end
end

local function showfeatureorder(rawdata,filename)
    local sequences = rawdata.resources.sequences
    if sequences and #sequences > 0 then
        if trace_loading then
            report_otf("font %a has %s sequences",filename,#sequences)
            report_otf(" ")
        end
        for nos=1,#sequences do
            local sequence  = sequences[nos]
            local typ       = sequence.type      or "no-type"
            local name      = sequence.name      or "no-name"
            local subtables = sequence.subtables or { "no-subtables" }
            local features  = sequence.features
            if trace_loading then
                report_otf("%3i  %-15s  %-20s  [% t]",nos,name,typ,subtables)
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
                            tt[#tt+1] = formatters["[%s: % t]"](script,ttt)
                        end
                        if trace_loading then
                            report_otf("       %s: % t",feature,tt)
                        end
                    else
                        if trace_loading then
                            report_otf("       %s: %S",feature,scripts)
                        end
                    end
                end
            end
        end
        if trace_loading then
            report_otf("\n")
        end
    elseif trace_loading then
        report_otf("font %a has no sequences",filename)
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
    "validation_state",
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

 -- "prepare tounicode",

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
--     "check extra features", -- after metadata

    "prepare tounicode",

    "check encoding", -- moved
    "add duplicates",

    "expand lookups", -- a temp hack awaiting the lua loader

--     "check extra features", -- after metadata and duplicates

    "cleanup tables",

    "compact lookups",
    "purge names",
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
            report_otf("apply enhancement %a to file %a",name,filename)
            ioflush()
        end
        enhancer(data,filename,raw)
    else
        -- no message as we can have private ones
    end
end

function enhancers.apply(data,filename,raw)
    local basename = file.basename(lower(filename))
    if trace_loading then
        report_otf("%s enhancing file %a","start",filename)
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
        report_otf("%s enhancing file %a","stop",filename)
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
        report_otf("patching: %s",formatters[fmt](...))
    end
end

function enhancers.register(what,action) -- only already registered can be overloaded
    actions[what] = action
end

function otf.load(filename,sub,featurefile) -- second argument (format) is gone !
    local base = file.basename(file.removesuffix(filename))
    local name = file.removesuffix(base)
    local attr = lfs.attributes(filename)
    local size = attr and attr.size or 0
    local time = attr and attr.modification or 0
    if featurefile then
        name = name .. "@" .. file.removesuffix(file.basename(featurefile))
    end
    -- or: sub = tonumber(sub)
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
                report_otf("loading error, no featurefile %a",s)
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
        report_otf("forced reload of %a due to hard coded flag",filename)
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
           report_otf("loading: forced reload due to changed featurefile specification %a",featurefile)
        end
     end
     if reload then
        starttiming("fontloader")
        report_otf("loading %a, hash %a",filename,hash)
        local fontdata, messages
        if sub then
            fontdata, messages = open_font(filename,sub)
        else
            fontdata, messages = open_font(filename)
        end
        if fontdata then
            mainfields = mainfields or (font_fields and font_fields(fontdata))
        end
        if trace_loading and messages and #messages > 0 then
            if type(messages) == "string" then
                report_otf("warning: %s",messages)
            else
                for m=1,#messages do
                    report_otf("warning: %S",messages[m])
                end
            end
        else
            report_otf("loading done")
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
                subfont     = sub,
                format      = otf_format(filename),
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
                warnings    = {
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
                helpers = { -- might go away
                    tounicodelist  = splitter,
                    tounicodetable = Ct(splitter),
                },
            }
            report_otf("file size: %s", size)
            enhancers.apply(data,filename,fontdata)
            local packtime = { }
            if packdata then
                if cleanup > 0 then
                    collectgarbage("collect")
                end
                starttiming(packtime)
                enhance("pack",data,filename,nil)
                stoptiming(packtime)
            end
            report_otf("saving %a in cache",filename)
            data = containers.write(otf.cache, hash, data)
            if cleanup > 1 then
                collectgarbage("collect")
            end
            stoptiming("fontloader")
            if elapsedtime then -- not in generic
                report_otf("loading, optimizing, packing and caching time %s, pack time %s",
                    elapsedtime("fontloader"),packdata and elapsedtime(packtime) or 0)
            end
            close_font(fontdata) -- free memory
            if cleanup > 3 then
                collectgarbage("collect")
            end
            data = containers.read(otf.cache, hash) -- this frees the old table and load the sparse one
            if cleanup > 2 then
                collectgarbage("collect")
            end
        else
            stoptiming("fontloader")
            data = nil
            report_otf("loading failed due to read error")
        end
    end
    if data then
        if trace_defining then
            report_otf("loading from cache using hash %a",hash)
        end
        enhance("unpack",data,filename,nil,false)
        --
        local resources  = data.resources
        local lookuptags = resources.lookuptags
        local unicodes   = resources.unicodes
        if not lookuptags then
            lookuptags = { }
            resources.lookuptags = lookuptags
        end
        setmetatableindex(lookuptags,function(t,k)
            local v = type(k) == "number" and ("lookup " .. k) or k
            t[k] = v
            return v
        end)
        if not unicodes then
            unicodes = { }
            resources.unicodes = unicodes
            setmetatableindex(unicodes,function(t,k)
                -- use rawget when no table has to be built
                setmetatableindex(unicodes,nil)
                for u, d in next, data.descriptions do
                    local n = d.name
                    if n then
                        t[n] = u
                     -- report_otf("accessing known name %a",k)
                    else
                     -- report_otf("accessing unknown name %a",k)
                    end
                end
                return rawget(t,k)
            end)
        end
        constructors.addcoreunicodes(unicodes) -- do we really need this?
        --
        if applyruntimefixes then
            applyruntimefixes(filename,data)
        end
        enhance("add dimensions",data,filename,nil,false)
enhance("check extra features",data,filename)
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
    data.properties.hasitalics = false
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
        local basename      = trace_markwidth and file.basename(filename)
        for _, d in next, descriptions do
            local bb, wd = d.boundingbox, d.width
            if not wd then
                -- or bb?
                d.width = defaultwidth
            elseif trace_markwidth and wd ~= 0 and d.class == "mark" then
                report_otf("mark %a with width %b found in %a",d.name or "<noname>",wd,basename)
             -- d.width  = -wd
            end
         -- if forcenotdef and not d.name then
         --     d.name = ".notdef"
         -- end
            if bb then
                local ht =  bb[4]
                local dp = -bb[2]
             -- if alldimensions then
             --     if ht ~= 0 then
             --         d.height = ht
             --     end
             --     if dp ~= 0 then
             --         d.depth  = dp
             --     end
             -- else
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
             -- end
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

-- not setting hasitalics and class (when nil) during table construction can save some mem

actions["prepare glyphs"] = function(data,filename,raw)
    local tableversion = tonumber(raw.table_version) or 0
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

        metadata.subfonts  = includesubfonts and { }
        properties.cidinfo = rawcidinfo

        if rawcidinfo.registry then
            local cidmap = fonts.cid.getmap(rawcidinfo)
            if cidmap then
                rawcidinfo.usedname = cidmap.usedname
                local nofnames    = 0
                local nofunicodes = 0
                local cidunicodes = cidmap.unicodes
                local cidnames    = cidmap.names
                local cidtotal    = 0
                local unique      = trace_subfonts and { }
                for cidindex=1,#rawsubfonts do
                    local subfont   = rawsubfonts[cidindex]
                    local cidglyphs = subfont.glyphs
                    if includesubfonts then
                        metadata.subfonts[cidindex] = somecopy(subfont)
                    end
                    local cidcnt, cidmin, cidmax
                    if tableversion > 0.3 then
                        -- we have delayed loading so we cannot use next
                        cidcnt = subfont.glyphcnt
                        cidmin = subfont.glyphmin
                        cidmax = subfont.glyphmax
                    else
                        cidcnt = subfont.glyphcnt
                        cidmin = 0
                        cidmax = cidcnt - 1
                    end
                    if trace_subfonts then
                        local cidtot = cidmax - cidmin + 1
                        cidtotal = cidtotal + cidtot
                        report_otf("subfont: %i, min: %i, max: %i, cnt: %i, n: %i",cidindex,cidmin,cidmax,cidtot,cidcnt)
                    end
                    if cidcnt > 0 then
                        for cidslot=cidmin,cidmax do
                            local glyph = cidglyphs[cidslot]
                            if glyph then
                                local index = tableversion > 0.3 and glyph.orig_pos or cidslot
                                if trace_subfonts then
                                    unique[index] = true
                                end
                                local unicode = glyph.unicode
                                if     unicode >= 0x00E000 and unicode <= 0x00F8FF then
                                    unicode = -1
                                elseif unicode >= 0x0F0000 and unicode <= 0x0FFFFD then
                                    unicode = -1
                                elseif unicode >= 0x100000 and unicode <= 0x10FFFD then
                                    unicode = -1
                                end
                                local name = glyph.name or cidnames[index]
                                if not unicode or unicode == -1 then -- or unicode >= criterium then
                                    unicode = cidunicodes[index]
                                end
                                if unicode and descriptions[unicode] then
                                    if trace_private then
                                        report_otf("preventing glyph %a at index %H to overload unicode %U",name or "noname",index,unicode)
                                    end
                                    unicode = -1
                                end
                                if not unicode or unicode == -1 then -- or unicode >= criterium then
                                    if not name then
                                        name = formatters["u%06X.ctx"](private)
                                    end
                                    unicode = private
                                    unicodes[name] = private
                                    if trace_private then
                                        report_otf("glyph %a at index %H is moved to private unicode slot %U",name,index,private)
                                    end
                                    private = private + 1
                                    nofnames = nofnames + 1
                                else
                                 -- if unicode > criterium then
                                 --     local taken = descriptions[unicode]
                                 --     if taken then
                                 --         private = private + 1
                                 --         descriptions[private] = taken
                                 --         unicodes[taken.name] = private
                                 --         indices[taken.index] = private
                                 --         if trace_private then
                                 --             report_otf("slot %U is moved to %U due to private in font",unicode)
                                 --         end
                                 --     end
                                 -- end
                                    if not name then
                                        name = formatters["u%06X.ctx"](unicode)
                                    end
                                    unicodes[name] = unicode
                                    nofunicodes = nofunicodes + 1
                                end
                                indices[index] = unicode -- each index is unique (at least now)
                                local description = {
                                 -- width       = glyph.width,
                                    boundingbox = glyph.boundingbox,
                                 -- name        = glyph.name or name or "unknown", -- uniXXXX
                                    name        = name or "unknown", -- uniXXXX
                                    cidindex    = cidindex,
                                    index       = cidslot,
                                    glyph       = glyph,
                                }
                                descriptions[unicode] = description
                                local altuni = glyph.altuni
                                if altuni then
                                 -- local d
                                    for i=1,#altuni do
                                        local a = altuni[i]
                                        local u = a.unicode
                                        if u ~= unicode then
                                            local v = a.variant
                                            if v then
                                                -- tricky: no addition to d? needs checking but in practice such dups are either very simple
                                                -- shapes or e.g cjk with not that many features
                                                local vv = variants[v]
                                                if vv then
                                                    vv[u] = unicode
                                                else -- xits-math has some:
                                                    vv = { [u] = unicode }
                                                    variants[v] = vv
                                                end
                                         -- elseif d then
                                         --     d[#d+1] = u
                                         -- else
                                         --     d = { u }
                                            end
                                        end
                                    end
                                 -- if d then
                                 --     duplicates[unicode] = d -- is this needed ?
                                 -- end
                                end
                            end
                        end
                    else
                        report_otf("potential problem: no glyphs found in subfont %i",cidindex)
                    end
                end
                if trace_subfonts then
                    report_otf("nofglyphs: %i, unique: %i",cidtotal,table.count(unique))
                end
                if trace_loading then
                    report_otf("cid font remapped, %s unicode points, %s symbolic names, %s glyphs",nofunicodes, nofnames, nofunicodes+nofnames)
                end
            elseif trace_loading then
                report_otf("unable to remap cid font, missing cid file for %a",filename)
            end
        elseif trace_loading then
            report_otf("font %a has no glyphs",filename)
        end

    else

        local cnt = raw.glyphcnt or 0
        local min = tableversion > 0.3 and raw.glyphmin or 0
        local max = tableversion > 0.3 and raw.glyphmax or (raw.glyphcnt - 1)
        if cnt > 0 then
--             for index=0,cnt-1 do
            for index=min,max do
                local glyph = rawglyphs[index]
                if glyph then
                    local unicode = glyph.unicode
                    local name    = glyph.name
                    if not unicode or unicode == -1 then -- or unicode >= criterium then
                        unicode = private
                        unicodes[name] = private
                        if trace_private then
                            report_otf("glyph %a at index %H is moved to private unicode slot %U",name,index,private)
                        end
                        private = private + 1
                    else
                        -- We have a font that uses and exposes the private area. As this is rather unreliable it's
                        -- advised no to trust slots here (better use glyphnames). Anyway, we need a double check:
                        -- we need to move already moved entries and we also need to bump the next private to after
                        -- the (currently) last slot. This could leave us with a hole but we have holes anyway.
                        if unicode > criterium then
                            -- \definedfont[file:HANBatang-LVT.ttf] \fontchar{uF0135} \char"F0135
                            local taken = descriptions[unicode]
                            if taken then
                                if unicode >= private then
                                    private = unicode + 1 -- restart private (so we can have mixed now)
                                else
                                    private = private + 1 -- move on
                                end
                                descriptions[private] = taken
                                unicodes[taken.name] = private
                                indices[taken.index] = private
                                if trace_private then
                                    report_otf("slot %U is moved to %U due to private in font",unicode)
                                end
                            else
                                if unicode >= private then
                                    private = unicode + 1 -- restart (so we can have mixed now)
                                end
                            end
                        end
                        unicodes[name] = unicode
                    end
                    indices[index] = unicode
                 -- if not name then
                 --     name = formatters["u%06X"](unicode) -- u%06X.ctx
                 -- end
                    descriptions[unicode] = {
                     -- width       = glyph.width,
                        boundingbox = glyph.boundingbox,
                        name        = name,
                        index       = index,
                        glyph       = glyph,
                    }
                    local altuni = glyph.altuni
                    if altuni then
                     -- local d
                        for i=1,#altuni do
                            local a = altuni[i]
                            local u = a.unicode
                            if u ~= unicode then
                                local v = a.variant
                                if v then
                                    -- tricky: no addition to d? needs checking but in practice such dups are either very simple
                                    -- shapes or e.g cjk with not that many features
                                    local vv = variants[v]
                                    if vv then
                                        vv[u] = unicode
                                    else -- xits-math has some:
                                        vv = { [u] = unicode }
                                        variants[v] = vv
                                    end
                             -- elseif d then
                             --     d[#d+1] = u
                             -- else
                             --     d = { u }
                                end
                            end
                        end
                     -- if d then
                     --     duplicates[unicode] = d -- is this needed ?
                     -- end
                    end
                else
                    report_otf("potential problem: glyph %U is used but empty",index)
                end
            end
        else
            report_otf("potential problem: no glyphs found")
        end

    end

    resources.private = private

end

-- the next one is still messy but will get better when we have
-- flattened map/enc tables in the font loader

-- the next one is not using a valid base for unicode privates
--
-- PsuedoEncodeUnencoded(EncMap *map,struct ttfinfo *info)

actions["check encoding"] = function(data,filename,raw)
    local descriptions = data.descriptions
    local resources    = data.resources
    local properties   = data.properties
    local unicodes     = resources.unicodes -- name to unicode
    local indices      = resources.indices  -- index to unicodes
    local duplicates   = resources.duplicates

    -- begin of messy (not needed when cidmap)

    local mapdata        = raw.map or { }
    local unicodetoindex = mapdata and mapdata.map or { }
    local indextounicode = mapdata and mapdata.backmap or { }
 -- local encname        = lower(data.enc_name or raw.enc_name or mapdata.enc_name or "")
    local encname        = lower(data.enc_name or mapdata.enc_name or "")
    local criterium      = 0xFFFF -- for instance cambria has a lot of mess up there
    local privateoffset  = constructors.privateoffset

    -- end of messy

    if find(encname,"unicode") then -- unicodebmp, unicodefull, ...
        if trace_loading then
            report_otf("checking embedded unicode map %a",encname)
        end
        local reported = { }
        -- we loop over the original unicode->index mapping but we
        -- need to keep in mind that that one can have weird entries
        -- so we need some extra checking
        for maybeunicode, index in next, unicodetoindex do
            if descriptions[maybeunicode] then
                -- we ignore invalid unicodes (unicode = -1) (ff can map wrong to non private)
            else
                local unicode = indices[index]
                if not unicode then
                    -- weird (cjk or so?)
                elseif maybeunicode == unicode then
                    -- no need to add
                elseif unicode > privateoffset then
                    -- we have a non-unicode
                else
                    local d = descriptions[unicode]
                    if d then
                        local c = d.copies
                        if c then
                            c[maybeunicode] = true
                        else
                            d.copies = { [maybeunicode] = true }
                        end
                    elseif index and not reported[index] then
                        report_otf("missing index %i",index)
                        reported[index] = true
                    end
                end
            end
        end
        for unicode, data in next, descriptions do
            local d = data.copies
            if d then
                duplicates[unicode] = sortedkeys(d)
                data.copies = nil
            end
        end
    elseif properties.cidinfo then
        report_otf("warning: no unicode map, used cidmap %a",properties.cidinfo.usedname)
    else
        report_otf("warning: non unicode map %a, only using glyph unicode data",encname or "whatever")
    end

    if mapdata then
        mapdata.map     = { } -- clear some memory (virtual and created each time anyway)
        mapdata.backmap = { } -- clear some memory (virtual and created each time anyway)
    end
end

-- for the moment we assume that a font with lookups will not use
-- altuni so we stick to kerns only .. alternatively we can always
-- do an indirect lookup uni_to_uni . but then we need that in
-- all lookups

actions["add duplicates"] = function(data,filename,raw)
    local descriptions = data.descriptions
    local resources    = data.resources
    local properties   = data.properties
    local unicodes     = resources.unicodes -- name to unicode
    local indices      = resources.indices  -- index to unicodes
    local duplicates   = resources.duplicates
    for unicode, d in next, duplicates do
        local nofduplicates = #d
        if nofduplicates > 4 then
            if trace_loading then
                report_otf("ignoring excessive duplicates of %U (n=%s)",unicode,nofduplicates)
            end
        else
         -- local validduplicates = { }
            for i=1,nofduplicates do
                local u = d[i]
                if not descriptions[u] then
                    local description = descriptions[unicode]
                    local n = 0
                    for _, description in next, descriptions do
                        local kerns = description.kerns
                        if kerns then
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
                    if u > 0 then -- and
                        local duplicate = table.copy(description) -- else packing problem
                        duplicate.comment = formatters["copy of %U"](unicode)
                        descriptions[u] = duplicate
                     -- validduplicates[#validduplicates+1] = u
                        if trace_loading then
                            report_otf("duplicating %U to %U with index %H (%s kerns)",unicode,u,description.index,n)
                        end
                    end
                end
            end
         -- duplicates[unicode] = #validduplicates > 0 and validduplicates or nil
        end
    end
end

-- class      : nil base mark ligature component (maybe we don't need it in description)
-- boundingbox: split into ht/dp takes more memory (larger tables and less sharing)

actions["analyze glyphs"] = function(data,filename,raw) -- maybe integrate this in the previous
    local descriptions = data.descriptions
    local resources    = data.resources
    local metadata     = data.metadata
    local properties   = data.properties
    local hasitalics   = false
    local widths       = { }
    local marks        = { } -- always present (saves checking)
    for unicode, description in next, descriptions do
        local glyph  = description.glyph
        local italic = glyph.italic_correction -- only in a math font (we also have vert/horiz)
        if not italic then
            -- skip
        elseif italic == 0 then
            -- skip
        else
            description.italic = italic
            hasitalics = true
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
    properties.hasitalics = hasitalics
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
    for k=1,#otf.glists do
        local what = otf.glists[k]
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

-- local function checklookups(data,missing,nofmissing)
--     local resources    = data.resources
--     local unicodes     = resources.unicodes
--     local lookuptypes  = resources.lookuptypes
--     if not unicodes or not lookuptypes then
--         return
--     elseif nofmissing <= 0 then
--         return
--     end
--     local descriptions = data.descriptions
--     local private      = fonts.constructors and fonts.constructors.privateoffset or 0xF0000 -- 0x10FFFF
--     --
--     local ns, nl = 0, 0

--     local guess  = { }
--     -- helper
--     local function check(gname,code,unicode)
--         local description = descriptions[code]
--         -- no need to add a self reference
--         local variant = description.name
--         if variant == gname then
--             return
--         end
--         -- the variant already has a unicode (normally that results in a default tounicode to self)
--         local unic = unicodes[variant]
--         if unic == -1 or unic >= private or (unic >= 0xE000 and unic <= 0xF8FF) or unic == 0xFFFE or unic == 0xFFFF then
--             -- no default mapping and therefore maybe no tounicode yet
--         else
--             return
--         end
--         -- the variant already has a tounicode
--         if descriptions[code].unicode then
--             return
--         end
--         -- add to the list
--         local g = guess[variant]
--      -- local r = overloads[unicode]
--      -- if r then
--      --     unicode = r.unicode
--      -- end
--         if g then
--             g[gname] = unicode
--         else
--             guess[variant] = { [gname] = unicode }
--         end
--     end
--     --
--     for unicode, description in next, descriptions do
--         local slookups = description.slookups
--         if slookups then
--             local gname = description.name
--             for tag, data in next, slookups do
--                 local lookuptype = lookuptypes[tag]
--                 if lookuptype == "alternate" then
--                     for i=1,#data do
--                         check(gname,data[i],unicode)
--                     end
--                 elseif lookuptype == "substitution" then
--                     check(gname,data,unicode)
--                 end
--             end
--         end
--         local mlookups = description.mlookups
--         if mlookups then
--             local gname = description.name
--             for tag, list in next, mlookups do
--                 local lookuptype = lookuptypes[tag]
--                 if lookuptype == "alternate" then
--                     for i=1,#list do
--                         local data = list[i]
--                         for i=1,#data do
--                             check(gname,data[i],unicode)
--                         end
--                     end
--                 elseif lookuptype == "substitution" then
--                     for i=1,#list do
--                         check(gname,list[i],unicode)
--                     end
--                 end
--             end
--         end
--     end
--     -- resolve references
--     local done = true
--     while done do
--         done = false
--         for k, v in next, guess do
--             if type(v) ~= "number" then
--                 for kk, vv in next, v do
--                     if vv == -1 or vv >= private or (vv >= 0xE000 and vv <= 0xF8FF) or vv == 0xFFFE or vv == 0xFFFF then
--                         local uu = guess[kk]
--                         if type(uu) == "number" then
--                             guess[k] = uu
--                             done = true
--                         end
--                     else
--                         guess[k] = vv
--                         done = true
--                     end
--                 end
--             end
--         end
--     end
--     -- wrap up
--     local orphans = 0
--     local guessed = 0
--     for k, v in next, guess do
--         if type(v) == "number" then
--             descriptions[unicodes[k]].unicode = descriptions[v].unicode or v -- can also be a table
--             guessed = guessed + 1
--         else
--             local t = nil
--             local l = lower(k)
--             local u = unicodes[l]
--             if not u then
--                 orphans = orphans + 1
--             elseif u == -1 or u >= private or (u >= 0xE000 and u <= 0xF8FF) or u == 0xFFFE or u == 0xFFFF then
--                 local unicode = descriptions[u].unicode
--                 if unicode then
--                     descriptions[unicodes[k]].unicode = unicode
--                     guessed = guessed + 1
--                 else
--                     orphans = orphans + 1
--                 end
--             else
--                 orphans = orphans + 1
--             end
--         end
--     end
--     if trace_loading and orphans > 0 or guessed > 0 then
--         report_otf("%s glyphs with no related unicode, %s guessed, %s orphans",guessed+orphans,guessed,orphans)
--     end
-- end

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
-- The following is no longer needed as AAT is ignored per end October 2013.
--
-- -- Research by Khaled Hosny has demonstrated that the font loader merges
-- -- regular and AAT features and that these can interfere (especially because
-- -- we dropped checking for valid features elsewhere. So, we just check for
-- -- the special flag and drop the feature if such a tag is found.
--
-- local function supported(features)
--     for i=1,#features do
--         if features[i].ismac then
--             return false
--         end
--     end
--     return true
-- end

actions["reorganize subtables"] = function(data,filename,raw)
    local resources       = data.resources
    local sequences       = { }
    local lookups         = { }
    local chainedfeatures = { }
    resources.sequences   = sequences
    resources.lookups     = lookups -- we also have lookups in data itself
    for k=1,#otf.glists do
        local what = otf.glists[k]
        local dw = raw[what]
        if dw then
            for k=1,#dw do
                local gk = dw[k]
                local features = gk.features
             -- if not features or supported(features) then -- not always features !
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
                    if not name then
                        -- in fact an error
                        report_otf("skipping weird lookup number %s",k)
                    elseif features then
                        -- scripts, tag, ismac
                        local f = { }
                        local o = { }
                        for i=1,#features do
                            local df = features[i]
                            local tag = strip(lower(df.tag))
                            local ft = f[tag]
                            if not ft then
                                ft = { }
                                f[tag] = ft
                                o[#o+1] = tag
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
                        sequences[#sequences+1] = {
                            type      = typ,
                            chain     = chain,
                            flags     = flags,
                            name      = name,
                            subtables = subtables,
                            markclass = markclass,
                            features  = f,
                            order     = o,
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
             -- end
            end
        end
    end
end

actions["prepare lookups"] = function(data,filename,raw)
    local lookups = raw.lookups
    if lookups then
        data.lookups = lookups
    end
end

-- The reverse handler does a bit redundant splitting but it's seldom
-- seen so we don't bother too much. We could store the replacement
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

local function s_uncover(splitter,cache,cover)
    if cover == "" then
        return nil
    else
        local uncovered = cache[cover]
        if not uncovered then
            uncovered = lpegmatch(splitter,cover)
         -- for i=1,#uncovered do
         --     uncovered[i] = { [uncovered[i]] = true }
         -- end
            cache[cover] = uncovered
        end
        return { uncovered }
    end
end

local function t_hashed(t,cache)
    if t then
        local ht = { }
        for i=1,#t do
            local ti = t[i]
            local tih = cache[ti]
            if not tih then
                local tn = #ti
                if tn == 1 then
                    tih = { [ti[1]] = true }
                else
                    tih = { }
                    for i=1,tn do
                        tih[ti[i]] = true
                    end
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

-- local s_hashed = t_hashed

local function s_hashed(t,cache)
    if t then
        local tf = t[1]
        local nf = #tf
        if nf == 1 then
            return { [tf[1]] = true }
        else
            local ht = { }
            for i=1,nf do
                ht[i] = { [tf[i]] = true }
            end
            return ht
        end
    else
        return nil
    end
end

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

actions["reorganize lookups"] = function(data,filename,raw) -- we could check for "" and n == 0
    -- we prefer the before lookups in a normal order
    if data.lookups then
        local helpers      = data.helpers
        local duplicates   = data.resources.duplicates
        local splitter     = helpers.tounicodetable
        local t_u_cache    = { }
        local s_u_cache    = t_u_cache -- string keys
        local t_h_cache    = { }
        local s_h_cache    = t_h_cache -- table keys (so we could use one cache)
        local r_u_cache    = { } -- maybe shared
        helpers.matchcache = t_h_cache -- so that we can add duplicates
        --
        for _, lookup in next, data.lookups do
            local rules = lookup.rules
            if rules then
                local format = lookup.format
                if format == "class" then
                    local before_class = lookup.before_class
                    if before_class then
                        before_class = t_uncover(splitter,t_u_cache,reversed(before_class))
                    end
                    local current_class = lookup.current_class
                    if current_class then
                        current_class = t_uncover(splitter,t_u_cache,current_class)
                    end
                    local after_class = lookup.after_class
                    if after_class then
                        after_class = t_uncover(splitter,t_u_cache,after_class)
                    end
                    for i=1,#rules do
                        local rule = rules[i]
                        local class = rule.class
                        local before = class.before
                        if before then
                            for i=1,#before do
                                before[i] = before_class[before[i]] or { }
                            end
                            rule.before = t_hashed(before,t_h_cache)
                        end
                        local current = class.current
                        local lookups = rule.lookups
                        if current then
                            for i=1,#current do
                                current[i] = current_class[current[i]] or { }
                                -- let's not be sparse
                                if lookups and not lookups[i] then
                                    lookups[i] = "" -- (was: false) e.g. we can have two lookups and one replacement
                                end
                                -- end of fix
                            end
                            rule.current = t_hashed(current,t_h_cache)
                        end
                        local after = class.after
                        if after then
                            for i=1,#after do
                                after[i] = after_class[after[i]] or { }
                            end
                            rule.after = t_hashed(after,t_h_cache)
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
                                before = t_uncover(splitter,t_u_cache,reversed(before))
                                rule.before = t_hashed(before,t_h_cache)
                            end
                            local current = coverage.current
                            if current then
                                current = t_uncover(splitter,t_u_cache,current)
                                -- let's not be sparse
                                local lookups = rule.lookups
                                if lookups then
                                    for i=1,#current do
                                        if not lookups[i] then
                                            lookups[i] = "" -- fix sparse array
                                        end
                                    end
                                end
                                --
                                rule.current = t_hashed(current,t_h_cache)
                            end
                            local after = coverage.after
                            if after then
                                after = t_uncover(splitter,t_u_cache,after)
                                rule.after = t_hashed(after,t_h_cache)
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
                                before = t_uncover(splitter,t_u_cache,reversed(before))
                                rule.before = t_hashed(before,t_h_cache)
                            end
                            local current = reversecoverage.current
                            if current then
                                current = t_uncover(splitter,t_u_cache,current)
                                rule.current = t_hashed(current,t_h_cache)
                            end
                            local after = reversecoverage.after
                            if after then
                                after = t_uncover(splitter,t_u_cache,after)
                                rule.after = t_hashed(after,t_h_cache)
                            end
                            local replacements = reversecoverage.replacements
                            if replacements then
                                rule.replacements = r_uncover(splitter,r_u_cache,current,replacements)
                            end
                            rule.reversecoverage = nil
                        end
                    end
                elseif format == "glyphs" then
                    -- I could store these more efficient (as not we use a nested tables for before,
                    -- after and current but this features happens so seldom that I don't bother
                    -- about it right now.
                    for i=1,#rules do
                        local rule = rules[i]
                        local glyphs = rule.glyphs
                        if glyphs then
                            local fore = glyphs.fore
                            if fore and fore ~= "" then
                                fore = s_uncover(splitter,s_u_cache,fore)
                                rule.after = s_hashed(fore,s_h_cache)
                            end
                            local back = glyphs.back
                            if back then
                                back = s_uncover(splitter,s_u_cache,back)
                                rule.before = s_hashed(back,s_h_cache)
                            end
                            local names = glyphs.names
                            if names then
                                names = s_uncover(splitter,s_u_cache,names)
                                rule.current = s_hashed(names,s_h_cache)
                            end
                            rule.glyphs = nil
                            local lookups = rule.lookups
                            if lookups then
                                for i=1,#names do
                                    if not lookups[i] then
                                        lookups[i] = "" -- fix sparse array
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

actions["expand lookups"] = function(data,filename,raw) -- we could check for "" and n == 0
    if data.lookups then
        local cache = data.helpers.matchcache
        if cache then
            local duplicates = data.resources.duplicates
            for key, hash in next, cache do
                local done = nil
                for key in next, hash do
                    local unicode = duplicates[key]
                    if not unicode then
                        -- no duplicate
                    elseif type(unicode) == "table" then
                        -- multiple duplicates
                        for i=1,#unicode do
                            local u = unicode[i]
                            if hash[u] then
                                -- already in set
                            elseif done then
                                done[u] = key
                            else
                                done = { [u] = key }
                            end
                        end
                    else
                        -- one duplicate
                        if hash[unicode] then
                            -- already in set
                        elseif done then
                            done[unicode] = key
                        else
                            done = { [unicode] = key }
                        end
                    end
                end
                if done then
                    for u in next, done do
                        hash[u] = true
                    end
                end
            end
        end
    end
end

local function check_variants(unicode,the_variants,splitter,unicodes)
    local variants = the_variants.variants
    if variants then -- use splitter
        local glyphs = lpegmatch(splitter,variants)
        local done   = { [unicode] = true }
        local n      = 0
        for i=1,#glyphs do
            local g = glyphs[i]
            if done[g] then
                if i > 1 then
                    report_otf("skipping cyclic reference %U in math variant %U",g,unicode)
                end
            else
                if n == 0 then
                    n = 1
                    variants = { g }
                else
                    n = n + 1
                    variants[n] = g
                end
                done[g] = true
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
    local italic = the_variants.italic
    if italic and italic == 0 then
        italic = nil
    end
    return variants, parts, italic
end

actions["analyze math"] = function(data,filename,raw)
    if raw.math then
        data.metadata.math = raw.math
        local unicodes = data.resources.unicodes
        local splitter = data.helpers.tounicodetable
        for unicode, description in next, data.descriptions do
            local glyph        = description.glyph
            local mathkerns    = glyph.mathkern -- singular
            local hvariants    = glyph.horiz_variants
            local vvariants    = glyph.vert_variants
            local accent       = glyph.top_accent
            local italic       = glyph.italic_correction
            if mathkerns or hvariants or vvariants or accent or italic then
                local math = { }
                if accent then
                    math.accent = accent
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
                if hvariants then
                    math.hvariants, math.hparts, math.hitalic = check_variants(unicode,hvariants,splitter,unicodes)
                end
                if vvariants then
                    math.vvariants, math.vparts, math.vitalic = check_variants(unicode,vvariants,splitter,unicodes)
                end
                if italic and italic ~= 0 then
                    math.italic = italic
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
                        report_otf("problems with unicode %a of kern %a of glyph %U",name,k,unicode)
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
        local ignored      = 0
        local blocked      = 0
        for gp=1,#gposlist do
            local gpos = gposlist[gp]
            local subtables = gpos.subtables
            if subtables then
                local first_done = { } -- could become an option so that we can deal with buggy fonts that don't get fixed
                local split = { } -- saves time .. although probably not that much any more in the fixed luatex kernclass table
                for s=1,#subtables do
                    local subtable = subtables[s]
                    local kernclass = subtable.kernclass -- name is inconsistent with anchor_classes
                    local lookup = subtable.lookup or subtable.name
                    if kernclass then -- the next one is quite slow
                        if #kernclass > 0 then
                            -- it's a table with one entry .. a future luatex can just
                            -- omit that level
                            kernclass = kernclass[1]
                            lookup    = type(kernclass.lookup) == "string" and kernclass.lookup or lookup
                            report_otf("fixing kernclass table of lookup %a",lookup)
                        end
                        local firsts  = kernclass.firsts
                        local seconds = kernclass.seconds
                        local offsets = kernclass.offsets
                     -- if offsets[1] == nil then
                     --     offsets[1] = "" -- defaults ?
                     -- end
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
                        for fk=1,#firsts do -- maxfirsts ?
                            local fv = firsts[fk]
                            local splt = split[fv]
                            if splt then
                                local extrakerns = { }
                                local baseoffset = (fk-1) * maxseconds
                                for sk=2,maxseconds do -- will become 1 based in future luatex
                                    local sv = seconds[sk]
                             -- for sk, sv in next, seconds do
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
                                    if first_done[first_unicode] then
                                        report_otf("lookup %a: ignoring further kerns of %C",lookup,first_unicode)
                                        blocked = blocked + 1
                                    else
                                        first_done[first_unicode] = true
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
                                            if overloadkerns then
                                                for second_unicode, kern in next, extrakerns do
                                                    lookupkerns[second_unicode] = kern
                                                end
                                            else
                                                for second_unicode, kern in next, extrakerns do
                                                    local k = lookupkerns[second_unicode]
                                                    if not k then
                                                        lookupkerns[second_unicode] = kern
                                                    elseif k ~= kern then
                                                        if trace_loading then
                                                            report_otf("lookup %a: ignoring overload of kern between %C and %C, rejecting %a, keeping %a",lookup,first_unicode,second_unicode,k,kern)
                                                        end
                                                        ignored = ignored + 1
                                                    end
                                                end
                                            end
                                        elseif trace_loading then
                                            report_otf("no glyph data for %U", first_unicode)
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
        if ignored > 0 then
            report_otf("%s kern overloads ignored",ignored)
        end
        if blocked > 0 then
            report_otf("%s successive kerns blocked",blocked)
        end
    end
end

actions["check glyphs"] = function(data,filename,raw)
    for unicode, description in next, data.descriptions do
        description.glyph = nil
    end
end

-- future versions will remove _

local valid = (R("\x00\x7E") - S("(){}[]<>%/ \n\r\f\v"))^0 * P(-1)

local function valid_ps_name(str)
    return str and str ~= "" and #str < 64 and lpegmatch(valid,str) and true or false
end

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
    --
    local names = raw.names
    --
    if metadata.validation_state and table.contains(metadata.validation_state,"bad_ps_fontname") then
        -- the ff library does a bit too much (and wrong) checking ... so we need to catch this
        -- at least for now
        local function valid(what)
            if names then
                for i=1,#names do
                    local list = names[i]
                    local names = list.names
                    if names then
                        local name = names[what]
                        if name and valid_ps_name(name) then
                            return name
                        end
                    end
                end
            end
        end
        local function check(what)
            local oldname = metadata[what]
            if valid_ps_name(oldname) then
                report_otf("ignoring warning %a because %s %a is proper ASCII","bad_ps_fontname",what,oldname)
            else
                local newname = valid(what)
                if not newname then
                    newname = formatters["bad-%s-%s"](what,file.nameonly(filename))
                end
                local warning = formatters["overloading %s from invalid ASCII name %a to %a"](what,oldname,newname)
                data.warnings[#data.warnings+1] = warning
                report_otf(warning)
                metadata[what] = newname
            end
        end
        check("fontname")
        check("fullname")
    end
    --
    if names then
        local psname = metadata.psname
        if not psname or psname == "" then
            for i=1,#names do
                local name = names[i]
                -- Currently we use the same restricted search as in the new context (specific) font loader
                -- but we might add more lang checks (it worked ok in the new loaded so now we're in sync)
                -- This check here is also because there are (esp) cjk fonts out there with psnames different
                -- from fontnames (gives a bad lookup in backend).
                if lower(name.lang) == "english (us)" then
                    local specification = name.names
                    if specification then
                        local postscriptname = specification.postscriptname
                        if postscriptname then
                            psname = postscriptname
                        end
                    end
                end
                break
            end
        end
        if psname ~= metadata.fontname then
            report_otf("fontname %a, fullname %a, psname %a",metadata.fontname,metadata.fullname,psname)
        end
        metadata.psname = psname
    end
    --
end

actions["cleanup tables"] = function(data,filename,raw)
    local duplicates = data.resources.duplicates
    if duplicates then
        for k, v in next, duplicates do
            if #v == 1 then
                duplicates[k] = v[1]
            end
        end
    end
    data.resources.indices  = nil -- not needed
    data.resources.unicodes = nil -- delayed
    data.helpers            = nil -- tricky as we have no unicodes any more
end

-- kern: ttf has a table with kerns
--
-- Weird, as maxfirst and maxseconds can have holes, first seems to be indexed, but
-- seconds can start at 2 .. this need to be fixed as getn as well as # are sort of
-- unpredictable alternatively we could force an [1] if not set (maybe I will do that
-- anyway).

-- we can share { } as it is never set

-- ligatures have an extra specification.char entry that we don't use

-- mlookups only with pairs and ligatures

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
                        report_otf("conflicting lookuptypes, %a points to %a and %a",tag,lt,lookuptype)
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
         -- description.lookups = nil
        end
    end
end

local zero = { 0, 0 }

actions["reorganize glyph anchors"] = function(data,filename,raw)
    local descriptions = data.descriptions
    for unicode, description in next, descriptions do
        local anchors = description.glyph.anchors
        if anchors then
            for class, data in next, anchors do
                if class == "baselig" then
                    for tag, specification in next, data do
                     -- for i=1,#specification do
                     --     local si = specification[i]
                     --     specification[i] = { si.x or 0, si.y or 0 }
                     -- end
                        -- can be sparse so we need to fill the holes
                        local n = 0
                        for k, v in next, specification do
                            if k > n then
                                n = k
                            end
                            local x, y = v.x, v.y
                            if x or y then
                                specification[k] = { x or 0, y or 0 }
                            else
                                specification[k] = zero
                            end
                        end
                        local t = { }
                        for i=1,n do
                            t[i] = specification[i] or zero
                        end
                        data[tag] = t -- so # is okay (nicer for packer)
                    end
                else
                    for tag, specification in next, data do
                        local x, y = specification.x, specification.y
                        if x or y then
                            data[tag] = { x or 0, y or 0 }
                        else
                            data[tag] = zero
                        end
                    end
                end
            end
            description.anchors = anchors
        end
    end
end

local bogusname   = (P("uni") + P("u")) * R("AF","09")^4
                  + (P("index") + P("glyph") + S("Ii") * P("dentity") * P(".")^0) * R("09")^1
local uselessname = (1-bogusname)^0 * bogusname

actions["purge names"] = function(data,filename,raw) -- not used yet
    if purge_names then
        local n = 0
        for u, d in next, data.descriptions do
            if lpegmatch(uselessname,d.name) then
                n = n + 1
                d.name = nil
            end
         -- d.comment = nil
        end
        if n > 0 then
            report_otf("%s bogus names removed",n)
        end
    end
end

actions["compact lookups"] = function(data,filename,raw)
    if not compact_lookups then
        report_otf("not compacting")
        return
    end
    -- create keyhash
    local last  = 0
    local tags  = table.setmetatableindex({ },
        function(t,k)
            last = last + 1
            t[k] = last
            return last
        end
    )
    --
    local descriptions = data.descriptions
    local resources    = data.resources
    --
    for u, d in next, descriptions do
        --
        -- -- we can also compact anchors and cursives (basechar basemark baselig mark)
        --
        local slookups = d.slookups
        if type(slookups) == "table" then
            local s = { }
            for k, v in next, slookups do
                s[tags[k]] = v
            end
            d.slookups = s
        end
        --
        local mlookups = d.mlookups
        if type(mlookups) == "table" then
            local m = { }
            for k, v in next, mlookups do
                m[tags[k]] = v
            end
            d.mlookups = m
        end
        --
        local kerns = d.kerns
        if type(kerns) == "table" then
            local t = { }
            for k, v in next, kerns do
                t[tags[k]] = v
            end
            d.kerns = t
        end
    end
    --
    local lookups = data.lookups
    if lookups then
        local l = { }
        for k, v in next, lookups do
            local rules = v.rules
            if rules then
                for i=1,#rules do
                    local l = rules[i].lookups
                    if type(l) == "table" then
                        for i=1,#l do
                            l[i] = tags[l[i]]
                        end
                    end
                end
            end
            l[tags[k]] = v
        end
        data.lookups = l
    end
    --
    local lookups = resources.lookups
    if lookups then
        local l = { }
        for k, v in next, lookups do
            local s = v.subtables
            if type(s) == "table" then
                for i=1,#s do
                    s[i] = tags[s[i]]
                end
            end
            l[tags[k]] = v
        end
        resources.lookups = l
    end
    --
    local sequences = resources.sequences
    if sequences then
        for i=1,#sequences do
            local s = sequences[i]
            local n = s.name
            if n then
                s.name = tags[n]
            end
            local t = s.subtables
            if type(t) == "table" then
                for i=1,#t do
                    t[i] = tags[t[i]]
                end
            end
        end
    end
    --
    local lookuptypes = resources.lookuptypes
    if lookuptypes then
        local l = { }
        for k, v in next, lookuptypes do
            l[tags[k]] = v
        end
        resources.lookuptypes = l
    end
    --
    local anchor_to_lookup = resources.anchor_to_lookup
    if anchor_to_lookup then
        for anchor, lookups in next, anchor_to_lookup do
            local l = { }
            for lookup, value in next, lookups do
                l[tags[lookup]] = value
            end
            anchor_to_lookup[anchor] = l
        end
    end
    --
    local lookup_to_anchor = resources.lookup_to_anchor
    if lookup_to_anchor then
        local l = { }
        for lookup, value in next, lookup_to_anchor do
            l[tags[lookup]] = value
        end
        resources.lookup_to_anchor = l
    end
    --
    tags = table.swapped(tags)
    --
    report_otf("%s lookup tags compacted",#tags)
    --
    resources.lookuptags = tags
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
-- we already assign an empty tabel to characters as we can add for
-- instance protruding info and loop over characters; one is not supposed
-- to change descriptions and if one does so one should make a copy!

local function copytotfm(data,cache_id)
    if data then
        local metadata       = data.metadata
        local warnings       = data.warnings
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
        local minsize        = metadata.minsize or metadata.design_range_bottom or designsize
        local maxsize        = metadata.maxsize or metadata.design_range_top    or designsize
        local mathspecs      = metadata.math
        --
        if designsize == 0 then
            designsize = 100
            minsize    = 100
            maxsize    = 100
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
                    --
                    local italic   = m.italic
                    --
                    local variants = m.hvariants
                    local parts    = m.hparts
                 -- local done     = { [unicode] = true }
                    if variants then
                        local c = character
                        for i=1,#variants do
                            local un = variants[i]
                         -- if done[un] then
                         --  -- report_otf("skipping cyclic reference %U in math variant %U",un,unicode)
                         -- else
                                c.next = un
                                c = characters[un]
                         --     done[un] = true
                         -- end
                        end -- c is now last in chain
                        c.horiz_variants = parts
                    elseif parts then
                        character.horiz_variants = parts
                        italic = m.hitalic
                    end
                    --
                    local variants = m.vvariants
                    local parts    = m.vparts
                 -- local done     = { [unicode] = true }
                    if variants then
                        local c = character
                        for i=1,#variants do
                            local un = variants[i]
                         -- if done[un] then
                         --  -- report_otf("skipping cyclic reference %U in math variant %U",un,unicode)
                         -- else
                                c.next = un
                                c = characters[un]
                         --     done[un] = true
                         -- end
                        end -- c is now last in chain
                        c.vert_variants = parts
                    elseif parts then
                        character.vert_variants = parts
                        italic = m.vitalic
                    end
                    --
                    if italic and italic ~= 0 then
                        character.italic = italic -- overload
                    end
                    --
                    local accent = m.accent
                    if accent then
                        character.accent = accent
                    end
                    --
                    local kerns = m.kerns
                    if kerns then
                        character.mathkerns = kerns
                    end
                end
            end
        end
        -- end math
        -- we need a runtime lookup because of running from cdrom or zip, brrr (shouldn't we use the basename then?)
        local filename = constructors.checkedfilename(resources)
        local fontname = metadata.fontname
        local fullname = metadata.fullname or fontname
        local psname   = metadata.psname or fontname or fullname
        local units    = metadata.units or metadata.units_per_em or 1000
        --
        if units == 0 then -- catch bugs in fonts
            units = 1000 -- maybe 2000 when ttf
            metadata.units = 1000
            report_otf("changing %a units to %a",0,units)
        end
        --
        local monospaced  = metadata.monospaced or metadata.isfixedpitch or (pfminfo.panose and pfminfo.panose.proportion == "Monospaced")
        local charwidth   = pfminfo.avgwidth -- or unset
        local charxheight = pfminfo.os2_xheight and pfminfo.os2_xheight > 0 and pfminfo.os2_xheight
-- charwidth = charwidth * units/1000
-- charxheight = charxheight * units/1000
        local italicangle = metadata.italicangle
        properties.monospaced  = monospaced
        parameters.italicangle = italicangle
        parameters.charwidth   = charwidth
        parameters.charxheight = charxheight
        --
        local space  = 0x0020
        local emdash = 0x2014
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
        if italicangle and italicangle ~= 0 then
            parameters.italicangle  = italicangle
            parameters.italicfactor = math.cos(math.rad(90+italicangle))
            parameters.slant        = - math.tan(italicangle*math.pi/180)
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
            local x = 0x0078
            if x then
                local x = descriptions[x]
                if x then
                    parameters.x_height = x.height
                end
            end
        end
        --
        parameters.designsize    = (designsize/10)*65536
        parameters.minsize       = (minsize   /10)*65536
        parameters.maxsize       = (maxsize   /10)*65536
        parameters.ascender      = abs(metadata.ascender  or metadata.ascent  or 0)
        parameters.descender     = abs(metadata.descender or metadata.descent or 0)
        parameters.units         = units
        --
        properties.space         = spacer
        properties.encodingbytes = 2
        properties.format        = data.format or otf_format(filename) or formats.otf
        properties.noglyphnames  = true
        properties.filename      = filename
        properties.fontname      = fontname
        properties.fullname      = fullname
        properties.psname        = psname
        properties.name          = filename or fullname
        --
     -- properties.name          = specification.name
     -- properties.sub           = specification.sub
        --
        if warnings and #warnings > 0 then
            report_otf("warnings for font: %s",filename)
            report_otf()
            for i=1,#warnings do
                report_otf("  %s",warnings[i])
            end
            report_otf()
        end
        return {
            characters     = characters,
            descriptions   = descriptions,
            parameters     = parameters,
            mathparameters = mathparameters,
            resources      = resources,
            properties     = properties,
            goodies        = goodies,
            warnings       = warnings,
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
     -- local format   = specification.format
        local features = specification.features.normal
        local rawdata  = otf.load(filename,sub,features and features.featurefile)
        if rawdata and next(rawdata) then
            local descriptions = rawdata.descriptions
            local duplicates = rawdata.resources.duplicates
            if duplicates then
                local nofduplicates, nofduplicated = 0, 0
                for parent, list in next, duplicates do
                    if type(list) == "table" then
                        local n = #list
                        for i=1,n do
                            local unicode = list[i]
                            if not descriptions[unicode] then
                                descriptions[unicode] = descriptions[parent] -- or copy
                                nofduplicated = nofduplicated + 1
                            end
                        end
                        nofduplicates = nofduplicates + n
                    else
                        if not descriptions[list] then
                            descriptions[list] = descriptions[parent] -- or copy
                            nofduplicated = nofduplicated + 1
                        end
                        nofduplicates = nofduplicates + 1
                    end
                end
                if trace_otf and nofduplicated ~= nofduplicates then
                    report_otf("%i extra duplicates copied out of %i",nofduplicated,nofduplicates)
                end
            end
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
             -- shared.features    = features -- default
                shared.dynamics    = { }
             -- shared.processes   = { }
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
        local allfeatures = tfmdata.shared.features or specification.features.normal
        constructors.applymanipulators("otf",tfmdata,allfeatures,trace_features,report_otf)
        constructors.setname(tfmdata,specification) -- only otf?
        fonts.loggers.register(tfmdata,file.suffix(specification.filename),specification)
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
    description  = "apply mathsize specified in the font",
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

-- readers (a bit messy, this forced so I might redo that bit: foo.ttf FOO.ttf foo.TTF FOO.TTF)

local function check_otf(forced,specification,suffix)
    local name = specification.name
    if forced then
        name = specification.forcedname -- messy
    end
    local fullname = findbinfile(name,suffix) or ""
    if fullname == "" then
        fullname = fonts.names.getfilename(name,suffix) or ""
    end
    if fullname ~= "" and not fonts.names.ignoredfile(fullname) then
        specification.filename = fullname
        return read_from_otf(specification)
    end
end

local function opentypereader(specification,suffix)
    local forced = specification.forced or ""
    if formats[forced] then
        return check_otf(true,specification,forced)
    else
        return check_otf(false,specification,suffix)
    end
end

readers.opentype = opentypereader -- kind of useless and obsolete

function readers.otf  (specification) return opentypereader(specification,"otf") end
function readers.ttf  (specification) return opentypereader(specification,"ttf") end
function readers.ttc  (specification) return opentypereader(specification,"ttf") end
function readers.dfont(specification) return opentypereader(specification,"ttf") end

-- this will be overloaded

function otf.scriptandlanguage(tfmdata,attr)
    local properties = tfmdata.properties
    return properties.script or "dflt", properties.language or "dflt"
end

-- a little bit of abstraction

local function justset(coverage,unicode,replacement)
    coverage[unicode] = replacement
end

otf.coverup = {
    stepkey = "subtables",
    actions = {
        substitution = justset,
        alternate    = justset,
        multiple     = justset,
        ligature     = justset,
        kern         = justset,
    },
    register = function(coverage,lookuptype,format,feature,n,descriptions,resources)
        local name = formatters["ctx_%s_%s"](feature,n)
        if lookuptype == "kern" then
            resources.lookuptypes[name] = "position"
        else
            resources.lookuptypes[name] = lookuptype
        end
        for u, c in next, coverage do
            local description = descriptions[u]
            local slookups = description.slookups
            if slookups then
                slookups[name] = c
            else
                description.slookups = { [name] = c }
            end
-- inspect(feature,description)
        end
        return name
    end
}

-- moved from font-oth.lua

local function getgsub(tfmdata,k,kind)
    local description = tfmdata.descriptions[k]
    if description then
        local slookups = description.slookups -- we assume only slookups (we can always extend)
        if slookups then
            local shared = tfmdata.shared
            local rawdata = shared and shared.rawdata
            if rawdata then
                local lookuptypes = rawdata.resources.lookuptypes
                if lookuptypes then
                    local properties = tfmdata.properties
                    -- we could cache these
                    local validlookups, lookuplist = otf.collectlookups(rawdata,kind,properties.script,properties.language)
                    if validlookups then
                        for l=1,#lookuplist do
                            local lookup = lookuplist[l]
                            local found  = slookups[lookup]
                            if found then
                                return found, lookuptypes[lookup]
                            end
                        end
                    end
                end
            end
        end
    end
end

otf.getgsub = getgsub -- returns value, gsub_kind

function otf.getsubstitution(tfmdata,k,kind,value)
    local found, kind = getgsub(tfmdata,k,kind)
    if not found then
        --
    elseif kind == "substitution" then
        return found
    elseif kind == "alternate" then
        local choice = tonumber(value) or 1 -- no random here (yet)
        return found[choice] or found[1] or k
    end
    return k
end

otf.getalternate = otf.getsubstitution

function otf.getmultiple(tfmdata,k,kind)
    local found, kind = getgsub(tfmdata,k,kind)
    if found and kind == "multiple" then
        return found
    end
    return { k }
end

function otf.getkern(tfmdata,left,right,kind)
    local kerns = getgsub(tfmdata,left,kind or "kern",true) -- for now we use getsub
    if kerns then
        local found = kerns[right]
        local kind  = type(found)
        if kind == "table" then
            found = found[1][3] -- can be more clever
        elseif kind ~= "number" then
            found = false
        end
        if found then
            return found * tfmdata.parameters.factor
        end
    end
    return 0
end
