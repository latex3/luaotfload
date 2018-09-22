--[[doc--
 luaotfload has tables with files list in many places. This makes maintenance difficult.
 This here is a try to get everything in one place. 
 As the order during the merge loading matters the table is an array.
 Sorted lists can be created with functions.
 Some redundancy can not be avoided for now if one want to avoid to have to change all sort of functions. 
 
 current locations
 mkimport script: decides which files to fetch (from two places) and which to merge in the default fontloader
 luaotfload-ini
 

--doc]]--

--- mkimport code:
--- Accounting of upstream files. There are different categories:
---
---   · *essential*: Files required at runtime.
---   · *merged*:    Files merged into the fontloader package.
---   · *ignored*:   Lua files not merged, but part of the format.
---   · *tex*:       TeX code, i.e. format and examples.
---   · *lualibs*:   Files merged, but also provided by the Lualibs package.
---   · *original*:  Files merged, but also provided by the Lualibs package.

local kind_essential = 0
local kind_merged    = 1
local kind_tex       = 2
local kind_ignored   = 3
local kind_lualibs   = 4
local kind_original  = 5

local kind_name = {
  [0] = "essential",
  [1] = "merged"   ,
  [2] = "tex"      ,
  [3] = "ignored"  ,
  [4] = "lualibs"  ,
  [5] = "original"
}

--[[mkimport--
mkimports needs an 
 --> "import" table with two subtables:
  --> fontloader, with the files to get from generic, scrtype = "ctxgene"
  --> context, with the files to get from context,    scrtype = "ctxbase"

and a 
 --> "package" table with 
  --> optional (probably unused)
  --> required = files of type kind_merged

--mkimport]]--



local   srcctxbase = "tex/context/base/mkiv/",
local   srcctxgene = "tex/generic/context/luatex/",
 
return 
 {
    { name = "l-lua"             , ours = "l-lua"             , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-lpeg"            , ours = "l-lpeg"            , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-function"        , ours = "l-function"        , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-string"          , ours = "l-string"          , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-table"           , ours = "l-table"           , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-io"              , ours = "l-io"              , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-file"            , ours = "l-file"            , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-boolean"         , ours = "l-boolean"         , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-math"            , ours = "l-math"            , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-unicode"         , ours = "l-unicode"         , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" }, 

    { name = "util-str"          , ours = "util-str"          , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "util-fil"          , ours = "util-fil"          , kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },

    { name = "basics-gen"        , ours = nil                 , kind = kind_essential , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" },
-- files merged in the fontloader. Two files are ignored
    { name = "data-con"          , ours = "data-con"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "basics-nod"        , ours = nil                 , kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" },
    { name = "basics-chr"        , ours = nil                 , kind = kind_ignored   , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" }, 
    { name = "font-ini"          , ours = "font-ini"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "fonts-mis"         , ours = nil                 , kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" }, 
    { name = "font-con"          , ours = "font-con"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "fonts-enc"         , ours = nil                 , kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" },
    { name = "font-cid"          , ours = "font-cid"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-map"          , ours = "font-map"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "fonts-syn"         , ours = nil                 , kind = kind_ignored   , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" },
    { name = "font-vfc"          , ours = "font-vfc"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" }, 
    { name = "font-otr"          , ours = "font-otr"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-oti"          , ours = "font-oti"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-ott"          , ours = "font-ott"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" }, 
    { name = "font-cff"          , ours = "font-cff"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-ttf"          , ours = "font-ttf"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-dsp"          , ours = "font-dsp"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-oup"          , ours = "font-oup"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-otl"          , ours = "font-otl"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-oto"          , ours = "font-oto"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-otj"          , ours = "font-otj"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-ota"          , ours = "font-ota"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-ots"          , ours = "font-ots"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-osd"          , ours = "font-osd"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-ocl"          , ours = "font-ocl"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-otc"          , ours = "font-otc"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-onr"          , ours = "font-onr"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-one"          , ours = "font-one"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-afk"          , ours = "font-afk"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-tfm"          , ours = "font-tfm"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-lua"          , ours = "font-lua"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-def"          , ours = "font-def"          , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" }, 
    { name = "fonts-def"         , ours = nil                 , kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" }, 
    { name = "fonts-ext"         , ours = nil                 , kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" },
    { name = "font-imp-tex"      , ours = "font-imp-tex"      , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-imp-ligatures", ours = "font-imp-ligatures", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-imp-italics"  , ours = "font-imp-italics"  , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-imp-effects"  , ours = "font-imp-effects"  , kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "fonts-lig"         , ours = nil                 , kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" }, 
    { name = "fonts-gbn"         , ours = nil                 , kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" }, 
-- end of files merged

    { name = "fonts-merged"      , ours = "reference"         , kind = kind_essential , srcdir= srcctxgene ,scrtype="ctxgene" , srcpref = "luatex-" },
 
--  this two files are useful as reference for the load order but should not be installed                                                              
    { name = "fonts"             , ours = "reference-load-order", kind = kind_ignored , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-"    }, -- corrected 22.09.2018, is not of type merged
    { name = "fonts"             , ours = "reference-load-order", kind = kind_tex     , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-"   },
}












} 


  optional = { --- components not included in the default package
--- UF: imho this table is not used and is only for information. 
--- The original initialization sequence by Hans Hagen, see the file
--- luatex-fonts.lua for details:
---
---   [01] l-lua.lua
---   [02] l-lpeg.lua
---   [03] l-function.lua
---   [04] l-string.lua
---   [05] l-table.lua
---   [06] l-io.lua
---   [07] l-file.lua
---   [08] l-boolean.lua
---   [09] l-math.lua
-- NEW     l-unicode.lua
---   [10] util-str.lua
---   [11] util-fil.lua
---   [12] luatex-basics-gen.lua
---   [13] data-con.lua
---   [14] luatex-basics-nod.lua
---   [15] luatex-basics-chr.lua
---   [16] font-ini.lua
---NEW     luatex-fonts-mis.lua
---   [17] font-con.lua
---   [18] luatex-fonts-enc.lua
---   [19] font-cid.lua
---   [20] font-map.lua
---   [21] luatex-fonts-syn.lua
---NEW     font-vfc.lua
---ORD[24] font-otr.lua 
---   [23] font-oti.lua
---NEW     font-ott.lua    
---   [25] font-cff.lua
---   [26] font-ttf.lua
---   [27] font-dsp.lua
---   [28] font-oup.lua
---   [29] font-otl.lua
---   [30] font-oto.lua
---   [31] font-otj.lua
---   [32] font-ota.lua
---   [33] font-ots.lua
---   [34] font-osd.lua
---   [35] font-ocl.lua
---   [36] font-otc.lua
---   [37] font-onr.lua
---   [38] font-one.lua
---   [39] font-afk.lua
---   [40] font-tfm.lua
---   [41] font-lua.lua
---   [42] font-def.lua
---REN[43] luatex-fonts-def.lua -- was font-xtx.lua
---   [44] luatex-fonts-ext.lua
---NEW     font-imp-tex.lua
---NEW     font-imp-ligatures.lua
---NEW     font-imp-italics.lua
---NEW     font-imp-effects.lua
---NEW     luatex-fonts-lig.lua  
---REN[45] luatex-fonts-gbn.lua -- was font-gbn.lua
---
--- Of these, nos. 01--11 are provided by the Lualibs. Keeping them
--- around in the Luaotfload fontloader is therefore unnecessary.
--- Packaging needs to account for this difference.

    "l-lua",
    "l-lpeg",
    "l-function",
    "l-string",
    "l-table",
    "l-io",
    "l-file",
    "l-boolean",
    "l-math",
    "l-unicode", -- NEW UF  18.09.2018
    "util-str",
    "util-fil",

--- Another file containing auxiliary definitions must be present
--- prior to initialization of the configuration.

    "luatex-basics-gen",  -- UF: NAMING? why not basics-gen?? see below

--- We have a custom script for autogenerating data so we don’t use the
--- definitions from upstream.

    "basics-chr",        -- UF: NAMING? why not luatex-basics-chr?? see above

  }, --[[ [package.optional] ]]

--- The files below constitute the “fontloader proper”. Some of the
--- functionality like file resolvers is overloaded later by
--- Luaotfload. Consequently, the resulting package is pretty
--- bare-bones and not usable independently.

  required = {

    "data-con",
    "basics-nod",
--  "basics-chr", -- is luaotfload-characters.lua the replacement??
    "font-ini",
    "font-con",
    "fonts-enc",
    "font-cid",
    "font-map",
    "font-vfc", --NEW 18.09.2018
    "font-oti",
    "font-otr",
    "font-ott", -- NEW 18.09.2018
    "font-cff",
    "font-ttf",
    "font-dsp",
    "font-oup",
    "font-otl",
    "font-oto",
    "font-otj",
    "font-ota",
    "font-ots",
    "font-osd",
    "font-ocl",
    "font-otc",
    "font-onr",
    "font-one",
    "font-afk",
    "font-tfm",
    "font-lua",
    "font-def",
    "fonts-def",          -- NEW 18.09.2018
    "fonts-ext",
    "font-imp-tex",       -- NEW
    "font-imp-ligatures", -- NEW
    "font-imp-italics",   -- NEW
    "font-imp-effects",   -- NEW
    "fonts-lig",          -- NEW   
    "fonts-gbn",          -- REN
    
  }, --[[ [package.required] ]]
