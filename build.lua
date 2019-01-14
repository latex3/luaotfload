
packageversion= "2.9406"
packagedate   = "2018-12-19"

local luatexstatus = status.list()
local ismiktex = string.match (luatexstatus.banner,"MiKTeX")


module   = "luaotfload"
ctanpkg  = "luaotfload"

-- l3build check settings
stdengine    = "luatex"
checkengines = {"luatex"}
checkconfigs = {
                "build",
                "config-loader-unpackaged",
                "config-loader-reference",
                "config-latex-TU",
                "config-unicode-math",
                "config-plain",
                "config-fontspec"
               }

checkruns = 3
checksuppfiles = {"texmf.cnf"} 

if os.env["CONTEXTPATH"] then 
  -- local system
  if ismiktex then
   excludetests = {"arabkernsfs","fontload-ttc-fontindex"}
  else
   excludetests = {}
  end
else
  -- travis or somewhere else ...
  excludetests = {"luatex-ja"}
end

-- table.insert(excludetests,"arab2") -- until bug is corrected.



-- l3build settings for CTAN/install target
packtdszip=true
sourcefiledir = "./src"

-- documentation
docfiledir    = "./doc" 

ctanreadme= "CTANREADME.md"

typesetexe = "lualatex"

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
    
  
typesetdemofiles  = {"filegraph.tex","luaotfload-conf.tex","luaotfload-tool.tex"}
-- typesetsuppfiles  = {"texmf.cnf"} --later

typesetfiles      = {"**/luaotfload-latex.tex"}
typesetcycles = 2 -- for the tests

-- installation
tdsroot = "luatex"

if options["target"] == "check" or options["target"] == "save" then 
  print("check/save")
--  sourcefiledir = "./dontexist"
  installfiles={} 
  sourcefiles={} 
  unpackfiles={}
else
  sourcefiles  = {
   "luaotfload.sty", 
   "**/luaotfload-*.lua",
   "**/fontloader-*.lua",
   "**/fontloader-*.tex",
   "luaotfload-blacklist.cnf",
   "./doc/filegraph.tex",
-- "./doc/luaotfload-conf.tex",
-- "./doc/luaotfload-tool.tex",
   "./doc/luaotfload-main.tex", 
                }
   installfiles = {
     "luaotfload.sty",
     "luaotfload-blacklist.cnf",
     "**/luaotfload-*.lua",
     "**/fontloader-b*.lua",
     "**/fontloader-d*.lua",
     "**/fontloader-f*.lua",
     "**/fontloader-l*.lua",
     "**/fontloader-u*.lua",
     "**/fontloader-reference.lua",
     "**/fontloader-2*.lua",
                }
end

scriptfiles   =  {"luaotfload-tool.lua"} 

scriptmanfiles = {"luaotfload.conf.5","luaotfload-tool.1"}

-- l3build settings for tags:

tagfiles = {
            "doc/CTANREADME.md",
            "README.md",
            "src/luaotfload.sty",
            "src/luaotfload-*.lua",
            "src/auto/luaotfload-glyphlist.lua",
            "doc/luaotfload-main.tex",
            "doc/luaotfload.conf.rst",
            "doc/luaotfload-tool.rst"
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
 end
 return content
 end

-- install directory is the texmf-tree
-- print(options["texmfhome"])
-- can this work??
options["texmfhome"] = "./texmf"

kpse.set_program_name ("kpsewhich")
if not release_date then
 dofile ( kpse.lookup ("l3build.lua"))
end
