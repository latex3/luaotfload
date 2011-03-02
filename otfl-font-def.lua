if not modules then modules = { } end modules ['font-def'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local concat = table.concat
local format, gmatch, match, find, lower, gsub = string.format, string.gmatch, string.match, string.find, string.lower, string.gsub
local tostring, next = tostring, next
local lpegmatch = lpeg.match

local allocate = utilities.storage.allocate

local trace_defining     = false  trackers  .register("fonts.defining", function(v) trace_defining     = v end)
local directive_embedall = false  directives.register("fonts.embedall", function(v) directive_embedall = v end)

trackers.register("fonts.loading", "fonts.defining", "otf.loading", "afm.loading", "tfm.loading")
trackers.register("fonts.all", "fonts.*", "otf.*", "afm.*", "tfm.*")

local report_defining = logs.reporter("fonts","defining")

--[[ldx--
<p>Here we deal with defining fonts. We do so by intercepting the
default loader that only handles <l n='tfm'/>.</p>
--ldx]]--

local fonts         = fonts
local tfm           = fonts.tfm
local vf            = fonts.vf

fonts.used          = allocate()

tfm.readers         = tfm.readers or { }
tfm.fonts           = allocate()

local readers       = tfm.readers
local sequence      = allocate { 'otf', 'ttf', 'afm', 'tfm', 'lua' }
readers.sequence    = sequence

tfm.version         = 1.01
tfm.cache           = containers.define("fonts", "tfm", tfm.version, false) -- better in font-tfm
tfm.autoprefixedafm = true -- this will become false some day (catches texnansi-blabla.*)

fonts.definers      = fonts.definers or { }
local definers      = fonts.definers

definers.specifiers = definers.specifiers or { }
local specifiers    = definers.specifiers

specifiers.variants = allocate()
local variants      = specifiers.variants

definers.method     = "afm or tfm" -- afm, tfm, afm or tfm, tfm or afm
definers.methods    = definers.methods or { }

local findbinfile   = resolvers.findbinfile

--[[ldx--
<p>We hardly gain anything when we cache the final (pre scaled)
<l n='tfm'/> table. But it can be handy for debugging.</p>
--ldx]]--

fonts.version = 1.05
fonts.cache   = containers.define("fonts", "def", fonts.version, false)

--[[ldx--
<p>We can prefix a font specification by <type>name:</type> or
<type>file:</type>. The first case will result in a lookup in the
synonym table.</p>

<typing>
[ name: | file: ] identifier [ separator [ specification ] ]
</typing>

<p>The following function split the font specification into components
and prepares a table that will move along as we proceed.</p>
--ldx]]--

-- beware, we discard additional specs
--
-- method:name method:name(sub) method:name(sub)*spec method:name*spec
-- name name(sub) name(sub)*spec name*spec
-- name@spec*oeps

local splitter, splitspecifiers = nil, ""

local P, C, S, Cc = lpeg.P, lpeg.C, lpeg.S, lpeg.Cc

local left  = P("(")
local right = P(")")
local colon = P(":")
local space = P(" ")

definers.defaultlookup = "file"

local prefixpattern  = P(false)

local function addspecifier(symbol)
    splitspecifiers     = splitspecifiers .. symbol
    local method        = S(splitspecifiers)
    local lookup        = C(prefixpattern) * colon
    local sub           = left * C(P(1-left-right-method)^1) * right
    local specification = C(method) * C(P(1)^1)
    local name          = C((1-sub-specification)^1)
    splitter = P((lookup + Cc("")) * name * (sub + Cc("")) * (specification + Cc("")))
end

local function addlookup(str,default)
    prefixpattern = prefixpattern + P(str)
end

definers.addlookup = addlookup

addlookup("file")
addlookup("name")
addlookup("spec")

local function getspecification(str)
    return lpegmatch(splitter,str)
end

definers.getspecification = getspecification

function definers.registersplit(symbol,action,verbosename)
    addspecifier(symbol)
    variants[symbol] = action
    if verbosename then
        variants[verbosename] = action
    end
end

function definers.makespecification(specification, lookup, name, sub, method, detail, size)
    size = size or 655360
    if trace_defining then
        report_defining("%s -> lookup: %s, name: %s, sub: %s, method: %s, detail: %s",
            specification, (lookup ~= "" and lookup) or "[file]", (name ~= "" and name) or "-",
            (sub ~= "" and sub) or "-", (method ~= "" and method) or "-", (detail ~= "" and detail) or "-")
    end
    if not lookup or lookup == "" then
        lookup = definers.defaultlookup
    end
    local t = {
        lookup        = lookup,        -- forced type
        specification = specification, -- full specification
        size          = size,          -- size in scaled points or -1000*n
        name          = name,          -- font or filename
        sub           = sub,           -- subfont (eg in ttc)
        method        = method,        -- specification method
        detail        = detail,        -- specification
        resolved      = "",            -- resolved font name
        forced        = "",            -- forced loader
        features      = { },           -- preprocessed features
    }
    return t
end

function definers.analyze(specification, size)
    -- can be optimized with locals
    local lookup, name, sub, method, detail = getspecification(specification or "")
    return definers.makespecification(specification, lookup, name, sub, method, detail, size)
end

--[[ldx--
<p>A unique hash value is generated by:</p>
--ldx]]--

local sortedhashkeys = table.sortedhashkeys

function tfm.hashfeatures(specification)
    local features = specification.features
    if features then
        local t, tn = { }, 0
        local normal = features.normal
        if normal and next(normal) then
            local f = sortedhashkeys(normal)
            for i=1,#f do
                local v = f[i]
                if v ~= "number" and v ~= "features" then -- i need to figure this out, features
                    tn = tn + 1
                    t[tn] = v .. '=' .. tostring(normal[v])
                end
            end
        end
        local vtf = features.vtf
        if vtf and next(vtf) then
            local f = sortedhashkeys(vtf)
            for i=1,#f do
                local v = f[i]
                tn = tn + 1
                t[tn] = v .. '=' .. tostring(vtf[v])
            end
        end
     -- if specification.mathsize then
     --     tn = tn + 1
     --     t[tn] = "mathsize=" .. specification.mathsize
     -- end
        if tn > 0 then
            return concat(t,"+")
        end
    end
    return "unknown"
end

fonts.designsizes = allocate()

--[[ldx--
<p>In principle we can share tfm tables when we are in node for a font, but then
we need to define a font switch as an id/attr switch which is no fun, so in that
case users can best use dynamic features ... so, we will not use that speedup. Okay,
when we get rid of base mode we can optimize even further by sharing, but then we
loose our testcases for <l n='luatex'/>.</p>
--ldx]]--

function tfm.hashinstance(specification,force)
    local hash, size, fallbacks = specification.hash, specification.size, specification.fallbacks
    if force or not hash then
        hash = tfm.hashfeatures(specification)
        specification.hash = hash
    end
    if size < 1000 and fonts.designsizes[hash] then
        size = math.round(tfm.scaled(size,fonts.designsizes[hash]))
        specification.size = size
    end
 -- local mathsize = specification.mathsize or 0
 -- if mathsize > 0 then
 --     local textsize = specification.textsize
 --     if fallbacks then
 --         return hash .. ' @ ' .. tostring(size) .. ' [ ' .. tostring(mathsize) .. ' : ' .. tostring(textsize) .. ' ] @ ' .. fallbacks
 --     else
 --         return hash .. ' @ ' .. tostring(size) .. ' [ ' .. tostring(mathsize) .. ' : ' .. tostring(textsize) .. ' ]'
 --     end
 -- else
        if fallbacks then
            return hash .. ' @ ' .. tostring(size) .. ' @ ' .. fallbacks
        else
            return hash .. ' @ ' .. tostring(size)
        end
 -- end
end

--[[ldx--
<p>We can resolve the filename using the next function:</p>
--ldx]]--

definers.resolvers = definers.resolvers or { }
local resolvers    = definers.resolvers

-- todo: reporter

function resolvers.file(specification)
    local suffix = file.suffix(specification.name)
    if fonts.formats[suffix] then
        specification.forced = suffix
        specification.name = file.removesuffix(specification.name)
    end
end

function resolvers.name(specification)
    local resolve = fonts.names.resolve
    if resolve then
        local resolved, sub = fonts.names.resolve(specification.name,specification.sub)
        specification.resolved, specification.sub = resolved, sub
        if resolved then
            local suffix = file.suffix(resolved)
            if fonts.formats[suffix] then
                specification.forced = suffix
                specification.name = file.removesuffix(resolved)
            else
                specification.name = resolved
            end
        end
    else
        resolvers.file(specification)
    end
end

function resolvers.spec(specification)
    local resolvespec = fonts.names.resolvespec
    if resolvespec then
        specification.resolved, specification.sub = fonts.names.resolvespec(specification.name,specification.sub)
        if specification.resolved then
            specification.forced = file.extname(specification.resolved)
            specification.name = file.removesuffix(specification.resolved)
        end
    else
        resolvers.name(specification)
    end
end

function definers.resolve(specification)
    if not specification.resolved or specification.resolved == "" then -- resolved itself not per se in mapping hash
        local r = resolvers[specification.lookup]
        if r then
            r(specification)
        end
    end
    if specification.forced == "" then
        specification.forced = nil
    else
        specification.forced = specification.forced
    end
    -- for the moment here (goodies set outside features)
    local goodies = specification.goodies
    if goodies and goodies ~= "" then
        local normalgoodies = specification.features.normal.goodies
        if not normalgoodies or normalgoodies == "" then
            specification.features.normal.goodies = goodies
        end
    end
    --
    specification.hash = lower(specification.name .. ' @ ' .. tfm.hashfeatures(specification))
    if specification.sub and specification.sub ~= "" then
        specification.hash = specification.sub .. ' @ ' .. specification.hash
    end
    return specification
end

--[[ldx--
<p>The main read function either uses a forced reader (as determined by
a lookup) or tries to resolve the name using the list of readers.</p>

<p>We need to cache when possible. We do cache raw tfm data (from <l
n='tfm'/>, <l n='afm'/> or <l n='otf'/>). After that we can cache based
on specificstion (name) and size, that is, <l n='tex'/> only needs a number
for an already loaded fonts. However, it may make sense to cache fonts
before they're scaled as well (store <l n='tfm'/>'s with applied methods
and features). However, there may be a relation between the size and
features (esp in virtual fonts) so let's not do that now.</p>

<p>Watch out, here we do load a font, but we don't prepare the
specification yet.</p>
--ldx]]--

function tfm.read(specification)
    local hash = tfm.hashinstance(specification)
    local tfmtable = tfm.fonts[hash] -- hashes by size !
    if not tfmtable then
        local forced = specification.forced or ""
        if forced ~= "" then
            local reader = readers[lower(forced)]
            tfmtable = reader and reader(specification)
            if not tfmtable then
                report_defining("forced type %s of %s not found",forced,specification.name)
            end
        else
            for s=1,#sequence do -- reader sequence
                local reader = sequence[s]
                if readers[reader] then -- not really needed
                    if trace_defining then
                        report_defining("trying (reader sequence driven) type %s for %s with file %s",reader,specification.name,specification.filename or "unknown")
                    end
                    tfmtable = readers[reader](specification)
                    if tfmtable then
                        break
                    else
                        specification.filename = nil
                    end
                end
            end
        end
        if tfmtable then
            if directive_embedall then
                tfmtable.embedding = "full"
            elseif tfmtable.filename and fonts.dontembed[tfmtable.filename] then
                tfmtable.embedding = "no"
            else
                tfmtable.embedding = "subset"
            end
            -- fonts.goodies.postprocessors.apply(tfmdata) -- only here
            local postprocessors = tfmtable.postprocessors
            if postprocessors then
                for i=1,#postprocessors do
                    local extrahash = postprocessors[i](tfmtable) -- after scaling etc
                    if type(extrahash) == "string" and extrahash ~= "" then
                        -- e.g. a reencoding needs this
                        extrahash = gsub(lower(extrahash),"[^a-z]","-")
                        tfmtable.fullname = format("%s-%s",tfmtable.fullname,extrahash)
                    end
                end
            end
            --
            tfm.fonts[hash] = tfmtable
            fonts.designsizes[specification.hash] = tfmtable.designsize -- we only know this for sure after loading once
        --~ tfmtable.mode = specification.features.normal.mode or "base"
        end
    end
    if not tfmtable then
        report_defining("font with asked name '%s' is not found using lookup '%s'",specification.name,specification.lookup)
    end
    return tfmtable
end

--[[ldx--
<p>For virtual fonts we need a slightly different approach:</p>
--ldx]]--

function tfm.readanddefine(name,size) -- no id
    local specification = definers.analyze(name,size)
    local method = specification.method
    if method and variants[method] then
        specification = variants[method](specification)
    end
    specification = definers.resolve(specification)
    local hash = tfm.hashinstance(specification)
    local id = definers.registered(hash)
    if not id then
        local tfmdata = tfm.read(specification)
        if tfmdata then
            tfmdata.hash = hash
            id = font.define(tfmdata)
            definers.register(tfmdata,id)
            tfm.cleanuptable(tfmdata)
        else
            id = 0  -- signal
        end
    end
    return fonts.identifiers[id], id
end

--[[ldx--
<p>We need to check for default features. For this we provide
a helper function.</p>
--ldx]]--

function definers.check(features,defaults) -- nb adapts features !
    local done = false
    if features and next(features) then
        for k,v in next, defaults do
            if features[k] == nil then
                features[k], done = v, true
            end
        end
    else
        features, done = table.fastcopy(defaults), true
    end
    return features, done -- done signals a change
end

--[[ldx--
<p>So far the specifiers. Now comes the real definer. Here we cache
based on id's. Here we also intercept the virtual font handler. Since
it evolved stepwise I may rewrite this bit (combine code).</p>

In the previously defined reader (the one resulting in a <l n='tfm'/>
table) we cached the (scaled) instances. Here we cache them again, but
this time based on id. We could combine this in one cache but this does
not gain much. By the way, passing id's back to in the callback was
introduced later in the development.</p>
--ldx]]--

local lastdefined  = nil -- we don't want this one to end up in s-tra-02
local internalized = { }

function definers.current() -- or maybe current
    return lastdefined
end

function definers.register(tfmdata,id) -- will be overloaded
    if tfmdata and id then
        local hash = tfmdata.hash
        if not internalized[hash] then
            if trace_defining then
                report_defining("registering font, id: %s, hash: %s",id or "?",hash or "?")
            end
            fonts.identifiers[id] = tfmdata
            internalized[hash] = id
        end
    end
end

function definers.registered(hash) -- will be overloaded
    local id = internalized[hash]
    return id, id and fonts.identifiers[id]
end

local cache_them = false

function tfm.make(specification)
    -- currently fonts are scaled while constructing the font, so we
    -- have to do scaling of commands in the vf at that point using
    -- e.g. "local scale = g.factor or 1" after all, we need to work
    -- with copies anyway and scaling needs to be done at some point;
    -- however, when virtual tricks are used as feature (makes more
    -- sense) we scale the commands in fonts.tfm.scale (and set the
    -- factor there)
    local fvm = definers.methods.variants[specification.features.vtf.preset]
    if fvm then
        return fvm(specification)
    else
        return nil
    end
end

function definers.read(specification,size,id) -- id can be optional, name can already be table
    statistics.starttiming(fonts)
    if type(specification) == "string" then
        specification = definers.analyze(specification,size)
    end
    local method = specification.method
    if method and variants[method] then
        specification = variants[method](specification)
    end
    specification = definers.resolve(specification)
    local hash = tfm.hashinstance(specification)
    if cache_them then
        local tfmdata = containers.read(fonts.cache,hash) -- for tracing purposes
    end
    local tfmdata = definers.registered(hash) -- id
    if not tfmdata then
        if specification.features.vtf and specification.features.vtf.preset then
            tfmdata = tfm.make(specification)
        else
            tfmdata = tfm.read(specification)
            if tfmdata then
                tfm.checkvirtualid(tfmdata)
            end
        end
        if cache_them then
            tfmdata = containers.write(fonts.cache,hash,tfmdata) -- for tracing purposes
        end
        if tfmdata then
            tfmdata.hash = hash
            tfmdata.cache = "no"
            if id then
                definers.register(tfmdata,id)
            end
        end
    end
    lastdefined = tfmdata or id -- todo ! ! ! ! !
    if not tfmdata then -- or id?
        report_defining( "unknown font %s, loading aborted",specification.name)
    elseif trace_defining and type(tfmdata) == "table" then
        report_defining("using %s font with id %s, name:%s size:%s bytes:%s encoding:%s fullname:%s filename:%s",
            tfmdata.type          or "unknown",
            id                    or "?",
            tfmdata.name          or "?",
            tfmdata.size          or "default",
            tfmdata.encodingbytes or "?",
            tfmdata.encodingname  or "unicode",
            tfmdata.fullname      or "?",
            file.basename(tfmdata.filename or "?"))
    end
    statistics.stoptiming(fonts)
    return tfmdata
end

function vf.find(name)
    name = file.removesuffix(file.basename(name))
    if tfm.resolvevirtualtoo then
        local format = fonts.logger.format(name)
        if format == 'tfm' or format == 'ofm' then
            if trace_defining then
                report_defining("locating vf for %s",name)
            end
            return findbinfile(name,"ovf")
        else
            if trace_defining then
                report_defining("vf for %s is already taken care of",name)
            end
            return nil -- ""
        end
    else
        if trace_defining then
            report_defining("locating vf for %s",name)
        end
        return findbinfile(name,"ovf")
    end
end

--[[ldx--
<p>We overload both the <l n='tfm'/> and <l n='vf'/> readers.</p>
--ldx]]--

callbacks.register('define_font' , definers.read, "definition of fonts (tfmtable preparation)")
callbacks.register('find_vf_file', vf.find,       "locating virtual fonts, insofar needed") -- not that relevant any more
