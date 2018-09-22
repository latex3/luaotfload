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

--[[doc--
 (from mkimport code and extended)
 Accounting of upstream files. There are different categories:

   · *essential*:     Files required at runtime.
   · *merged*:        Files merged into the fontloader package.
   · *ignored*:       Lua files not merged, but part of the format.
   · *tex*:           TeX code, i.e. format and examples.
   · *lualibs*:       Files imported, but also provided by the Lualibs package.
   · *library*:       native luaotfload-files of type library
   · *core*:          native core luaotfload files
   · *generated*:     generated luaotfload files
   · *scripts*:       scripts (mk-...)
   · *docu*:          documentation (should perhaps be more refined
   
   
   
--doc]]--


local kind_essential = 0
local kind_merged    = 1
local kind_tex       = 2
local kind_ignored   = 3
local kind_lualibs   = 4
local kind_library   = 5
local kind_core      = 6
local kind_generated = 7
local kind_scripts   = 8
local kind_docu      = 9

local kind_name = {
  [0] = "essential",
  [1] = "merged"   ,
  [2] = "tex"      ,
  [3] = "ignored"  ,
  [4] = "lualibs"  ,
  [5] = "library"  ,
  [6] = "core",
  [7] = "generated",
  [8] = "scripts",
  [9] = "docu"
}

--[[mkimport--
mkimports needs an 
 --> "import" table with two subtables:
  --> fontloader, with the files to get from generic, cond: scrtype = "ctxgene"
  --> context, with the files to get from context,    cond: scrtype = "ctxbase"
  entries are subtables with {name=, ours=, kind= }

and a 
 --> "package" table with 
  --> optional (probably unused)
  --> required = files of type kind_merged
  entries are the values of name

--mkimport]]--

--[[mkstatus--
needs a list of files too ...
--mkstatus]]--

--[[init.lua --
initlua needs a table
--> context_modules
with the (ordered) entries

{false, "name"}            -- kind_lualibs
{srcdir,"scrprefix+name"} -- kind_essential or kind_merged 

The same list should be used in local init_main = function ()
but only without the prefix.
it is unclear how fonts_syn should be handled!!!!


--init.lua]]--



local   srcctxbase = "tex/context/base/mkiv/",
local   srcctxgene = "tex/generic/context/luatex/",

-- the "real" name of a file is srcpref+name+extension
 
return 
 {
  -- at first the source files from context
    { name = "l-lua"             , ours = "l-lua"             , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-lpeg"            , ours = "l-lpeg"            , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-function"        , ours = "l-function"        , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-string"          , ours = "l-string"          , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-table"           , ours = "l-table"           , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-io"              , ours = "l-io"              , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-file"            , ours = "l-file"            , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-boolean"         , ours = "l-boolean"         , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-math"            , ours = "l-math"            , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "l-unicode"         , ours = "l-unicode"         , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" }, 

    { name = "util-str"          , ours = "util-str"          , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "util-fil"          , ours = "util-fil"          , ext = ".lua", kind = kind_lualibs   , srcdir= srcctxbase, scrtype = "ctxbase" },

    { name = "basics-gen"        , ours = nil                 , ext = ".lua", kind = kind_essential , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" },
-- files merged in the fontloader. Two files are ignored
    { name = "data-con"          , ours = "data-con"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "basics-nod"        , ours = nil                 , ext = ".lua", kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" },
    { name = "basics-chr"        , ours = nil                 , ext = ".lua", kind = kind_ignored   , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" }, 
    { name = "font-ini"          , ours = "font-ini"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "fonts-mis"         , ours = nil                 , ext = ".lua", kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" }, 
    { name = "font-con"          , ours = "font-con"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "fonts-enc"         , ours = nil                 , ext = ".lua", kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" },
    { name = "font-cid"          , ours = "font-cid"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-map"          , ours = "font-map"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "fonts-syn"         , ours = nil                 , ext = ".lua", kind = kind_ignored   , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" },
    { name = "font-vfc"          , ours = "font-vfc"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" }, 
    { name = "font-otr"          , ours = "font-otr"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-oti"          , ours = "font-oti"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-ott"          , ours = "font-ott"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" }, 
    { name = "font-cff"          , ours = "font-cff"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-ttf"          , ours = "font-ttf"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-dsp"          , ours = "font-dsp"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-oup"          , ours = "font-oup"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-otl"          , ours = "font-otl"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-oto"          , ours = "font-oto"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-otj"          , ours = "font-otj"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-ota"          , ours = "font-ota"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-ots"          , ours = "font-ots"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-osd"          , ours = "font-osd"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-ocl"          , ours = "font-ocl"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-otc"          , ours = "font-otc"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-onr"          , ours = "font-onr"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-one"          , ours = "font-one"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-afk"          , ours = "font-afk"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-tfm"          , ours = "font-tfm"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-lua"          , ours = "font-lua"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-def"          , ours = "font-def"          , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" }, 
    { name = "fonts-def"         , ours = nil                 , ext = ".lua", kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" }, 
    { name = "fonts-ext"         , ours = nil                 , ext = ".lua", kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" },
    { name = "font-imp-tex"      , ours = "font-imp-tex"      , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-imp-ligatures", ours = "font-imp-ligatures", ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-imp-italics"  , ours = "font-imp-italics"  , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "font-imp-effects"  , ours = "font-imp-effects"  , ext = ".lua", kind = kind_merged    , srcdir= srcctxbase, scrtype = "ctxbase" },
    { name = "fonts-lig"         , ours = nil                 , ext = ".lua", kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" }, 
    { name = "fonts-gbn"         , ours = nil                 , ext = ".lua", kind = kind_merged    , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" }, 
-- end of files merged

    { name = "fonts-merged"      , ours = "reference"         , ext = ".lua", kind = kind_essential , srcdir= srcctxgene ,scrtype = "ctxgene" , srcpref = "luatex-" },


 
--  this two files are useful as reference for the load order but should not be installed                                                              
    { name = "fonts"             , ours = "load-order-reference", ext = ".lua", kind = kind_ignored , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" }, 
    { name = "fonts"             , ours = "load-order-reference", ext = ".tex", kind = kind_tex     , srcdir= srcctxgene, scrtype = "ctxgene" , srcpref = "luatex-" },

-- the default fontloader. How to code the name??
    { name = "YYYY-MM-DD"       ,          , ext = ".lua", kind = kind_generated },

-- the luaotfload files
    { name = "luaotfload"       ,kind = kind_core, ext =".sty"},
    { name = "main"              ,kind = kind_core, ext =".lua", srcpref = "luaotfload-" },
    { name = "init"              ,kind = kind_core, ext =".lua", srcpref = "luaotfload-" },
    { name = "log"               ,kind = kind_core, ext =".lua", srcpref = "luaotfload-" },
    { name = "diagnostics"       ,kind = kind_core, ext =".lua", srcpref = "luaotfload-" },
    
    { name = "tool"              ,kind = kind_core, ext =".lua", srcpref = "luaotfload-" ,tgtdir = "scripts" },
    { name = "blacklist"         ,kind = kind_core, ext =".cnf", srcpref = "luaotfload-" },


    { name = "auxiliary"         ,kind = kind_library, ext =".lua", srcpref = "luaotfload-" },
    { name = "colors"            ,kind = kind_library, ext =".lua", srcpref = "luaotfload-" },
    { name = "configuration"     ,kind = kind_library, ext =".lua", srcpref = "luaotfload-" },
    { name = "database"          ,kind = kind_library, ext =".lua", srcpref = "luaotfload-" },
    { name = "features"          ,kind = kind_library, ext =".lua", srcpref = "luaotfload-" }, 
    { name = "letterspace"       ,kind = kind_library, ext =".lua", srcpref = "luaotfload-" }, 
    { name = "loaders"           ,kind = kind_library, ext =".lua", srcpref = "luaotfload-" }, 
    { name = "parsers"           ,kind = kind_library, ext =".lua", srcpref = "luaotfload-" }, 
    { name = "resolvers"         ,kind = kind_library, ext =".lua", srcpref = "luaotfload-" }, 

    { name = "characters"        ,kind = kind_generated, ext =".lua", srcpref = "luaotfload-", script="mkcharacter" },
    { name = "glyphlist"         ,kind = kind_generated, ext =".lua", srcpref = "luaotfload-", script="mkglyphlist" },
    { name = "status"            ,kind = kind_generated, ext =".lua", srcpref = "luaotfload-", script="mkstatus" },
     


-- scripts
    { name = "mkimport"       ,kind = kind_script},
    { name = "mkglyphslist"   ,kind = kind_script},
    { name = "mkcharacters"   ,kind = kind_script},
    { name = "mkstatus"       ,kind = kind_script},
    { name = "mktest"         ,kind = kind_script},
    
-- documentation (source dirs need perhaps coding ...) but don't overdo for now

   { name = "latex"      , kind= kind_docu, ext = ".tex", scrpref = "luaotfload-", ctan=true,  typeset = true },
   { name = "main"       , kind= kind_docu, ext = ".tex", scrpref = "luaotfload-", ctan=true,  typeset = false },
   { name = "conf"       , kind= kind_docu, ext = ".tex", scrpref = "luaotfload-", ctan=true,  typeset = true , generated = true},
   { name = "tool"       , kind= kind_docu, ext = ".tex", scrpref = "luaotfload-", ctan=true,  typeset = true , generated = true},
   { name = "filegraph"  , kind= kind_docu, ext = ".tex",                          ctan=true,  typeset = true , generated = true},
   { name = "conf"       , kind= kind_docu, ext = ".rst", scrpref = "luaotfload.", ctan=false, },
   { name = "conf"       , kind= kind_docu, ext = ".5"  , scrpref = "luaotfload.", ctan=true, tgtdir = "man" },  
   { name = "tool"       , kind= kind_docu, ext = ".rst", scrpref = "luaotfload-", ctan=false, },       
   { name = "tool"       , kind= kind_docu, ext = ".1"  , scrpref = "luaotfload-", ctan=true, tgtdir = "man" },
   { name = "README"     , kind= kind_docu, ext = ".md" ,  ctan=true},
   { name = "COPYING"    , kind= kind_docu, ext = ""    ,  ctan=true},
   { name = "NEWS"       , kind= kind_docu, ext = ""    ,  ctan=true},
   
}














