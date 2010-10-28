if not modules then modules = { } end modules ['font-oti'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local lower = string.lower

local fonts = fonts

local otf          = fonts.otf
local initializers = fonts.initializers

local languages    = otf.tables.languages
local scripts      = otf.tables.scripts

local function set_language(tfmdata,value)
    if value then
        value = lower(value)
        if languages[value] then
            tfmdata.language = value
        end
    end
end

local function set_script(tfmdata,value)
    if value then
        value = lower(value)
        if scripts[value] then
            tfmdata.script = value
        end
    end
end

local function set_mode(tfmdata,value)
    if value then
        tfmdata.mode = lower(value)
    end
end

local base_initializers = initializers.base.otf
local node_initializers = initializers.node.otf

base_initializers.language = set_language
base_initializers.script   = set_script
base_initializers.mode     = set_mode
base_initializers.method   = set_mode

node_initializers.language = set_language
node_initializers.script   = set_script
node_initializers.mode     = set_mode
node_initializers.method   = set_mode

otf.features.register("features",true)     -- we always do features
table.insert(fonts.processors,"features")  -- we need a proper function for doing this

