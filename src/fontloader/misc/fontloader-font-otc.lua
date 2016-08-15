if not modules then modules = { } end modules ['font-otc'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (context)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, insert, sortedkeys, tohash = string.format, table.insert, table.sortedkeys, table.tohash
local type, next = type, next
local lpegmatch = lpeg.match
local utfbyte, utflen = utf.byte, utf.len

-- we assume that the other otf stuff is loaded already

local trace_loading       = false  trackers.register("otf.loading", function(v) trace_loading = v end)
local report_otf          = logs.reporter("fonts","otf loading")

local fonts               = fonts
local otf                 = fonts.handlers.otf
local registerotffeature  = otf.features.register
local setmetatableindex   = table.setmetatableindex

local normalized = {
    substitution      = "substitution",
    single            = "substitution",
    ligature          = "ligature",
    alternate         = "alternate",
    multiple          = "multiple",
    kern              = "kern",
    pair              = "pair",
    chainsubstitution = "chainsubstitution",
    chainposition     = "chainposition",
}

local types = {
    substitution      = "gsub_single",
    ligature          = "gsub_ligature",
    alternate         = "gsub_alternate",
    multiple          = "gsub_multiple",
    kern              = "gpos_pair",
    pair              = "gpos_pair",
    chainsubstitution = "gsub_contextchain",
    chainposition     = "gpos_contextchain",
}

local names = {
    gsub_single              = "gsub",
    gsub_multiple            = "gsub",
    gsub_alternate           = "gsub",
    gsub_ligature            = "gsub",
    gsub_context             = "gsub",
    gsub_contextchain        = "gsub",
    gsub_reversecontextchain = "gsub",
    gpos_single              = "gpos",
    gpos_pair                = "gpos",
    gpos_cursive             = "gpos",
    gpos_mark2base           = "gpos",
    gpos_mark2ligature       = "gpos",
    gpos_mark2mark           = "gpos",
    gpos_context             = "gpos",
    gpos_contextchain        = "gpos",
}

setmetatableindex(types, function(t,k) t[k] = k return k end) -- "key"

local everywhere = { ["*"] = { ["*"] = true } } -- or: { ["*"] = { "*" } }
local noflags    = { false, false, false, false }

-- beware: shared, maybe we should copy the sequence

local function getrange(sequences,category)
    local count = #sequences
    local first = nil
    local last  = nil
    for i=1,count do
        local t = sequences[i].type
        if t and names[t] == category then
            if not first then
                first = i
            end
            last  = i
        end
    end
    return first or 1, last or count
end

local function validspecification(specification,name)
    local dataset = specification.dataset
    if dataset then
        -- okay
    elseif specification[1] then
        dataset = specification
        specification = { dataset = dataset }
    else
        dataset = { { data = specification.data } }
        specification.data    = nil
        specification.dataset = dataset
    end
    local first = dataset[1]
    if first then
        first = first.data
    end
    if not first then
        report_otf("invalid feature specification, no dataset")
        return
    end
    if type(name) ~= "string" then
        name = specification.name or first.name
    end
    if type(name) ~= "string" then
        report_otf("invalid feature specification, no name")
        return
    end
    local n = #dataset
    if n > 0 then
        for i=1,n do
            setmetatableindex(dataset[i],specification)
        end
        return specification, name
    end
end

local function addfeature(data,feature,specifications)

    -- todo: add some validator / check code so that we're more tolerant to
    -- user errors

    if not specifications then
        report_otf("missing specification")
        return
    end

    local descriptions = data.descriptions
    local resources    = data.resources
    local features     = resources.features
    local sequences    = resources.sequences

    if not features or not sequences then
        report_otf("missing specification")
        return
    end

    local alreadydone = resources.alreadydone
    if not alreadydone then
        alreadydone = { }
        resources.alreadydone = alreadydone
    end
    if alreadydone[specifications] then
        return
    else
        alreadydone[specifications] = true
    end

    -- feature has to be unique but the name entry wins eventually

    local fontfeatures = resources.features or everywhere
    local unicodes     = resources.unicodes
    local splitter     = lpeg.splitter(" ",unicodes)
    local done         = 0
    local skip         = 0
    local aglunicodes  = false

    local specifications = validspecification(specifications,feature)
    if not specifications then
     -- report_otf("invalid specification")
        return
    end

    local function tounicode(code)
        if not code then
            return
        end
        if type(code) == "number" then
            return code
        end
        local u = unicodes[code]
        if u then
            return u
        end
        if utflen(code) == 1 then
            u = utfbyte(code)
            if u then
                return u
            end
        end
        if not aglunicodes then
            aglunicodes = fonts.encodings.agl.unicodes -- delayed
        end
        return aglunicodes[code]
    end

    local coverup      = otf.coverup
    local coveractions = coverup.actions
    local stepkey      = coverup.stepkey
    local register     = coverup.register

    local function prepare_substitution(list,featuretype)
        local coverage = { }
        local cover    = coveractions[featuretype]
        for code, replacement in next, list do
            local unicode     = tounicode(code)
            local description = descriptions[unicode]
            if description then
                if type(replacement) == "table" then
                    replacement = replacement[1]
                end
                replacement = tounicode(replacement)
                if replacement and descriptions[replacement] then
                    cover(coverage,unicode,replacement)
                    done = done + 1
                else
                    skip = skip + 1
                end
            else
                skip = skip + 1
            end
        end
        return coverage
    end

    local function prepare_alternate(list,featuretype)
        local coverage = { }
        local cover    = coveractions[featuretype]
        for code, replacement in next, list do
            local unicode     = tounicode(code)
            local description = descriptions[unicode]
            if not description then
                skip = skip + 1
            elseif type(replacement) == "table" then
                local r = { }
                for i=1,#replacement do
                    local u = tounicode(replacement[i])
                    r[i] = descriptions[u] and u or unicode
                end
                cover(coverage,unicode,r)
                done = done + 1
            else
                local u = tounicode(replacement)
                if u then
                    cover(coverage,unicode,{ u })
                    done = done + 1
                else
                    skip = skip + 1
                end
            end
        end
        return coverage
    end

    local function prepare_multiple(list,featuretype)
        local coverage = { }
        local cover    = coveractions[featuretype]
        for code, replacement in next, list do
            local unicode     = tounicode(code)
            local description = descriptions[unicode]
            if not description then
                skip = skip + 1
            elseif type(replacement) == "table" then
                local r, n = { }, 0
                for i=1,#replacement do
                    local u = tounicode(replacement[i])
                    if descriptions[u] then
                        n = n + 1
                        r[n] = u
                    end
                end
                if n > 0 then
                    cover(coverage,unicode,r)
                    done = done + 1
                else
                    skip = skip + 1
                end
            else
                local u = tounicode(replacement)
                if u then
                    cover(coverage,unicode,{ u })
                    done = done + 1
                else
                    skip = skip + 1
                end
            end
        end
        return coverage
    end

    local function prepare_ligature(list,featuretype)
        local coverage = { }
        local cover    = coveractions[featuretype]
        for code, ligature in next, list do
            local unicode     = tounicode(code)
            local description = descriptions[unicode]
            if description then
                if type(ligature) == "string" then
                    ligature = { lpegmatch(splitter,ligature) }
                end
                local present = true
                for i=1,#ligature do
                    local l = ligature[i]
                    local u = tounicode(l)
                    if descriptions[u] then
                        ligature[i] = u
                    else
                        present = false
                        break
                    end
                end
                if present then
                    cover(coverage,unicode,ligature)
                    done = done + 1
                else
                    skip = skip + 1
                end
            else
                skip = skip + 1
            end
        end
        return coverage
    end

    local function prepare_kern(list,featuretype)
        local coverage = { }
        local cover    = coveractions[featuretype]
        for code, replacement in next, list do
            local unicode     = tounicode(code)
            local description = descriptions[unicode]
            if description and type(replacement) == "table" then
                local r = { }
                for k, v in next, replacement do
                    local u = tounicode(k)
                    if u then
                        r[u] = v
                    end
                end
                if next(r) then
                    cover(coverage,unicode,r)
                    done = done + 1
                else
                    skip = skip + 1
                end
            else
                skip = skip + 1
            end
        end
        return coverage
    end

    local function prepare_pair(list,featuretype)
        local coverage = { }
        local cover    = coveractions[featuretype]
        if cover then
            for code, replacement in next, list do
                local unicode     = tounicode(code)
                local description = descriptions[unicode]
                if description and type(replacement) == "table" then
                    local r = { }
                    for k, v in next, replacement do
                        local u = tounicode(k)
                        if u then
                            r[u] = v
                        end
                    end
                    if next(r) then
                        cover(coverage,unicode,r)
                        done = done + 1
                    else
                        skip = skip + 1
                    end
                else
                    skip = skip + 1
                end
            end
        else
            report_otf("unknown cover type %a",featuretype)
        end
        return coverage
    end

    local function prepare_chain(list,featuretype,sublookups)
        -- todo: coveractions
        local rules    = list.rules
        local coverage = { }
        if rules then
            local rulehash     = { }
            local rulesize     = 0
            local sequence     = { }
            local nofsequences = 0
            local lookuptype   = types[featuretype]
            for nofrules=1,#rules do
                local rule         = rules[nofrules]
                local current      = rule.current
                local before       = rule.before
                local after        = rule.after
                local replacements = rule.replacements or false
                local sequence     = { }
                local nofsequences = 0
                if before then
                    for n=1,#before do
                        nofsequences = nofsequences + 1
                        sequence[nofsequences] = before[n]
                    end
                end
                local start = nofsequences + 1
                for n=1,#current do
                    nofsequences = nofsequences + 1
                    sequence[nofsequences] = current[n]
                end
                local stop = nofsequences
                if after then
                    for n=1,#after do
                        nofsequences = nofsequences + 1
                        sequence[nofsequences] = after[n]
                    end
                end
                local lookups = rule.lookups or false
                local subtype = nil
                if lookups and sublookups then
                    for k, v in next, lookups do
                        local lookup = sublookups[v]
                        if lookup then
                            lookups[k] = lookup
                            if not subtype then
                                subtype = lookup.type
                            end
                        else
                            -- already expanded
                        end
                    end
                end
                if nofsequences > 0 then -- we merge coverage into one
                    -- we copy as we can have different fonts
                    local hashed = { }
                    for i=1,nofsequences do
                        local t = { }
                        local s = sequence[i]
                        for i=1,#s do
                            local u = tounicode(s[i])
                            if u then
                                t[u] = true
                            end
                        end
                        hashed[i] = t
                    end
                    sequence = hashed
                    -- now we create the rule
                    rulesize = rulesize + 1
                    rulehash[rulesize] = {
                        nofrules,     -- 1
                        lookuptype,   -- 2
                        sequence,     -- 3
                        start,        -- 4
                        stop,         -- 5
                        lookups,      -- 6 (6/7 also signal of what to do)
                        replacements, -- 7
                        subtype,      -- 8
                    }
                    for unic in next, sequence[start] do
                        local cu = coverage[unic]
                        if not cu then
                            coverage[unic] = rulehash -- can now be done cleaner i think
                        end
                    end
                end
            end
        end
        return coverage
    end

    local dataset = specifications.dataset

    local function report(name,category,position,first,last,sequences)
        report_otf("injecting name %a of category %a at position %i in [%i,%i] of [%i,%i]",
            name,category,position,first,last,1,#sequences)
    end

    local function inject(specification,sequences,sequence,first,last,category,name)
        local position = specification.position or false
        if not position then
            position = specification.prepend
            if position == true then
                if trace_loading then
                    report(name,category,first,first,last,sequences)
                end
                insert(sequences,first,sequence)
                return
            end
        end
        if not position then
            position = specification.append
            if position == true then
                if trace_loading then
                    report(name,category,last+1,first,last,sequences)
                end
                insert(sequences,last+1,sequence)
                return
            end
        end
        local kind = type(position)
        if kind == "string" then
            local index = false
            for i=first,last do
                local s = sequences[i]
                local f = s.features
                if f then
                    for k in next, f do
                        if k == position then
                            index = i
                            break
                        end
                    end
                    if index then
                        break
                    end
                end
            end
            if index then
                position = index
            else
                position = last + 1
            end
        elseif kind == "number" then
            if position < 0 then
                position = last - position + 1
            end
            if position > last then
                position = last + 1
            elseif position < first then
                position = first
            end
        else
            position = last + 1
        end
        if trace_loading then
            report(name,category,position,first,last,sequences)
        end
        insert(sequences,position,sequence)
    end

    for s=1,#dataset do
        local specification = dataset[s]
        local valid = specification.valid -- nowhere used
        local feature = specification.name or feature
        if not feature or feature == "" then
            report_otf("no valid name given for extra feature")
        elseif not valid or valid(data,specification,feature) then -- anum uses this
            local initialize = specification.initialize
            if initialize then
                -- when false is returned we initialize only once
                specification.initialize = initialize(specification,data) and initialize or nil
            end
            local askedfeatures = specification.features or everywhere
            local askedsteps    = specification.steps or specification.subtables or { specification.data } or { }
            local featuretype   = normalized[specification.type or "substitution"] or "substitution"
            local featureflags  = specification.flags or noflags
            local featureorder  = specification.order or { feature }
            local featurechain  = (featuretype == "chainsubstitution" or featuretype == "chainposition") and 1 or 0
            local nofsteps      = 0
            local steps         = { }
            local sublookups    = specification.lookups
            local category      = nil
            if sublookups then
                local s = { }
                for i=1,#sublookups do
                    local specification = sublookups[i]
                    local askedsteps    = specification.steps or specification.subtables or { specification.data } or { }
                    local featuretype   = normalized[specification.type or "substitution"] or "substitution"
                    local featureflags  = specification.flags or noflags
                    local nofsteps      = 0
                    local steps         = { }
                    for i=1,#askedsteps do
                        local list     = askedsteps[i]
                        local coverage = nil
                        local format   = nil
                        if featuretype == "substitution" then
                            coverage = prepare_substitution(list,featuretype)
                        elseif featuretype == "ligature" then
                            coverage = prepare_ligature(list,featuretype)
                        elseif featuretype == "alternate" then
                            coverage = prepare_alternate(list,featuretype)
                        elseif featuretype == "multiple" then
                            coverage = prepare_multiple(list,featuretype)
                        elseif featuretype == "kern" then
                            format   = "kern"
                            coverage = prepare_kern(list,featuretype)
                        elseif featuretype == "pair" then
                            format   = "pair"
                            coverage = prepare_pair(list,featuretype)
                        end
                        if coverage and next(coverage) then
                            nofsteps = nofsteps + 1
                            steps[nofsteps] = register(coverage,featuretype,format,feature,nofsteps,descriptions,resources)
                        end
                    end
                    s[i] = {
                        [stepkey] = steps,
                        nofsteps  = nofsteps,
                        type      = types[featuretype],
                    }
                end
                sublookups = s
            end
            for i=1,#askedsteps do
                local list     = askedsteps[i]
                local coverage = nil
                local format   = nil
                if featuretype == "substitution" then
                    category = "gsub"
                    coverage = prepare_substitution(list,featuretype)
                elseif featuretype == "ligature" then
                    category = "gsub"
                    coverage = prepare_ligature(list,featuretype)
                elseif featuretype == "alternate" then
                    category = "gsub"
                    coverage = prepare_alternate(list,featuretype)
                elseif featuretype == "multiple" then
                    category = "gsub"
                    coverage = prepare_multiple(list,featuretype)
                elseif featuretype == "kern" then
                    category = "gpos"
                    format   = "kern"
                    coverage = prepare_kern(list,featuretype)
                elseif featuretype == "pair" then
                    category = "gpos"
                    format   = "pair"
                    coverage = prepare_pair(list,featuretype)
                elseif featuretype == "chainsubstitution" then
                    category = "gsub"
                    coverage = prepare_chain(list,featuretype,sublookups)
                elseif featuretype == "chainposition" then
                    category = "gpos"
                    coverage = prepare_chain(list,featuretype,sublookups)
                else
                    report_otf("not registering feature %a, unknown category",feature)
                    return
                end
                if coverage and next(coverage) then
                    nofsteps = nofsteps + 1
                    steps[nofsteps] = register(coverage,featuretype,format,feature,nofsteps,descriptions,resources)
                end
            end
            if nofsteps > 0 then
                -- script = { lang1, lang2, lang3 } or script = { lang1 = true, ... }
                for k, v in next, askedfeatures do
                    if v[1] then
                        askedfeatures[k] = tohash(v)
                    end
                end
                if featureflags[1] then featureflags[1] = "mark" end
                if featureflags[2] then featureflags[2] = "ligature" end
                if featureflags[3] then featureflags[3] = "base" end
                local steptype = types[featuretype]
                local sequence = {
                    chain     = featurechain,
                    features  = { [feature] = askedfeatures },
                    flags     = featureflags,
                    name      = feature, -- redundant
                    order     = featureorder,
                    [stepkey] = steps,
                    nofsteps  = nofsteps,
                    type      = steptype,
                }
                -- position | prepend | append
                local first, last = getrange(sequences,category)
                inject(specification,sequences,sequence,first,last,category,feature)
                -- register in metadata (merge as there can be a few)
                local features = fontfeatures[category]
                if not features then
                    features  = { }
                    fontfeatures[category] = features
                end
                local k = features[feature]
                if not k then
                    k = { }
                    features[feature] = k
                end
                --
                for script, languages in next, askedfeatures do
                    local kk = k[script]
                    if not kk then
                        kk = { }
                        k[script] = kk
                    end
                    for language, value in next, languages do
                        kk[language] = value
                    end
                end
            end
        end
    end
    if trace_loading then
        report_otf("registering feature %a, affected glyphs %a, skipped glyphs %a",feature,done,skip)
    end
end

otf.enhancers.addfeature = addfeature

local extrafeatures = { }
local knownfeatures = { }

function otf.addfeature(name,specification)
    if type(name) == "table" then
        specification = name
    end
    if type(specification) ~= "table" then
        report_otf("invalid feature specification, no valid table")
        return
    end
    specification, name = validspecification(specification,name)
    if name and specification then
        local slot = knownfeatures[name]
        if slot then
            -- we overload one .. should be option
        else
            slot = #extrafeatures + 1
            knownfeatures[name] = slot
        end
        specification.name  = name -- to be sure
        extrafeatures[slot] = specification
     -- report_otf("adding feature %a @ %i",name,slot)
    end
end

-- for feature, specification in next, extrafeatures do
--     addfeature(data,feature,specification)
-- end

local function enhance(data,filename,raw)
    for slot=1,#extrafeatures do
        local specification = extrafeatures[slot]
        addfeature(data,specification.name,specification)
    end
end

otf.enhancers.enhance = enhance

otf.enhancers.register("check extra features",enhance)

-- tlig --

local tlig = { -- we need numbers for some fonts so ...
 -- endash        = "hyphen hyphen",
 -- emdash        = "hyphen hyphen hyphen",
    [0x2013]      = { 0x002D, 0x002D },
    [0x2014]      = { 0x002D, 0x002D, 0x002D },
 -- quotedblleft  = "quoteleft quoteleft",
 -- quotedblright = "quoteright quoteright",
 -- quotedblleft  = "grave grave",
 -- quotedblright = "quotesingle quotesingle",
 -- quotedblbase  = "comma comma",
}

local tlig_specification = {
    type     = "ligature",
    features = everywhere,
    data     = tlig,
    order    = { "tlig" },
    flags    = noflags,
    prepend  = true,
}

otf.addfeature("tlig",tlig_specification)

registerotffeature {
    -- this makes it a known feature (in tables)
    name        = 'tlig',
    description = 'tex ligatures',
}

-- trep

local trep = {
 -- [0x0022] = 0x201D,
    [0x0027] = 0x2019,
 -- [0x0060] = 0x2018,
}

local trep_specification = {
    type      = "substitution",
    features  = everywhere,
    data      = trep,
    order     = { "trep" },
    flags     = noflags,
    prepend   = true,
}

otf.addfeature("trep",trep_specification)

registerotffeature {
    -- this makes it a known feature (in tables)
    name        = 'trep',
    description = 'tex replacements',
}

-- -- tcom (obsolete, was already not set for a while)

-- if characters.combined then
--
--     local tcom = { }
--
--     local function initialize()
--         characters.initialize()
--         for first, seconds in next, characters.combined do
--             for second, combination in next, seconds do
--                 tcom[combination] = { first, second }
--             end
--         end
--         -- return false
--     end
--
--     local tcom_specification = {
--         type       = "ligature",
--         features   = everywhere,
--         data       = tcom,
--         order      = { "tcom" },
--         flags      = noflags,
--         initialize = initialize,
--     }
--
--     otf.addfeature("tcom",tcom_specification)
--
--     registerotffeature {
--         name        = 'tcom',
--         description = 'tex combinations',
--     }
--
-- end

-- anum

local anum_arabic = {
    [0x0030] = 0x0660,
    [0x0031] = 0x0661,
    [0x0032] = 0x0662,
    [0x0033] = 0x0663,
    [0x0034] = 0x0664,
    [0x0035] = 0x0665,
    [0x0036] = 0x0666,
    [0x0037] = 0x0667,
    [0x0038] = 0x0668,
    [0x0039] = 0x0669,
}

local anum_persian = {
    [0x0030] = 0x06F0,
    [0x0031] = 0x06F1,
    [0x0032] = 0x06F2,
    [0x0033] = 0x06F3,
    [0x0034] = 0x06F4,
    [0x0035] = 0x06F5,
    [0x0036] = 0x06F6,
    [0x0037] = 0x06F7,
    [0x0038] = 0x06F8,
    [0x0039] = 0x06F9,
}

local function valid(data)
    local features = data.resources.features
    if features then
        for k, v in next, features do
            for k, v in next, v do
                if v.arab then
                    return true
                end
            end
        end
    end
end

local anum_specification = {
    {
        type     = "substitution",
        features = { arab = { urd = true, dflt = true } },
        order    = { "anum" },
        data     = anum_arabic,
        flags    = noflags, -- { },
        valid    = valid,
    },
    {
        type     = "substitution",
        features = { arab = { urd = true } },
        order    = { "anum" },
        data     = anum_persian,
        flags    = noflags, -- { },
        valid    = valid,
    },
}

otf.addfeature("anum",anum_specification) -- todo: only when there is already an arab script feature

registerotffeature {
    -- this makes it a known feature (in tables)
    name        = 'anum',
    description = 'arabic digits',
}

-- maybe:

-- fonts.handlers.otf.addfeature("hangulfix",{
--     type     = "substitution",
--     features = { ["hang"] = { ["*"] = true } },
--     data     = {
--         [0x1160] = 0x119E,
--     },
--     order    = { "hangulfix" },
--     flags    = { },
--     prepend  = true,
-- })

-- fonts.handlers.otf.features.register {
--     name        = 'hangulfix',
--     description = 'fixes for hangul',
-- }

-- fonts.handlers.otf.addfeature {
--     name = "stest",
--     type = "substitution",
--     data = {
--         a = "X",
--         b = "P",
--     }
-- }
-- fonts.handlers.otf.addfeature {
--     name = "atest",
--     type = "alternate",
--     data = {
--         a = { "X", "Y" },
--         b = { "P", "Q" },
--     }
-- }
-- fonts.handlers.otf.addfeature {
--     name = "mtest",
--     type = "multiple",
--     data = {
--         a = { "X", "Y" },
--         b = { "P", "Q" },
--     }
-- }
-- fonts.handlers.otf.addfeature {
--     name = "ltest",
--     type = "ligature",
--     data = {
--         X = { "a", "b" },
--         Y = { "d", "a" },
--     }
-- }
-- fonts.handlers.otf.addfeature {
--     name = "ktest",
--     type = "kern",
--     data = {
--         a = { b = -500 },
--     }
-- }
