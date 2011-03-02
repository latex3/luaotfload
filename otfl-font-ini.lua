if not modules then modules = { } end modules ['font-ini'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- The font code will be upgraded and reorganized so that we have a
-- leaner generic code base and can do more tuning for context.

--[[ldx--
<p>Not much is happening here.</p>
--ldx]]--

local utf = unicode.utf8
local format, serialize = string.format, table.serialize
local write_nl = texio.write_nl
local lower = string.lower
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local report_defining = logs.reporter("fonts","defining")

fontloader.totable = fontloader.to_table

-- vtf comes first
-- fix comes last

fonts = fonts or { }

-- beware, some already defined

fonts.identifiers = mark(fonts.identifiers or { }) -- fontdata
-----.characters  = mark(fonts.characters  or { }) -- chardata
-----.csnames     = mark(fonts.csnames     or { }) -- namedata
-----.quads       = mark(fonts.quads       or { }) -- quaddata

--~ fonts.identifiers[0] = { -- nullfont
--~     characters   = { },
--~     descriptions = { },
--~     name         = "nullfont",
--~ }

fonts.tfm = fonts.tfm or { }
fonts.vf  = fonts.vf  or { }
fonts.afm = fonts.afm or { }
fonts.pfb = fonts.pfb or { }
fonts.otf = fonts.otf or { }

fonts.privateoffset = 0xF0000 -- 0x10FFFF
fonts.verbose       = false   -- more verbose cache tables (will move to context namespace)

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

fonts.analyzers = fonts.analyzers or {
    useunicodemarks = false,
}

fonts.manipulators = fonts.manipulators or {
}

fonts.tracers = fonts.tracers or {
}

fonts.typefaces = fonts.typefaces or {
}

fonts.definers                     = fonts.definers                     or { }
fonts.definers.specifiers          = fonts.definers.specifiers          or { }
fonts.definers.specifiers.synonyms = fonts.definers.specifiers.synonyms or { }

-- tracing

if not fonts.colors then

    fonts.colors = allocate {
        set   = function() end,
        reset = function() end,
    }

end

-- format identification

fonts.formats = allocate()

function fonts.fontformat(filename,default)
    local extname = lower(file.extname(filename))
    local format = fonts.formats[extname]
    if format then
        return format
    else
        report_defining("unable to determine font format for '%s'",filename)
        return default
    end
end

-- readers

fonts.tfm.readers = fonts.tfm.readers or { }
