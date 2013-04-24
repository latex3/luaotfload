if not modules then modules = { } end modules ["features"] = {
    version   = 1.000,
    comment   = "companion to luaotfload.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, insert = string.format, table.insert
local type, next = type, next
local lpegmatch = lpeg.match

---[[ begin included font-ltx.lua ]]
--- this appears to be based in part on luatex-fonts-def.lua

local fonts = fonts

-- A bit of tuning for definitions.

fonts.constructors.namemode = "specification" -- somehow latex needs this (changed name!) => will change into an overload

-- tricky: we sort of bypass the parser and directly feed all into
-- the sub parser

function fonts.definers.getspecification(str)
    return "", str, "", ":", str
end

local feature_list = { }

local report = logs.names_report

local stringlower      = string.lower
local stringsub        = string.sub
local stringgsub       = string.gsub
local stringfind       = string.find
local stringexplode    = string.explode
local stringis_empty   = string.is_empty

--[[doc--
Apparently, these “modifiers” are another measure of emulating \XETEX,
cf. “About \XETEX”, by Jonathan Kew, 2005; and
    “The \XETEX Reference Guide”, by Will Robertson, 2011.
--doc]]--

local supported = {
    b    = "bold",
    i    = "italic",
    bi   = "bolditalic",
    aat  = false,
    icu  = false,
    gr   = false,
}

--- this parses the optional flags after the slash
--- the original behavior is that multiple slashes
--- are valid but they might cancel prior settings
--- example: {name:Antykwa Torunska/I/B} -> bold

local isstyle = function (request)
    request = stringlower(request)
    request = stringexplode(request, "/")

    for _,v in next, request do
        local stylename = supported[v]
        if stylename then
            feature_list.style = stylename
        elseif stringfind(v, "^s=") then
            --- after all, we want everything after the second byte ...
            local val = stringsub(v, 3)
            feature_list.optsize = val
        elseif stylename == false then
            report("log", 0,
                "load font", "unsupported font option: %s", v)
        elseif not stringis_empty(v) then
            feature_list.style = stringgsub(v, "[^%a%d]", "")
        end
    end
end

local defaults = {
    dflt = {
        "ccmp", "locl", "rlig", "liga", "clig",
        "kern", "mark", "mkmk", 'itlc',
    },
    arab = {
        "ccmp", "locl", "isol", "fina", "fin2",
        "fin3", "medi", "med2", "init", "rlig",
        "calt", "liga", "cswh", "mset", "curs",
        "kern", "mark", "mkmk",
    },
    deva = {
        "ccmp", "locl", "init", "nukt", "akhn",
        "rphf", "blwf", "half", "pstf", "vatu",
        "pres", "blws", "abvs", "psts", "haln",
        "calt", "blwm", "abvm", "dist", "kern",
        "mark", "mkmk",
    },
    khmr = {
        "ccmp", "locl", "pref", "blwf", "abvf",
        "pstf", "pres", "blws", "abvs", "psts",
        "clig", "calt", "blwm", "abvm", "dist",
        "kern", "mark", "mkmk",
    },
    thai = {
        "ccmp", "locl", "liga", "kern", "mark",
        "mkmk",
    },
    hang = {
        "ccmp", "ljmo", "vjmo", "tjmo",
    },
}

local global_defaults = { mode = "node" }

defaults.beng = defaults.deva
defaults.guru = defaults.deva
defaults.gujr = defaults.deva
defaults.orya = defaults.deva
defaults.taml = defaults.deva
defaults.telu = defaults.deva
defaults.knda = defaults.deva
defaults.mlym = defaults.deva
defaults.sinh = defaults.deva

defaults.syrc = defaults.arab
defaults.mong = defaults.arab
defaults.nko  = defaults.arab

defaults.tibt = defaults.khmr

defaults.lao  = defaults.thai

--- (string, string) dict -> (string, string) dict
local set_default_features = function (speclist)
    local script = speclist.script or "dflt"

    report("log", 0, "load font",
        "auto-selecting default features for script: %s",
        script)

    local requested = defaults[script]
    if not requested then
        report("log", 0, "load font",
            "no defaults for script “%s”, falling back to “dflt”",
            script)
        requested = defaults.dflt
    end

    for i=1, #requested do
        local feat = requested[i]
        if speclist[feat] ~= false then
            speclist[feat] = true
        end
    end

    for feat, state in next, global_defaults do
        --- This is primarily intended for setting node
        --- mode unless “base” is requested, as stated
        --- in the manual.
        if not speclist[feat] then speclist[feat] = state end
    end
    return speclist
end

local function issome ()    feature_list.lookup = 'name' end
local function isfile ()    feature_list.lookup = 'file' end
local function isname ()    feature_list.lookup = 'name' end
local function thename(s)   feature_list.name   = s end
local function issub  (v)   feature_list.sub    = v end
local function istrue (s)   feature_list[s]     = true end
local function isfalse(s)   feature_list[s]     = false end
local function iskey  (k,v) feature_list[k]     = v end

local P, S, R, C = lpeg.P, lpeg.S, lpeg.R, lpeg.C

local spaces     = P(" ")^0
--local namespec   = (1-S("/:("))^0 -- was: (1-S("/: ("))^0
--[[phg-- this prevents matching of absolute paths as file names --]]--
local namespec   = (1-S("/:("))^1
local filespec   = (R("az", "AZ") * P(":"))^-1 * (1-S(":("))^1
local stylespec  = spaces * P("/") * (((1-P(":"))^0)/isstyle) * spaces
local filename   = (P("file:")/isfile * (filespec/thename)) + (P("[") * P(true)/isname * (((1-P("]"))^0)/thename) * P("]"))
local fontname   = (P("name:")/isname * (namespec/thename)) + P(true)/issome * (namespec/thename)
local sometext   = (R("az","AZ","09") + S("+-.,"))^1
local truevalue  = P("+") * spaces * (sometext/istrue)
local falsevalue = P("-") * spaces * (sometext/isfalse)
local keyvalue   = P("+") + (C(sometext) * spaces * P("=") * spaces * C(sometext))/iskey
local somevalue  = sometext/istrue
local subvalue   = P("(") * (C(P(1-S("()"))^1)/issub) * P(")") -- for Kim
local option     = spaces * (keyvalue + falsevalue + truevalue + somevalue) * spaces
local options    = P(":") * spaces * (P(";")^0  * option)^0
local pattern    = (filename + fontname) * subvalue^0 * stylespec^0 * options^0

local function colonized(specification) -- xetex mode
    feature_list = { }
    lpeg.match(pattern,specification.specification)
    feature_list = set_default_features(feature_list)
    if feature_list.style then
        specification.style = feature_list.style
        feature_list.style = nil
    end
    if feature_list.optsize then
        specification.optsize = feature_list.optsize
        feature_list.optsize = nil
    end
    if feature_list.name then
        if resolvers.findfile(feature_list.name, "tfm") then
            feature_list.lookup = "file"
            feature_list.name   = file.addsuffix(feature_list.name, "tfm")
        elseif resolvers.findfile(feature_list.name, "ofm") then
            feature_list.lookup = "file"
            feature_list.name   = file.addsuffix(feature_list.name, "ofm")
        end

        specification.name = feature_list.name
        feature_list.name = nil
    end
    if feature_list.lookup then
        specification.lookup = feature_list.lookup
        feature_list.lookup = nil
    end
    if feature_list.sub then
        specification.sub = feature_list.sub
        feature_list.sub = nil
    end
    if not feature_list.mode then
        -- if no mode is set, use our default
        feature_list.mode = fonts.mode
    end
    specification.features.normal = fonts.handlers.otf.features.normalize(feature_list)
    return specification
end

fonts.definers.registersplit(":",colonized,"cryptic")
fonts.definers.registersplit("", colonized,"more cryptic") -- catches \font\text=[names]

--- TODO below section is literally the same in luatex-fonts-def
---      why is it here?
--function fonts.definers.applypostprocessors(tfmdata)
--    local postprocessors = tfmdata.postprocessors
--    if postprocessors then
--        for i=1,#postprocessors do
--            local extrahash = postprocessors[i](tfmdata) -- after scaling etc
--            if type(extrahash) == "string" and extrahash ~= "" then
--                -- e.g. a reencoding needs this
--                extrahash = string.gsub(lower(extrahash),"[^a-z]","-")
--                tfmdata.properties.fullname = format("%s-%s",tfmdata.properties.fullname,extrahash)
--            end
--        end
--    end
--    return tfmdata
--end
---[[ end included font-ltx.lua ]]

--[[doc--
This uses the code from luatex-fonts-merged (<- font-otc.lua) instead
of the removed luaotfload-font-otc.lua.

TODO find out how far we get setting features without these lines,
relying on luatex-fonts only (it *does* handle features somehow, after
all).
--doc]]--

-- we assume that the other otf stuff is loaded already

---[[ begin snippet from font-otc.lua ]]
local trace_loading       = false  trackers.register("otf.loading", function(v) trace_loading = v end)
local report_otf          = logs.reporter("fonts","otf loading")

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

---[[ end snippet from font-otc.lua ]]

local tlig = {
    {
        type      = "substitution",
        features  = everywhere,
        data      = {
            [0x0022] = 0x201D,                   -- quotedblright
            [0x0027] = 0x2019,                   -- quoteleft
            [0x0060] = 0x2018,                   -- quoteright
        },
        flags     = { },
    },
    {
        type     = "ligature",
        features = everywhere,
        data     = {
            [0x2013] = {0x002D, 0x002D},         -- endash
            [0x2014] = {0x002D, 0x002D, 0x002D}, -- emdash
            [0x201C] = {0x2018, 0x2018},         -- quotedblleft
            [0x201D] = {0x2019, 0x2019},         -- quotedblright
            [0x201E] = {0x002C, 0x002C},         -- quotedblbase
            [0x00A1] = {0x0021, 0x2018},         -- exclamdown
            [0x00BF] = {0x003F, 0x2018},         -- questiondown
        },
        flags    = { },
    },
    {
        type     = "ligature",
        features = everywhere,
        data     = {
            [0x201C] = {0x0060, 0x0060},         -- quotedblleft
            [0x201D] = {0x0027, 0x0027},         -- quotedblright
            [0x00A1] = {0x0021, 0x0060},         -- exclamdown
            [0x00BF] = {0x003F, 0x0060},         -- questiondown
        },
        flags    = { },
    },
}

otf.addfeature("tlig", tlig)
otf.addfeature("trep", { }) -- empty, all in tlig now

local anum_arabic = { --- these are the same as in font-otc
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

local anum_persian = {--- these are the same as in font-otc
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
        features = { arab = { far = true, urd = true, snd = true } },
        data     = anum_persian,
        flags    = { },
        valid    = valid,
    },
    {
        type     = "substitution",
        features = { arab = { ["*"] = true } },
        data     = anum_arabic,
        flags    = { },
        valid    = valid,
    },
}

--- below the specifications as given in the removed font-otc.lua
--- the rest was identical to what this file had from the beginning
--- both make the “anum.tex” test pass anyways
--
--local anum_specification = {
--    {
--        type     = "substitution",
--        features = { arab = { urd = true, dflt = true } },
--        data     = anum_arabic,
--        flags    = noflags, -- { },
--        valid    = valid,
--    },
--    {
--        type     = "substitution",
--        features = { arab = { urd = true } },
--        data     = anum_persian,
--        flags    = noflags, -- { },
--        valid    = valid,
--    },
--}
--
otf.addfeature("anum",anum_specification)

registerotffeature {
    name        = 'anum',
    description = 'arabic digits',
}

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

-- vim:tw=71:sw=4:ts=4:expandtab
