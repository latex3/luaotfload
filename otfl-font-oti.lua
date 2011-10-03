if not modules then modules = { } end modules ['font-oti'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lower = string.lower

local allocate = utilities.storage.allocate

local fonts              = fonts
local otf                = { }
fonts.handlers.otf       = otf

local otffeatures        = fonts.constructors.newfeatures("otf")
local registerotffeature = otffeatures.register

registerotffeature {
    name        = "features",
    description = "initialization of feature handler",
    default     = true,
}

-- these are later hooked into node and base initializaters

local otftables = otf.tables -- not always defined

local function setmode(tfmdata,value)
    if value then
        tfmdata.properties.mode = lower(value)
    end
end

local function setlanguage(tfmdata,value)
    if value then
        local cleanvalue = lower(value)
        local languages  = otftables and otftables.languages
        local properties = tfmdata.properties
        if not languages then
            properties.language = cleanvalue
        elseif languages[value] then
            properties.language = cleanvalue
        else
            properties.language = "dflt"
        end
    end
end

local function setscript(tfmdata,value)
    if value then
        local cleanvalue = lower(value)
        local scripts    = otftables and otftables.scripts
        local properties = tfmdata.properties
        if not scripts then
            properties.script = cleanvalue
        elseif scripts[value] then
            properties.script = cleanvalue
        else
            properties.script = "dflt"
        end
    end
end

registerotffeature {
    name        = "mode",
    description = "mode",
    initializers = {
        base = setmode,
        node = setmode,
    }
}

registerotffeature {
    name         = "language",
    description  = "language",
    initializers = {
        base = setlanguage,
        node = setlanguage,
    }
}

registerotffeature {
    name        = "script",
    description = "script",
    initializers = {
        base = setscript,
        node = setscript,
    }
}

