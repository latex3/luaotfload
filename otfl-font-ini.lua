if not modules then modules = { } end modules ['font-ini'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Not much is happening here.</p>
--ldx]]--

local utf = unicode.utf8
local format, serialize = string.format, table.serialize
local write_nl = texio.write_nl
local lower = string.lower
local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local report_define = logs.new("define fonts")

fontloader.totable = fontloader.to_table

-- vtf comes first
-- fix comes last

fonts = fonts or { }

-- we will also have des and fam hashes

-- beware, soem alreadyu defined

fonts.ids = mark(fonts.ids or { })  fonts.identifiers = fonts.ids -- aka fontdata
fonts.chr = mark(fonts.chr or { })  fonts.characters  = fonts.chr -- aka chardata
fonts.qua = mark(fonts.qua or { })  fonts.quads       = fonts.qua -- aka quaddata
fonts.css = mark(fonts.css or { })  fonts.csnames     = fonts.css -- aka namedata

fonts.tfm = fonts.tfm or { }
fonts.vf  = fonts.vf  or { }
fonts.afm = fonts.afm or { }
fonts.pfb = fonts.pfb or { }
fonts.otf = fonts.otf or { }

fonts.privateoffset = 0xF0000 -- 0x10FFFF
fonts.verbose = false -- more verbose cache tables

fonts.ids[0] = { -- nullfont
    characters   = { },
    descriptions = { },
    name         = "nullfont",
}

fonts.chr[0] = { }

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
        report_define("unable to determine font format for '%s'",filename)
        return default
    end
end
