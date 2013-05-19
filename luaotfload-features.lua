if not modules then modules = { } end modules ["features"] = {
    version   = 2.200,
    comment   = "companion to luaotfload.lua",
    author    = "Hans Hagen, Khaled Hosny, Elie Roux, Philipp Gesang",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next        = type, next
local tonumber          = tonumber
local tostring          = tostring
local lpegmatch         = lpeg.match

---[[ begin included font-ltx.lua ]]
--- this appears to be based in part on luatex-fonts-def.lua

local fonts = fonts

--HH A bit of tuning for definitions.

fonts.constructors.namemode = "specification" -- somehow latex needs this (changed name!) => will change into an overload

--[[HH--
    tricky: we sort of bypass the parser and directly feed all into
    the sub parser
--HH]]--

function fonts.definers.getspecification(str)
    return "", str, "", ":", str
end

local report = logs.names_report

local stringfind       = string.find
local stringlower      = string.lower
local stringgsub       = string.gsub
local stringsub        = string.sub
local stringformat     = string.format
local stringis_empty   = string.is_empty
local mathceil         = math.ceil

--- TODO an option to dump the default features for a script would make
---      a nice addition to luaotfload-tool

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

local global_defaults = { mode = "node" }

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

---[[ begin excerpt from font-ott.lua ]]

local scripts = {
    ['arab'] = 'arabic',
    ['armn'] = 'armenian',
    ['bali'] = 'balinese',
    ['beng'] = 'bengali',
    ['bopo'] = 'bopomofo',
    ['brai'] = 'braille',
    ['bugi'] = 'buginese',
    ['buhd'] = 'buhid',
    ['byzm'] = 'byzantine music',
    ['cans'] = 'canadian syllabics',
    ['cher'] = 'cherokee',
    ['copt'] = 'coptic',
    ['cprt'] = 'cypriot syllabary',
    ['cyrl'] = 'cyrillic',
    ['deva'] = 'devanagari',
    ['dsrt'] = 'deseret',
    ['ethi'] = 'ethiopic',
    ['geor'] = 'georgian',
    ['glag'] = 'glagolitic',
    ['goth'] = 'gothic',
    ['grek'] = 'greek',
    ['gujr'] = 'gujarati',
    ['guru'] = 'gurmukhi',
    ['hang'] = 'hangul',
    ['hani'] = 'cjk ideographic',
    ['hano'] = 'hanunoo',
    ['hebr'] = 'hebrew',
    ['ital'] = 'old italic',
    ['jamo'] = 'hangul jamo',
    ['java'] = 'javanese',
    ['kana'] = 'hiragana and katakana',
    ['khar'] = 'kharosthi',
    ['khmr'] = 'khmer',
    ['knda'] = 'kannada',
    ['lao' ] = 'lao',
    ['latn'] = 'latin',
    ['limb'] = 'limbu',
    ['linb'] = 'linear b',
    ['math'] = 'mathematical alphanumeric symbols',
    ['mlym'] = 'malayalam',
    ['mong'] = 'mongolian',
    ['musc'] = 'musical symbols',
    ['mymr'] = 'myanmar',
    ['nko' ] = "n'ko",
    ['ogam'] = 'ogham',
    ['orya'] = 'oriya',
    ['osma'] = 'osmanya',
    ['phag'] = 'phags-pa',
    ['phnx'] = 'phoenician',
    ['runr'] = 'runic',
    ['shaw'] = 'shavian',
    ['sinh'] = 'sinhala',
    ['sylo'] = 'syloti nagri',
    ['syrc'] = 'syriac',
    ['tagb'] = 'tagbanwa',
    ['tale'] = 'tai le',
    ['talu'] = 'tai lu',
    ['taml'] = 'tamil',
    ['telu'] = 'telugu',
    ['tfng'] = 'tifinagh',
    ['tglg'] = 'tagalog',
    ['thaa'] = 'thaana',
    ['thai'] = 'thai',
    ['tibt'] = 'tibetan',
    ['ugar'] = 'ugaritic cuneiform',
    ['xpeo'] = 'old persian cuneiform',
    ['xsux'] = 'sumero-akkadian cuneiform',
    ['yi'  ] = 'yi',
}

local languages = {
    ['aba'] = 'abaza',
    ['abk'] = 'abkhazian',
    ['ady'] = 'adyghe',
    ['afk'] = 'afrikaans',
    ['afr'] = 'afar',
    ['agw'] = 'agaw',
    ['als'] = 'alsatian',
    ['alt'] = 'altai',
    ['amh'] = 'amharic',
    ['ara'] = 'arabic',
    ['ari'] = 'aari',
    ['ark'] = 'arakanese',
    ['asm'] = 'assamese',
    ['ath'] = 'athapaskan',
    ['avr'] = 'avar',
    ['awa'] = 'awadhi',
    ['aym'] = 'aymara',
    ['aze'] = 'azeri',
    ['bad'] = 'badaga',
    ['bag'] = 'baghelkhandi',
    ['bal'] = 'balkar',
    ['bau'] = 'baule',
    ['bbr'] = 'berber',
    ['bch'] = 'bench',
    ['bcr'] = 'bible cree',
    ['bel'] = 'belarussian',
    ['bem'] = 'bemba',
    ['ben'] = 'bengali',
    ['bgr'] = 'bulgarian',
    ['bhi'] = 'bhili',
    ['bho'] = 'bhojpuri',
    ['bik'] = 'bikol',
    ['bil'] = 'bilen',
    ['bkf'] = 'blackfoot',
    ['bli'] = 'balochi',
    ['bln'] = 'balante',
    ['blt'] = 'balti',
    ['bmb'] = 'bambara',
    ['bml'] = 'bamileke',
    ['bos'] = 'bosnian',
    ['bre'] = 'breton',
    ['brh'] = 'brahui',
    ['bri'] = 'braj bhasha',
    ['brm'] = 'burmese',
    ['bsh'] = 'bashkir',
    ['bti'] = 'beti',
    ['cat'] = 'catalan',
    ['ceb'] = 'cebuano',
    ['che'] = 'chechen',
    ['chg'] = 'chaha gurage',
    ['chh'] = 'chattisgarhi',
    ['chi'] = 'chichewa',
    ['chk'] = 'chukchi',
    ['chp'] = 'chipewyan',
    ['chr'] = 'cherokee',
    ['chu'] = 'chuvash',
    ['cmr'] = 'comorian',
    ['cop'] = 'coptic',
    ['cos'] = 'corsican',
    ['cre'] = 'cree',
    ['crr'] = 'carrier',
    ['crt'] = 'crimean tatar',
    ['csl'] = 'church slavonic',
    ['csy'] = 'czech',
    ['dan'] = 'danish',
    ['dar'] = 'dargwa',
    ['dcr'] = 'woods cree',
    ['deu'] = 'german',
    ['dgr'] = 'dogri',
    ['div'] = 'divehi',
    ['djr'] = 'djerma',
    ['dng'] = 'dangme',
    ['dnk'] = 'dinka',
    ['dri'] = 'dari',
    ['dun'] = 'dungan',
    ['dzn'] = 'dzongkha',
    ['ebi'] = 'ebira',
    ['ecr'] = 'eastern cree',
    ['edo'] = 'edo',
    ['efi'] = 'efik',
    ['ell'] = 'greek',
    ['eng'] = 'english',
    ['erz'] = 'erzya',
    ['esp'] = 'spanish',
    ['eti'] = 'estonian',
    ['euq'] = 'basque',
    ['evk'] = 'evenki',
    ['evn'] = 'even',
    ['ewe'] = 'ewe',
    ['fan'] = 'french antillean',
    ['far'] = 'farsi',
    ['fin'] = 'finnish',
    ['fji'] = 'fijian',
    ['fle'] = 'flemish',
    ['fne'] = 'forest nenets',
    ['fon'] = 'fon',
    ['fos'] = 'faroese',
    ['fra'] = 'french',
    ['fri'] = 'frisian',
    ['frl'] = 'friulian',
    ['fta'] = 'futa',
    ['ful'] = 'fulani',
    ['gad'] = 'ga',
    ['gae'] = 'gaelic',
    ['gag'] = 'gagauz',
    ['gal'] = 'galician',
    ['gar'] = 'garshuni',
    ['gaw'] = 'garhwali',
    ['gez'] = "ge'ez",
    ['gil'] = 'gilyak',
    ['gmz'] = 'gumuz',
    ['gon'] = 'gondi',
    ['grn'] = 'greenlandic',
    ['gro'] = 'garo',
    ['gua'] = 'guarani',
    ['guj'] = 'gujarati',
    ['hai'] = 'haitian',
    ['hal'] = 'halam',
    ['har'] = 'harauti',
    ['hau'] = 'hausa',
    ['haw'] = 'hawaiin',
    ['hbn'] = 'hammer-banna',
    ['hil'] = 'hiligaynon',
    ['hin'] = 'hindi',
    ['hma'] = 'high mari',
    ['hnd'] = 'hindko',
    ['ho']  = 'ho',
    ['hri'] = 'harari',
    ['hrv'] = 'croatian',
    ['hun'] = 'hungarian',
    ['hye'] = 'armenian',
    ['ibo'] = 'igbo',
    ['ijo'] = 'ijo',
    ['ilo'] = 'ilokano',
    ['ind'] = 'indonesian',
    ['ing'] = 'ingush',
    ['inu'] = 'inuktitut',
    ['iri'] = 'irish',
    ['irt'] = 'irish traditional',
    ['isl'] = 'icelandic',
    ['ism'] = 'inari sami',
    ['ita'] = 'italian',
    ['iwr'] = 'hebrew',
    ['jan'] = 'japanese',
    ['jav'] = 'javanese',
    ['jii'] = 'yiddish',
    ['jud'] = 'judezmo',
    ['jul'] = 'jula',
    ['kab'] = 'kabardian',
    ['kac'] = 'kachchi',
    ['kal'] = 'kalenjin',
    ['kan'] = 'kannada',
    ['kar'] = 'karachay',
    ['kat'] = 'georgian',
    ['kaz'] = 'kazakh',
    ['keb'] = 'kebena',
    ['kge'] = 'khutsuri georgian',
    ['kha'] = 'khakass',
    ['khk'] = 'khanty-kazim',
    ['khm'] = 'khmer',
    ['khs'] = 'khanty-shurishkar',
    ['khv'] = 'khanty-vakhi',
    ['khw'] = 'khowar',
    ['kik'] = 'kikuyu',
    ['kir'] = 'kirghiz',
    ['kis'] = 'kisii',
    ['kkn'] = 'kokni',
    ['klm'] = 'kalmyk',
    ['kmb'] = 'kamba',
    ['kmn'] = 'kumaoni',
    ['kmo'] = 'komo',
    ['kms'] = 'komso',
    ['knr'] = 'kanuri',
    ['kod'] = 'kodagu',
    ['koh'] = 'korean old hangul',
    ['kok'] = 'konkani',
    ['kon'] = 'kikongo',
    ['kop'] = 'komi-permyak',
    ['kor'] = 'korean',
    ['koz'] = 'komi-zyrian',
    ['kpl'] = 'kpelle',
    ['kri'] = 'krio',
    ['krk'] = 'karakalpak',
    ['krl'] = 'karelian',
    ['krm'] = 'karaim',
    ['krn'] = 'karen',
    ['krt'] = 'koorete',
    ['ksh'] = 'kashmiri',
    ['ksi'] = 'khasi',
    ['ksm'] = 'kildin sami',
    ['kui'] = 'kui',
    ['kul'] = 'kulvi',
    ['kum'] = 'kumyk',
    ['kur'] = 'kurdish',
    ['kuu'] = 'kurukh',
    ['kuy'] = 'kuy',
    ['kyk'] = 'koryak',
    ['lad'] = 'ladin',
    ['lah'] = 'lahuli',
    ['lak'] = 'lak',
    ['lam'] = 'lambani',
    ['lao'] = 'lao',
    ['lat'] = 'latin',
    ['laz'] = 'laz',
    ['lcr'] = 'l-cree',
    ['ldk'] = 'ladakhi',
    ['lez'] = 'lezgi',
    ['lin'] = 'lingala',
    ['lma'] = 'low mari',
    ['lmb'] = 'limbu',
    ['lmw'] = 'lomwe',
    ['lsb'] = 'lower sorbian',
    ['lsm'] = 'lule sami',
    ['lth'] = 'lithuanian',
    ['ltz'] = 'luxembourgish',
    ['lub'] = 'luba',
    ['lug'] = 'luganda',
    ['luh'] = 'luhya',
    ['luo'] = 'luo',
    ['lvi'] = 'latvian',
    ['maj'] = 'majang',
    ['mak'] = 'makua',
    ['mal'] = 'malayalam traditional',
    ['man'] = 'mansi',
    ['map'] = 'mapudungun',
    ['mar'] = 'marathi',
    ['maw'] = 'marwari',
    ['mbn'] = 'mbundu',
    ['mch'] = 'manchu',
    ['mcr'] = 'moose cree',
    ['mde'] = 'mende',
    ['men'] = "me'en",
    ['miz'] = 'mizo',
    ['mkd'] = 'macedonian',
    ['mle'] = 'male',
    ['mlg'] = 'malagasy',
    ['mln'] = 'malinke',
    ['mlr'] = 'malayalam reformed',
    ['mly'] = 'malay',
    ['mnd'] = 'mandinka',
    ['mng'] = 'mongolian',
    ['mni'] = 'manipuri',
    ['mnk'] = 'maninka',
    ['mnx'] = 'manx gaelic',
    ['moh'] = 'mohawk',
    ['mok'] = 'moksha',
    ['mol'] = 'moldavian',
    ['mon'] = 'mon',
    ['mor'] = 'moroccan',
    ['mri'] = 'maori',
    ['mth'] = 'maithili',
    ['mts'] = 'maltese',
    ['mun'] = 'mundari',
    ['nag'] = 'naga-assamese',
    ['nan'] = 'nanai',
    ['nas'] = 'naskapi',
    ['ncr'] = 'n-cree',
    ['ndb'] = 'ndebele',
    ['ndg'] = 'ndonga',
    ['nep'] = 'nepali',
    ['new'] = 'newari',
    ['ngr'] = 'nagari',
    ['nhc'] = 'norway house cree',
    ['nis'] = 'nisi',
    ['niu'] = 'niuean',
    ['nkl'] = 'nkole',
    ['nko'] = "n'ko",
    ['nld'] = 'dutch',
    ['nog'] = 'nogai',
    ['nor'] = 'norwegian',
    ['nsm'] = 'northern sami',
    ['nta'] = 'northern tai',
    ['nto'] = 'esperanto',
    ['nyn'] = 'nynorsk',
    ['oci'] = 'occitan',
    ['ocr'] = 'oji-cree',
    ['ojb'] = 'ojibway',
    ['ori'] = 'oriya',
    ['oro'] = 'oromo',
    ['oss'] = 'ossetian',
    ['paa'] = 'palestinian aramaic',
    ['pal'] = 'pali',
    ['pan'] = 'punjabi',
    ['pap'] = 'palpa',
    ['pas'] = 'pashto',
    ['pgr'] = 'polytonic greek',
    ['pil'] = 'pilipino',
    ['plg'] = 'palaung',
    ['plk'] = 'polish',
    ['pro'] = 'provencal',
    ['ptg'] = 'portuguese',
    ['qin'] = 'chin',
    ['raj'] = 'rajasthani',
    ['rbu'] = 'russian buriat',
    ['rcr'] = 'r-cree',
    ['ria'] = 'riang',
    ['rms'] = 'rhaeto-romanic',
    ['rom'] = 'romanian',
    ['roy'] = 'romany',
    ['rsy'] = 'rusyn',
    ['rua'] = 'ruanda',
    ['rus'] = 'russian',
    ['sad'] = 'sadri',
    ['san'] = 'sanskrit',
    ['sat'] = 'santali',
    ['say'] = 'sayisi',
    ['sek'] = 'sekota',
    ['sel'] = 'selkup',
    ['sgo'] = 'sango',
    ['shn'] = 'shan',
    ['sib'] = 'sibe',
    ['sid'] = 'sidamo',
    ['sig'] = 'silte gurage',
    ['sks'] = 'skolt sami',
    ['sky'] = 'slovak',
    ['sla'] = 'slavey',
    ['slv'] = 'slovenian',
    ['sml'] = 'somali',
    ['smo'] = 'samoan',
    ['sna'] = 'sena',
    ['snd'] = 'sindhi',
    ['snh'] = 'sinhalese',
    ['snk'] = 'soninke',
    ['sog'] = 'sodo gurage',
    ['sot'] = 'sotho',
    ['sqi'] = 'albanian',
    ['srb'] = 'serbian',
    ['srk'] = 'saraiki',
    ['srr'] = 'serer',
    ['ssl'] = 'south slavey',
    ['ssm'] = 'southern sami',
    ['sur'] = 'suri',
    ['sva'] = 'svan',
    ['sve'] = 'swedish',
    ['swa'] = 'swadaya aramaic',
    ['swk'] = 'swahili',
    ['swz'] = 'swazi',
    ['sxt'] = 'sutu',
    ['syr'] = 'syriac',
    ['tab'] = 'tabasaran',
    ['taj'] = 'tajiki',
    ['tam'] = 'tamil',
    ['tat'] = 'tatar',
    ['tcr'] = 'th-cree',
    ['tel'] = 'telugu',
    ['tgn'] = 'tongan',
    ['tgr'] = 'tigre',
    ['tgy'] = 'tigrinya',
    ['tha'] = 'thai',
    ['tht'] = 'tahitian',
    ['tib'] = 'tibetan',
    ['tkm'] = 'turkmen',
    ['tmn'] = 'temne',
    ['tna'] = 'tswana',
    ['tne'] = 'tundra nenets',
    ['tng'] = 'tonga',
    ['tod'] = 'todo',
    ['trk'] = 'turkish',
    ['tsg'] = 'tsonga',
    ['tua'] = 'turoyo aramaic',
    ['tul'] = 'tulu',
    ['tuv'] = 'tuvin',
    ['twi'] = 'twi',
    ['udm'] = 'udmurt',
    ['ukr'] = 'ukrainian',
    ['urd'] = 'urdu',
    ['usb'] = 'upper sorbian',
    ['uyg'] = 'uyghur',
    ['uzb'] = 'uzbek',
    ['ven'] = 'venda',
    ['vit'] = 'vietnamese',
    ['wa' ] = 'wa',
    ['wag'] = 'wagdi',
    ['wcr'] = 'west-cree',
    ['wel'] = 'welsh',
    ['wlf'] = 'wolof',
    ['xbd'] = 'tai lue',
    ['xhs'] = 'xhosa',
    ['yak'] = 'yakut',
    ['yba'] = 'yoruba',
    ['ycr'] = 'y-cree',
    ['yic'] = 'yi classic',
    ['yim'] = 'yi modern',
    ['zhh'] = 'chinese hong kong',
    ['zhp'] = 'chinese phonetic',
    ['zhs'] = 'chinese simplified',
    ['zht'] = 'chinese traditional',
    ['znd'] = 'zande',
    ['zul'] = 'zulu'
}

local features = {
    ['aalt'] = 'access all alternates',
    ['abvf'] = 'above-base forms',
    ['abvm'] = 'above-base mark positioning',
    ['abvs'] = 'above-base substitutions',
    ['afrc'] = 'alternative fractions',
    ['akhn'] = 'akhands',
    ['blwf'] = 'below-base forms',
    ['blwm'] = 'below-base mark positioning',
    ['blws'] = 'below-base substitutions',
    ['c2pc'] = 'petite capitals from capitals',
    ['c2sc'] = 'small capitals from capitals',
    ['calt'] = 'contextual alternates',
    ['case'] = 'case-sensitive forms',
    ['ccmp'] = 'glyph composition/decomposition',
    ['cjct'] = 'conjunct forms',
    ['clig'] = 'contextual ligatures',
    ['cpsp'] = 'capital spacing',
    ['cswh'] = 'contextual swash',
    ['curs'] = 'cursive positioning',
    ['dflt'] = 'default processing',
    ['dist'] = 'distances',
    ['dlig'] = 'discretionary ligatures',
    ['dnom'] = 'denominators',
    ['dtls'] = 'dotless forms', -- math
    ['expt'] = 'expert forms',
    ['falt'] = 'final glyph alternates',
    ['fin2'] = 'terminal forms #2',
    ['fin3'] = 'terminal forms #3',
    ['fina'] = 'terminal forms',
    ['flac'] = 'flattened accents over capitals', -- math
    ['frac'] = 'fractions',
    ['fwid'] = 'full width',
    ['half'] = 'half forms',
    ['haln'] = 'halant forms',
    ['halt'] = 'alternate half width',
    ['hist'] = 'historical forms',
    ['hkna'] = 'horizontal kana alternates',
    ['hlig'] = 'historical ligatures',
    ['hngl'] = 'hangul',
    ['hojo'] = 'hojo kanji forms',
    ['hwid'] = 'half width',
    ['init'] = 'initial forms',
    ['isol'] = 'isolated forms',
    ['ital'] = 'italics',
    ['jalt'] = 'justification alternatives',
    ['jp04'] = 'jis2004 forms',
    ['jp78'] = 'jis78 forms',
    ['jp83'] = 'jis83 forms',
    ['jp90'] = 'jis90 forms',
    ['kern'] = 'kerning',
    ['lfbd'] = 'left bounds',
    ['liga'] = 'standard ligatures',
    ['ljmo'] = 'leading jamo forms',
    ['lnum'] = 'lining figures',
    ['locl'] = 'localized forms',
    ['mark'] = 'mark positioning',
    ['med2'] = 'medial forms #2',
    ['medi'] = 'medial forms',
    ['mgrk'] = 'mathematical greek',
    ['mkmk'] = 'mark to mark positioning',
    ['mset'] = 'mark positioning via substitution',
    ['nalt'] = 'alternate annotation forms',
    ['nlck'] = 'nlc kanji forms',
    ['nukt'] = 'nukta forms',
    ['numr'] = 'numerators',
    ['onum'] = 'old style figures',
    ['opbd'] = 'optical bounds',
    ['ordn'] = 'ordinals',
    ['ornm'] = 'ornaments',
    ['palt'] = 'proportional alternate width',
    ['pcap'] = 'petite capitals',
    ['pnum'] = 'proportional figures',
    ['pref'] = 'pre-base forms',
    ['pres'] = 'pre-base substitutions',
    ['pstf'] = 'post-base forms',
    ['psts'] = 'post-base substitutions',
    ['pwid'] = 'proportional widths',
    ['qwid'] = 'quarter widths',
    ['rand'] = 'randomize',
    ['rkrf'] = 'rakar forms',
    ['rlig'] = 'required ligatures',
    ['rphf'] = 'reph form',
    ['rtbd'] = 'right bounds',
    ['rtla'] = 'right-to-left alternates',
    ['rtlm'] = 'right to left math', -- math
    ['ruby'] = 'ruby notation forms',
    ['salt'] = 'stylistic alternates',
    ['sinf'] = 'scientific inferiors',
    ['size'] = 'optical size',
    ['smcp'] = 'small capitals',
    ['smpl'] = 'simplified forms',
 -- ['ss01'] = 'stylistic set 1',
 -- ['ss02'] = 'stylistic set 2',
 -- ['ss03'] = 'stylistic set 3',
 -- ['ss04'] = 'stylistic set 4',
 -- ['ss05'] = 'stylistic set 5',
 -- ['ss06'] = 'stylistic set 6',
 -- ['ss07'] = 'stylistic set 7',
 -- ['ss08'] = 'stylistic set 8',
 -- ['ss09'] = 'stylistic set 9',
 -- ['ss10'] = 'stylistic set 10',
 -- ['ss11'] = 'stylistic set 11',
 -- ['ss12'] = 'stylistic set 12',
 -- ['ss13'] = 'stylistic set 13',
 -- ['ss14'] = 'stylistic set 14',
 -- ['ss15'] = 'stylistic set 15',
 -- ['ss16'] = 'stylistic set 16',
 -- ['ss17'] = 'stylistic set 17',
 -- ['ss18'] = 'stylistic set 18',
 -- ['ss19'] = 'stylistic set 19',
 -- ['ss20'] = 'stylistic set 20',
    ['ssty'] = 'script style', -- math
    ['subs'] = 'subscript',
    ['sups'] = 'superscript',
    ['swsh'] = 'swash',
    ['titl'] = 'titling',
    ['tjmo'] = 'trailing jamo forms',
    ['tnam'] = 'traditional name forms',
    ['tnum'] = 'tabular figures',
    ['trad'] = 'traditional forms',
    ['twid'] = 'third widths',
    ['unic'] = 'unicase',
    ['valt'] = 'alternate vertical metrics',
    ['vatu'] = 'vattu variants',
    ['vert'] = 'vertical writing',
    ['vhal'] = 'alternate vertical half metrics',
    ['vjmo'] = 'vowel jamo forms',
    ['vkna'] = 'vertical kana alternates',
    ['vkrn'] = 'vertical kerning',
    ['vpal'] = 'proportional alternate vertical metrics',
    ['vrt2'] = 'vertical rotation',
    ['zero'] = 'slashed zero',

    ['trep'] = 'traditional tex replacements',
    ['tlig'] = 'traditional tex ligatures',

    ['ss..'] = 'stylistic set ..',
    ['cv..'] = 'character variant ..',
    ['js..'] = 'justification ..',

    ["dv.."] = "devanagari ..",
}

local baselines = {
    ['hang'] = 'hanging baseline',
    ['icfb'] = 'ideographic character face bottom edge baseline',
    ['icft'] = 'ideographic character face tope edige baseline',
    ['ideo'] = 'ideographic em-box bottom edge baseline',
    ['idtp'] = 'ideographic em-box top edge baseline',
    ['math'] = 'mathmatical centered baseline',
    ['romn'] = 'roman baseline'
}

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

local support_incomplete = table.tohash({
    "deva", "beng", "guru", "gujr",
    "orya", "taml", "telu", "knda",
    "mlym", "sinh",
}, true)

--[[doc--

    Which features are active by default depends on the script
    requested.

--doc]]--

--- (string, string) dict -> (string, string) dict
local set_default_features = function (speclist)
    speclist = speclist or { }

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
            report("log", 0, "load",
                "support for the requested script: "
                .. "“%s” may be incomplete", script)
        end
    else
        script = "dflt"
    end
    speclist.script = script

    report("log", 0, "load",
        "auto-selecting default features for script: %s",
        script)

    local requested = defaults[script]
    if not requested then
        report("log", 0, "load",
            "no defaults for script “%s”, falling back to “dflt”",
            script)
        requested = defaults.dflt
    end

    for i=1, #requested do
        local feat = requested[i]
        if speclist[feat] ~= false then speclist[feat] = true end
    end

    for feat, state in next, global_defaults do
        --- This is primarily intended for setting node
        --- mode unless “base” is requested, as stated
        --- in the manual.
        if not speclist[feat] then speclist[feat] = state end
    end
    return speclist
end

-----------------------------------------------------------------------
---                    request syntax parser 2.2
-----------------------------------------------------------------------
--- the luaotfload font request syntax (see manual)
--- has a canonical form:
---
---     \font<csname>=<prefix>:<identifier>:<features>
---
--- where
---   <csname> is the control sequence that activates the font
---   <prefix> is either “file” or “name”, determining the lookup
---   <identifer> is either a file name (no path) or a font
---               name, depending on the lookup
---   <features> is a list of switches or options, separated by
---              semicolons or commas; a switch is of the form “+” foo
---              or “-” foo, options are of the form lhs “=” rhs
---
--- however, to ensure backward compatibility we also have
--- support for Xetex-style requests.
---
--- for the Xetex emulation see:
--- · The XeTeX Reference Guide by Will Robertson, 2011
--- · The XeTeX Companion by Michel Goosens, 2010
--- · About XeTeX by Jonathan Kew, 2005
---
---
--- caueat emptor.
---     the request is parsed into one of **four** different
---     lookup categories: the regular ones, file and name,
---     as well as the Xetex compatibility ones, path and anon.
---     (maybe a better choice of identifier would be “ambig”.)
---
---     according to my reconstruction, the correct chaining
---     of the lookups for each category is as follows:
---
---     | File -> ( db/filename lookup )
---
---     | Name -> ( db/name lookup,
---                 db/filename lookup )
---
---     | Path -> ( db/filename lookup,
---                 fullpath lookup )
---
---     | Anon -> ( kpse.find_file(),     // <- for tfm, ofm
---                 db/name lookup,
---                 db/filename lookup,
---                 fullpath lookup )
---
---     caching of successful lookups is essential. we now
---     as of v2.2 have an experimental lookup cache that is
---     stored in a separate file. it pertains only to name:
---     lookups, and is described in more detail in
---     luaotfload-database.lua.
---
-----------------------------------------------------------------------

--[[doc--

    One further incompatibility between Xetex and Luatex-Fonts consists
    in their option list syntax: apparently, Xetex requires key-value
    options to be prefixed by a "+" (ascii “plus”) character. We
    silently accept this as well, dropping the first byte if it is a
    plus or minus character.

    Reference: https://github.com/lualatex/luaotfload/issues/79#issuecomment-18104483

--doc]]--

local handle_normal_option = function (key, val)
    val = stringlower(val)
    --- the former “toboolean()” handler
    if val == "true"  then
        val = true
    elseif val == "false" then
        val = false
    end
    return key, val
end

--[[doc--

    Xetex style indexing begins at zero which we just increment before
    passing it along to the font loader.  Ymmv.

--doc]]--

local handle_xetex_option = function (key, val)
    val = stringlower(val)
    local numeric = tonumber(val) --- decimal only; keeps colors intact
    if numeric then --- ugh
        if  mathceil(numeric) == numeric then -- integer, possible index
            val = tostring(numeric + 1)
        end
    elseif val == "true"  then
        val = true
    elseif val == "false" then
        val = false
    end
    return key, val
end

--[[doc--

    Dirty test if a file: request is actually a path: lookup; don’t
    ask! Note this fails on Windows-style absolute paths. These will
    *really* have to use the correct request.

--doc]]--

local check_garbage = function (_,i, garbage)
    if stringfind(garbage, "/") then
        report("log", 0, "load",  --- ffs use path!
            "warning: path in file: lookups is deprecated; ")
        report("log", 0, "load", "use bracket syntax instead!")
        report("log", 0, "load",
            "position: %d; full match: “%s”",
            i, garbage)
        return true
    end
    return false
end

local lpegmatch = lpeg.match
local P, S, R   = lpeg.P, lpeg.S, lpeg.R
local C, Cc, Cf, Cg, Cmt, Cs, Ct
    = lpeg.C, lpeg.Cc, lpeg.Cf, lpeg.Cg, lpeg.Cmt, lpeg.Cs, lpeg.Ct

--- terminals and low-level classes -----------------------------------
--- note we could use the predefined ones from lpeg.patterns
local dot         = P"."
local colon       = P":"
local featuresep  = S",;"
local slash       = P"/"
local equals      = P"="
local lbrk, rbrk  = P"[", P"]"

local spacing     = S" \t\v"
local ws          = spacing^0

local digit       = R"09"
local alpha       = R("az", "AZ")
local anum        = alpha + digit
local decimal     = digit^1 * (dot * digit^0)^-1

--- modifiers ---------------------------------------------------------
--[[doc--
    The slash notation: called “modifiers” (Kew) or “font options”
    (Robertson, Goosens)
    we only support the shorthands for italic / bold / bold italic
    shapes, as well as setting optical size, the rest is ignored.
--doc]]--
local style_modifier    = (P"BI" + P"IB" + P"bi" + P"ib" + S"biBI")
                        / stringlower
local size_modifier     = S"Ss" * P"="    --- optical size
                        * Cc"optsize" * C(decimal)
local other_modifier    = P"AAT" + P"aat" --- apple stuff;  unsupported
                        + P"ICU" + P"icu" --- not applicable
                        + P"GR"  + P"gr"  --- sil stuff;    unsupported
local garbage_modifier  = ((1 - colon - slash)^0 * Cc(false))
local modifier          = slash * (other_modifier      --> ignore
                                 + Cs(style_modifier)  --> collect
                                 + Ct(size_modifier)   --> collect
                                 + garbage_modifier)   --> warn
local modifier_list     = Cg(Ct(modifier^0), "modifiers")

--- lookups -----------------------------------------------------------
local fontname          = C((1-S":(/")^1)  --- like luatex-fonts
local unsupported       = Cmt((1-S":(")^1, check_garbage)
local prefixed          = P"name:" * ws * Cg(fontname, "name")
--- initially we intended file: to emulate the behavior of
--- luatex-fonts, i.e. no paths allowed. after all, we do have XeTeX
--- emulation with the path lookup and it interferes with db lookups.
--- turns out fontspec and other widely used packages rely on file:
--- with paths already, so we’ll add a less strict rule here.  anyways,
--- we’ll emit a warning.
                        + P"file:" * ws * Cg(unsupported, "path")
                        + P"file:" * ws * Cg(fontname,    "file")
local unprefixed        = Cg(fontname, "anon")
local path_lookup       = lbrk * Cg(C((1-rbrk)^1), "path") * rbrk

--- features ----------------------------------------------------------
local field_char        = anum + S"+-." --- sic!
local field             = field_char^1
--- assignments are “lhs=rhs”
---              or “+lhs=rhs” (Xetex-style)
--- switches    are “+key” | “-key”
local normal_option     = C(field) * ws * equals * ws * C(field) * ws
local xetex_option      = P"+" * ws * normal_option
local assignment        = xetex_option  / handle_xetex_option
                        + normal_option / handle_normal_option
----- assignment        = (field / strip_leading_sign) * ws
-----                   * equals * ws
-----                   * (field / toboolean)
local switch            = P"+" * ws * C(field) * Cc(true)
                        + P"-" * ws * C(field) * Cc(false)
--                      +             C(field) * Cc(true) -- catch crap
local ignore            = (1 - featuresep)^1 --- ignores one option
local feature_expr      = ws * Cg(assignment + switch) * ws
local option            = feature_expr + ignore
local feature_list      = Cf(Ct""
                           * option
                           * (featuresep * option)^0
                           , rawset)
                        * featuresep^-1

--- other -------------------------------------------------------------
--- This rule is present in the original parser. It sets the “sub”
--- field of the specification which allows addressing a specific
--- font inside a TTC container. Neither in Luatex-Fonts nor in
--- Luaotfload is this documented, so we might as well silently drop
--- it. However, as backward compatibility is one of our prime goals we
--- just insert it here and leave it undocumented until someone cares
--- to ask. (Note: afair subfonts are numbered, but this rule matches a
--- string; I won’t mess with it though until someone reports a
--- problem.)
--- local subvalue   = P("(") * (C(P(1-S("()"))^1)/issub) * P(")") -- for Kim
--- Note to self: subfonts apparently start at index 0. Tested with
--- Cambria.ttc that includes “Cambria Math” at 0 and “Cambria” at 1.
--- Other values cause luatex to segfault.
local subfont           = P"(" * Cg((1 - S"()")^1, "sub") * P")"
--- top-level rules ---------------------------------------------------
--- \font\foo=<specification>:<features>
local features          = Cg(feature_list, "features")
local specification     = (prefixed + unprefixed)
                        * subfont^-1
                        * modifier_list^-1
local font_request      = Ct(path_lookup   * (colon^-1 * features)^-1
                           + specification * (colon    * features)^-1)

--  lpeg.print(font_request)
--- new parser: 657 rules
--- old parser: 230 rules

local import_values = {
    --- That’s what the 1.x parser did, not quite as graciously,
    --- with an array of branch expressions.
    -- "style", "optsize",--> from slashed notation; handled otherwise
    { "lookup", false },
    { "sub",    false },
    { "mode",   true },
}

local lookup_types = { "anon", "file", "name", "path" }

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
    b    = "bold",
    i    = "italic",
    bi   = "bolditalic",
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
            report("log", 0,
                "load", "unsupported font option: %s", v)
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
    local request = lpegmatch(font_request,
                              specification.specification)
    if not request then
        --- happens when called with an absolute path
        --- in an anonymous lookup;
        --- we try to behave as friendly as possible
        --- just go with it ...
        report("log", 1, "load", "invalid request “%s” of type anon",
            specification.specification)
        report("log", 1, "load",
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
    local lookup, name = select_lookup(request)
    request.features  = set_default_features(request.features)

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
            specification[feat]    = request.features[feat]
            if not keep then
                request.features[feat] = nil
            end
        end
    end

    --- The next line sets the “rand” feature to “random”; I haven’t
    --- investigated it any further (luatex-fonts-ext), so it will
    --- just stay here.
    specification.features.normal
        = fonts.handlers.otf.features.normalize(request.features)
    return specification
end

local compare_requests = function (spec)
    local old = old_behavior(spec)
    local new = handle_request(spec)
    return new
end

fonts.definers.registersplit(":", handle_request, "cryptic")
fonts.definers.registersplit("",  handle_request, "more cryptic") -- catches \font\text=[names]

---[[ end included font-ltx.lua ]]

--[[doc--
This uses the code from luatex-fonts-merged (<- font-otc.lua) instead
of the removed luaotfload-font-otc.lua.

TODO find out how far we get setting features without these lines,
relying on luatex-fonts only (it *does* handle features somehow, after
all).
--doc]]--

-- we assume that the other otf stuff is loaded already

---[[ begin snippet from font-otc.lua ]]
local trace_loading       = false  trackers.register("otf.loading", function(v) trace_loading = v end)
local report_otf          = logs.reporter("fonts","otf loading")

local otf                 = fonts.handlers.otf
local registerotffeature  = otf.features.register
local setmetatableindex   = table.setmetatableindex

--[[HH--

   In the userdata interface we can not longer tweak the loaded font as
   conveniently as before. For instance, instead of pushing extra data in
   in the table using the original structure, we now have to operate on
   the mkiv representation. And as the fontloader interface is modelled
   after fontforge we cannot change that one too much either.

--HH]]--

local types = {
    substitution = "gsub_single",
    ligature     = "gsub_ligature",
    alternate    = "gsub_alternate",
}

setmetatableindex(types, function(t,k) t[k] = k return k end) -- "key"

local everywhere = { ["*"] = { ["*"] = true } } -- or: { ["*"] = { "*" } }
local noflags    = { }

local function addfeature(data,feature,specifications)
    local descriptions = data.descriptions
    local resources    = data.resources
    local lookups      = resources.lookups
    local gsubfeatures = resources.features.gsub
    if gsubfeatures and gsubfeatures[feature] then
        -- already present
    else
        local sequences    = resources.sequences
        local fontfeatures = resources.features
        local unicodes     = resources.unicodes
        local lookuptypes  = resources.lookuptypes
        local splitter     = lpeg.splitter(" ",unicodes)
        local done         = 0
        local skip         = 0
        if not specifications[1] then
            -- so we accept a one entry specification
            specifications = { specifications }
        end
        -- subtables are tables themselves but we also accept flattened singular subtables
        for s=1,#specifications do
            local specification = specifications[s]
            local valid         = specification.valid
            if not valid or valid(data,specification,feature) then
                local initialize = specification.initialize
                if initialize then
                    -- when false is returned we initialize only once
                    specification.initialize = initialize(specification) and initialize or nil
                end
                local askedfeatures = specification.features or everywhere
                local subtables     = specification.subtables or { specification.data } or { }
                local featuretype   = types[specification.type or "substitution"]
                local featureflags  = specification.flags or noflags
                local added         = false
                local featurename   = stringformat("ctx_%s_%s",feature,s)
                local st = { }
                for t=1,#subtables do
                    local list = subtables[t]
                    local full = stringformat("%s_%s",featurename,t)
                    st[t] = full
                    if featuretype == "gsub_ligature" then
                        lookuptypes[full] = "ligature"
                        for code, ligature in next, list do
                            local unicode = tonumber(code) or unicodes[code]
                            local description = descriptions[unicode]
                            if description then
                                local slookups = description.slookups
                                if type(ligature) == "string" then
                                    ligature = { lpegmatch(splitter,ligature) }
                                end
                                local present = true
                                for i=1,#ligature do
                                    if not descriptions[ligature[i]] then
                                        present = false
                                        break
                                    end
                                end
                                if present then
                                    if slookups then
                                        slookups[full] = ligature
                                    else
                                        description.slookups = { [full] = ligature }
                                    end
                                    done, added = done + 1, true
                                else
                                    skip = skip + 1
                                end
                            end
                        end
                    elseif featuretype == "gsub_single" then
                        lookuptypes[full] = "substitution"
                        for code, replacement in next, list do
                            local unicode = tonumber(code) or unicodes[code]
                            local description = descriptions[unicode]
                            if description then
                                local slookups = description.slookups
                                replacement = tonumber(replacement) or unicodes[replacement]
                                if descriptions[replacement] then
                                    if slookups then
                                        slookups[full] = replacement
                                    else
                                        description.slookups = { [full] = replacement }
                                    end
                                    done, added = done + 1, true
                                end
                            end
                        end
                    end
                end
                if added then
                    -- script = { lang1, lang2, lang3 } or script = { lang1 = true, ... }
                    for k, v in next, askedfeatures do
                        if v[1] then
                            askedfeatures[k] = table.tohash(v)
                        end
                    end
                    sequences[#sequences+1] = {
                        chain     = 0,
                        features  = { [feature] = askedfeatures },
                        flags     = featureflags,
                        name      = featurename,
                        subtables = st,
                        type      = featuretype,
                    }
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
end

otf.enhancers.addfeature = addfeature

local extrafeatures = { }

function otf.addfeature(name,specification)
    extrafeatures[name] = specification
end

local function enhance(data,filename,raw)
    for feature, specification in next, extrafeatures do
        addfeature(data,feature,specification)
    end
end

otf.enhancers.register("check extra features",enhance)

---[[ end snippet from font-otc.lua ]]

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

otf.addfeature("tlig", tlig)
otf.addfeature("trep", { }) -- empty, all in tlig now

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

--[[doc--

    Below the specifications as given in the removed font-otc.lua.
    The rest was identical to what this file had from the beginning.
    Both make the “anum.tex” test pass anyways.

--doc]]--

otf.addfeature("anum",anum_specification)

registerotffeature {
    name        = 'anum',
    description = 'arabic digits',
}

-- vim:tw=71:sw=4:ts=4:expandtab
