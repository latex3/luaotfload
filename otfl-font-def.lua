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
local fontdata      = fonts.hashes.identifiers
local readers       = fonts.readers
local definers      = fonts.definers
local specifiers    = fonts.specifiers
local constructors  = fonts.constructors

readers.sequence    = allocate { 'otf', 'ttf', 'afm', 'tfm', 'lua' } -- dfont ttc

local variants      = allocate()
specifiers.variants = variants

definers.methods    = definers.methods or { }

local internalized  = allocate() -- internal tex numbers (private)


local loadedfonts   = constructors.loadedfonts
local designsizes   = constructors.designsizes

--[[ldx--
<p>We hardly gain anything when we cache the final (pre scaled)
<l n='tfm'/> table. But it can be handy for debugging, so we no
longer carry this code along. Also, we now have quite some reference
to other tables so we would end up with lots of catches.</p>
--ldx]]--

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

function definers.makespecification(specification,lookup,name,sub,method,detail,size)
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
        local resolved, sub = resolve(specification.name,specification.sub,specification) -- we pass specification for overloaded versions
        if resolved then
            specification.resolved = resolved
            specification.sub      = sub
            local suffix = file.suffix(resolved)
            if fonts.formats[suffix] then
                specification.forced = suffix
                specification.name   = file.removesuffix(resolved)
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
        local resolved, sub = resolvespec(specification.name,specification.sub,specification) -- we pass specification for overloaded versions
        if resolved then
            specification.resolved = resolved
            specification.sub      = sub
            specification.forced   = file.extname(resolved)
            specification.name     = file.removesuffix(resolved)
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
        local normal = specification.features.normal
        if not normal then
            specification.features.normal = { goodies = goodies }
        elseif not normal.goodies then
            normal.goodies = goodies
        end
    end
    --
    specification.hash = lower(specification.name .. ' @ ' .. constructors.hashfeatures(specification))
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

-- very experimental:

function definers.applypostprocessors(tfmdata)
    local postprocessors = tfmdata.postprocessors
    if postprocessors then
        for i=1,#postprocessors do
            local extrahash = postprocessors[i](tfmdata) -- after scaling etc
            if type(extrahash) == "string" and extrahash ~= "" then
                -- e.g. a reencoding needs this
                extrahash = gsub(lower(extrahash),"[^a-z]","-")
                tfmdata.properties.fullname = format("%s-%s",tfmdata.properties.fullname,extrahash)
            end
        end
    end
    return tfmdata
end

-- function definers.applypostprocessors(tfmdata)
--     return tfmdata
-- end

function definers.loadfont(specification)
    local hash = constructors.hashinstance(specification)
    local tfmdata = loadedfonts[hash] -- hashes by size !
    if not tfmdata then
        local forced = specification.forced or ""
        if forced ~= "" then
            local reader = readers[lower(forced)]
            tfmdata = reader and reader(specification)
            if not tfmdata then
                report_defining("forced type %s of %s not found",forced,specification.name)
            end
        else
            local sequence = readers.sequence -- can be overloaded so only a shortcut here
            for s=1,#sequence do
                local reader = sequence[s]
                if readers[reader] then -- we skip not loaded readers
                    if trace_defining then
                        report_defining("trying (reader sequence driven) type %s for %s with file %s",reader,specification.name,specification.filename or "unknown")
                    end
                    tfmdata = readers[reader](specification)
                    if tfmdata then
                        break
                    else
                        specification.filename = nil
                    end
                end
            end
        end
        if tfmdata then
            local properties = tfmdata.properties
            local embedding
            if directive_embedall then
                embedding = "full"
            elseif properties and properties.filename and constructors.dontembed[properties.filename] then
                embedding = "no"
            else
                embedding = "subset"
            end
            if properties then
                properties.embedding = embedding
            else
                tfmdata.properties = { embedding = embedding }
            end
            tfmdata = definers.applypostprocessors(tfmdata)
            loadedfonts[hash] = tfmdata
            designsizes[specification.hash] = tfmdata.parameters.designsize
        end
    end
    if not tfmdata then
        report_defining("font with asked name '%s' is not found using lookup '%s'",specification.name,specification.lookup)
    end
    return tfmdata
end

--[[ldx--
<p>For virtual fonts we need a slightly different approach:</p>
--ldx]]--

function constructors.readanddefine(name,size) -- no id -- maybe a dummy first
    local specification = definers.analyze(name,size)
    local method = specification.method
    if method and variants[method] then
        specification = variants[method](specification)
    end
    specification = definers.resolve(specification)
    local hash = constructors.hashinstance(specification)
    local id = definers.registered(hash)
    if not id then
        local tfmdata = definers.loadfont(specification)
        if tfmdata then
            tfmdata.properties.hash = hash
            id = font.define(tfmdata)
            definers.register(tfmdata,id)
        else
            id = 0  -- signal
        end
    end
    return fontdata[id], id
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

function definers.registered(hash)
    local id = internalized[hash]
    return id, id and fontdata[id]
end

function definers.register(tfmdata,id)
    if tfmdata and id then
        local hash = tfmdata.properties.hash
        if not internalized[hash] then
            internalized[hash] = id
            if trace_defining then
                report_defining("registering font, id: %s, hash: %s",id or "?",hash or "?")
            end
            fontdata[id] = tfmdata
        end
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
    local hash = constructors.hashinstance(specification)
    local tfmdata = definers.registered(hash) -- id
    if tfmdata then
        if trace_defining then
            report_defining("already hashed: %s",hash)
        end
    else
        tfmdata = definers.loadfont(specification) -- can be overloaded
        if tfmdata then
            if trace_defining then
                report_defining("loaded and hashed: %s",hash)
            end
        --~ constructors.checkvirtualid(tfmdata) -- interferes
            tfmdata.properties.hash = hash
            if id then
                definers.register(tfmdata,id)
            end
        else
            if trace_defining then
                report_defining("not loaded and hashed: %s",hash)
            end
        end
    end
    lastdefined = tfmdata or id -- todo ! ! ! ! !
    if not tfmdata then -- or id?
        report_defining( "unknown font %s, loading aborted",specification.name)
    elseif trace_defining and type(tfmdata) == "table" then
        local properties = tfmdata.properties or { }
        local parameters = tfmdata.parameters or { }
        report_defining("using %s font with id %s, name:%s size:%s bytes:%s encoding:%s fullname:%s filename:%s",
                       properties.format        or "unknown",
                       id                       or "?",
                       properties.name          or "?",
                       parameters.size          or "default",
                       properties.encodingbytes or "?",
                       properties.encodingname  or "unicode",
                       properties.fullname      or "?",
         file.basename(properties.filename      or "?"))
    end
    statistics.stoptiming(fonts)
    return tfmdata
end

--[[ldx--
<p>We overload the <l n='tfm'/> reader.</p>
--ldx]]--

callbacks.register('define_font', definers.read, "definition of fonts (tfmdata preparation)")
