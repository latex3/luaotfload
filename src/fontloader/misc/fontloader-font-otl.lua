if not modules then modules = { } end modules ['font-otl'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
}

-- After some experimenting with an alternative loader (one that is needed for
-- getting outlines in mp) I decided not to be compatible with the old (built-in)
-- one. The approach used in font-otn is as follows: we load the font in a compact
-- format but still very compatible with the ff data structures. From there we
-- create hashes to access the data efficiently. The implementation of feature
-- processing is mostly based on looking at the data as organized in the glyphs and
-- lookups as well as the specification. Keeping the lookup data in the glyphs is
-- very instructive and handy for tracing. On the other hand hashing is what brings
-- speed. So, the in the new approach (the old one will stay around too) we no
-- longer keep data in the glyphs which saves us a (what in retrospect looks a bit
-- like) a reconstruction step. It also means that the data format of the cached
-- files changes. What method is used depends on that format. There is no fundamental
-- change in processing, and not even in data organation. Most has to do with
-- loading and storage.

-- todo: less tounicodes

local gmatch, find, match, lower, strip = string.gmatch, string.find, string.match, string.lower, string.strip
local type, next, tonumber, tostring, unpack = type, next, tonumber, tostring, unpack
local abs = math.abs
local ioflush = io.flush
local derivetable = table.derive
local formatters = string.formatters

local setmetatableindex  = table.setmetatableindex
local allocate           = utilities.storage.allocate
local registertracker    = trackers.register
local registerdirective  = directives.register
local starttiming        = statistics.starttiming
local stoptiming         = statistics.stoptiming
local elapsedtime        = statistics.elapsedtime
local findbinfile        = resolvers.findbinfile

----- trace_private      = false  registertracker("otf.private",        function(v) trace_private   = v end)
----- trace_subfonts     = false  registertracker("otf.subfonts",       function(v) trace_subfonts  = v end)
local trace_loading      = false  registertracker("otf.loading",        function(v) trace_loading   = v end)
local trace_features     = false  registertracker("otf.features",       function(v) trace_features  = v end)
----- trace_dynamics     = false  registertracker("otf.dynamics",       function(v) trace_dynamics  = v end)
----- trace_sequences    = false  registertracker("otf.sequences",      function(v) trace_sequences = v end)
----- trace_markwidth    = false  registertracker("otf.markwidth",      function(v) trace_markwidth = v end)
local trace_defining     = false  registertracker("fonts.defining",     function(v) trace_defining  = v end)

local report_otf         = logs.reporter("fonts","otf loading")

local fonts              = fonts
local otf                = fonts.handlers.otf

otf.version              = 3.022 -- beware: also sync font-mis.lua and in mtx-fonts
otf.cache                = containers.define("fonts", "otl", otf.version, true)
otf.svgcache             = containers.define("fonts", "svg", otf.version, true)
otf.pdfcache             = containers.define("fonts", "pdf", otf.version, true)

otf.svgenabled           = false

local otfreaders         = otf.readers

local hashes             = fonts.hashes
local definers           = fonts.definers
local readers            = fonts.readers
local constructors       = fonts.constructors

local otffeatures        = constructors.features.otf
local registerotffeature = otffeatures.register

local enhancers          = allocate()
otf.enhancers            = enhancers
local patches            = { }
enhancers.patches        = patches

local forceload          = false
local cleanup            = 0     -- mk: 0=885M 1=765M 2=735M (regular run 730M)
local syncspace          = true
local forcenotdef        = false

local applyruntimefixes  = fonts.treatments and fonts.treatments.applyfixes

local wildcard           = "*"
local default            = "dflt"

local formats            = fonts.formats

formats.otf              = "opentype"
formats.ttf              = "truetype"
formats.ttc              = "truetype"

registerdirective("fonts.otf.loader.cleanup",       function(v) cleanup       = tonumber(v) or (v and 1) or 0 end)
registerdirective("fonts.otf.loader.force",         function(v) forceload     = v end)
registerdirective("fonts.otf.loader.syncspace",     function(v) syncspace     = v end)
registerdirective("fonts.otf.loader.forcenotdef",   function(v) forcenotdef   = v end)

-- local function load_featurefile(raw,featurefile)
--     if featurefile and featurefile ~= "" then
--         if trace_loading then
--             report_otf("using featurefile %a", featurefile)
--         end
--         -- TODO: apply_featurefile(raw, featurefile)
--     end
-- end

-- Enhancers are used to apply fixes and extensions to fonts. For instance, we use them
-- to implement tlig and trep features. They are not neccessarily bound to opentype
-- fonts but can also apply to type one fonts, given that they obey the structure of an
-- opentype font. They are not to be confused with format specific features but maybe
-- some are so generic that they might eventually move to this mechanism.

local ordered_enhancers = {
    "check extra features",
}

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
    --
    local featurefile = nil -- not supported (yet)
    --
    local base = file.basename(file.removesuffix(filename))
    local name = file.removesuffix(base)
    local attr = lfs.attributes(filename)
    local size = attr and attr.size or 0
    local time = attr and attr.modification or 0
    if featurefile then
        name = name .. "@" .. file.removesuffix(file.basename(featurefile))
    end
    -- sub can be number of string
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
    local reload = not data or data.size ~= size or data.time ~= time or data.tableversion ~= otfreaders.tableversion
    if forceload then
        report_otf("forced reload of %a due to hard coded flag",filename)
        reload = true
    end
 -- if not reload then
 --     local featuredata = data.featuredata
 --     if featurefiles then
 --         if not featuredata or #featuredata ~= #featurefiles then
 --             reload = true
 --         else
 --             for i=1,#featurefiles do
 --                 local fi, fd = featurefiles[i], featuredata[i]
 --                 if fi.name ~= fd.name or fi.size ~= fd.size or fi.time ~= fd.time then
 --                     reload = true
 --                     break
 --                 end
 --             end
 --         end
 --     elseif featuredata then
 --         reload = true
 --     end
 --     if reload then
 --        report_otf("loading: forced reload due to changed featurefile specification %a",featurefile)
 --     end
 --  end
     if reload then
        report_otf("loading %a, hash %a",filename,hash)
        --
        starttiming(otfreaders)
        data = otfreaders.loadfont(filename,sub or 1) -- we can pass the number instead (if it comes from a name search)
        --
        -- if featurefiles then
        --     for i=1,#featurefiles do
        --         load_featurefile(data,featurefiles[i].name)
        --     end
        -- end
        --
        --
        if data then
            --
            local resources = data.resources
            local svgshapes = resources.svgshapes
            if svgshapes then
                resources.svgshapes = nil
                if otf.svgenabled then
                    local timestamp = os.date()
                    -- work in progress ... a bit boring to do
                    containers.write(otf.svgcache,hash, {
                        svgshapes = svgshapes,
                        timestamp = timestamp,
                    })
                    data.properties.svg = {
                        hash      = hash,
                        timestamp = timestamp,
                    }
                end
            end
            --
            otfreaders.compact(data)
            otfreaders.rehash(data,"unicodes")
            otfreaders.addunicodetable(data)
            otfreaders.extend(data)
            otfreaders.pack(data)
            report_otf("loading done")
            report_otf("saving %a in cache",filename)
            data = containers.write(otf.cache, hash, data)
            if cleanup > 1 then
                collectgarbage("collect")
            end
            stoptiming(otfreaders)
            if elapsedtime then -- not in generic
                report_otf("loading, optimizing, packing and caching time %s", elapsedtime(otfreaders))
            end
            if cleanup > 3 then
                collectgarbage("collect")
            end
            data = containers.read(otf.cache,hash) -- this frees the old table and load the sparse one
            if cleanup > 2 then
                collectgarbage("collect")
            end
        else
            data = nil
            report_otf("loading failed due to read error")
        end
    end
    if data then
        if trace_defining then
            report_otf("loading from cache using hash %a",hash)
        end
        --
        otfreaders.unpack(data)
        otfreaders.expand(data) -- inline tables
        otfreaders.addunicodetable(data) -- only when not done yet
        --
        enhancers.apply(data,filename,data)
        --
     -- constructors.addcoreunicodes(data.resources.unicodes) -- still needed ?
        --
        if applyruntimefixes then
            applyruntimefixes(filename,data)
        end
        --
        data.metadata.math = data.resources.mathconstants
    end


    return data
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
-- we already assign an empty table to characters as we can add for
-- instance protruding info and loop over characters; one is not supposed
-- to change descriptions and if one does so one should make a copy!

local function copytotfm(data,cache_id)
    if data then
        local metadata       = data.metadata
        local properties     = derivetable(data.properties)
        local descriptions   = derivetable(data.descriptions)
        local goodies        = derivetable(data.goodies)
        local characters     = { }
        local parameters     = { }
        local mathparameters = { }
        --
        local resources      = data.resources
        local unicodes       = resources.unicodes
        local spaceunits     = 500
        local spacer         = "space"
        local designsize     = metadata.designsize or 100
        local minsize        = metadata.minsize or designsize
        local maxsize        = metadata.maxsize or designsize
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
        for unicode in next, data.descriptions do -- use parent table
            characters[unicode] = { }
        end
        if mathspecs then
            for unicode, character in next, characters do
                local d = descriptions[unicode]
                local m = d.math
                if m then
                    -- watch out: luatex uses horiz_variants for the parts
                    --
                    local italic   = m.italic
                    local vitalic  = m.vitalic
                    --
                    local variants = m.hvariants
                    local parts    = m.hparts
                    if variants then
                        local c = character
                        for i=1,#variants do
                         -- local un = variants[i].glyph
                            local un = variants[i]
                            c.next = un
                            c = characters[un]
                        end -- c is now last in chain
                        c.horiz_variants = parts
                    elseif parts then
                        character.horiz_variants = parts
                        italic = m.hitalic
                    end
                    --
                    local variants = m.vvariants
                    local parts    = m.vparts
                    if variants then
                        local c = character
                        for i=1,#variants do
                         -- local un = variants[i].glyph
                            local un = variants[i]
                            c.next = un
                            c = characters[un]
                        end -- c is now last in chain
                        c.vert_variants = parts
                    elseif parts then
                        character.vert_variants = parts
                    end
                    --
                    if italic and italic ~= 0 then
                        character.italic = italic
                    end
                    --
                    if vitalic and vitalic ~= 0 then
                        character.vert_italic = vitalic
                    end
                    --
                    local accent = m.accent -- taccent?
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
        -- we need a runtime lookup because of running from cdrom or zip, brrr (shouldn't
        -- we use the basename then?)
        local filename = constructors.checkedfilename(resources)
        local fontname = metadata.fontname
        local fullname = metadata.fullname or fontname
        local psname   = fontname or fullname
        local units    = metadata.units or 1000
        --
        if units == 0 then -- catch bugs in fonts
            units = 1000 -- maybe 2000 when ttf
            metadata.units = 1000
            report_otf("changing %a units to %a",0,units)
        end
        --
        local monospaced  = metadata.monospaced
        local charwidth   = metadata.averagewidth -- or unset
        local charxheight = metadata.xheight -- or unset
        local italicangle = metadata.italicangle
        local hasitalics  = metadata.hasitalics
        properties.monospaced  = monospaced
        properties.hasitalics  = hasitalics
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
        parameters.space_stretch = 1*units/2   --  500   -- 1.666 (cmr10)
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
        parameters.ascender      = abs(metadata.ascender  or 0)
        parameters.descender     = abs(metadata.descender or 0)
        parameters.units         = units
        --
        properties.space         = spacer
        properties.encodingbytes = 2
        properties.format        = data.format or formats.otf
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
        local subindex = specification.subindex
        local filename = specification.filename
        local features = specification.features.normal
        local rawdata  = otf.load(filename,sub,features and features.featurefile)
        if rawdata and next(rawdata) then
            local descriptions = rawdata.descriptions
            rawdata.lookuphash = { } -- to be done
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

-- readers

function otf.collectlookups(rawdata,kind,script,language)
    if not kind then
        return
    end
    if not script then
        script = default
    end
    if not language then
        language = default
    end
    local lookupcache = rawdata.lookupcache
    if not lookupcache then
        lookupcache = { }
        rawdata.lookupcache = lookupcache
    end
    local kindlookup = lookupcache[kind]
    if not kindlookup then
        kindlookup = { }
        lookupcache[kind] = kindlookup
    end
    local scriptlookup = kindlookup[script]
    if not scriptlookup then
        scriptlookup = { }
        kindlookup[script] = scriptlookup
    end
    local languagelookup = scriptlookup[language]
    if not languagelookup then
        local sequences   = rawdata.resources.sequences
        local featuremap  = { }
        local featurelist = { }
        if sequences then
            for s=1,#sequences do
                local sequence = sequences[s]
                local features = sequence.features
                if features then
                    features = features[kind]
                    if features then
                     -- features = features[script] or features[default] or features[wildcard]
                        features = features[script] or features[wildcard]
                        if features then
                         -- features = features[language] or features[default] or features[wildcard]
                            features = features[language] or features[wildcard]
                            if features then
                                if not featuremap[sequence] then
                                    featuremap[sequence] = true
                                    featurelist[#featurelist+1] = sequence
                                end
                            end
                        end
                    end
                end
            end
            if #featurelist == 0 then
                featuremap, featurelist = false, false
            end
        else
            featuremap, featurelist = false, false
        end
        languagelookup = { featuremap, featurelist }
        scriptlookup[language] = languagelookup
    end
    return unpack(languagelookup)
end

-- moved from font-oth.lua, todo: also afm

local function getgsub(tfmdata,k,kind,value)
    local shared  = tfmdata.shared
    local rawdata = shared and shared.rawdata
    if rawdata then
        local sequences = rawdata.resources.sequences
        if sequences then
            local properties = tfmdata.properties
            local validlookups, lookuplist = otf.collectlookups(rawdata,kind,properties.script,properties.language)
            if validlookups then
                local choice = tonumber(value) or 1 -- no random here (yet)
                for i=1,#lookuplist do
                    local lookup   = lookuplist[i]
                    local steps    = lookup.steps
                    local nofsteps = lookup.nofsteps
                    for i=1,nofsteps do
                        local coverage = steps[i].coverage
                        if coverage then
                            local found = coverage[k]
                            if found then
                                return found, lookup.type
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
    elseif kind == "gsub_single" then
        return found
    elseif kind == "gsub_alternate" then
        local choice = tonumber(value) or 1 -- no random here (yet)
        return found[choice] or found[1] or k
    end
    return k
end

otf.getalternate = otf.getsubstitution

function otf.getmultiple(tfmdata,k,kind)
    local found, kind = getgsub(tfmdata,k,kind)
    if found and kind == "gsub_multiple" then
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
    stepkey = "steps",
    actions = {
        chainsubstitution = justset,
        chainposition     = justset,
        substitution      = justset,
        alternate         = justset,
        multiple          = justset,
        kern              = justset,
        pair              = justset,
        ligature          = function(coverage,unicode,ligature)
            local first = ligature[1]
            local tree  = coverage[first]
            if not tree then
                tree = { }
                coverage[first] = tree
            end
            for i=2,#ligature do
                local l = ligature[i]
                local t = tree[l]
                if not t then
                    t = { }
                    tree[l] = t
                end
                tree = t
            end
            tree.ligature = unicode
        end,
    },
    register = function(coverage,featuretype,format)
        return {
            format   = format,
            coverage = coverage,
        }
    end
}
