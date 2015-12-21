if not modules then modules = { } end modules ['luatex-fonts-def'] = {
    version   = 1.001,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if context then
    texio.write_nl("fatal error: this module is not for context")
    os.exit()
end

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

local function issome ()    list.lookup = 'name'          end -- xetex mode prefers name (not in context!)
local function isfile ()    list.lookup = 'file'          end
local function isname ()    list.lookup = 'name'          end
local function thename(s)   list.name   = s               end
local function issub  (v)   list.sub    = v               end
local function iscrap (s)   list.crap   = string.lower(s) end
local function iskey  (k,v) list[k]     = v               end
local function istrue (s)   list[s]     = true            end
local function isfalse(s)   list[s]     = false           end

local P, S, R, C = lpeg.P, lpeg.S, lpeg.R, lpeg.C

local spaces     = P(" ")^0
local namespec   = (1-S("/:("))^0 -- was: (1-S("/: ("))^0
local crapspec   = spaces * P("/") * (((1-P(":"))^0)/iscrap) * spaces
local filename_1 = P("file:")/isfile * (namespec/thename)
local filename_2 = P("[") * P(true)/isname * (((1-P("]"))^0)/thename) * P("]")
local fontname_1 = P("name:")/isname * (namespec/thename)
local fontname_2 = P(true)/issome * (namespec/thename)
local sometext   = (R("az","AZ","09") + S("+-."))^1
local truevalue  = P("+") * spaces * (sometext/istrue)
local falsevalue = P("-") * spaces * (sometext/isfalse)
local keyvalue   = (C(sometext) * spaces * P("=") * spaces * C(sometext))/iskey
local somevalue  = sometext/istrue
local subvalue   = P("(") * (C(P(1-S("()"))^1)/issub) * P(")") -- for Kim
local option     = spaces * (keyvalue + falsevalue + truevalue + somevalue) * spaces
local options    = P(":") * spaces * (P(";")^0  * option)^0

local pattern    = (filename_1 + filename_2 + fontname_1 + fontname_2) * subvalue^0 * crapspec^0 * options^0

local function colonized(specification) -- xetex mode
    list = { }
    lpeg.match(pattern,specification.specification)
    list.crap = nil -- style not supported, maybe some day
    if list.name then
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
