
packageversion= "2.9"
packagestatus = "dev"
packagedate   = "0000-00-00"

module   = "luaotfload"
ctanpkg  = "luaotfload"

-- l3build check settings
stdengine    = "luatex"
checkengines = {"luatex"}
checkconfigs = {
                "build",
                "config-latex-TU",
                "config-unicode-math",
                "config-plain",
                "config-fontspec"
               }

checkruns = 3

-- l3build settings local folder descriptions 
sourcefiledir = "./src"
docfiledir    = "./doc" 

-- l3build settings for CTAN/install target
-- documentation

-- check if they should be relative to maindir or docfiledir
docfiles = {
  docfiledir.."/luaotfload.conf.rst",
  "COPYING",
  "./misc/luaotfload.conf.example",
  "NEWS",
  "README.md" -- perhaps later a README.md in doc which is different to the github readme
  }

typesetdemofiles = {"filegraph.tex"}
typesetfiles     = {"luaotfload-latex.tex"}

-- installation
tdsroot = "luatex"

sourcefiles  = {
                "luaotfload.sty",
                "**/*.lua",
                "luaotfload-blacklist.cnf",
                "**/*.tex"
                }
                
installfiles = {"*.sty","*.lua","*.tex"}

scriptfiles = {"luaotfload-tool.lua"} -- how install the mk-scripts???

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
-- options["texmfhome"] = lfs.currentdir().."/texmf"
-- this works:
 os.setenv("TEXMFHOME",lfs.currentdir().."/texmf")

kpse.set_program_name ("kpsewhich")
if not release_date then
 dofile ( kpse.lookup ("l3build.lua"))
end
