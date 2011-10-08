if not modules then modules = { } end modules ['font-ltx'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local fonts = fonts

-- A bit of tuning for definitions.

fonts.constructors.namemode = "specification" -- somehow latex needs this (changed name!) => will change into an overload

-- tricky: we sort of bypass the parser and directly feed all into
-- the sub parser

function fonts.definers.getspecification(str)
    return "", str, "", ":", str
end

-- the generic name parser (different from context!)

local list = { }

local function isstyle(s)
    local style  = string.lower(s):split("/")
    for _,v in ipairs(style) do
        if v == "b" then
            list.style = "bold"
        elseif v == "i" then
            list.style = "italic"
        elseif v == "bi" or v == "ib" then
            list.style = "bolditalic"
        elseif v:find("^s=") then
            list.optsize = v:split("=")[2]
        elseif v == "aat" or v == "icu" or v == "gr" then
            logs.report("load font", "unsupported font option: %s", v)
        elseif not v:is_empty() then
            list.style = v:gsub("[^%a%d]", "")
        end
    end
end

local defaults = {
    dflt = {
        "ccmp", "locl", "rlig", "liga", "clig",
        "kern", "mark", "mkmk",
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
    logs.report("load font", "auto-selecting default features for script: %s", script)
    if defaults[script] then
        features = defaults[script]
    else
        features = defaults["dflt"]
    end
    for _,v in next, features do
        if list[v] ~= false then
            list[v] = true
        end
    end
end

local function issome ()    list.lookup = 'name' end
local function isfile ()    list.lookup = 'file' end
local function isname ()    list.lookup = 'name' end
local function thename(s)   list.name   = s end
local function issub  (v)   list.sub    = v end
local function istrue (s)   list[s]     = true end
local function isfalse(s)   list[s]     = false end
local function iskey  (k,v) list[k]     = v end

local P, S, R, C = lpeg.P, lpeg.S, lpeg.R, lpeg.C

local spaces     = P(" ")^0
local namespec   = (1-S("/:("))^0 -- was: (1-S("/: ("))^0
local filespec   = (R("az", "AZ") * P(":"))^-1 * (1-S(":("))^1
local stylespec  = spaces * P("/") * (((1-P(":"))^0)/isstyle) * spaces
local filename   = (P("file:")/isfile * (filespec/thename)) + (P("[") * P(true)/isname * (((1-P("]"))^0)/thename) * P("]"))
local fontname   = (P("name:")/isname * (namespec/thename)) + P(true)/issome * (namespec/thename)
local sometext   = (R("az","AZ","09") + S("+-."))^1
local truevalue  = P("+") * spaces * (sometext/istrue)
local falsevalue = P("-") * spaces * (sometext/isfalse)
local keyvalue   = P("+") + (C(sometext) * spaces * P("=") * spaces * C(sometext))/iskey
local somevalue  = sometext/istrue
local subvalue   = P("(") * (C(P(1-S("()"))^1)/issub) * P(")") -- for Kim
local option     = spaces * (keyvalue + falsevalue + truevalue + somevalue) * spaces
local options    = P(":") * spaces * (P(";")^0  * option)^0
local pattern    = (filename + fontname) * subvalue^0 * stylespec^0 * options^0

local function colonized(specification) -- xetex mode
    list = { }
    lpeg.match(pattern,specification.specification)
    set_default_features(list.script)
    if list.style then
        specification.style = list.style
        list.style = nil
    end
    if list.optsize then
        specification.optsize = list.optsize
        list.optsize = nil
    end
    if list.name then
        if resolvers.findfile(list.name, "tfm") then
            list.lookup = "file"
            list.name   = file.addsuffix(list.name, "tfm")
        elseif resolvers.findfile(list.name, "ofm") then
            list.lookup = "file"
            list.name   = file.addsuffix(list.name, "ofm")
        end

        specification.name = list.name
        list.name = nil
    end
    if list.lookup then
        specification.lookup = list.lookup
        list.lookup = nil
    end
    if list.sub then
        specification.sub = list.sub
        list.sub = nil
    end
    specification.features.normal = fonts.handlers.otf.features.normalize(list)
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
