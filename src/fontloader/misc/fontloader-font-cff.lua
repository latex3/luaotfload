if not modules then modules = { } end modules ['font-cff'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- todo: option.outlines
-- todo: option.boundingbox
-- per charstring (less memory)

-- This is a heavy one as it is a rather packed format. We don't need al the information
-- now but we might need it later (who know what magic we can do with metapost). So at
-- some point this might become a module. We just follow Adobe Technical Notes #5176 and
-- #5177. In case of doubt I looked in the fontforge code that comes with LuaTeX.

-- For now we save the segments in a list of segments with the operator last in an entry
-- because that reflects the original. But it might make more sense to use a single array
-- per segment. For pdf a simple concat works ok, but for other purposes a operator first
-- flush is nicer.

local next, type, tonumber = next, type, tonumber
local byte = string.byte
local concat, remove = table.concat, table.remove
local floor, abs, round, ceil = math.floor, math.abs, math.round, math.ceil
local P, C, R, S, C, Cs, Ct = lpeg.P, lpeg.C, lpeg.R, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Ct
local lpegmatch = lpeg.match
local formatters = string.formatters

local readers           = fonts.handlers.otf.readers
local streamreader      = readers.streamreader

local readbytes         = streamreader.readbytes
local readstring        = streamreader.readstring
local readbyte          = streamreader.readcardinal1  --  8-bit unsigned integer
local readushort        = streamreader.readcardinal2  -- 16-bit unsigned integer
local readuint          = streamreader.readcardinal3  -- 24-bit unsigned integer
local readulong         = streamreader.readcardinal4  -- 24-bit unsigned integer
local setposition       = streamreader.setposition
local getposition       = streamreader.getposition

local setmetatableindex = table.setmetatableindex

local trace_charstrings = false trackers.register("fonts.cff.charstrings",function(v) trace_charstrings = v end)
local report            = logs.reporter("otf reader","cff")

local parsedictionaries
local parsecharstring
local parsecharstrings
local resetcharstrings
local parseprivates

local defaultstrings = { [0] = -- taken from ff
    ".notdef", "space", "exclam", "quotedbl", "numbersign", "dollar", "percent",
    "ampersand", "quoteright", "parenleft", "parenright", "asterisk", "plus",
    "comma", "hyphen", "period", "slash", "zero", "one", "two", "three", "four",
    "five", "six", "seven", "eight", "nine", "colon", "semicolon", "less",
    "equal", "greater", "question", "at", "A", "B", "C", "D", "E", "F", "G", "H",
    "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W",
    "X", "Y", "Z", "bracketleft", "backslash", "bracketright", "asciicircum",
    "underscore", "quoteleft", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
    "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y",
    "z", "braceleft", "bar", "braceright", "asciitilde", "exclamdown", "cent",
    "sterling", "fraction", "yen", "florin", "section", "currency",
    "quotesingle", "quotedblleft", "guillemotleft", "guilsinglleft",
    "guilsinglright", "fi", "fl", "endash", "dagger", "daggerdbl",
    "periodcentered", "paragraph", "bullet", "quotesinglbase", "quotedblbase",
    "quotedblright", "guillemotright", "ellipsis", "perthousand", "questiondown",
    "grave", "acute", "circumflex", "tilde", "macron", "breve", "dotaccent",
    "dieresis", "ring", "cedilla", "hungarumlaut", "ogonek", "caron", "emdash",
    "AE", "ordfeminine", "Lslash", "Oslash", "OE", "ordmasculine", "ae",
    "dotlessi", "lslash", "oslash", "oe", "germandbls", "onesuperior",
    "logicalnot", "mu", "trademark", "Eth", "onehalf", "plusminus", "Thorn",
    "onequarter", "divide", "brokenbar", "degree", "thorn", "threequarters",
    "twosuperior", "registered", "minus", "eth", "multiply", "threesuperior",
    "copyright", "Aacute", "Acircumflex", "Adieresis", "Agrave", "Aring",
    "Atilde", "Ccedilla", "Eacute", "Ecircumflex", "Edieresis", "Egrave",
    "Iacute", "Icircumflex", "Idieresis", "Igrave", "Ntilde", "Oacute",
    "Ocircumflex", "Odieresis", "Ograve", "Otilde", "Scaron", "Uacute",
    "Ucircumflex", "Udieresis", "Ugrave", "Yacute", "Ydieresis", "Zcaron",
    "aacute", "acircumflex", "adieresis", "agrave", "aring", "atilde",
    "ccedilla", "eacute", "ecircumflex", "edieresis", "egrave", "iacute",
    "icircumflex", "idieresis", "igrave", "ntilde", "oacute", "ocircumflex",
    "odieresis", "ograve", "otilde", "scaron", "uacute", "ucircumflex",
    "udieresis", "ugrave", "yacute", "ydieresis", "zcaron", "exclamsmall",
    "Hungarumlautsmall", "dollaroldstyle", "dollarsuperior", "ampersandsmall",
    "Acutesmall", "parenleftsuperior", "parenrightsuperior", "twodotenleader",
    "onedotenleader", "zerooldstyle", "oneoldstyle", "twooldstyle",
    "threeoldstyle", "fouroldstyle", "fiveoldstyle", "sixoldstyle",
    "sevenoldstyle", "eightoldstyle", "nineoldstyle", "commasuperior",
    "threequartersemdash", "periodsuperior", "questionsmall", "asuperior",
    "bsuperior", "centsuperior", "dsuperior", "esuperior", "isuperior",
    "lsuperior", "msuperior", "nsuperior", "osuperior", "rsuperior", "ssuperior",
    "tsuperior", "ff", "ffi", "ffl", "parenleftinferior", "parenrightinferior",
    "Circumflexsmall", "hyphensuperior", "Gravesmall", "Asmall", "Bsmall",
    "Csmall", "Dsmall", "Esmall", "Fsmall", "Gsmall", "Hsmall", "Ismall",
    "Jsmall", "Ksmall", "Lsmall", "Msmall", "Nsmall", "Osmall", "Psmall",
    "Qsmall", "Rsmall", "Ssmall", "Tsmall", "Usmall", "Vsmall", "Wsmall",
    "Xsmall", "Ysmall", "Zsmall", "colonmonetary", "onefitted", "rupiah",
    "Tildesmall", "exclamdownsmall", "centoldstyle", "Lslashsmall",
    "Scaronsmall", "Zcaronsmall", "Dieresissmall", "Brevesmall", "Caronsmall",
    "Dotaccentsmall", "Macronsmall", "figuredash", "hypheninferior",
    "Ogoneksmall", "Ringsmall", "Cedillasmall", "questiondownsmall", "oneeighth",
    "threeeighths", "fiveeighths", "seveneighths", "onethird", "twothirds",
    "zerosuperior", "foursuperior", "fivesuperior", "sixsuperior",
    "sevensuperior", "eightsuperior", "ninesuperior", "zeroinferior",
    "oneinferior", "twoinferior", "threeinferior", "fourinferior",
    "fiveinferior", "sixinferior", "seveninferior", "eightinferior",
    "nineinferior", "centinferior", "dollarinferior", "periodinferior",
    "commainferior", "Agravesmall", "Aacutesmall", "Acircumflexsmall",
    "Atildesmall", "Adieresissmall", "Aringsmall", "AEsmall", "Ccedillasmall",
    "Egravesmall", "Eacutesmall", "Ecircumflexsmall", "Edieresissmall",
    "Igravesmall", "Iacutesmall", "Icircumflexsmall", "Idieresissmall",
    "Ethsmall", "Ntildesmall", "Ogravesmall", "Oacutesmall", "Ocircumflexsmall",
    "Otildesmall", "Odieresissmall", "OEsmall", "Oslashsmall", "Ugravesmall",
    "Uacutesmall", "Ucircumflexsmall", "Udieresissmall", "Yacutesmall",
    "Thornsmall", "Ydieresissmall", "001.000", "001.001", "001.002", "001.003",
    "Black", "Bold", "Book", "Light", "Medium", "Regular", "Roman", "Semibold",
}

local cffreaders = {
    readbyte,
    readushort,
    readuint,
    readulong,
}

-- The header contains information about its own size.

local function readheader(f)
    local offset = getposition(f)
    local header = {
        offset = offset,
        major  = readbyte(f),
        minor  = readbyte(f),
        size   = readbyte(f), -- headersize
        osize  = readbyte(f), -- for offsets to start
    }
    setposition(f,offset+header.size)
    return header
end

-- The indexes all look the same, so we share a loader. We could pass a handler
-- and run over the array but why bother, we only have a few uses.

local function readlengths(f)
    local count = readushort(f)
    if count == 0 then
        return { }
    end
    local osize = readbyte(f)
    local read  = cffreaders[osize]
    if not read then
        report("bad offset size: %i",osize)
        return { }
    end
    local lengths  = { }
    local previous = read(f)
    for i=1,count do
        local offset = read(f)
        lengths[i] = offset - previous
        previous = offset
    end
    return lengths
end

-- There can be subfonts so names is an array. However, in our case it's always
-- one font. The same is true for the top dictionaries. Watch how we only load
-- the dictionary string as for interpretation we need to have the strings loaded
-- as well.

local function readfontnames(f)
    local names = readlengths(f)
    for i=1,#names do
        names[i] = readstring(f,names[i])
    end
    return names
end

local function readtopdictionaries(f)
    local dictionaries = readlengths(f)
    for i=1,#dictionaries do
        dictionaries[i] = readstring(f,dictionaries[i])
    end
    return dictionaries
end

-- Strings are added to a list of standard strings so we start the font specific
-- one with an offset. Strings are shared so we have one table.

local function readstrings(f)
    local lengths = readlengths(f)
    local strings = setmetatableindex({ }, defaultstrings)
    local index   = #defaultstrings
    for i=1,#lengths do
        index = index + 1
        strings[index] = readstring(f,lengths[i])
    end
    return strings
end

-- Parsing the dictionaries is delayed till we have the strings loaded. The parser
-- is stack based so the operands come before the operator (like in postscript).

-- local function delta(t)
--     local n = #t
--     if n > 1 then
--         local p = t[1]
--         for i=2,n do
--             local c = t[i]
--             t[i] = c + p
--             p = c
--         end
--     end
-- end

do

    -- We use a closure so that we don't need to pass too much around.

    local stack   = { }
    local top     = 0
    local result  = { }
    local strings = { }

    local p_single =
        P("\00") / function()
            result.version = strings[stack[top]] or "unset"
            top = 0
        end
      + P("\01") / function()
            result.notice = strings[stack[top]] or "unset"
            top = 0
        end
      + P("\02") / function()
            result.fullname = strings[stack[top]] or "unset"
            top = 0
        end
      + P("\03") / function()
            result.familyname = strings[stack[top]] or "unset"
            top = 0
        end
      + P("\04") / function()
            result.weight = strings[stack[top]] or "unset"
            top = 0
        end
      + P("\05") / function()
            result.fontbbox = { unpack(stack,1,4) }
            top = 0
        end
   -- + P("\06") / function() end -- bluevalues
   -- + P("\07") / function() end -- otherblues
   -- + P("\08") / function() end -- familyblues
   -- + P("\09") / function() end -- familyotherblues
   -- + P("\10") / function() end -- strhw
   -- + P("\11") / function() end -- stdvw
      + P("\13") / function()
            result.uniqueid = stack[top]
            top = 0
        end
      + P("\14") / function()
            result.xuid = concat(stack,"",1,top)
            top = 0
        end
      + P("\15") / function()
            result.charset = stack[top]
            top = 0
        end
      + P("\16") / function()
            result.encoding = stack[top]
            top = 0
        end
      + P("\17") / function()
            result.charstrings = stack[top]
            top = 0
        end
      + P("\18") / function()
            result.private = {
                size   = stack[top-1],
                offset = stack[top],
            }
            top = 0
        end
      + P("\19") / function()
            result.subroutines = stack[top]
        end
      + P("\20") / function()
            result.defaultwidthx = stack[top]
        end
      + P("\21") / function()
            result.nominalwidthx = stack[top]
        end
   -- + P("\22") / function() end -- reserved
   -- + P("\23") / function() end -- reserved
   -- + P("\24") / function() end -- reserved
   -- + P("\25") / function() end -- reserved
   -- + P("\26") / function() end -- reserved
   -- + P("\27") / function() end -- reserved

    local p_double = P("\12") * (
        P("\00") / function()
            result.copyright = stack[top]
            top = 0
        end
      + P("\01") / function()
            result.monospaced = stack[top] == 1 and true or false -- isfixedpitch
            top = 0
        end
      + P("\02") / function()
            result.italicangle = stack[top]
            top = 0
        end
      + P("\03") / function()
            result.underlineposition = stack[top]
            top = 0
        end
      + P("\04") / function()
            result.underlinethickness = stack[top]
            top = 0
        end
      + P("\05") / function()
            result.painttype = stack[top]
            top = 0
        end
      + P("\06") / function()
            result.charstringtype = stack[top]
            top = 0
        end
      + P("\07") / function()
            result.fontmatrix = { unpack(stack,1,6) }
            top = 0
        end
      + P("\08") / function()
            result.strokewidth = stack[top]
            top = 0
        end
      + P("\20") / function()
            result.syntheticbase = stack[top]
            top = 0
        end
      + P("\21") / function()
            result.postscript = strings[stack[top]] or "unset"
            top = 0
        end
      + P("\22") / function()
            result.basefontname = strings[stack[top]] or "unset"
            top = 0
        end
      + P("\21") / function()
            result.basefontblend = stack[top]
            top = 0
        end
      + P("\30") / function()
            result.cid.registry   = strings[stack[top-2]] or "unset"
            result.cid.ordering   = strings[stack[top-1]] or "unset"
            result.cid.supplement = stack[top]
            top = 0
        end
      + P("\31") / function()
            result.cid.fontversion = stack[top]
            top = 0
        end
      + P("\32") / function()
            result.cid.fontrevision= stack[top]
            top = 0
        end
      + P("\33") / function()
            result.cid.fonttype = stack[top]
            top = 0
        end
      + P("\34") / function()
            result.cid.count = stack[top]
            top = 0
        end
      + P("\35") / function()
            result.cid.uidbase = stack[top]
            top = 0
        end
      + P("\36") / function()
            result.cid.fdarray = stack[top]
            top = 0
        end
      + P("\37") / function()
            result.cid.fdselect = stack[top]
            top = 0
        end
      + P("\38") / function()
            result.cid.fontname = strings[stack[top]] or "unset"
            top = 0
        end
    )

    -- Some lpeg fun ... a first variant split the byte and made a new string but
    -- the second variant is much faster. Not that it matters much as we don't see
    -- such numbers often.

    local p_last = P("\x0F") / "0" + P("\x1F") / "1" + P("\x2F") / "2"  + P("\x3F") / "3"
        + P("\x4F") / "4" + P("\x5F") / "5" + P("\x6F") / "6"  + P("\x7F") / "7"
        + P("\x8F") / "8" + P("\x9F") / "9" + P("\xAF") / ""   + P("\xBF") / ""
        + P("\xCF") / ""  + P("\xDF") / ""  + P("\xEF") / ""   + R("\xF0\xFF") / ""

 -- local remap = { [0] =
 --     "00",  "01",  "02",  "03",  "04",  "05",  "06",  "07",  "08",  "09",  "0.",  "0E",  "0E-",  "0",  "0-",  "0",
 --     "10",  "11",  "12",  "13",  "14",  "15",  "16",  "17",  "18",  "19",  "0.",  "0E",  "0E-",  "0",  "0-",  "0",
 --     "20",  "21",  "22",  "23",  "24",  "25",  "26",  "27",  "28",  "29",  "0.",  "0E",  "0E-",  "0",  "0-",  "0",
 --     "30",  "31",  "32",  "33",  "34",  "35",  "36",  "37",  "38",  "39",  "0.",  "0E",  "0E-",  "0",  "0-",  "0",
 --     "40",  "41",  "42",  "43",  "44",  "45",  "46",  "47",  "48",  "49",  "0.",  "0E",  "0E-",  "0",  "0-",  "0",
 --     "50",  "51",  "52",  "53",  "54",  "55",  "56",  "57",  "58",  "59",  "0.",  "0E",  "0E-",  "0",  "0-",  "0",
 --     "60",  "61",  "62",  "63",  "64",  "65",  "66",  "67",  "68",  "69",  "0.",  "0E",  "0E-",  "0",  "0-",  "0",
 --     "70",  "71",  "72",  "73",  "74",  "75",  "76",  "77",  "78",  "79",  "0.",  "0E",  "0E-",  "0",  "0-",  "0",
 --     "80",  "81",  "82",  "83",  "84",  "85",  "86",  "87",  "88",  "89",  "0.",  "0E",  "0E-",  "0",  "0-",  "0",
 --     "90",  "91",  "92",  "93",  "94",  "95",  "96",  "97",  "98",  "99",  "0.",  "0E",  "0E-",  "0",  "0-",  "0",
 --     ".0",  ".1",  ".2",  ".3",  ".4",  ".5",  ".6",  ".7",  ".8",  ".9",  "..",  ".E",  ".E-",  ".",  ".-",  ".",
 --     "E0",  "E1",  "E2",  "E3",  "E4",  "E5",  "E6",  "E7",  "E8",  "E9",  "E.",  "EE",  "EE-",  "E",  "E-",  "E",
 --     "E-0", "E-1", "E-2", "E-3", "E-4", "E-5", "E-6", "E-7", "E-8", "E-9", "E-.", "E-E", "E-E-", "E-", "E--", "E-",
 --     "-0",  "-1",  "-2",  "-3",  "-4",  "-5",  "-6",  "-7",  "-8",  "-9",  "-.",  "-E",  "-E-",  "-",  "--",  "-",
 -- }

 -- local p_nibbles = Cs(((1-p_last)/byte/remap)^0+p_last)

 -- local p = P("\30") * p_nibbles / function(t)
 --     print(tonumber(t))
 -- end

    local remap = {
        ["\x00"] = "00",  ["\x01"] = "01",  ["\x02"] = "02",  ["\x03"] = "03",  ["\x04"] = "04",  ["\x05"] = "05",  ["\x06"] = "06",  ["\x07"] = "07",  ["\x08"] = "08",  ["\x09"] = "09",  ["\x0A"] = "0.",  ["\x0B"] = "0E",  ["\x0C"] = "0E-",  ["\x0D"] = "0",  ["\x0E"] = "0-",  ["\x0F"] = "0",
        ["\x10"] = "10",  ["\x11"] = "11",  ["\x12"] = "12",  ["\x13"] = "13",  ["\x14"] = "14",  ["\x15"] = "15",  ["\x16"] = "16",  ["\x17"] = "17",  ["\x18"] = "18",  ["\x19"] = "19",  ["\x1A"] = "0.",  ["\x1B"] = "0E",  ["\x1C"] = "0E-",  ["\x1D"] = "0",  ["\x1E"] = "0-",  ["\x1F"] = "0",
        ["\x20"] = "20",  ["\x21"] = "21",  ["\x22"] = "22",  ["\x23"] = "23",  ["\x24"] = "24",  ["\x25"] = "25",  ["\x26"] = "26",  ["\x27"] = "27",  ["\x28"] = "28",  ["\x29"] = "29",  ["\x2A"] = "0.",  ["\x2B"] = "0E",  ["\x2C"] = "0E-",  ["\x2D"] = "0",  ["\x2E"] = "0-",  ["\x2F"] = "0",
        ["\x30"] = "30",  ["\x31"] = "31",  ["\x32"] = "32",  ["\x33"] = "33",  ["\x34"] = "34",  ["\x35"] = "35",  ["\x36"] = "36",  ["\x37"] = "37",  ["\x38"] = "38",  ["\x39"] = "39",  ["\x3A"] = "0.",  ["\x3B"] = "0E",  ["\x3C"] = "0E-",  ["\x3D"] = "0",  ["\x3E"] = "0-",  ["\x3F"] = "0",
        ["\x40"] = "40",  ["\x41"] = "41",  ["\x42"] = "42",  ["\x43"] = "43",  ["\x44"] = "44",  ["\x45"] = "45",  ["\x46"] = "46",  ["\x47"] = "47",  ["\x48"] = "48",  ["\x49"] = "49",  ["\x4A"] = "0.",  ["\x4B"] = "0E",  ["\x4C"] = "0E-",  ["\x4D"] = "0",  ["\x4E"] = "0-",  ["\x4F"] = "0",
        ["\x50"] = "50",  ["\x51"] = "51",  ["\x52"] = "52",  ["\x53"] = "53",  ["\x54"] = "54",  ["\x55"] = "55",  ["\x56"] = "56",  ["\x57"] = "57",  ["\x58"] = "58",  ["\x59"] = "59",  ["\x5A"] = "0.",  ["\x5B"] = "0E",  ["\x5C"] = "0E-",  ["\x5D"] = "0",  ["\x5E"] = "0-",  ["\x5F"] = "0",
        ["\x60"] = "60",  ["\x61"] = "61",  ["\x62"] = "62",  ["\x63"] = "63",  ["\x64"] = "64",  ["\x65"] = "65",  ["\x66"] = "66",  ["\x67"] = "67",  ["\x68"] = "68",  ["\x69"] = "69",  ["\x6A"] = "0.",  ["\x6B"] = "0E",  ["\x6C"] = "0E-",  ["\x6D"] = "0",  ["\x6E"] = "0-",  ["\x6F"] = "0",
        ["\x70"] = "70",  ["\x71"] = "71",  ["\x72"] = "72",  ["\x73"] = "73",  ["\x74"] = "74",  ["\x75"] = "75",  ["\x76"] = "76",  ["\x77"] = "77",  ["\x78"] = "78",  ["\x79"] = "79",  ["\x7A"] = "0.",  ["\x7B"] = "0E",  ["\x7C"] = "0E-",  ["\x7D"] = "0",  ["\x7E"] = "0-",  ["\x7F"] = "0",
        ["\x80"] = "80",  ["\x81"] = "81",  ["\x82"] = "82",  ["\x83"] = "83",  ["\x84"] = "84",  ["\x85"] = "85",  ["\x86"] = "86",  ["\x87"] = "87",  ["\x88"] = "88",  ["\x89"] = "89",  ["\x8A"] = "0.",  ["\x8B"] = "0E",  ["\x8C"] = "0E-",  ["\x8D"] = "0",  ["\x8E"] = "0-",  ["\x8F"] = "0",
        ["\x90"] = "90",  ["\x91"] = "91",  ["\x92"] = "92",  ["\x93"] = "93",  ["\x94"] = "94",  ["\x95"] = "95",  ["\x96"] = "96",  ["\x97"] = "97",  ["\x98"] = "98",  ["\x99"] = "99",  ["\x9A"] = "0.",  ["\x9B"] = "0E",  ["\x9C"] = "0E-",  ["\x9D"] = "0",  ["\x9E"] = "0-",  ["\x9F"] = "0",
        ["\xA0"] = ".0",  ["\xA1"] = ".1",  ["\xA2"] = ".2",  ["\xA3"] = ".3",  ["\xA4"] = ".4",  ["\xA5"] = ".5",  ["\xA6"] = ".6",  ["\xA7"] = ".7",  ["\xA8"] = ".8",  ["\xA9"] = ".9",  ["\xAA"] = "..",  ["\xAB"] = ".E",  ["\xAC"] = ".E-",  ["\xAD"] = ".",  ["\xAE"] = ".-",  ["\xAF"] = ".",
        ["\xB0"] = "E0",  ["\xB1"] = "E1",  ["\xB2"] = "E2",  ["\xB3"] = "E3",  ["\xB4"] = "E4",  ["\xB5"] = "E5",  ["\xB6"] = "E6",  ["\xB7"] = "E7",  ["\xB8"] = "E8",  ["\xB9"] = "E9",  ["\xBA"] = "E.",  ["\xBB"] = "EE",  ["\xBC"] = "EE-",  ["\xBD"] = "E",  ["\xBE"] = "E-",  ["\xBF"] = "E",
        ["\xC0"] = "E-0", ["\xC1"] = "E-1", ["\xC2"] = "E-2", ["\xC3"] = "E-3", ["\xC4"] = "E-4", ["\xC5"] = "E-5", ["\xC6"] = "E-6", ["\xC7"] = "E-7", ["\xC8"] = "E-8", ["\xC9"] = "E-9", ["\xCA"] = "E-.", ["\xCB"] = "E-E", ["\xCC"] = "E-E-", ["\xCD"] = "E-", ["\xCE"] = "E--", ["\xCF"] = "E-",
        ["\xD0"] = "-0",  ["\xD1"] = "-1",  ["\xD2"] = "-2",  ["\xD3"] = "-3",  ["\xD4"] = "-4",  ["\xD5"] = "-5",  ["\xD6"] = "-6",  ["\xD7"] = "-7",  ["\xD8"] = "-8",  ["\xD9"] = "-9",  ["\xDA"] = "-.",  ["\xDB"] = "-E",  ["\xDC"] = "-E-",  ["\xDD"] = "-",  ["\xDE"] = "--",  ["\xDF"] = "-",
    }

    local p_nibbles = P("\30") * Cs(((1-p_last)/remap)^0+p_last) / function(n)
        -- 0-9=digit a=. b=E c=E- d=reserved e=- f=finish
        top = top + 1
        stack[top] = tonumber(n) or 0
    end

    local p_byte = C(R("\32\246")) / function(b0)
        -- -107 .. +107
        top = top + 1
        stack[top] = byte(b0) - 139
    end

    local p_positive =  C(R("\247\250")) * C(1) / function(b0,b1)
        -- +108 .. +1131
        top = top + 1
        stack[top] = (byte(b0)-247)*256 + byte(b1) + 108
    end

    local p_negative = C(R("\251\254")) * C(1) / function(b0,b1)
        -- -1131 .. -108
        top = top + 1
        stack[top] = -(byte(b0)-251)*256 - byte(b1) - 108
    end

    local p_short = P("\28") * C(1) * C(1) / function(b1,b2)
        -- -32768 .. +32767 : b1<<8 | b2
        top = top + 1
        local n = 0x100 * byte(b1) + byte(b2)
        if n  >= 0x8000 then
            stack[top] = n - 0xFFFF - 1
        else
            stack[top] =  n
        end
    end

    local p_long = P("\29") * C(1) * C(1) * C(1) * C(1) / function(b1,b2,b3,b4)
        -- -2^31 .. +2^31-1 : b1<<24 | b2<<16 | b3<<8 | b4
        top = top + 1
        local n = 0x1000000 * byte(b1) + 0x10000 * byte(b2) + 0x100 * byte(b3) + byte(b4)
        if n >= 0x8000000 then
            stack[top] = n - 0xFFFFFFFF - 1
        else
            stack[top] = n
        end
    end

    local p_unsupported = P(1) / function(detail)
        top = 0
    end

    local p_dictionary = (
        p_byte
      + p_positive
      + p_negative
      + p_short
      + p_long
      + p_nibbles
      + p_single
      + p_double
      + p_unsupported
    )^1

    parsedictionaries = function(data,dictionaries)
        stack   = { }
        strings = data.strings
        for i=1,#dictionaries do
            top    = 0
            result = {
                monospaced         = false,
                italicangle        = 0,
                underlineposition  = -100,
                underlinethickness = 50,
                painttype          = 0,
                charstringtype     = 2,
                fontmatrix         = { 0.001, 0, 0, 0.001, 0, 0 },
                fontbbox           = { 0, 0, 0, 0 },
                strokewidth        = 0,
                charset            = 0,
                encoding           = 0,
                cid = {
                    fontversion     = 0,
                    fontrevision    = 0,
                    fonttype        = 0,
                    count           = 8720,
                }
            }
            lpegmatch(p_dictionary,dictionaries[i])
            dictionaries[i] = result
        end
        --
        result = { }
        top    = 0
        stack  = { }
    end

    parseprivates = function(data,dictionaries)
        stack   = { }
        strings = data.strings
        for i=1,#dictionaries do
            local private = dictionaries[i].private
            if private and private.data then
                top     = 0
                result  = {
                    forcebold         = false,
                    languagegroup     = 0,
                    expansionfactor   = 0.06,
                    initialrandomseed = 0,
                    subroutines       = 0,
                    defaultwidthx     = 0,
                    nominalwidthx     = 0,
                    cid               = {
                        -- actually an error
                    },
                }
                lpegmatch(p_dictionary,private.data)
                private.data = result
            end
        end
        result = { }
        top    = 0
        stack  = { }
    end

    -- All bezier curves have 6 points with successive pairs relative to
    -- the previous pair. Some can be left out and are then copied or zero
    -- (optimization).
    --
    -- We are not really interested in all the details of a glyph because we
    -- only need to calculate the boundingbox. So, todo: a quick no result but
    -- calculate only variant.
    --
    -- The conversion is straightforward and the specification os clear once
    -- you understand that the x and y needs to be updates each step. It's also
    -- quite easy to test because in mp a shape will look bad when a few variables
    -- are swapped. But still there might be bugs down here because not all
    -- variants are seen in a font so far. We are less compact that the ff code
    -- because there quite some variants are done in one helper with a lot of
    -- testing for states.

    local x          = 0
    local y          = 0
    local width      = false
    local r          = 0
    local stems      = 0
    local globalbias = 0
    local localbias  = 0
    local globals    = false
    local locals     = false
    local depth      = 1
    local xmin       = 0
    local xmax       = 0
    local ymin       = 0
    local ymax       = 0
    local checked    = false
    local keepcurve  = false
    local version    = 2

    local function showstate(where)
        report("%w%-10s : [%s] n=%i",depth*2,where,concat(stack," ",1,top),top)
    end

    local function showvalue(where,value,showstack)
        if showstack then
            report("%w%-10s : %s : [%s] n=%i",depth*2,where,tostring(value),concat(stack," ",1,top),top)
        else
            report("%w%-10s : %s",depth*2,where,tostring(value))
        end
    end

    -- All these indirect calls make this run slower but it's cleaner this way
    -- and we cache the result. As we moved the boundingbox code inline we gain
    -- some back.

    local function moveto(x,y)
        if keepcurve then
            r = r + 1
            result[r] = { x, y, "m" }
        end
        if checked then
            if x < xmin then xmin = x elseif x > xmax then xmax = x end
            if y < ymin then ymin = y elseif y > ymax then ymax = y end
        else
            xmin = x
            ymin = y
            xmax = x
            ymax = y
            checked = true
        end
    end

    local function lineto(x,y)
        if keepcurve then
            r = r + 1
            result[r] = { x, y, "l" }
        end
        if checked then
            if x < xmin then xmin = x elseif x > xmax then xmax = x end
            if y < ymin then ymin = y elseif y > ymax then ymax = y end
        else
            xmin = x
            ymin = y
            xmax = x
            ymax = y
            checked = true
        end
    end

    local function curveto(x1,y1,x2,y2,x3,y3)
        if keepcurve then
            r = r + 1
            result[r] = { x1, y1, x2, y2, x3, y3, "c" }
        end
        if checked then
            if x1 < xmin then xmin = x1 elseif x1 > xmax then xmax = x1 end
            if y1 < ymin then ymin = y1 elseif y1 > ymax then ymax = y1 end
        else
            xmin = x1
            ymin = y1
            xmax = x1
            ymax = y1
            checked = true
        end
        if x2 < xmin then xmin = x2 elseif x2 > xmax then xmax = x2 end
        if y2 < ymin then ymin = y2 elseif y2 > ymax then ymax = y2 end
        if x3 < xmin then xmin = x3 elseif x3 > xmax then xmax = x3 end
        if y3 < ymin then ymin = y3 elseif y3 > ymax then ymax = y3 end
    end

    local function rmoveto()
        if top > 2 then
            if not width then
                width = stack[1]
                if trace_charstrings then
                    showvalue("width",width)
                end
            end
        elseif not width then
            width = true
        end
        if trace_charstrings then
            showstate("rmoveto")
        end
        x = x + stack[top-1] -- dx1
        y = y + stack[top]   -- dy1
        top = 0
        moveto(x,y)
    end

    local function hmoveto()
        if top > 1 then
            if not width then
                width = stack[1]
                if trace_charstrings then
                    showvalue("width",width)
                end
            end
        elseif not width then
            width = true
        end
        if trace_charstrings then
            showstate("hmoveto")
        end
        x = x + stack[top] -- dx1
        top = 0
        moveto(x,y)
    end

    local function vmoveto()
        if top > 1 then
            if not width then
                width = stack[1]
                if trace_charstrings then
                    showvalue("width",width)
                end
            end
        elseif not width then
            width = true
        end
        if trace_charstrings then
            showstate("vmoveto")
        end
        y = y + stack[top] -- dy1
        top = 0
        moveto(x,y)
    end

    local function rlineto()
        if trace_charstrings then
            showstate("rlineto")
        end
        for i=1,top,2 do
            x = x + stack[i]   -- dxa
            y = y + stack[i+1] -- dya
            lineto(x,y)
        end
        top = 0
    end

    local function xlineto(swap) -- x (y,x)+ | (x,y)+
        for i=1,top do
            if swap then
                x = x + stack[i]
                swap = false
            else
                y = y + stack[i]
                swap = true
            end
            lineto(x,y)
        end
        top = 0
    end

    local function hlineto() -- x (y,x)+ | (x,y)+
        if trace_charstrings then
            showstate("hlineto")
        end
        xlineto(true)
    end

    local function vlineto() -- y (x,y)+ | (y,x)+
        if trace_charstrings then
            showstate("vlineto")
        end
        xlineto(false)
    end

    local function rrcurveto()
        if trace_charstrings then
            showstate("rrcurveto")
        end
        for i=1,top,6 do
            local ax = x  + stack[i]   -- dxa
            local ay = y  + stack[i+1] -- dya
            local bx = ax + stack[i+2] -- dxb
            local by = ay + stack[i+3] -- dyb
            x = bx + stack[i+4] -- dxc
            y = by + stack[i+5] -- dyc
            curveto(ax,ay,bx,by,x,y)
        end
        top = 0
    end

    local function hhcurveto()
        if trace_charstrings then
            showstate("hhcurveto")
        end
        local s = 1
        if top % 2 ~= 0 then
            y = y + stack[1] -- dy1
            s = 2
        end
        for i=s,top,4 do
            local ax = x + stack[i] -- dxa
            local ay = y
            local bx = ax + stack[i+1] -- dxb
            local by = ay + stack[i+2] -- dyb
            x = bx + stack[i+3] -- dxc
            y = by
            curveto(ax,ay,bx,by,x,y)
        end
        top = 0
    end

    local function vvcurveto()
        if trace_charstrings then
            showstate("vvcurveto")
        end
        local s = 1
        local d = 0
        if top % 2 ~= 0 then
            d = stack[1] -- dx1
            s = 2
        end
        for i=s,top,4 do
            local ax = x + d
            local ay = y + stack[i] -- dya
            local bx = ax + stack[i+1] -- dxb
            local by = ay + stack[i+2] -- dyb
            x = bx
            y = by + stack[i+3] -- dyc
            curveto(ax,ay,bx,by,x,y)
            d = 0
        end
        top = 0
    end

    local function xxcurveto(swap)
        local last = top % 4 ~= 0 and stack[top]
        if last then
            top = top - 1
        end
        local sw = swap
        for i=1,top,4 do
            local ax, ay, bx, by
            if swap then
                ax = x  + stack[i]
                ay = y
                bx = ax + stack[i+1]
                by = ay + stack[i+2]
                y  = by + stack[i+3]
                if last and i+3 == top then
                    x = bx + last
                else
                    x = bx
                end
                swap = false
            else
                ax = x
                ay = y  + stack[i]
                bx = ax + stack[i+1]
                by = ay + stack[i+2]
                x  = bx + stack[i+3]
                if last and i+3 == top then
                    y = by + last
                else
                    y = by
                end
                swap = true
            end
            curveto(ax,ay,bx,by,x,y)
        end
        top = 0
    end

    local function hvcurveto()
        if trace_charstrings then
            showstate("hvcurveto")
        end
        xxcurveto(true)
    end

    local function vhcurveto()
        if trace_charstrings then
            showstate("vhcurveto")
        end
        xxcurveto(false)
    end

    local function rcurveline()
        if trace_charstrings then
            showstate("rcurveline")
        end
        for i=1,top-2,6 do
            local ax = x  + stack[i]   -- dxa
            local ay = y  + stack[i+1] -- dya
            local bx = ax + stack[i+2] -- dxb
            local by = ay + stack[i+3] -- dyb
            x = bx + stack[i+4] -- dxc
            y = by + stack[i+5] -- dyc
            curveto(ax,ay,bx,by,x,y)
        end
        x = x + stack[top-1] -- dxc
        y = y + stack[top]   -- dyc
        lineto(x,y)
        top = 0
    end

    local function rlinecurve()
        if trace_charstrings then
            showstate("rlinecurve")
        end
        if top > 6 then
            for i=1,top-6,2 do
                x = x + stack[i]
                y = y + stack[i+1]
                lineto(x,y)
            end
        end
        local ax = x  + stack[top-5]
        local ay = y  + stack[top-4]
        local bx = ax + stack[top-3]
        local by = ay + stack[top-2]
        x = bx + stack[top-1]
        y = by + stack[top]
        curveto(ax,ay,bx,by,x,y)
        top = 0
    end

    -- flex is not yet tested! no loop

    local function flex() -- fd not used
        if trace_charstrings then
            showstate("flex")
        end
        local ax = x  + stack[1]  -- dx1
        local ay = y  + stack[2]  -- dy1
        local bx = ax + stack[3]  -- dx2
        local by = ay + stack[4]  -- dy2
        local cx = bx + stack[5]  -- dx3
        local cy = by + stack[6]  -- dy3
        curveto(ax,ay,bx,by,cx,cy)
        local dx = cx + stack[7]  -- dx4
        local dy = cy + stack[8]  -- dy4
        local ex = dx + stack[9]  -- dx5
        local ey = dy + stack[10] -- dy5
        x = ex + stack[11]        -- dx6
        y = ey + stack[12]        -- dy6
        curveto(dx,dy,ex,ey,x,y)
        top = 0
    end

    local function hflex()
        if trace_charstrings then
            showstate("hflex")
        end
        local ax = x  + stack[1]   -- dx1
        local ay = y
        local bx = ax + stack[2] -- dx2
        local by = ay + stack[3] -- dy2
        local cx = bx + stack[4] -- dx3
        local cy = by
        curveto(ax,ay,bx,by,cx,cy)
        local dx = cx + stack[5] -- dx4
        local dy = by
        local ex = dx + stack[6] -- dx5
        local ey = y
        x  = ex + stack[7]       -- dx6
        curveto(dx,dy,ex,ey,x,y)
        top = 0
    end

    local function hflex1()
        if trace_charstrings then
            showstate("hflex1")
        end
        local ax = x  + stack[1] -- dx1
        local ay = y  + stack[2] -- dy1
        local bx = ax + stack[3] -- dx2
        local by = ay + stack[4] -- dy2
        local cx = bx + stack[5] -- dx3
        local cy = by
        curveto(ax,ay,bx,by,cx,cy)
        local dx = cx + stack[6] -- dx4
        local dy = by
        local ex = dx + stack[7] -- dx5
        local ey = dy + stack[8] -- dy5
        x  = ex + stack[9]       -- dx6
        curveto(dx,dy,ex,ey,x,y)
        top = 0
    end

    local function flex1()
        if trace_charstrings then
            showstate("flex1")
        end
        local ax = x  + stack[1]  --dx1
        local ay = y  + stack[2]  --dy1
        local bx = ax + stack[3]  --dx2
        local by = ay + stack[4]  --dy2
        local cx = bx + stack[5]  --dx3
        local cy = by + stack[6]  --dy3
        curveto(ax,ay,bx,by,cx,cy)
        local dx = cx + stack[7]  --dx4
        local dy = cy + stack[8]  --dy4
        local ex = dx + stack[9]  --dx5
        local ey = dy + stack[10] --dy5
        if abs(ex - x) > abs(ey - y) then -- spec: abs(dx) > abs(dy)
            x = ex + stack[11]
        else
            y = ey + stack[11]
        end
        curveto(dx,dy,ex,ey,x,y)
        top = 0
    end

    local function getstem()
        if top == 0 then
            -- bad
        elseif top % 2 ~= 0 then
            if width then
                remove(stack,1)
            else
                width = remove(stack,1)
                if trace_charstrings then
                    showvalue("width",width)
                end
            end
            top = top - 1
        end
        if trace_charstrings then
            showstate("stem")
        end
        stems = stems + top/2
        top   = 0
    end

    local function getmask()
        if top == 0 then
            -- bad
        elseif top % 2 ~= 0 then
            if width then
                remove(stack,1)
            else
                width = remove(stack,1)
                if trace_charstrings then
                    showvalue("width",width)
                end
            end
            top = top - 1
        end
        if trace_charstrings then
            showstate(operator == 19 and "hintmark" or "cntrmask")
        end
        stems = stems + top/2
        top   = 0
        if stems == 0 then
            -- forget about it
        elseif stems <= 8 then
            return 1
        else
            return floor((stems+7)/8)
        end
    end

    local function unsupported(t)
        if trace_charstrings then
            showstate("unsupported " .. t)
        end
        top = 0
    end

    local function unsupportedsub(t)
        if trace_charstrings then
            showstate("unsupported sub " .. t)
        end
        top = 0
    end

    -- type 1 (not used in type 2)

    local function getstem3()
        if trace_charstrings then
            showstate("stem3")
        end
        top = 0
    end

    local function divide()
        if version == 1 then
            local d = stack[top]
            top = top - 1
            stack[top] = stack[top] / d
        end
    end

    local function closepath()
        if version == 1 then
            if trace_charstrings then
                showstate("closepath")
            end
        end
        top = 0
    end

    local function hsbw()
        if version == 1 then
            if trace_charstrings then
                showstate("dotsection")
            end
            width = stack[top]
        end
        top = 0
    end

    local function seac()
        if version == 1 then
            if trace_charstrings then
                showstate("seac")
            end
        end
        top = 0
    end

    local function sbw()
        if version == 1 then
            if trace_charstrings then
                showstate("sbw")
            end
            width = stack[top-1]
        end
        top = 0
    end

    -- these are probably used for special cases i.e. call out to postscript

    local function callothersubr()
        if version == 1 then
            -- we don't support this (ok, we could mimick these othersubs)
            if trace_charstrings then
                showstate("callothersubr (unsupported)")
            end
        end
        top = 0
    end

    local function pop()
        if version == 1 then
            -- we don't support this
            if trace_charstrings then
                showstate("pop (unsupported)")
            end
            top = top + 1
            stack[top] = 0 -- a dummy
        else
            top = 0
        end
    end

    local function setcurrentpoint()
        if version == 1 then
            -- we don't support this
            if trace_charstrings then
                showstate("pop (unsupported)")
            end
            x = x + stack[top-1]
            y = y + stack[top]
        end
        top = 0
    end

    -- so far for unsupported postscript

    -- Bah, we cannot use a fast lpeg because a hint has an unknown size and a
    -- runtime capture cannot handle that well.

    local actions = { [0] =
        unsupported,  --  0
        getstem,      --  1 -- hstem
        unsupported,  --  2
        getstem,      --  3 -- vstem
        vmoveto,      --  4
        rlineto,      --  5
        hlineto,      --  6
        vlineto,      --  7
        rrcurveto,    --  8
        unsupported,  --  9 -- closepath
        unsupported,  -- 10 -- calllocal,
        unsupported,  -- 11 -- callreturn,
        unsupported,  -- 12 -- elsewhere
        hsbw,         -- 13 -- hsbw (type 1 cff)
        unsupported,  -- 14 -- endchar,
        unsupported,  -- 15
        unsupported,  -- 16
        unsupported,  -- 17
        getstem,      -- 18 -- hstemhm
        getmask,      -- 19 -- hintmask
        getmask,      -- 20 -- cntrmask
        rmoveto,      -- 21
        hmoveto,      -- 22
        getstem,      -- 23 -- vstemhm
        rcurveline,   -- 24
        rlinecurve,   -- 25
        vvcurveto,    -- 26
        hhcurveto,    -- 27
        unsupported,  -- 28 -- elsewhere
        unsupported,  -- 29 -- elsewhere
        vhcurveto,    -- 30
        hvcurveto,    -- 31
    }

    local subactions = {
        -- cff 1
        [000] = dotsection,
        [001] = getstem3,
        [002] = getstem3,
        [006] = seac,
        [007] = sbw,
        [012] = divide,
        [016] = callothersubr,
        [017] = pop,
        [033] = setcurrentpoint,
        -- cff 2
        [034] = hflex,
        [035] = flex,
        [036] = hflex1,
        [037] = flex1,
    }

    local p_bytes = Ct((P(1)/byte)^0)

    local function call(scope,list,bias,process)
        depth = depth + 1
        if top == 0 then
            showstate(formatters["unknown %s call"](scope))
            top = 0
        else
            local index = stack[top] + bias
            top = top - 1
            if trace_charstrings then
                showvalue(scope,index,true)
            end
            local tab = list[index]
            if tab then
                if type(tab) == "string" then
                    tab = lpegmatch(p_bytes,tab)
                    list[index] = tab
                end
                process(tab)
            else
                showstate(formatters["unknown %s call %i"](scope,index))
                top = 0
            end
        end
        depth = depth - 1
    end

    local function process(tab)
        local i = 1
        local n = #tab
        while i <= n do
            local t = tab[i]
            if t >= 32 and t <= 246 then
                -- -107 .. +107
                top = top + 1
                stack[top] = t - 139
                i = i + 1
            elseif t >= 247 and t <= 250 then
                -- +108 .. +1131
                top = top + 1
                stack[top] = (t-247)*256 + tab[i+1] + 108
                i = i + 2
            elseif t >= 251 and t <= 254 then
                -- -1131 .. -108
                top = top + 1
                stack[top] = -(t-251)*256 - tab[i+1] - 108
                i = i + 2
            elseif t == 28 then
                -- -32768 .. +32767 : b1<<8 | b2
                top = top + 1
                local n = 0x100 * tab[i+1] + tab[i+2]
                if n  >= 0x8000 then
                    stack[top] = n - 0xFFFF - 1
                else
                    stack[top] = n
                end
                i = i + 3
            elseif t == 255 then
                local n = 0x100 * tab[i+1] + tab[i+2]
                top = top + 1
                if n  >= 0x8000 then
                    stack[top] = n - 0xFFFF - 1 + (0x100 * tab[i+3] + tab[i+4])/0xFFFF
                else
                    stack[top] = n              + (0x100 * tab[i+3] + tab[i+4])/0xFFFF
                end
                i = i + 5
           elseif t == 11 then
                if trace_charstrings then
                    showstate("return")
                end
                return
            elseif t == 10 then
                call("local",locals,localbias,process)
                i = i + 1
             elseif t == 14 then -- endchar
                if width then
                    -- okay
                elseif top > 0 then
                    width = stack[1]
                    if trace_charstrings then
                        showvalue("width",width)
                    end
                else
                    width = true
                end
                if trace_charstrings then
                    showstate("endchar")
                end
                return
            elseif t == 29 then
                call("global",globals,globalbias,process)
                i = i + 1
            elseif t == 12 then
                i = i + 1
                local t = tab[i]
                local a = subactions[t]
                if a then
                    a(t)
                else
                    if trace_charstrings then
                        showvalue("<subaction>",t)
                    end
                    top = 0
                end
                i = i + 1
            else
                local a = actions[t]
                if a then
                    local s = a(t)
                    if s then
                        i = i + s
                    end
                else
                    if trace_charstrings then
                        showvalue("<action>",t)
                    end
                    top = 0
                end
                i = i + 1
            end
        end
    end

 -- local function calculatebounds(segments,x,y)
 --     local nofsegments = #segments
 --     if nofsegments == 0 then
 --         return { x, y, x, y }
 --     else
 --         local xmin =  10000
 --         local xmax = -10000
 --         local ymin =  10000
 --         local ymax = -10000
 --         if x < xmin then xmin = x end
 --         if x > xmax then xmax = x end
 --         if y < ymin then ymin = y end
 --         if y > ymax then ymax = y end
 --         -- we now have a reasonable start so we could
 --         -- simplyfy the next checks
 --         for i=1,nofsegments do
 --             local s = segments[i]
 --             local x = s[1]
 --             local y = s[2]
 --             if x < xmin then xmin = x end
 --             if x > xmax then xmax = x end
 --             if y < ymin then ymin = y end
 --             if y > ymax then ymax = y end
 --             if s[#s] == "c" then -- "curveto"
 --                 local x = s[3]
 --                 local y = s[4]
 --                 if x < xmin then xmin = x elseif x > xmax then xmax = x end
 --                 if y < ymin then ymin = y elseif y > ymax then ymax = y end
 --                 local x = s[5]
 --                 local y = s[6]
 --                 if x < xmin then xmin = x elseif x > xmax then xmax = x end
 --                 if y < ymin then ymin = y elseif y > ymax then ymax = y end
 --             end
 --         end
 --         return { round(xmin), round(ymin), round(xmax), round(ymax) } -- doesn't make ceil more sense
 --     end
 -- end

    local function setbias(globals,locals)
        if version == 1 then
            return
                false,
                false
        else
            local g, l = #globals, #locals
            return
                ((g <  1240 and 107) or (g < 33900 and 1131) or 32768) + 1,
                ((l <  1240 and 107) or (l < 33900 and 1131) or 32768) + 1
        end
    end

    parsecharstrings = function(data,glyphs,doshapes,tversion)
        -- for all charstrings
        local dictionary  = data.dictionaries[1]
        local charstrings = dictionary.charstrings
        local charset     = dictionary.charset
        local private     = dictionary.private or { data = { } }

        keepcurve  = doshapes
        version    = tversion
        stack      = { }
        glyphs     = glyphs or { }
        strings    = data.strings
        globals    = data.routines or { }
        locals     = dictionary.subroutines or { }

        globalbias, localbias = setbias(globals,locals)

        local nominalwidth = private.data.nominalwidthx or 0
        local defaultwidth = private.data.defaultwidthx or 0

        for i=1,#charstrings do
            local tab = charstrings[i]
            if type(tab) == "string" then
                tab = lpegmatch(p_bytes,tab)
            end
            local index = i - 1
            x       = 0
            y       = 0
            width   = false
            r       = 0
            top     = 0
            stems   = 0
            result  = { }
            --
            xmin    = 0
            xmax    = 0
            ymin    = 0
            ymax    = 0
            checked = false
            --
            if trace_charstrings then
                report("glyph: %i",index)
                report("data: % t",tab)
            end
            --
            process(tab)
            --
            local boundingbox = { round(xmin), round(ymin), round(xmax), round(ymax) }
            --
            if width == true or width == false then
                width = defaultwidth
            else
                width = nominalwidth + width
            end
            --
         -- trace_charstrings = index == 3078 -- todo: make tracker
            local glyph = glyphs[index] -- can be autodefined in otr
            if not glyph then
                glyphs[index] = {
                    segments    = doshapes ~= false and result or nil, -- optional
                    boundingbox = boundingbox,
                    width       = width,
                    name        = charset[index],
                 -- sidebearing = 0,
                }
            else
                glyph.segments    = doshapes ~= false and result or nil
                glyph.boundingbox = boundingbox
                if not glyph.width then
                    glyph.width = width
                end
                if charset and not glyph.name then
                    glyph.name = charset[index]
                end
             -- glyph.sidebearing = 0 -- todo
            end
            if trace_charstrings then
                report("width: %s",tostring(width))
                report("boundingbox: % t",boundingbox)
            end
            charstrings[i] = nil -- free memory
        end
        return glyphs
    end

    parsecharstring = function(data,dictionary,tab,glyphs,index,doshapes,tversion)
        local private = dictionary.private
        keepcurve  = doshapes
        version    = tversion
        strings    = data.strings -- or in dict?
        locals     = dictionary.subroutines or { }
        globals    = data.routines or { }

        globalbias, localbias = setbias(globals,locals)

        local nominalwidth = private and private.data.nominalwidthx or 0
        local defaultwidth = private and private.data.defaultwidthx or 0
        --
        if type(tab) == "string" then
            tab = lpegmatch(p_bytes,tab)
        end
        --
        x         = 0
        y         = 0
        width     = false
        r         = 0
        top       = 0
        stems     = 0
        result    = { }
        --
        xmin      = 0
        xmax      = 0
        ymin      = 0
        ymax      = 0
        checked   = false
        --
        if trace_charstrings then
            report("glyph: %i",index)
            report("data: % t",tab)
        end
        --
        process(tab)
        --
        local boundingbox = { xmin, ymin, xmax, ymax }
        --
        if width == true or width == false then
            width = defaultwidth
        else
            width = nominalwidth + width
        end
        --
        index = index - 1
        --
        local glyph = glyphs[index] -- can be autodefined in otr
        if not glyph then
            glyphs[index] = {
                segments    = doshapes ~= false and result or nil, -- optional
                boundingbox = boundingbox,
                width       = width,
                name        = charset[index],
             -- sidebearing = 0,
            }
        else
            glyph.segments    = doshapes ~= false and result or nil
            glyph.boundingbox = boundingbox
            if not glyph.width then
                glyph.width = width
            end
            if charset and not glyph.name then
                glyph.name = charset[index]
            end
         -- glyph.sidebearing = 0 -- todo
        end
        --
        if trace_charstrings then
            report("width: %s",tostring(width))
            report("boundingbox: % t",boundingbox)
        end
    end

    resetcharstrings = function()
        result = { }
        top    = 0
        stack  = { }
    end

end

local function readglobals(f,data)
    local routines = readlengths(f)
    for i=1,#routines do
        routines[i] = readstring(f,routines[i])
    end
    data.routines = routines
end

local function readencodings(f,data)
    data.encodings = { }
end

local function readcharsets(f,data,dictionary)
    local header        = data.header
    local strings       = data.strings
    local nofglyphs     = data.nofglyphs
    local charsetoffset = dictionary.charset

    if charsetoffset ~= 0 then
        setposition(f,header.offset+charsetoffset)
        local format       = readbyte(f)
        local charset      = { [0] = ".notdef" }
        dictionary.charset = charset
        if format == 0 then
            for i=1,nofglyphs do
                charset[i] = strings[readushort(f)]
            end
        elseif format == 1 or format == 2 then
            local readcount = format == 1 and readbyte or readushort
            local i = 1
            while i <= nofglyphs do
                local sid = readushort(f)
                local n   = readcount(f)
                for s=sid,sid+n do
                    charset[i] = strings[s]
                    i = i + 1
                    if i > nofglyphs then
                        break
                    end
                end
            end
        else
            report("cff parser: unsupported charset format %a",format)
        end
    end
end

local function readprivates(f,data)
    local header       = data.header
    local dictionaries = data.dictionaries
    local private      = dictionaries[1].private
    if private then
        setposition(f,header.offset+private.offset)
        private.data = readstring(f,private.size)
    end
end

local function readlocals(f,data,dictionary)
    local header  = data.header
    local private = dictionary.private
    if private then
        local subroutineoffset = private.data.subroutines
        if subroutineoffset ~= 0 then
            setposition(f,header.offset+private.offset+subroutineoffset)
            local subroutines = readlengths(f)
            for i=1,#subroutines do
                subroutines[i] = readstring(f,subroutines[i])
            end
            dictionary.subroutines = subroutines
            private.data.subroutines = nil
        else
            dictionary.subroutines = { }
        end
    else
        dictionary.subroutines = { }
    end
end

-- These charstrings are little programs and described in: Technical Note #5177. A truetype
-- font has only one dictionary.

local function readcharstrings(f,data)
    local header       = data.header
    local dictionaries = data.dictionaries
    local dictionary   = dictionaries[1]
    local type         = dictionary.charstringtype
    local offset       = dictionary.charstrings
    if type == 2 then
        setposition(f,header.offset+offset)
        -- could be a metatable .. delayed loading
        local charstrings = readlengths(f)
        local nofglyphs   = #charstrings
        for i=1,nofglyphs do
            charstrings[i] = readstring(f,charstrings[i])
        end
        data.nofglyphs         = nofglyphs
        dictionary.charstrings = charstrings
    else
        report("unsupported charstr type %i",type)
        data.nofglyphs         = 0
        dictionary.charstrings = { }
    end
end

-- cid (maybe do this stepwise so less mem) -- share with above

local function readcidprivates(f,data)
    local header       = data.header
    local dictionaries = data.dictionaries[1].cid.dictionaries
    for i=1,#dictionaries do
        local dictionary = dictionaries[i]
        local private    = dictionary.private
        if private then
            setposition(f,header.offset+private.offset)
            private.data = readstring(f,private.size)
        end
    end
    parseprivates(data,dictionaries)
end

local function readnoselect(f,data,glyphs,doshapes,version)
    local dictionaries = data.dictionaries
    local dictionary   = dictionaries[1]
    readglobals(f,data)
    readcharstrings(f,data)
    readencodings(f,data)
    readcharsets(f,data,dictionary)
    readprivates(f,data)
    parseprivates(data,data.dictionaries)
    readlocals(f,data,dictionary)
    parsecharstrings(data,glyphs,doshapes,version)
    resetcharstrings()
end

readers.parsecharstrings = parsecharstrings

local function readfdselect(f,data,glyphs,doshapes,version)
    local header       = data.header
    local dictionaries = data.dictionaries
    local dictionary   = dictionaries[1]
    local cid          = dictionary.cid
    local cidselect    = cid and cid.fdselect
    readglobals(f,data)
    readcharstrings(f,data)
    readencodings(f,data)
    local charstrings  = dictionary.charstrings
    local fdindex      = { }
    local nofglyphs    = data.nofglyphs
    local maxindex     = -1
    setposition(f,header.offset+cidselect)
    local format       = readbyte(f)
    if format == 1 then
        for i=0,nofglyphs do -- notdef included (needs checking)
            local index = readbyte(i)
            fdindex[i] = index
            if index > maxindex then
                maxindex = index
            end
        end
    elseif format == 3 then
        local nofranges = readushort(f)
        local first     = readushort(f)
        local index     = readbyte(f)
        while true do
            local last = readushort(f)
            if index > maxindex then
                maxindex = index
            end
            for i=first,last do
                fdindex[i] = index
            end
            if last >= nofglyphs then
                break
            else
                first = last + 1
                index = readbyte(f)
            end
        end
    else
        -- unsupported format
    end
    if maxindex >= 0 then
        local cidarray = cid.fdarray
        setposition(f,header.offset+cidarray)
        local dictionaries = readlengths(f)
        for i=1,#dictionaries do
            dictionaries[i] = readstring(f,dictionaries[i])
        end
        parsedictionaries(data,dictionaries)
        cid.dictionaries = dictionaries
        readcidprivates(f,data)
        for i=1,#dictionaries do
            readlocals(f,data,dictionaries[i])
        end
        for i=1,#charstrings do
            parsecharstring(data,dictionaries[fdindex[i]+1],charstrings[i],glyphs,i,doshapes,version)
        end
        resetcharstrings()
    end
end

function readers.cff(f,fontdata,specification)
--     if specification.glyphs then
    if specification.details then
        local datatable = fontdata.tables.cff
        if datatable then
            local offset = datatable.offset
            local glyphs = fontdata.glyphs
            if not f then
                report("invalid filehandle")
                return
            end
            if offset then
                setposition(f,offset)
            end
            local header = readheader(f)
            if header.major > 1 then
                report("version mismatch")
                return
            end
            local names        = readfontnames(f)
            local dictionaries = readtopdictionaries(f)
            local strings      = readstrings(f)
            local data = {
                header       = header,
                names        = names,
                dictionaries = dictionaries,
                strings      = strings,
                nofglyphs    = fontdata.nofglyphs,
            }
            --
            parsedictionaries(data,data.dictionaries)
            --
            local d = dictionaries[1]
            local c = d.cid
            fontdata.cffinfo = {
                familynamename     = d.familyname,
                fullname           = d.fullname,
                boundingbox        = d.boundingbox,
                weight             = d.weight,
                italicangle        = d.italicangle,
                underlineposition  = d.underlineposition,
                underlinethickness = d.underlinethickness,
                monospaced         = d.monospaced,
            }
            fontdata.cidinfo = c and {
                registry   = c.registry,
                ordering   = c.ordering,
                supplement = c.supplement,
            }
            --
            if not specification.glyphs then
                -- we only want some metadata
            else
                local cid = d.cid
                if cid and cid.fdselect then
                    readfdselect(f,data,glyphs,specification.shapes or false)
                else
                    readnoselect(f,data,glyphs,specification.shapes or false)
                end
            end
            --
            -- cleanup (probably more can go)
            --
         -- for i=1,#dictionaries do
         --     local d = dictionaries[i]
         --     d.subroutines = nil
         -- end
         -- data.strings = nil
         -- if data then
         --     data.charstrings  = nil
         --     data.routines     = nil
         -- end
        end
    end
end
