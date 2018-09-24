
packageversion= "2.9"
packagestatus = "dev"
packagedate   = "2018-09-23"

module   = "luaotfload"
ctanpkg  = "luaotfload"

-- l3build check settings
stdengine    = "luatex"
checkengines = {"luatex"}
checkconfigs = {
                "build",
                "config-loader-unpacked",
                "config-loader-reference",
                "config-latex-TU",
                "config-unicode-math",
                "config-plain",
                "config-fontspec"
               }

checkruns = 3

-- l3build settings local folder descriptions 
sourcefiledir = "./src"
docfiledir    = "./doc" 
supportdir    = "./doc"

-- l3build settings for CTAN/install target
packtdszip=true

-- documentation

typesetexe = "lualatex"

docfiles = 
 {
  "luaotfload.conf.example",
  "luaotfload-main.tex"
  }

textfiles = 
 {
  "COPYING",
  "NEWS",
  docfiledir .. "/README.md",
  }
    
  
typesetdemofiles  = {"filegraph.tex","luaotfload-conf.tex","luaotfload-tool.tex"}
typesetsuppfiles   = {"luaotfload-main.tex"}
typesetfiles      = {"**/luaotfload-latex.tex"}
typsetcycles = 2 -- for the tests

-- installation
tdsroot = "luatex"

sourcefiles  = {
 "luaotfload.sty", 
 "**/luaotfload-*.lua",
 "**/fontloader-*.lua",
 "**/fontloader-*.tex",
 "luaotfload-blacklist.cnf",
 "./doc/filegraph.tex",
 "./doc/luaotfload-conf.tex",
 "./doc/luaotfload-tool.tex",
 "./doc/luaotfload-main.tex", 
                }
                
installfiles = {"luaotfload.sty",
                "luaotfload-blacklist.cnf",
                "luaotfload-configuration.lua",
               "luaotfload-init.lua",
               "luaotfload-filelist.lua",
               "luaotfload-letterspace.lua",
               "luaotfload-database.lua",
               "luaotfload-diagnostics.lua",
               "luaotfload-resolvers.lua",
               "luaotfload-log.lua",
               "luaotfload-auxiliary.lua",
               "luaotfload-main.lua",
               "luaotfload-glyphlist.lua",
               "luaotfload-features.lua",
               "luaotfload-colors.lua",
               "**/luaotfload-characters.lua",
               "**/luaotfload-status.lua",
               "**/luaotfload-glyphlist.lua",
               "luaotfload-loaders.lua",
               "luaotfload-parsers.lua",
               "**/fontloader-*.lua",
                "**/fontloader-*.tex",
                }


scriptfiles   =  {"luaotfload-tool.lua"} 

scriptmanfiles = {"luaotfload.conf.5","luaotfload-tool.1"}

-- l3build settings for tags:

tagfiles = {
            "src/*.md",
            "src/luaotfload.sty",
            "src/luaotfload-*.lua",
            "doc/luaotfload-main.tex",
            "doc/luaotfload.conf.rst"
            }

function update_tag (file,content,tagname,tagdate)
 tagdate = string.gsub (packagedate,"-", "/")
 if string.match (file, "%.sty$" ) then
  content = string.gsub (content,  
                         "%d%d%d%d/%d%d/%d%d [a-z]+%d%.%d+",
                         tagdate.." ".. packagestatus..packageversion)
  return content                         
 elseif string.match (file, "%.lua$") then
  content = string.gsub (content,  
                         "-- REQUIREMENTS:  luaotfload %d.%d+",
                         "-- REQUIREMENTS:  luaotfload "..packageversion)                         
  return content                         
 elseif string.match (file, "%.md$") then
   content = string.gsub (content,  
                         "Packageversion: %d%.%d",
                         "Packageversion: " .. packageversion )
   content = string.gsub (content,  
                         "Packagedate: %d%d%d%d/%d%d/%d%d",
                         "Packagedate: " .. tagdate )                      
   return content
 elseif string.match (file, "%.tex$" ) then
   content = string.gsub (content,  
                         "%d%d%d%d/%d%d/%d%d [a-z]+%d%.%d+",
                         tagdate.." ".. packagestatus..packageversion)
  return content    
 elseif string.match (file, "%.rst$" ) then
   content = string.gsub (content,  
                         "%d%d%d%d-%d%d-%d%d",
                         packagedate)
  content = string.gsub (content,  
                         ":Version:               2.8",
                         ":Version:               "..packageversion)                       
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
