packageversion= "3.28-dev"
packagedate   = "2024-02-14"
fontloaderdate= "2023-12-28"
packagedesc   = ""

module   = "luaotfload"
ctanpkg  = "luaotfload"
tdsroot  = "luatex"

-- load my personal data for the ctan upload
local ok, mydata = pcall(require, "ulrikefischerdata.lua")
if not ok then
  mydata= {email="XXX",github="XXX",name="XXX"}
end

-- test the email
print(mydata.email)

-- Allow for 'dev' release
--
-- See https://docs.github.com/en/actions/learn-github-actions/environment-variables
-- for the meaning of the environment variables, but tl;dr: GITHUB_REF_TYPE says
-- if we have a tag or a branch, GITHUB_REF_NAME has the corresponding name.
-- If either one of them isn't set, we look at the current git HEAD.
local main_branch do
  local gh_type = os.getenv'GITHUB_REF_TYPE'
  local name = os.getenv'GITHUB_REF_NAME'
  if gh_type == 'tag' and name then
    main_branch = not string.match(name, '-dev$')
  else
    if gh_type ~= 'branch' or not name then
      local f = io.popen'git rev-parse --abbrev-ref HEAD'
      name = f:read'*a':sub(1,-2)
      assert(f:close())
    end
    main_branch = string.match(name, '^main')
  end
  if not main_branch then
    tdsroot = "latex-dev"
    print("Creating/installing dev-version in " .. tdsroot)
    ctanpkg = ctanpkg .. "-dev"
    ctanzip = ctanpkg
  end
end
---------------------------------

uploadconfig = {
     pkg     = ctanpkg,
  version    = "v"..packageversion.." "..packagedate,
-- author    = "Ulrike Fischer;Philipp Gesang;Marcel Krüger;The LaTeX Team;Élie Roux;Manuel Pégourié-Gonnard (inactive);Khaled Hosny (inactive);Will Robertson (inactive)",
-- author list is too long
  author     = "... as before ...",
  license    = "gpl2",
  summary    = "OpenType ‘loader’ for Plain TeX and LaTeX",
  ctanPath   = "/macros/luatex/generic/"..ctanpkg,
  repository = "https://github.com/latex3/luaotfload",
  bugtracker = "https://github.com/latex3/luaotfload/issues",
  support    = "https://github.com/latex3/luaotfload/issues",
  uploader   = mydata.name,
  email      = mydata.email,
  update     = true ,
  topic      = {"font-use","luatex"},
  note       = [[Uploaded automatically by l3build... description is unchanged despite the missing linebreaks, authors are unchanged]],
  description=[[The package adopts the TrueType/OpenType Font loader code provided in ConTeXt,
              and adapts it to use in Plain TeX and LaTeX. It works under LuaLaTeX only.]],
  announcement_file="ctan.ann"
}

-- we perhaps need different settings for miktex ...
local luatexstatus = status.list()
local ismiktex = string.match (luatexstatus.banner,"MiKTeX")

-- l3build check settings

 stdengine     = "luatex"

checkformat   = "latex"
specialformats = specialformats or {}
specialformats["latex"] = specialformats["latex"] or
   {
    luatexdev     = {binary="luahbtex" ,format = "lualatex-dev"},
    luatex        = {binary="luahbtex" ,format = "lualatex"}
   } 

checkengines = {"luatex"}

checkconfigs = {
                "build",
                "config-harf",
                "config-loader-unpackaged",
                "config-loader-reference",
                "config-latex-TU",
                -- "config-unicode-math", 
                "config-plain",
                "config-fontspec",                
               }

checkruns = 3
checksuppfiles = {"texmf.cnf"}
typesetsuppfiles = {"texmf.cnf"}

maxprintline=9999

-- exclude some text temporarly or in certain systems ...
if os.env["CONTEXTPATH"] then
  -- local system
  --   excludetests = {"math"} -- because of adjdemerits bug
  if ismiktex then
   excludetests = {"arabkernsfs","fontload-ttc-fontindex"}
  else
   -- excludetests = {"luatex-ja"}
  end
else
  -- travis or somewhere else ...
  -- luacolor will fail until update ...
  excludetests = {"luatex-ja","aux-resolve-fontname","luacolor"}
end

---------------------------------------------
-- l3build settings for CTAN/install target
---------------------------------------------

packtdszip=true
sourcefiledir = "./src"
docfiledir    = "./doc"

-------------------
-- documentation
-------------------

typesetexe = "lua"..checkformat

-- main docu
typesetfiles      = {"luaotfload-latex.tex"}
typesetcycles = 3 -- for the tests

ctanreadme= "CTANREADME.md"

docfiles =
 {
  "luaotfload.conf.example",
  "luaotfload-main.tex",
  "luaotfload.conf.rst",
  "luaotfload-tool.rst",
  }

textfiles =
 {
  "COPYING",
  "NEWS",
   docfiledir .. "/CTANREADME.md",
  }

typesetdemofiles  =
  {
   "filegraph.tex",
   "luaotfload-conf.tex",
   "luaotfload-tool.tex",
   "shaper-demo-graphite.tex",
   "shaper-demo.tex",
   "scripts-demo.tex"
  }


---------------------
-- installation
---------------------


  sourcefiles  =
  {
    "luaotfload.sty",
    "**/luaotfload*.lua",
    "**/fontloader-*.lua",
    "**/fontloader-*.tex",
    "luaotfload-blacklist.cnf",
    "./doc/filegraph.tex",
    "./doc/luaotfload-main.tex",
   }
   installfiles = {
     "luaotfload.sty",
     "luaotfload-blacklist.cnf",
     "**/luaotfload*.lua",
     "**/fontloader-*.lua",
     "**/fontloader-*.tex",
                }

tdslocations=
 {
  "source/luatex/luaotfload/fontloader-reference-load-order.lua",
  "source/luatex/luaotfload/fontloader-reference-load-order.tex",
 }

scriptfiles   =  {"luaotfload-tool.lua"}

scriptmanfiles = {"luaotfload.conf.5","luaotfload-tool.1"}

-----------------------------
-- l3build settings for tags:
-----------------------------
tagfiles = {
            "doc/CTANREADME.md",
            "README.md",
            "src/luaotfload.sty",
            "src/luaotfload*.lua",
            "src/auto/luaotfload-glyphlist.lua",
            "src/auto/luaotfload-status.lua",
            "doc/luaotfload-main.tex",
            "doc/luaotfload.conf.rst",
            "doc/luaotfload-tool.rst",
            "src/fontloader/runtime/fontloader-basics-gen.lua",
            "scripts/mkstatus",
            "testfiles/aaaaa-luakern.tlg"
            }
   
 -- windows/UF
  function typeset_demo_tasks()
   local errorlevel = 0
   local pyextension 
   if os.type == "windows" then 
    pyextension = ".py" 
   else 
    pyextension = "" 
   end
   local rst2man   = "rst2man"    .. pyextension
   local rst2xetex = "rst2xetex" .. pyextension
   errorlevel = run (docfiledir, rst2man .." luaotfload.conf.rst luaotfload.conf.5")
   if errorlevel ~= 0 then
          return errorlevel
   end
   errorlevel = run (docfiledir, rst2man .." luaotfload-tool.rst luaotfload-tool.1")
   if errorlevel ~= 0 then
          return errorlevel
   end
   errorlevel= run (typesetdir, rst2xetex .. " luaotfload.conf.rst luaotfload-conf.tex")
   if errorlevel ~= 0 then
          return errorlevel
   end
   errorlevel=run (typesetdir, rst2xetex .. " luaotfload-tool.rst luaotfload-tool.tex")
   if errorlevel ~= 0 then
          return errorlevel
   end
   return 0
  end


local function lpeggsub(pattern)
  return lpeg.Cs(lpeg.P{pattern + (1 * (lpeg.V(1) + -1))}^0)
end
local digit = lpeg.R'09'
local spaces = lpeg.P' '^1
local function lpegrep(pattern,times)
  if times == 0 then return true end
  return pattern * lpegrep(pattern, times - 1)
end
local tagdatepat = lpeg.Cg( -- Date: YYYY/MM/DD
  lpegrep(digit, 4) * lpegrep('/' * digit * digit, 2)
  * lpeg.Cc(string.gsub(packagedate, '-', '/')))
local packagedatepat = lpeg.Cg( -- Date: YYYY-MM-DD
  lpegrep(digit, 4) * lpegrep('-' * digit * digit, 2)
  * lpeg.Cc(packagedate))
local imgpackagedatepat = lpeg.Cg( -- Date: YYYY--MM--DD
  lpegrep(digit, 4) * lpegrep('--' * digit * digit, 2)
  * lpeg.Cc(string.gsub(packagedate, '-', '--')))
local xxxpackagedatepat = lpeg.Cg( -- Date: YYYYxxxMMxxxDD
  lpegrep(digit, 4) * lpegrep('xxx' * digit * digit, 2)
  * lpeg.Cc(string.gsub(fontloaderdate, '-', 'xxx')))
local packageversionpat = lpeg.Cg( -- Version: M.mmmm-dev
  digit * '.' * digit^1 * lpeg.P'-dev'^-1
  * lpeg.Cc(packageversion))
local imgpackageversionpat = lpeg.Cg( -- Version: M.mmmm--dev
  digit * '.' * digit^1 * lpeg.P'--dev'^-1
  * lpeg.Cc(string.gsub(packageversion, '-', '--')))
local sty_pattern = lpeggsub(tagdatepat * ' v' * packageversionpat)
local tex_pattern = lpeggsub(packagedatepat * ' v' * packageversionpat)
local lua_pattern = lpeggsub(
      'version' * spaces * '=' * spaces
           * '"' * packageversionpat * '",' * spaces * '--TAGVERSION'
    + 'date' * spaces * '=' * spaces
           * '"' * packagedatepat * '",' * spaces * '--TAGDATE')
local readme_pattern = lpeggsub(
      (lpeg.P'Version: ' + 'for ') * packageversionpat
    + 'version-' * imgpackageversionpat
    + packagedatepat + imgpackagedatepat)
local ctanreadme_pattern = lpeggsub(
      'VERSION: ' * packageversionpat
    + 'DATE: ' * packagedatepat)
local rst_pattern = lpeggsub(
      ':Date:' * spaces * packagedatepat
    + ':Version:' * spaces * packageversionpat)
local status_pattern = lpeggsub('v' * packageversionpat * '/' * packagedatepat)
local fontloader_pattern = lpeggsub(
      packageversionpat * ' with fontloaderxxx' * xxxpackagedatepat)
function update_tag (file,content,_tagname,_tagdate)
  if string.match (file, "%.sty$" ) then
    return sty_pattern:match(content)
  elseif string.match (file,"fontloader%-basic") then
   if main_branch then
     return string.gsub (content,
                          "caches.namespace = 'generic%-dev'",
                          "caches.namespace = 'generic'")
   else
     return string.gsub (content,
                          "caches.namespace = 'generic'",
                          "caches.namespace = 'generic-dev'")
   end
  elseif file == "luaotfload-status.lua" then
   return status_pattern:match(content)
  elseif string.match (file, "%.lua$") then
    return lua_pattern:match(content)
  elseif file == 'README.md' then
    return readme_pattern:match(content)
  elseif string.match (file, "CTANREADME.md$") then
    return ctanreadme_pattern:match(content)
  elseif string.match (file, "%.tex$" ) then
    return tex_pattern:match(content)
  elseif string.match (file, "%.rst$" ) then
    return rst_pattern:match(content)
  elseif string.match (file,"mkstatus$") then
    return status_pattern:match(content)
  elseif string.match (file,"aaaaa%-luakern") then
    return fontloader_pattern:match(content)
  end
  return content
end


kpse.set_program_name ("kpsewhich")
if not release_date then
 dofile ( kpse.lookup ("l3build.lua"))
end
