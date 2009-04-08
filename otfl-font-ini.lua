if not modules then modules = { } end modules ['font-ini'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Not much is happening here.</p>
--ldx]]--

local utf = unicode.utf8

if not fontloader then fontloader = fontforge end

fontloader.totable = fontloader.to_table

-- vtf comes first
-- fix comes last

fonts     = fonts     or { }
fonts.ids = fonts.ids or { } -- aka fontdata
fonts.tfm = fonts.tfm or { }

fonts.mode    = 'base'
fonts.private = 0xF0000 -- 0x10FFFF
fonts.verbose = false -- more verbose cache tables

fonts.methods = fonts.methods or {
    base = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { } },
    node = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { }  },
}

fonts.initializers = fonts.initializers or {
    base = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { }  },
    node = { tfm = { }, afm = { }, otf = { }, vtf = { }, fix = { }  }
}

fonts.triggers = fonts.triggers or {
    'mode',
    'language',
    'script',
    'strategy',
}

fonts.processors = fonts.processors or {
}

fonts.manipulators = fonts.manipulators or {
}

fonts.define                  = fonts.define                  or { }
fonts.define.specify          = fonts.define.specify          or { }
fonts.define.specify.synonyms = fonts.define.specify.synonyms or { }

-- tracing

fonts.color = fonts.color or { }

local attribute = attributes.private('color')
local mapping   = (attributes and attributes.list[attribute])  or { }

local set_attribute   = node.set_attribute
local unset_attribute = node.unset_attribute

function fonts.color.set(n,c)
    local mc = mapping[c]
    if not mc then
        unset_attribute(n,attribute)
    else
        set_attribute(n,attribute,mc)
    end
end
function fonts.color.reset(n)
    unset_attribute(n,attribute)
end

-- this will change ...

function fonts.show_char_data(n)
    local tfmdata = fonts.ids[font.current()]
    if tfmdata then
        if type(n) == "string" then
            n = utf.byte(n)
        end
        local chr = tfmdata.characters[n]
        if chr then
            texio.write_nl(table.serialize(chr,string.format("U_%04X",n)))
        end
    end
end
