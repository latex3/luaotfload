if not modules then modules = { } end modules ["features"] = {
    version   = "2.7",
    comment   = "companion to luaotfload-main.lua",
    author    = "Hans Hagen, Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type              = type
local next              = next
local tonumber          = tonumber
local tostring          = tostring

local lpeg              = require "lpeg"
local lpegmatch         = lpeg.match
local P                 = lpeg.P
local R                 = lpeg.R
local C                 = lpeg.C

local table             = table
local tabletohash       = table.tohash
local tablesort         = table.sort
local setmetatableindex = table.setmetatableindex
local insert            = table.insert

---[[ begin included font-ltx.lua ]]
--- this appears to be based in part on luatex-fonts-def.lua

local fonts             = fonts
local definers          = fonts.definers
local handlers          = fonts.handlers
local fontidentifiers   = fonts.hashes and fonts.hashes.identifiers

local config            = config or { luaotfload = { run = { } } }

local as_script         = true
local normalize         = function () end

if config.luaotfload.run.live ~= false then
    normalize = handlers.otf.features.normalize
    as_script = false
end

--HH A bit of tuning for definitions.

if fonts.constructors then
    fonts.constructors.namemode = "specification" -- somehow latex needs this (changed name!) => will change into an overload
end

--[[HH--
    tricky: we sort of bypass the parser and directly feed all into
    the sub parser
--HH]]--

function fonts.definers.getspecification(str)
    return "", str, "", ":", str
end

local log              = luaotfload.log
local report           = log.report

local stringfind       = string.find
local stringlower      = string.lower
local stringgsub       = string.gsub
local stringsub        = string.sub
local stringformat     = string.format
local stringis_empty   = string.is_empty
local mathceil         = math.ceil

local cmp_by_idx = function (a, b) return a.idx < b.idx end

local defined_combos = 0

local handle_combination = function (combo, spec)
    defined_combos = defined_combos + 1
    if not combo [1] then
        report ("both", 0, "features",
                "combo %d: Empty font combination requested.",
                defined_combos)
        return false
    end

    if not fontidentifiers then
        fontidentifiers = fonts.hashes and fonts.hashes.identifiers
    end

    local chain   = { }
    local fontids = { }
    local n       = #combo

    tablesort (combo, cmp_by_idx)

    --- pass 1: skim combo and resolve fonts
    report ("both", 2, "features", "combo %d: combining %d fonts.",
            defined_combos, n)
    for i = 1, n do
        local cur = combo [i]
        local id  = cur.id
        local idx = cur.idx
        local fnt = fontidentifiers [id]
        if fnt then
            local chars = cur.chars
            if chars == true then
                report ("both", 2, "features",
                        " *> %.2d: fallback font %d at rank %d.",
                        i, id, idx)
            else
                report ("both", 2, "features",
                        " *> %.2d: include font %d at rank %d (%d items).",
                        i, id, idx, (chars and #chars or 0))
            end
            chain   [#chain + 1]   = { fnt, chars, idx = idx }
            fontids [#fontids + 1] = { id = id }
        else
            report ("both", 0, "features",
                    " *> %.2d: font %d at rank %d unknown, skipping.",
                    n, id, idx)
            --- TODO might instead attempt to define the font at this point
            ---      but that’d require some modifications to the syntax
        end
    end

    local nc = #chain
    if nc == 0 then
        report ("both", 0, "features",
                " *> no valid font (of %d) in combination.", n)
        return false
    end

    local basefnt = chain [1] [1]
    if nc == 1 then
        report ("both", 0, "features",
                " *> combination boils down to a single font (%s) \z
                 of %d initially specified; not pursuing this any \z
                 further.", basefnt.fullname, n)
        return basefnt
    end

    local basechar       = basefnt.characters
    local baseprop       = basefnt.properties
    baseprop.name        = spec.name
    baseprop.virtualized = true
    basefnt.fonts        = fontids

    for i = 2, nc do
        local cur = chain [i]
        local fnt = cur [1]
        local def = cur [2]
        local src = fnt.characters
        local cnt = 0

        local pickchr = function (uc, unavailable)
            local chr = src [uc]
            if unavailable == true and basechar [uc] then
                --- fallback mode: already known
                return
            end
            if chr then
                chr.commands = { { "slot", i, uc } }
                basechar [uc] = chr
                cnt = cnt + 1
            end
        end

        if def == true then --> fallback; grab all currently unavailable
            for uc, _chr in next, src do pickchr (uc, true) end
        else --> grab only defined range
            for j = 1, #def do
                local this = def [j]
                if type (this) == "number" then
                    report ("both", 2, "features",
                            " *> [%d][%d]: import codepoint U+%.4X",
                            i, j, this)
                    pickchr (this)
                elseif type (this) == "table" then
                    local lo, hi = unpack (this)
                    report ("both", 2, "features",
                            " *> [%d][%d]: import codepoint range U+%.4X--U+%.4X",
                            i, j, lo, hi)
                    for uc = lo, hi do pickchr (uc) end
                else
                    report ("both", 0, "features",
                            " *> item no. %d of combination definition \z
                             %d not processable.", j, i)
                end
            end
        end
        report ("both", 2, "features",
                " *> font %d / %d: imported %d glyphs into combo.",
                i, nc, cnt)
    end
    spec.lookup     = "combo"
    spec.file       = basefnt.filename
    spec.name       = stringformat ("luaotfload<%d>", defined_combos)
    spec.features   = { normal = { spec.specification } }
    spec.forced     = "evl"
    spec.eval       = function () return basefnt end
    return spec
end

---[[ begin excerpt from font-ott.lua ]]

local scripts = {
    ["arab"] = "arabic",
    ["armn"] = "armenian",
    ["bali"] = "balinese",
    ["beng"] = "bengali",
    ["bopo"] = "bopomofo",
    ["brai"] = "braille",
    ["bugi"] = "buginese",
    ["buhd"] = "buhid",
    ["byzm"] = "byzantine music",
    ["cans"] = "canadian syllabics",
    ["cher"] = "cherokee",
    ["copt"] = "coptic",
    ["cprt"] = "cypriot syllabary",
    ["cyrl"] = "cyrillic",
    ["deva"] = "devanagari",
    ["dsrt"] = "deseret",
    ["ethi"] = "ethiopic",
    ["geor"] = "georgian",
    ["glag"] = "glagolitic",
    ["goth"] = "gothic",
    ["grek"] = "greek",
    ["gujr"] = "gujarati",
    ["guru"] = "gurmukhi",
    ["hang"] = "hangul",
    ["hani"] = "cjk ideographic",
    ["hano"] = "hanunoo",
    ["hebr"] = "hebrew",
    ["ital"] = "old italic",
    ["jamo"] = "hangul jamo",
    ["java"] = "javanese",
    ["kana"] = "hiragana and katakana",
    ["khar"] = "kharosthi",
    ["khmr"] = "khmer",
    ["knda"] = "kannada",
    ["lao" ] = "lao",
    ["latn"] = "latin",
    ["limb"] = "limbu",
    ["linb"] = "linear b",
    ["math"] = "mathematical alphanumeric symbols",
    ["mlym"] = "malayalam",
    ["mong"] = "mongolian",
    ["musc"] = "musical symbols",
    ["mymr"] = "myanmar",
    ["nko" ] = "n\"ko",
    ["ogam"] = "ogham",
    ["orya"] = "oriya",
    ["osma"] = "osmanya",
    ["phag"] = "phags-pa",
    ["phnx"] = "phoenician",
    ["runr"] = "runic",
    ["shaw"] = "shavian",
    ["sinh"] = "sinhala",
    ["sylo"] = "syloti nagri",
    ["syrc"] = "syriac",
    ["tagb"] = "tagbanwa",
    ["tale"] = "tai le",
    ["talu"] = "tai lu",
    ["taml"] = "tamil",
    ["telu"] = "telugu",
    ["tfng"] = "tifinagh",
    ["tglg"] = "tagalog",
    ["thaa"] = "thaana",
    ["thai"] = "thai",
    ["tibt"] = "tibetan",
    ["ugar"] = "ugaritic cuneiform",
    ["xpeo"] = "old persian cuneiform",
    ["xsux"] = "sumero-akkadian cuneiform",
    ["yi"  ] = "yi",
} -- [[ [scripts] ]]

local languages = {
    ["aba" ] = "abaza",
    ["abk" ] = "abkhazian",
    ["ach" ] = "acholi",
    ["acr" ] = "achi",
    ["ady" ] = "adyghe",
    ["afk" ] = "afrikaans",
    ["afr" ] = "afar",
    ["agw" ] = "agaw",
    ["aio" ] = "aiton",
    ["aka" ] = "akan",
    ["als" ] = "alsatian",
    ["alt" ] = "altai",
    ["amh" ] = "amharic",
    ["ang" ] = "anglo-saxon",
    ["apph"] = "phonetic transcription—americanist conventions",
    ["ara" ] = "arabic",
    ["arg" ] = "aragonese",
    ["ari" ] = "aari",
    ["ark" ] = "rakhine",
    ["asm" ] = "assamese",
    ["ast" ] = "asturian",
    ["ath" ] = "athapaskan",
    ["avr" ] = "avar",
    ["awa" ] = "awadhi",
    ["aym" ] = "aymara",
    ["azb" ] = "torki",
    ["aze" ] = "azerbaijani",
    ["bad" ] = "badaga",
    ["bad0"] = "banda",
    ["bag" ] = "baghelkhandi",
    ["bal" ] = "balkar",
    ["ban" ] = "balinese",
    ["bar" ] = "bavarian",
    ["bau" ] = "baulé",
    ["bbc" ] = "batak toba",
    ["bbr" ] = "berber",
    ["bch" ] = "bench",
    ["bcr" ] = "bible cree",
    ["bdy" ] = "bandjalang",
    ["bel" ] = "belarussian",
    ["bem" ] = "bemba",
    ["ben" ] = "bengali",
    ["bgc" ] = "haryanvi",
    ["bgq" ] = "bagri",
    ["bgr" ] = "bulgarian",
    ["bhi" ] = "bhili",
    ["bho" ] = "bhojpuri",
    ["bik" ] = "bikol",
    ["bil" ] = "bilen",
    ["bis" ] = "bislama",
    ["bjj" ] = "kanauji",
    ["bkf" ] = "blackfoot",
    ["bli" ] = "baluchi",
    ["blk" ] = "pa'o karen",
    ["bln" ] = "balante",
    ["blt" ] = "balti",
    ["bmb" ] = "bambara (bamanankan)",
    ["bml" ] = "bamileke",
    ["bos" ] = "bosnian",
    ["bpy" ] = "bishnupriya manipuri",
    ["bre" ] = "breton",
    ["brh" ] = "brahui",
    ["bri" ] = "braj bhasha",
    ["brm" ] = "burmese",
    ["brx" ] = "bodo",
    ["bsh" ] = "bashkir",
    ["bti" ] = "beti",
    ["bts" ] = "batak simalungun",
    ["bug" ] = "bugis",
    ["cak" ] = "kaqchikel",
    ["cat" ] = "catalan",
    ["cbk" ] = "zamboanga chavacano",
    ["ceb" ] = "cebuano",
    ["cgg" ] = "chiga",
    ["cha" ] = "chamorro",
    ["che" ] = "chechen",
    ["chg" ] = "chaha gurage",
    ["chh" ] = "chattisgarhi",
    ["chi" ] = "chichewa (chewa, nyanja)",
    ["chk" ] = "chukchi",
    ["chk0"] = "chuukese",
    ["cho" ] = "choctaw",
    ["chp" ] = "chipewyan",
    ["chr" ] = "cherokee",
    ["chu" ] = "chuvash",
    ["chy" ] = "cheyenne",
    ["cmr" ] = "comorian",
    ["cop" ] = "coptic",
    ["cor" ] = "cornish",
    ["cos" ] = "corsican",
    ["cpp" ] = "creoles",
    ["cre" ] = "cree",
    ["crr" ] = "carrier",
    ["crt" ] = "crimean tatar",
    ["csb" ] = "kashubian",
    ["csl" ] = "church slavonic",
    ["csy" ] = "czech",
    ["ctg" ] = "chittagonian",
    ["cuk" ] = "san blas kuna",
    ["dan" ] = "danish",
    ["dar" ] = "dargwa",
    ["dax" ] = "dayi",
    ["dcr" ] = "woods cree",
    ["deu" ] = "german",
    ["dgo" ] = "dogri",
    ["dgr" ] = "dogri",
    ["dhg" ] = "dhangu",
    ["dhv" ] = "divehi (dhivehi, maldivian)",
    ["diq" ] = "dimli",
    ["div" ] = "divehi (dhivehi, maldivian)",
    ["djr" ] = "zarma",
    ["djr0"] = "djambarrpuyngu",
    ["dng" ] = "dangme",
    ["dnj" ] = "dan",
    ["dnk" ] = "dinka",
    ["dri" ] = "dari",
    ["duj" ] = "dhuwal",
    ["dun" ] = "dungan",
    ["dzn" ] = "dzongkha",
    ["ebi" ] = "ebira",
    ["ecr" ] = "eastern cree",
    ["edo" ] = "edo",
    ["efi" ] = "efik",
    ["ell" ] = "greek",
    ["emk" ] = "eastern maninkakan",
    ["eng" ] = "english",
    ["erz" ] = "erzya",
    ["esp" ] = "spanish",
    ["esu" ] = "central yupik",
    ["eti" ] = "estonian",
    ["euq" ] = "basque",
    ["evk" ] = "evenki",
    ["evn" ] = "even",
    ["ewe" ] = "ewe",
    ["fan" ] = "french antillean",
    ["fan0"] = " fang",
    ["far" ] = "persian",
    ["fat" ] = "fanti",
    ["fin" ] = "finnish",
    ["fji" ] = "fijian",
    ["fle" ] = "dutch (flemish)",
    ["fne" ] = "forest nenets",
    ["fon" ] = "fon",
    ["fos" ] = "faroese",
    ["fra" ] = "french",
    ["frc" ] = "cajun french",
    ["fri" ] = "frisian",
    ["frl" ] = "friulian",
    ["frp" ] = "arpitan",
    ["fta" ] = "futa",
    ["ful" ] = "fulah",
    ["fuv" ] = "nigerian fulfulde",
    ["gad" ] = "ga",
    ["gae" ] = "scottish gaelic (gaelic)",
    ["gag" ] = "gagauz",
    ["gal" ] = "galician",
    ["gar" ] = "garshuni",
    ["gaw" ] = "garhwali",
    ["gez" ] = "ge'ez",
    ["gih" ] = "githabul",
    ["gil" ] = "gilyak",
    ["gil0"] = " kiribati (gilbertese)",
    ["gkp" ] = "kpelle (guinea)",
    ["glk" ] = "gilaki",
    ["gmz" ] = "gumuz",
    ["gnn" ] = "gumatj",
    ["gog" ] = "gogo",
    ["gon" ] = "gondi",
    ["grn" ] = "greenlandic",
    ["gro" ] = "garo",
    ["gua" ] = "guarani",
    ["guc" ] = "wayuu",
    ["guf" ] = "gupapuyngu",
    ["guj" ] = "gujarati",
    ["guz" ] = "gusii",
    ["hai" ] = "haitian (haitian creole)",
    ["hal" ] = "halam",
    ["har" ] = "harauti",
    ["hau" ] = "hausa",
    ["haw" ] = "hawaiian",
    ["hay" ] = "haya",
    ["haz" ] = "hazaragi",
    ["hbn" ] = "hammer-banna",
    ["her" ] = "herero",
    ["hil" ] = "hiligaynon",
    ["hin" ] = "hindi",
    ["hma" ] = "high mari",
    ["hmn" ] = "hmong",
    ["hmo" ] = "hiri motu",
    ["hnd" ] = "hindko",
    ["ho"  ] = "ho",
    ["hri" ] = "harari",
    ["hrv" ] = "croatian",
    ["hun" ] = "hungarian",
    ["hye" ] = "armenian",
    ["hye0"] = "armenian east",
    ["iba" ] = "iban",
    ["ibb" ] = "ibibio",
    ["ibo" ] = "igbo",
    ["ido" ] = "ido",
    ["ijo" ] = "ijo languages",
    ["ile" ] = "interlingue",
    ["ilo" ] = "ilokano",
    ["ina" ] = "interlingua",
    ["ind" ] = "indonesian",
    ["ing" ] = "ingush",
    ["inu" ] = "inuktitut",
    ["ipk" ] = "inupiat",
    ["ipph"] = "phonetic transcription—ipa conventions",
    ["iri" ] = "irish",
    ["irt" ] = "irish traditional",
    ["isl" ] = "icelandic",
    ["ism" ] = "inari sami",
    ["ita" ] = "italian",
    ["iwr" ] = "hebrew",
    ["jam" ] = "jamaican creole",
    ["jan" ] = "japanese",
    ["jav" ] = "javanese",
    ["jbo" ] = "lojban",
    ["jii" ] = "yiddish",
    ["jud" ] = "ladino",
    ["jul" ] = "jula",
    ["kab" ] = "kabardian",
    ["kab0"] = "kabyle",
    ["kac" ] = "kachchi",
    ["kal" ] = "kalenjin",
    ["kan" ] = "kannada",
    ["kar" ] = "karachay",
    ["kat" ] = "georgian",
    ["kaz" ] = "kazakh",
    ["kde" ] = "makonde",
    ["kea" ] = "kabuverdianu (crioulo)",
    ["keb" ] = "kebena",
    ["kek" ] = "kekchi",
    ["kge" ] = "khutsuri georgian",
    ["kha" ] = "khakass",
    ["khk" ] = "khanty-kazim",
    ["khm" ] = "khmer",
    ["khs" ] = "khanty-shurishkar",
    ["kht" ] = "khamti shan",
    ["khv" ] = "khanty-vakhi",
    ["khw" ] = "khowar",
    ["kik" ] = "kikuyu (gikuyu)",
    ["kir" ] = "kirghiz (kyrgyz)",
    ["kis" ] = "kisii",
    ["kiu" ] = "kirmanjki",
    ["kjd" ] = "southern kiwai",
    ["kjp" ] = "eastern pwo karen",
    ["kkn" ] = "kokni",
    ["klm" ] = "kalmyk",
    ["kmb" ] = "kamba",
    ["kmn" ] = "kumaoni",
    ["kmo" ] = "komo",
    ["kms" ] = "komso",
    ["knr" ] = "kanuri",
    ["kod" ] = "kodagu",
    ["koh" ] = "korean old hangul",
    ["kok" ] = "konkani",
    ["kom" ] = "komi",
    ["kon" ] = "kikongo",
    ["kon0"] = "kongo",
    ["kop" ] = "komi-permyak",
    ["kor" ] = "korean",
    ["kos" ] = "kosraean",
    ["koz" ] = "komi-zyrian",
    ["kpl" ] = "kpelle",
    ["kri" ] = "krio",
    ["krk" ] = "karakalpak",
    ["krl" ] = "karelian",
    ["krm" ] = "karaim",
    ["krn" ] = "karen",
    ["krt" ] = "koorete",
    ["ksh" ] = "kashmiri",
    ["ksh0"] = "ripuarian",
    ["ksi" ] = "khasi",
    ["ksm" ] = "kildin sami",
    ["ksw" ] = "s’gaw karen",
    ["kua" ] = "kuanyama",
    ["kui" ] = "kui",
    ["kul" ] = "kulvi",
    ["kum" ] = "kumyk",
    ["kur" ] = "kurdish",
    ["kuu" ] = "kurukh",
    ["kuy" ] = "kuy",
    ["kyk" ] = "koryak",
    ["kyu" ] = "western kayah",
    ["lad" ] = "ladin",
    ["lah" ] = "lahuli",
    ["lak" ] = "lak",
    ["lam" ] = "lambani",
    ["lao" ] = "lao",
    ["lat" ] = "latin",
    ["laz" ] = "laz",
    ["lcr" ] = "l-cree",
    ["ldk" ] = "ladakhi",
    ["lez" ] = "lezgi",
    ["lij" ] = "ligurian",
    ["lim" ] = "limburgish",
    ["lin" ] = "lingala",
    ["lis" ] = "lisu",
    ["ljp" ] = "lampung",
    ["lki" ] = "laki",
    ["lma" ] = "low mari",
    ["lmb" ] = "limbu",
    ["lmo" ] = "lombard",
    ["lmw" ] = "lomwe",
    ["lom" ] = "loma",
    ["lrc" ] = "luri",
    ["lsb" ] = "lower sorbian",
    ["lsm" ] = "lule sami",
    ["lth" ] = "lithuanian",
    ["ltz" ] = "luxembourgish",
    ["lua" ] = "luba-lulua",
    ["lub" ] = "luba-katanga",
    ["lug" ] = "ganda",
    ["luh" ] = "luyia",
    ["luo" ] = "luo",
    ["lvi" ] = "latvian",
    ["mad" ] = "madura",
    ["mag" ] = "magahi",
    ["mah" ] = "marshallese",
    ["maj" ] = "majang",
    ["mak" ] = "makhuwa",
    ["mal" ] = "malayalam reformed",
    ["mam" ] = "mam",
    ["man" ] = "mansi",
    ["map" ] = "mapudungun",
    ["mar" ] = "marathi",
    ["maw" ] = "marwari",
    ["mbn" ] = "mbundu",
    ["mch" ] = "manchu",
    ["mcr" ] = "moose cree",
    ["mde" ] = "mende",
    ["mdr" ] = "mandar",
    ["men" ] = "me'en",
    ["mer" ] = "meru",
    ["mfe" ] = "morisyen",
    ["min" ] = "minangkabau",
    ["miz" ] = "mizo",
    ["mkd" ] = "macedonian",
    ["mkr" ] = "makasar",
    ["mkw" ] = "kituba",
    ["mle" ] = "male",
    ["mlg" ] = "malagasy",
    ["mln" ] = "malinke",
    ["mly" ] = "malay",
    ["mnd" ] = "mandinka",
    ["mng" ] = "mongolian",
    ["mni" ] = "manipuri",
    ["mnk" ] = "maninka",
    ["mnx" ] = "manx",
    ["moh" ] = "mohawk",
    ["mok" ] = "moksha",
    ["mol" ] = "moldavian",
    ["mon" ] = "mon",
    ["mor" ] = "moroccan",
    ["mos" ] = "mossi",
    ["mri" ] = "maori",
    ["mth" ] = "maithili",
    ["mts" ] = "maltese",
    ["mun" ] = "mundari",
    ["mus" ] = "muscogee",
    ["mwl" ] = "mirandese",
    ["mww" ] = "hmong daw",
    ["myn" ] = "mayan",
    ["mzn" ] = "mazanderani",
    ["nag" ] = "naga-assamese",
    ["nah" ] = "nahuatl",
    ["nan" ] = "nanai",
    ["nap" ] = "neapolitan",
    ["nas" ] = "naskapi",
    ["nau" ] = "nauruan",
    ["nav" ] = "navajo",
    ["ncr" ] = "n-cree",
    ["ndb" ] = "ndebele",
    ["ndc" ] = "ndau",
    ["ndg" ] = "ndonga",
    ["nds" ] = "low saxon",
    ["nep" ] = "nepali",
    ["new" ] = "newari",
    ["nga" ] = "ngbaka",
    ["ngr" ] = "nagari",
    ["nhc" ] = "norway house cree",
    ["nis" ] = "nisi",
    ["niu" ] = "niuean",
    ["nkl" ] = "nyankole",
    ["nko" ] = "n'ko",
    ["nld" ] = "dutch",
    ["noe" ] = "nimadi",
    ["nog" ] = "nogai",
    ["nor" ] = "norwegian",
    ["nov" ] = "novial",
    ["nsm" ] = "northern sami",
    ["nso" ] = "sotho, northern",
    ["nta" ] = "northern tai",
    ["nto" ] = "esperanto",
    ["nym" ] = "nyamwezi",
    ["nyn" ] = "norwegian nynorsk",
    ["oci" ] = "occitan",
    ["ocr" ] = "oji-cree",
    ["ojb" ] = "ojibway",
    ["ori" ] = "odia",
    ["oro" ] = "oromo",
    ["oss" ] = "ossetian",
    ["paa" ] = "palestinian aramaic",
    ["pag" ] = "pangasinan",
    ["pal" ] = "pali",
    ["pam" ] = "pampangan",
    ["pan" ] = "punjabi",
    ["pap" ] = "palpa",
    ["pap0"] = "papiamentu",
    ["pas" ] = "pashto",
    ["pau" ] = "palauan",
    ["pcc" ] = "bouyei",
    ["pcd" ] = "picard",
    ["pdc" ] = "pennsylvania german",
    ["pgr" ] = "polytonic greek",
    ["phk" ] = "phake",
    ["pih" ] = "norfolk",
    ["pil" ] = "filipino",
    ["plg" ] = "palaung",
    ["plk" ] = "polish",
    ["pms" ] = "piemontese",
    ["pnb" ] = "western panjabi",
    ["poh" ] = "pocomchi",
    ["pon" ] = "pohnpeian",
    ["pro" ] = "provencal",
    ["ptg" ] = "portuguese",
    ["pwo" ] = "western pwo karen",
    ["qin" ] = "chin",
    ["quc" ] = "k’iche’",
    ["quh" ] = "quechua (bolivia)",
    ["quz" ] = "quechua",
    ["qvi" ] = "quechua (ecuador)",
    ["qwh" ] = "quechua (peru)",
    ["raj" ] = "rajasthani",
    ["rar" ] = "rarotongan",
    ["rbu" ] = "russian buriat",
    ["rcr" ] = "r-cree",
    ["rej" ] = "rejang",
    ["ria" ] = "riang",
    ["rif" ] = "tarifit",
    ["rit" ] = "ritarungo",
    ["rkw" ] = "arakwal",
    ["rms" ] = "romansh",
    ["rmy" ] = "vlax romani",
    ["rom" ] = "romanian",
    ["roy" ] = "romany",
    ["rsy" ] = "rusyn",
    ["rtm" ] = "rotuman",
    ["rua" ] = "kinyarwanda",
    ["run" ] = "rundi",
    ["rup" ] = "aromanian",
    ["rus" ] = "russian",
    ["sad" ] = "sadri",
    ["san" ] = "sanskrit",
    ["sas" ] = "sasak",
    ["sat" ] = "santali",
    ["say" ] = "sayisi",
    ["scn" ] = "sicilian",
    ["sco" ] = "scots",
    ["sek" ] = "sekota",
    ["sel" ] = "selkup",
    ["sga" ] = "old irish",
    ["sgo" ] = "sango",
    ["sgs" ] = "samogitian",
    ["shi" ] = "tachelhit",
    ["shn" ] = "shan",
    ["sib" ] = "sibe",
    ["sid" ] = "sidamo",
    ["sig" ] = "silte gurage",
    ["sks" ] = "skolt sami",
    ["sky" ] = "slovak",
    ["sla" ] = "slavey",
    ["slv" ] = "slovenian",
    ["sml" ] = "somali",
    ["smo" ] = "samoan",
    ["sna" ] = "sena",
    ["sna0"] = "shona",
    ["snd" ] = "sindhi",
    ["snh" ] = "sinhala (sinhalese)",
    ["snk" ] = "soninke",
    ["sog" ] = "sodo gurage",
    ["sop" ] = "songe",
    ["sot" ] = "sotho, southern",
    ["sqi" ] = "albanian",
    ["srb" ] = "serbian",
    ["srd" ] = "sardinian",
    ["srk" ] = "saraiki",
    ["srr" ] = "serer",
    ["ssl" ] = "south slavey",
    ["ssm" ] = "southern sami",
    ["stq" ] = "saterland frisian",
    ["suk" ] = "sukuma",
    ["sun" ] = "sundanese",
    ["sur" ] = "suri",
    ["sva" ] = "svan",
    ["sve" ] = "swedish",
    ["swa" ] = "swadaya aramaic",
    ["swk" ] = "swahili",
    ["swz" ] = "swati",
    ["sxt" ] = "sutu",
    ["sxu" ] = "upper saxon",
    ["syl" ] = "sylheti",
    ["syr" ] = "syriac",
    ["szl" ] = "silesian",
    ["tab" ] = "tabasaran",
    ["taj" ] = "tajiki",
    ["tam" ] = "tamil",
    ["tat" ] = "tatar",
    ["tcr" ] = "th-cree",
    ["tdd" ] = "dehong dai",
    ["tel" ] = "telugu",
    ["tet" ] = "tetum",
    ["tgl" ] = "tagalog",
    ["tgn" ] = "tongan",
    ["tgr" ] = "tigre",
    ["tgy" ] = "tigrinya",
    ["tha" ] = "thai",
    ["tht" ] = "tahitian",
    ["tib" ] = "tibetan",
    ["tiv" ] = "tiv",
    ["tkm" ] = "turkmen",
    ["tmh" ] = "tamashek",
    ["tmn" ] = "temne",
    ["tna" ] = "tswana",
    ["tne" ] = "tundra nenets",
    ["tng" ] = "tonga",
    ["tod" ] = "todo",
    ["tod0"] = "toma",
    ["tpi" ] = "tok pisin",
    ["trk" ] = "turkish",
    ["tsg" ] = "tsonga",
    ["tua" ] = "turoyo aramaic",
    ["tul" ] = "tulu",
    ["tuv" ] = "tuvin",
    ["tvl" ] = "tuvalu",
    ["twi" ] = "twi",
    ["tyz" ] = "tày",
    ["tzm" ] = "tamazight",
    ["tzo" ] = "tzotzil",
    ["udm" ] = "udmurt",
    ["ukr" ] = "ukrainian",
    ["umb" ] = "umbundu",
    ["urd" ] = "urdu",
    ["usb" ] = "upper sorbian",
    ["uyg" ] = "uyghur",
    ["uzb" ] = "uzbek",
    ["vec" ] = "venetian",
    ["ven" ] = "venda",
    ["vit" ] = "vietnamese",
    ["vol" ] = "volapük",
    ["vro" ] = "võro",
    ["wa"  ] = "wa",
    ["wag" ] = "wagdi",
    ["war" ] = "waray-waray",
    ["wcr" ] = "west-cree",
    ["wel" ] = "welsh",
    ["wlf" ] = "wolof",
    ["wln" ] = "walloon",
    ["xbd" ] = "lü",
    ["xhs" ] = "xhosa",
    ["xjb" ] = "minjangbal",
    ["xog" ] = "soga",
    ["xpe" ] = "kpelle (liberia)",
    ["yak" ] = "sakha",
    ["yao" ] = "yao",
    ["yap" ] = "yapese",
    ["yba" ] = "yoruba",
    ["ycr" ] = "y-cree",
    ["yic" ] = "yi classic",
    ["yim" ] = "yi modern",
    ["zea" ] = "zealandic",
    ["zgh" ] = "standard morrocan tamazigh",
    ["zha" ] = "zhuang",
    ["zhh" ] = "chinese, hong kong sar",
    ["zhp" ] = "chinese phonetic",
    ["zhs" ] = "chinese simplified",
    ["zht" ] = "chinese traditional",
    ["znd" ] = "zande",
    ["zul" ] = "zulu",
    ["zza" ] = "zazaki",
} --[[ [languages] ]]

local features = {
    ["aalt"] = "access all alternates",
    ["abvf"] = "above-base forms",
    ["abvm"] = "above-base mark positioning",
    ["abvs"] = "above-base substitutions",
    ["afrc"] = "alternative fractions",
    ["akhn"] = "akhands",
    ["blwf"] = "below-base forms",
    ["blwm"] = "below-base mark positioning",
    ["blws"] = "below-base substitutions",
    ["c2pc"] = "petite capitals from capitals",
    ["c2sc"] = "small capitals from capitals",
    ["calt"] = "contextual alternates",
    ["case"] = "case-sensitive forms",
    ["ccmp"] = "glyph composition/decomposition",
    ["cfar"] = "conjunct form after ro",
    ["cjct"] = "conjunct forms",
    ["clig"] = "contextual ligatures",
    ["cpct"] = "centered cjk punctuation",
    ["cpsp"] = "capital spacing",
    ["cswh"] = "contextual swash",
    ["curs"] = "cursive positioning",
    ["dflt"] = "default processing",
    ["dist"] = "distances",
    ["dlig"] = "discretionary ligatures",
    ["dnom"] = "denominators",
    ["dtls"] = "dotless forms", -- math
    ["expt"] = "expert forms",
    ["falt"] = "final glyph alternates",
    ["fin2"] = "terminal forms #2",
    ["fin3"] = "terminal forms #3",
    ["fina"] = "terminal forms",
    ["flac"] = "flattened accents over capitals", -- math
    ["frac"] = "fractions",
    ["fwid"] = "full width",
    ["half"] = "half forms",
    ["haln"] = "halant forms",
    ["halt"] = "alternate half width",
    ["hist"] = "historical forms",
    ["hkna"] = "horizontal kana alternates",
    ["hlig"] = "historical ligatures",
    ["hngl"] = "hangul",
    ["hojo"] = "hojo kanji forms",
    ["hwid"] = "half width",
    ["init"] = "initial forms",
    ["isol"] = "isolated forms",
    ["ital"] = "italics",
    ["jalt"] = "justification alternatives",
    ["jp04"] = "jis2004 forms",
    ["jp78"] = "jis78 forms",
    ["jp83"] = "jis83 forms",
    ["jp90"] = "jis90 forms",
    ["kern"] = "kerning",
    ["lfbd"] = "left bounds",
    ["liga"] = "standard ligatures",
    ["ljmo"] = "leading jamo forms",
    ["lnum"] = "lining figures",
    ["locl"] = "localized forms",
    ["ltra"] = "left-to-right alternates",
    ["ltrm"] = "left-to-right mirrored forms",
    ["mark"] = "mark positioning",
    ["med2"] = "medial forms #2",
    ["medi"] = "medial forms",
    ["mgrk"] = "mathematical greek",
    ["mkmk"] = "mark to mark positioning",
    ["mset"] = "mark positioning via substitution",
    ["nalt"] = "alternate annotation forms",
    ["nlck"] = "nlc kanji forms",
    ["nukt"] = "nukta forms",
    ["numr"] = "numerators",
    ["onum"] = "old style figures",
    ["opbd"] = "optical bounds",
    ["ordn"] = "ordinals",
    ["ornm"] = "ornaments",
    ["palt"] = "proportional alternate width",
    ["pcap"] = "petite capitals",
    ["pkna"] = "proportional kana",
    ["pnum"] = "proportional figures",
    ["pref"] = "pre-base forms",
    ["pres"] = "pre-base substitutions",
    ["pstf"] = "post-base forms",
    ["psts"] = "post-base substitutions",
    ["pwid"] = "proportional widths",
    ["qwid"] = "quarter widths",
    ["rand"] = "randomize",
    ["rclt"] = "required contextual alternates",
    ["rkrf"] = "rakar forms",
    ["rlig"] = "required ligatures",
    ["rphf"] = "reph form",
    ["rtbd"] = "right bounds",
    ["rtla"] = "right-to-left alternates",
    ["rtlm"] = "right to left math", -- math
    ["ruby"] = "ruby notation forms",
    ["salt"] = "stylistic alternates",
    ["sinf"] = "scientific inferiors",
    ["size"] = "optical size",
    ["smcp"] = "small capitals",
    ["smpl"] = "simplified forms",
 -- ["ss01"] = "stylistic set 1",
 -- ["ss02"] = "stylistic set 2",
 -- ["ss03"] = "stylistic set 3",
 -- ["ss04"] = "stylistic set 4",
 -- ["ss05"] = "stylistic set 5",
 -- ["ss06"] = "stylistic set 6",
 -- ["ss07"] = "stylistic set 7",
 -- ["ss08"] = "stylistic set 8",
 -- ["ss09"] = "stylistic set 9",
 -- ["ss10"] = "stylistic set 10",
 -- ["ss11"] = "stylistic set 11",
 -- ["ss12"] = "stylistic set 12",
 -- ["ss13"] = "stylistic set 13",
 -- ["ss14"] = "stylistic set 14",
 -- ["ss15"] = "stylistic set 15",
 -- ["ss16"] = "stylistic set 16",
 -- ["ss17"] = "stylistic set 17",
 -- ["ss18"] = "stylistic set 18",
 -- ["ss19"] = "stylistic set 19",
 -- ["ss20"] = "stylistic set 20",
    ["ssty"] = "script style", -- math
    ["stch"] = "stretching glyph decomposition",
    ["subs"] = "subscript",
    ["sups"] = "superscript",
    ["swsh"] = "swash",
    ["titl"] = "titling",
    ["tjmo"] = "trailing jamo forms",
    ["tnam"] = "traditional name forms",
    ["tnum"] = "tabular figures",
    ["trad"] = "traditional forms",
    ["twid"] = "third widths",
    ["unic"] = "unicase",
    ["valt"] = "alternate vertical metrics",
    ["vatu"] = "vattu variants",
    ["vert"] = "vertical writing",
    ["vhal"] = "alternate vertical half metrics",
    ["vjmo"] = "vowel jamo forms",
    ["vkna"] = "vertical kana alternates",
    ["vkrn"] = "vertical kerning",
    ["vpal"] = "proportional alternate vertical metrics",
    ["vrt2"] = "vertical rotation",
    ["zero"] = "slashed zero",

    ["trep"] = "traditional tex replacements",
    ["tlig"] = "traditional tex ligatures",

    ["ss.."] = "stylistic set ..",
    ["cv.."] = "character variant ..",
    ["js.."] = "justification ..",

    ["dv.."] = "devanagari ..",
    ["ml.."] = "malayalam ..",
} --[[ [features] ]]

local baselines = {
    ["hang"] = "hanging baseline",
    ["icfb"] = "ideographic character face bottom edge baseline",
    ["icft"] = "ideographic character face tope edige baseline",
    ["ideo"] = "ideographic em-box bottom edge baseline",
    ["idtp"] = "ideographic em-box top edge baseline",
    ["math"] = "mathematical centered baseline",
    ["romn"] = "roman baseline"
} --[[ [baselines] ]]

local swapped = function (h)
    local r = { }
    for k, v in next, h do
        r[stringgsub(v,"[^a-z0-9]","")] = k -- is already lower
    end
    return r
end

local verbosescripts   = swapped(scripts  )
local verboselanguages = swapped(languages)
local verbosefeatures  = swapped(features )
local verbosebaselines = swapped(baselines)

---[[ end excerpt from font-ott.lua ]]

--[[doc--

    As discussed, we will issue a warning because of incomplete support
    when one of the scripts below is requested.

    Reference: https://github.com/lualatex/luaotfload/issues/31

--doc]]--

local support_incomplete = tabletohash({
    "deva", "beng", "guru", "gujr",
    "orya", "taml", "telu", "knda",
    "mlym", "sinh",
}, true)

--[[doc--

    Which features are active by default depends on the script
    requested.

--doc]]--

--- (string, string) dict -> (string, string) dict
local apply_default_features = function (speclist)
    local default_features = luaotfload.features

    speclist = speclist or { }
    speclist[""] = nil --- invalid options stub

    --- handle language tag
    local language = speclist.language
    if language then --- already lowercase at this point
        language = stringgsub(language, "[^a-z0-9]", "")
        language = rawget(verboselanguages, language) -- srsly, rawget?
                or (languages[language] and language)
                or "dflt"
    else
        language = "dflt"
    end
    speclist.language = language

    --- handle script tag
    local script = speclist.script
    if script then
        script = stringgsub(script, "[^a-z0-9]","")
        script = rawget(verbosescripts, script)
              or (scripts[script] and script)
              or "dflt"
        if support_incomplete[script] then
            report("log", 0, "features",
                "Support for the requested script: "
                .. "%q may be incomplete.", script)
        end
    else
        script = "dflt"
    end
    speclist.script = script

    report("log", 2, "features",
        "Auto-selecting default features for script: %s.",
        script)

    local requested = default_features.defaults[script]
    if not requested then
        report("log", 2, "features",
            "No default features for script %q, falling back to \"dflt\".",
            script)
        requested = default_features.defaults.dflt
    end

    for feat, state in next, requested do
        if speclist[feat] == nil then speclist[feat] = state end
    end

    for feat, state in next, default_features.global do
        --- This is primarily intended for setting node
        --- mode unless “base” is requested, as stated
        --- in the manual.
        if speclist[feat] == nil then speclist[feat] = state end
    end
    return speclist
end

local import_values = {
    --- That’s what the 1.x parser did, not quite as graciously,
    --- with an array of branch expressions.
    -- "style", "optsize",--> from slashed notation; handled otherwise
    { "lookup", false },
    { "sub",    false },
    { "mode",   true },
}

local lookup_types = { "anon"  , "file", "kpse"
                     , "my"    , "name", "path"
                     , "combo"
                     }

local select_lookup = function (request)
    for i=1, #lookup_types do
        local lookup = lookup_types[i]
        local value  = request[lookup]
        if value then
            return lookup, value
        end
    end
end

local supported = {
    b    = "b",
    i    = "i",
    bi   = "bi",
    aat  = false,
    icu  = false,
    gr   = false,
}

--- (string | (string * string) | bool) list -> (string * number)
local handle_slashed = function (modifiers)
    local style, optsize
    for i=1, #modifiers do
        local mod  = modifiers[i]
        if type(mod) == "table" and mod[1] == "optsize" then --> optical size
            optsize = tonumber(mod[2])
        elseif mod == false then
            --- ignore
            report("log", 0, "features", "unsupported font option: %s", v)
        elseif supported[mod] then
            style = supported[mod]
        elseif not stringis_empty(mod) then
            style = stringgsub(mod, "[^%a%d]", "")
        end
    end
    return style, optsize
end

local extract_subfont
do
    local eof         = P(-1)
    local digit       = R"09"
    --- Theoretically a valid subfont address can be up to ten
    --- digits long.
    local sub_expr    = P"(" * C(digit^1) * P")" * eof
    local full_path   = C(P(1 - sub_expr)^1)
    extract_subfont   = full_path * sub_expr
end

--- spec -> spec
local handle_request = function (specification)
    local request = lpegmatch(luaotfload.parsers.font_request,
                              specification.specification)
----inspect(request)
    if not request then
        --- happens when called with an absolute path
        --- in an anonymous lookup;
        --- we try to behave as friendly as possible
        --- just go with it ...
        report("log", 1, "features", "invalid request %q of type anon",
            specification.specification)
        report("log", 1, "features",
               "use square bracket syntax or consult the documentation.")
        --- The result of \fontname must be re-feedable into \font
        --- which is expected by the Latex font mechanism. Now this
        --- is complicated with TTC fonts that need to pass the
        --- number of the requested subfont along with the file name.
        --- Thus we test whether the request is a bare path only or
        --- ends in a subfont expression (decimal digits inside
        --- parentheses).
        --- https://github.com/lualatex/luaotfload/issues/57
        local fullpath, sub = lpegmatch(extract_subfont,
                                        specification.specification)
        if fullpath and sub then
            specification.sub  = tonumber(sub)
            specification.name = fullpath
        else
            specification.name = specification.specification
        end
        specification.lookup = "path"
        return specification
    end

    local lookup, name = select_lookup (request)
    if lookup == "combo" then
        return handle_combination (request.combo, specification)
    end

    request.features = apply_default_features(request.features)

    if name then
        specification.name    = name
        specification.lookup  = lookup or specification.lookup
    end

    if request.modifiers then
        local style, optsize = handle_slashed(request.modifiers)
        specification.style, specification.optsize = style, optsize
    end

    for n=1, #import_values do
        local feat       = import_values[n][1]
        local keep       = import_values[n][2]
        local newvalue   = request.features[feat]
        if newvalue then
            specification[feat] = request.features[feat]
            if not keep then
                request.features[feat] = nil
            end
        end
    end

    --- The next line sets the “rand” feature to “random”; I haven’t
    --- investigated it any further (luatex-fonts-ext), so it will
    --- just stay here.
    specification.features.normal = normalize (request.features)
    local subfont = tonumber (specification.sub)
    if subfont and subfont >= 0 then
        specification.sub = subfont + 1
    end
    return specification
end

if as_script == true then --- skip the remainder of the file
    fonts.names.handle_request = handle_request
    report ("log", 5, "features",
            "Exiting early from luaotfload-features.lua.")
    return
else
    local registersplit = definers.registersplit
    registersplit (":", handle_request, "common")
    registersplit ("",  handle_request, "xetex path style") -- catches \font\text=[names]
end

---[[ end included font-ltx.lua ]]

-- We assume that the other otf stuff is loaded already; though there’s
-- another check below during the initialization phase.

---[[ begin snippet from font-otc.lua ]]
local trace_loading       = false  trackers.register("otf.loading", function(v) trace_loading = v end)
local report_otf          = logs.reporter("fonts","otf loading")

--[[HH--

   In the userdata interface we can not longer tweak the loaded font as
   conveniently as before. For instance, instead of pushing extra data in
   in the table using the original structure, we now have to operate on
   the mkiv representation. And as the fontloader interface is modelled
   after fontforge we cannot change that one too much either.

--HH]]--

--- start locals for addfeature()

local utfbyte = unicode.utf8.byte
local utfchar = unicode.utf8.char

local otf = handlers and handlers.otf --- filled in later during initialization

local normalized = {
    substitution      = "substitution",
    single            = "substitution",
    ligature          = "ligature",
    alternate         = "alternate",
    multiple          = "multiple",
    kern              = "kern",
    pair              = "pair",
    chainsubstitution = "chainsubstitution",
    chainposition     = "chainposition",
}

local types = {
    substitution      = "gsub_single",
    ligature          = "gsub_ligature",
    alternate         = "gsub_alternate",
    multiple          = "gsub_multiple",
    kern              = "gpos_pair",
    pair              = "gpos_pair",
    chainsubstitution = "gsub_contextchain",
    chainposition     = "gpos_contextchain",
}

setmetatableindex(types, function(t,k) t[k] = k return k end) -- "key"

--- stop locals for addfeature()

local everywhere = { ["*"] = { ["*"] = true } } -- or: { ["*"] = { "*" } }
local noflags = { false, false, false, false }

local tohash = table.tohash

local function current_addfeature(data,feature,specifications)
    local descriptions = data.descriptions
    local resources    = data.resources
    local features     = resources.features
    local sequences    = resources.sequences
    if not features or not sequences then
        return
    end
    local gsubfeatures = features.gsub
    if gsubfeatures and gsubfeatures[feature] then
        return -- already present
    end
    local fontfeatures = resources.features or everywhere
    local unicodes     = resources.unicodes
    local splitter     = lpeg.splitter(" ",unicodes)
    local done         = 0
    local skip         = 0
    if not specifications[1] then
        -- so we accept a one entry specification
        specifications = { specifications }
    end

    local function tounicode(code)
        if not code then
            return
        elseif type(code) == "number" then
            return code
        else
            return unicodes[code] or utfbyte(code)
        end
    end

    local coverup      = otf.coverup
    local coveractions = coverup.actions
    local stepkey      = coverup.stepkey
    local register     = coverup.register

    for s=1,#specifications do
        local specification = specifications[s]
        local valid         = specification.valid
        if not valid or valid(data,specification,feature) then
            local initialize = specification.initialize
            if initialize then
                -- when false is returned we initialize only once
                specification.initialize = initialize(specification,data) and initialize or nil
            end
            local askedfeatures = specification.features or everywhere
            local askedsteps    = specifications.steps or specification.subtables or { specification.data } or { }
            local featuretype   = normalized[specification.type or "substitution"] or "substitution"
            local featureflags  = specification.flags or noflags
            local featureorder  = specification.order or { feature }
            local added         = false
            local nofsteps      = 0
            local steps         = { }
            for i=1,#askedsteps do
                local list     = askedsteps[i]
                local coverage = { }
                local cover    = coveractions[featuretype]
                local format   = nil
                if not cover then
                    -- unknown
                elseif featuretype == "substitution" then
                    for code, replacement in next, list do
                        local unicode     = tounicode(code)
                        local description = descriptions[unicode]
                        if description then
                            if type(replacement) == "table" then
                                replacement = replacement[1]
                            end
                            replacement = tounicode(replacement)
                            if replacement and descriptions[replacement] then
                                cover(coverage,unicode,replacement)
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        else
                            skip = skip + 1
                        end
                    end
                elseif featuretype == "ligature" then
                    for code, ligature in next, list do
                        local unicode     = tounicode(code)
                        local description = descriptions[unicode]
                        if description then
                            if type(ligature) == "string" then
                                ligature = { lpegmatch(splitter,ligature) }
                            end
                            local present = true
                            for i=1,#ligature do
                                local l = ligature[i]
                                local u = tounicode(l)
                                if descriptions[u] then
                                    ligature[i] = u
                                else
                                    present = false
                                    break
                                end
                            end
                            if present then
                                cover(coverage,unicode,ligature)
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        else
                            skip = skip + 1
                        end
                    end
                elseif featuretype == "alternate" then
                    for code, replacement in next, list do
                        local unicode     = tounicode(code)
                        local description = descriptions[unicode]
                        if not description then
                            skip = skip + 1
                        elseif type(replacement) == "table" then
                            local r = { }
                            for i=1,#replacement do
                                local u = tounicode(replacement[i])
                                r[i] = descriptions[u] and u or unicode
                            end
                            cover(coverage,unicode,r)
                            done = done + 1
                        else
                            local u = tounicode(replacement)
                            if u then
                                cover(coverage,unicode,{ u })
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        end
                    end
                elseif featuretype == "multiple" then -- todo: unicode can be table
                    for code, replacement in next, list do
                        local unicode     = tounicode(code)
                        local description = descriptions[unicode]
                        if not description then
                            skip = skip + 1
                        elseif type(replacement) == "table" then
                            local r, n = { }, 0
                            for i=1,#replacement do
                                local u = tounicode(replacement[i])
                                if descriptions[u] then
                                    n = n + 1
                                    r[n] = u
                                end
                            end
                            if n > 0 then
                                cover(coverage,unicode,r)
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        else
                            local u = tounicode(replacement)
                            if u then
                                cover(coverage,unicode,{ u })
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        end
                    end
                elseif featuretype == "kern" then
                    for code, replacement in next, list do
                        local unicode     = tounicode(code)
                        local description = descriptions[unicode]
                        if description and type(replacement) == "table" then
                            local r = { }
                            for k, v in next, replacement do
                                local u = tounicode(k)
                                if u then
                                    r[u] = v
                                end
                            end
                            if next(r) then
                                cover(coverage,unicode,r)
                                done = done + 1
                            else
                                skip = skip + 1
                            end
                        else
                            skip = skip + 1
                        end
                    end
                    format = "kern"
                end
                if next(coverage) then
                    added = true
                    nofsteps = nofsteps + 1
                    steps[nofsteps] = register(coverage,featuretype,format,feature,nofsteps,descriptions,resources)
                end
            end
            if added then
                -- script = { lang1, lang2, lang3 } or script = { lang1 = true, ... }
                for k, v in next, askedfeatures do
                    if v[1] then
                        askedfeatures[k] = tohash(v)
                    end
                end
                local sequence = {
                    chain     = 0,
                    features  = { [feature] = askedfeatures },
                    flags     = featureflags,
                    name      = feature, -- not needed
                    order     = featureorder,
                    [stepkey] = steps,
                    nofsteps  = nofsteps,
                    type      = types[featuretype],
                }
                if specification.prepend then
                    insert(sequences,1,sequence)
                else
                    insert(sequences,sequence)
                end
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

---[[ end snippet from font-otc.lua ]]

local tlig_specification = {
    {
        type      = "substitution",
        features  = everywhere,
        data      = {
            [0x0022] = 0x201D,                   -- quotedblright
            [0x0027] = 0x2019,                   -- quoteleft
            [0x0060] = 0x2018,                   -- quoteright
        },
        flags     = noflags,
        order     = { "tlig" },
        prepend   = true,
    },
    {
        type     = "ligature",
        features = everywhere,
        data     = {
            [0x2013] = {0x002D, 0x002D},         -- endash
            [0x2014] = {0x002D, 0x002D, 0x002D}, -- emdash
            [0x201C] = {0x2018, 0x2018},         -- quotedblleft
            [0x201D] = {0x2019, 0x2019},         -- quotedblright
            [0x00A1] = {0x0021, 0x2018},         -- exclamdown
            [0x00BF] = {0x003F, 0x2018},         -- questiondown
            --- next three originate in T1 encoding; Xetex applies
            --- them too
            [0x201E] = {0x002C, 0x002C},         -- quotedblbase
            [0x00AB] = {0x003C, 0x003C},         -- LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
            [0x00BB] = {0x003E, 0x003E},         -- RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
        },
        flags    = noflags,
        order    = { "tlig" },
        prepend  = true,
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
        flags    = noflags,
        order    = { "tlig" },
        prepend  = true,
    },
}

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
        flags    = noflags,
        order    = { "anum" },
        valid    = valid,
    },
    {
        type     = "substitution",
        features = { arab = { ["*"] = true } },
        data     = anum_arabic,
        flags    = noflags,
        order    = { "anum" },
        valid    = valid,
    },
}

local rot13_specification = {
    type      = "substitution",
    features  = everywhere,
    data      = {
        [65] = 78, [ 97] = 110, [78] = 65, [110] =  97,
        [66] = 79, [ 98] = 111, [79] = 66, [111] =  98,
        [67] = 80, [ 99] = 112, [80] = 67, [112] =  99,
        [68] = 81, [100] = 113, [81] = 68, [113] = 100,
        [69] = 82, [101] = 114, [82] = 69, [114] = 101,
        [70] = 83, [102] = 115, [83] = 70, [115] = 102,
        [71] = 84, [103] = 116, [84] = 71, [116] = 103,
        [72] = 85, [104] = 117, [85] = 72, [117] = 104,
        [73] = 86, [105] = 118, [86] = 73, [118] = 105,
        [74] = 87, [106] = 119, [87] = 74, [119] = 106,
        [75] = 88, [107] = 120, [88] = 75, [120] = 107,
        [76] = 89, [108] = 121, [89] = 76, [121] = 108,
        [77] = 90, [109] = 122, [90] = 77, [122] = 109,
    },
    flags     = noflags,
    order     = { "rot13" },
    prepend   = true,
}

local extrafeatures = {
    tlig  = { tlig_specification,  "tex ligatures and substitutions" },
    anum  = { anum_specification,  "arabic numerals"                 },
    rot13 = { rot13_specification, "rot13"                           },
}

function add_otf_feature (name, specification)
    if type (name) == "table" then
        specification = name
        name = specification.name
    end
    if type (name) == "string" then
        extrafeatures[name] = specification
    end
end

otf.addfeature           = add_otf_feature

local install_extra_features = function (data, filename, raw)
    local metadata = data and data.metadata
    if not metadata then
        logreport ("both", 4, "features",
                   "no metadata received from font “%s”; not \z
                    installing extra features.", filename)
        return
    end
    local format = data.format
    if not format then
        logreport ("both", 4, "features",
                   "no format info for font “%s”/“%s”; not \z
                   installing extra features.",
                   fontname, filename)
        return
    end
    for feature, specification in next, extrafeatures do
        if not fontname then fontname = "<unknown>" end
        if not subfont  then subfont  = -1          end
        local fontname = tostring (data.metadata.fontname) or "<unknown>"
        local subfont  = tonumber (metadata.subfontindex)  or -1
        logreport ("both", 3, "features",
                   "register synthetic feature “%s” for %s font “%s”(%d)",
                   feature, format, fontname, subfont)
        otf.features.register { name = feature, description = specification[2] }
        otf.enhancers.addfeature (data, feature, specification[1])
    end
end

return {
    init = function ()

        logreport = luaotfload.log.report

        if not fonts and fonts.handlers then
            logreport ("log", 0, "features",
                       "OTF mechanisms missing -- did you forget to \z
                       load a font loader?")
            return false
        end

        otf = fonts.handlers.otf
        otf.enhancers.addfeature = current_addfeature
        otf.enhancers.register ("check extra features",
                                install_extra_features)

        return true
    end
}

-- vim:tw=79:sw=4:ts=4:expandtab
