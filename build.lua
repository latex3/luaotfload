
packageversion= "3.0003"
packagedate   = "2019-08-11"
packagedesc   = "bidi-dev"
checkformat   = "latex-dev" -- for travis until something better comes up

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

--------- setup things for a dev-version
-- See stackoverflow.com/a/12142066/212001 / build-config from latex2e
local errorlevel = os.execute("git rev-parse --abbrev-ref HEAD > branch.tmp")
local master_branch = true
if errorlevel ~= 0 then
  exit(1)
else
 local f = assert(io.open("branch.tmp", "rb"))
 local branch = f:read("*all")
 f:close()
 os.remove("branch.tmp")
 if  string.match(branch, "dev") then
    master_branch = false
    tdsroot = "latex-dev"
    print("creating/installing dev-version in " .. tdsroot)
    ctanpkg = ctanpkg .. "-dev"
    ctanzip = ctanpkg
    checkformat="latex-dev"
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

stdengine    = "luatex"
checkengines = {"luatex"}

 -- local errorlevel   = os.execute("harftex --version") 
 -- if not os.getenv('TRAVIS') and errorlevel==0 then 
 --  checkengines = {"luatex","harftex"}
 -- end 
 
-- temporary for test dev branch
if master_branch then 
checkconfigs = {
                "build",
                "config-loader-unpackaged",
                "config-loader-reference",
                "config-latex-TU",
                "config-unicode-math",
                "config-plain",
                "config-fontspec"
               }
else
checkconfigs = {
                "build",
               -- "config-loader-unpackaged",
               -- "config-loader-reference",
                "config-latex-TU",
                "config-unicode-math",
                "config-plain",
                "config-fontspec"
               }            
end
checkruns = 3
checksuppfiles = {"texmf.cnf"} 

-- exclude some text temporarly or in certain systems ...
if os.env["CONTEXTPATH"] then 
  -- local system
  if ismiktex then
   excludetests = {"arabkernsfs","fontload-ttc-fontindex"}
  else
   -- excludetests = {"luatex-ja"}
  end
else
  -- travis or somewhere else ...
  excludetests = {"luatex-ja","aux-resolve-fontname"}
end

---------------------------------------------
-- l3build settings for CTAN/install target
---------------------------------------------

packtdszip=true
sourcefiledir = "./src"
docfiledir    = "./doc" 
-- install directory is the texmf-tree
options = options or {}
options["texmfhome"] = "./texmf"

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
  "luaotfload-tool.rst"
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
   "luaotfload-tool.tex"
  }
-- typesetsuppfiles  = {"texmf.cnf"} --later

---------------------
-- installation
---------------------


if options["target"] == "check" or options["target"] == "save" then 
  print("check/save")
  installfiles ={} 
  sourcefiles  ={} 
  unpackfiles  ={}
else
  sourcefiles  = 
  {
    "luaotfload.sty", 
    "**/luaotfload-*.lua",
    "**/fontloader-*.lua",
    "**/fontloader-*.tex",
    "luaotfload-blacklist.cnf",
    "BidiMirroring-510.txt",
    "./doc/filegraph.tex",
    "./doc/luaotfload-main.tex", 
   }
   installfiles = {
     "luaotfload.sty",
     "luaotfload-blacklist.cnf",
     "BidiMirroring-510.txt",
     "**/luaotfload-*.lua",
     "**/fontloader-*.lua",
     "**/fontloader-*.tex",
                }
end
tdslocations=
 {
  "source/luatex/luaotfload/fontloader-reference-load-order.lua",
  "source/luatex/luaotfload/fontloader-reference-load-order.tex",
  "tex/generic/unicode-data/BidiMirroring-510.txt"
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
            "src/luaotfload-*.lua",
            "src/auto/luaotfload-glyphlist.lua",
            "doc/luaotfload-main.tex",
            "doc/luaotfload.conf.rst",
            "doc/luaotfload-tool.rst",
            "src/fontloader/runtime/fontloader-basics-gen.lua",
            "scripts/mkstatus",
            "testfiles/aaaaa-luakern.tlg"
            }

function typeset_demo_tasks()
 local errorlevel = 0
 errorlevel = run (docfiledir,"rst2man.py luaotfload.conf.rst luaotfload.conf.5")
 if errorlevel ~= 0 then
        return errorlevel
 end
 errorlevel = run (docfiledir,"rst2man.py luaotfload-tool.rst luaotfload-tool.1")
 if errorlevel ~= 0 then
        return errorlevel
 end
 errorlevel= run (typesetdir,"rst2xetex.py luaotfload.conf.rst luaotfload-conf.tex") 
 if errorlevel ~= 0 then
        return errorlevel
 end
 errorlevel=run (typesetdir,"rst2xetex.py luaotfload-tool.rst luaotfload-tool.tex")
 if errorlevel ~= 0 then
        return errorlevel
 end
 return 0
end 

function update_tag (file,content,tagname,tagdate)
 tagdate = string.gsub (packagedate,"-", "/")
 if string.match (file, "%.sty$" ) then
  content = string.gsub (content,  
                         "%d%d%d%d/%d%d/%d%d [a-z]+%d%.%d+",
                         tagdate.." v"..packageversion)
  return content  
 elseif string.match (file,"fontloader%-basic") then
  if master_branch then
    content = string.gsub (content,
                           "caches.namespace = 'generic%-dev'",
                           "caches.namespace = 'generic'")
  else 
   content = string.gsub (content,
                           "caches.namespace = 'generic'",
                           "caches.namespace = 'generic-dev'")
  end       
  return content                              
 elseif string.match (file, "%.lua$") then
  content = string.gsub (content,  
                         '(version%s*=%s*")%d%.%d+(",%s*--TAGVERSION)',
                         "%1"..packageversion.."%2")
  content = string.gsub (content,  
                         '(date%s*=%s*")%d%d%d%d%-%d%d%-%d%d(",%s*--TAGDATE)',
                         "%1"..packagedate.."%2")                                                                                           
  return content                         
 elseif string.match (file, "^README.md$") then
   content = string.gsub (content,  
                         "Version: %d%.%d+",
                         "Version: " .. packageversion )
   content = string.gsub (content,  
                         "version%-%d%.%d+",
                         "version-" .. packageversion ) 
   content = string.gsub (content,  
                         "for %d%.%d+",
                         "for " .. packageversion ) 
   content = string.gsub (content,  
                         "%d%d%d%d%-%d%d%-%d%d",
                         packagedate )
   local imgpackagedate = string.gsub (packagedate,"%-","--")                          
   content = string.gsub (content,  
                         "%d%d%d%d%-%-%d%d%-%-%d%d",
                         imgpackagedate)                                                                                                     
   return content
 elseif string.match (file, "CTANREADME.md$") then
   content = string.gsub (content,  
                         "VERSION: %d%.%d+",
                         "VERSION: " .. packageversion )
   content = string.gsub (content,  
                         "DATE: %d%d%d%d%-%d%d%-%d%d",
                         "DATE: " .. packagedate )                                                                          
   return content   
 elseif string.match (file, "%.tex$" ) then
   content = string.gsub (content,  
                         "%d%d%d%d%-%d%d%-%d%d v%d%.%d+",
                         packagedate.." v"..packageversion)
  return content    
 elseif string.match (file, "%.rst$" ) then
   content = string.gsub (content,  
                         "(:Date:%s+)%d%d%d%d%-%d%d%-%d%d",
                         "%1"..packagedate)
  content = string.gsub (content,  
                         "(:Version:%s+)%d%.%d+",
                         "%1"..packageversion)                       
  return content 
 elseif string.match (file,"mkstatus") then
  content= string.gsub (content,  
                         "v%d%.%d+/%d%d%d%d%-%d%d%-%d%d",
                         "v"..packageversion.."/"..packagedate)
 
  return content
 elseif string.match (file,"aaaaa%-luakern") then   
    content= string.gsub (content,  
                         "%d%.%d+%swith%sfontloaderxxx%d%d%d%dxxx%d%dxxx%d%d",
                         packageversion.." with fontloaderxxx"..string.gsub(packagedate,"[%-]","xxx"))

   return content                           
 end
 return content
 end


kpse.set_program_name ("kpsewhich")
if not release_date then
 dofile ( kpse.lookup ("l3build.lua"))
end
