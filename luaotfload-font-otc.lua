if not modules then modules = { } end modules ['font-otc'] = {
    version   = 1.001,
    comment   = "companion to font-otf.lua (context)",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, insert = string.format, table.insert
local type, next = type, next
local lpegmatch = lpeg.match

-- we assume that the other otf stuff is loaded already

local trace_loading       = false  trackers.register("otf.loading", function(v) trace_loading = v end)
local report_otf          = logs.reporter("fonts","otf loading")

local fonts               = fonts
local otf                 = fonts.handlers.otf
local registerotffeature  = otf.features.register
local setmetatableindex   = table.setmetatableindex

-- In the userdata interface we can not longer tweak the loaded font as
-- conveniently as before. For instance, instead of pushing extra data in
-- in the table using the original structure, we now have to operate on
-- the mkiv representation. And as the fontloader interface is modelled
-- after fontforge we cannot change that one too much either.

local types = {
    substitution = "gsub_single",
    ligature     = "gsub_ligature",
    alternate    = "gsub_alternate",
}

setmetatableindex(types, function(t,k) t[k] = k return k end) -- "key"

local everywhere = { ["*"] = { ["*"] = true } } -- or: { ["*"] = { "*" } }
local noflags    = { }

local function addfeature(data,feature,specifications)
    local descriptions = data.descriptions
    local resources    = data.resources
    local lookups      = resources.lookups
    local gsubfeatures = resources.features.gsub
    if gsubfeatures and gsubfeatures[feature] then
        -- already present
    else
        local sequences    = resources.sequences
        local fontfeatures = resources.features
        local unicodes     = resources.unicodes
        local lookuptypes  = resources.lookuptypes
        local splitter     = lpeg.splitter(" ",unicodes)
        local done         = 0
        local skip         = 0
        if not specifications[1] then
            -- so we accept a one entry specification
            specifications = { specifications }
        end
        -- subtables are tables themselves but we also accept flattened singular subtables
        for s=1,#specifications do
            local specification = specifications[s]
            local valid         = specification.valid
            if not valid or valid(data,specification,feature) then
                local initialize = specification.initialize
                if initialize then
                    -- when false is returned we initialize only once
                    specification.initialize = initialize(specification) and initialize or nil
                end
                local askedfeatures = specification.features or everywhere
                local subtables     = specification.subtables or { specification.data } or { }
                local featuretype   = types[specification.type or "substitution"]
                local featureflags  = specification.flags or noflags
                local added         = false
                local featurename   = format("ctx_%s_%s",feature,s)
                local st = { }
                for t=1,#subtables do
                    local list = subtables[t]
                    local full = format("%s_%s",featurename,t)
                    st[t] = full
                    if featuretype == "gsub_ligature" then
                        lookuptypes[full] = "ligature"
                        for code, ligature in next, list do
                            local unicode = tonumber(code) or unicodes[code]
                            local description = descriptions[unicode]
                            if description then
                                local slookups = description.slookups
                                if type(ligature) == "string" then
                                    ligature = { lpegmatch(splitter,ligature) }
                                end
                                local present = true
                                for i=1,#ligature do
                                    if not descriptions[ligature[i]] then
                                        present = false
                                        break
                                    end
                                end
                                if present then
                                    if slookups then
                                        slookups[full] = ligature
                                    else
                                        description.slookups = { [full] = ligature }
                                    end
                                    done, added = done + 1, true
                                else
                                    skip = skip + 1
                                end
                            end
                        end
                    elseif featuretype == "gsub_single" then
                        lookuptypes[full] = "substitution"
                        for code, replacement in next, list do
                            local unicode = tonumber(code) or unicodes[code]
                            local description = descriptions[unicode]
                            if description then
                                local slookups = description.slookups
                                replacement = tonumber(replacement) or unicodes[replacement]
                                if descriptions[replacement] then
                                    if slookups then
                                        slookups[full] = replacement
                                    else
                                        description.slookups = { [full] = replacement }
                                    end
                                    done, added = done + 1, true
                                end
                            end
                        end
                    end
                end
                if added then
                    -- script = { lang1, lang2, lang3 } or script = { lang1 = true, ... }
                    for k, v in next, askedfeatures do
                        if v[1] then
                            askedfeatures[k] = table.tohash(v)
                        end
                    end
                    sequences[#sequences+1] = {
                        chain     = 0,
                        features  = { [feature] = askedfeatures },
                        flags     = featureflags,
                        name      = featurename,
                        subtables = st,
                        type      = featuretype,
                    }
                    -- register in metadata (merge as there can be a few)
                    if not gsubfeatures then
                        gsubfeatures  = { }
                        fontfeatures.gsub = gsubfeatures
                    end
                    local k = gsubfeatures[feature]
                    if not k then
                        k = { }
                        gsubfeatures[feature] = k
                    end
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
end

otf.enhancers.addfeature = addfeature

local extrafeatures = { }

function otf.addfeature(name,specification)
    extrafeatures[name] = specification
end

local function enhance(data,filename,raw)
    for feature, specification in next, extrafeatures do
        addfeature(data,feature,specification)
    end
end

otf.enhancers.register("check extra features",enhance)

-- tlig --

local tlig = {
    endash        = "hyphen hyphen",
    emdash        = "hyphen hyphen hyphen",
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
    flags    = noflags,
}

otf.addfeature("tlig",tlig_specification)

registerotffeature {
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
    flags     = noflags,
}

otf.addfeature("trep",trep_specification)

registerotffeature {
    name        = 'trep',
    description = 'tex replacements',
}

-- tcom

if characters.combined then

    local tcom = { }

    local function initialize()
        characters.initialize()
        for first, seconds in next, characters.combined do
            for second, combination in next, seconds do
                tcom[combination] = { first, second }
            end
        end
        -- return false
    end

    local tcom_specification = {
        type       = "ligature",
        features   = everywhere,
        data       = tcom,
        flags      = noflags,
        initialize = initialize,
    }

    otf.addfeature("tcom",tcom_specification)

    registerotffeature {
        name        = 'tcom',
        description = 'tex combinations',
    }

end

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
        data     = anum_arabic,
        flags    = noflags, -- { },
        valid    = valid,
    },
    {
        type     = "substitution",
        features = { arab = { urd = true } },
        data     = anum_persian,
        flags    = noflags, -- { },
        valid    = valid,
    },
}

otf.addfeature("anum",anum_specification) -- todo: only when there is already an arab script feature

registerotffeature {
    name        = 'anum',
    description = 'arabic digits',
}
