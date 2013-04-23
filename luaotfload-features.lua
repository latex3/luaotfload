if not modules then modules = { } end modules ["features"] = {
    version   = 1.000,
    comment   = "companion to luaotfload.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

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

local function set_default_features(script)
    local features
    local script = script or "dflt"
    report("log", 0, "load font",
        "auto-selecting default features for script: %s",
        script)
    if defaults[script] then
        features = defaults[script]
    else
        features = defaults["dflt"]
    end
    for _,v in next, features do
        if feature_list[v] ~= false then
            feature_list[v] = true
        end
    end
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
    set_default_features(feature_list.script)
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

function fonts.definers.applypostprocessors(tfmdata)
    local postprocessors = tfmdata.postprocessors
    if postprocessors then
        for i=1,#postprocessors do
            local extrahash = postprocessors[i](tfmdata) -- after scaling etc
            if type(extrahash) == "string" and extrahash ~= "" then
                -- e.g. a reencoding needs this
                extrahash = string.gsub(lower(extrahash),"[^a-z]","-")
                tfmdata.properties.fullname = format("%s-%s",tfmdata.properties.fullname,extrahash)
            end
        end
    end
    return tfmdata
end
---[[ end included font-ltx.lua ]]

--[[doc--
Taken from the most recent branch of luaotfload.
--doc]]--
local addotffeature       = fonts.handlers.otf.addfeature
local registerotffeature  = fonts.handlers.otf.features.register

local everywhere = { ["*"] = { ["*"] = true } }

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

addotffeature("tlig", tlig)
addotffeature("trep", { }) -- empty, all in tlig now
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

addotffeature("anum",anum_specification)

registerotffeature {
    name        = 'anum',
    description = 'arabic digits',
}

-- vim:tw=71:sw=4:ts=4:expandtab
