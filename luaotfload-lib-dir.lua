if not modules then modules = { } end modules ['l-dir'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- dir.expandname will be merged with cleanpath and collapsepath

local type, select = type, select
local find, gmatch, match, gsub = string.find, string.gmatch, string.match, string.gsub
local concat, insert, remove, unpack = table.concat, table.insert, table.remove, table.unpack
local lpegmatch = lpeg.match

local P, S, R, C, Cc, Cs, Ct, Cv, V = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Cc, lpeg.Cs, lpeg.Ct, lpeg.Cv, lpeg.V

dir = dir or { }
local dir = dir
local lfs = lfs

local attributes = lfs.attributes
local walkdir    = lfs.dir
local isdir      = lfs.isdir
local isfile     = lfs.isfile
local currentdir = lfs.currentdir
local chdir      = lfs.chdir

-- in case we load outside luatex

if not isdir then
    function isdir(name)
        local a = attributes(name)
        return a and a.mode == "directory"
    end
    lfs.isdir = isdir
end

if not isfile then
    function isfile(name)
        local a = attributes(name)
        return a and a.mode == "file"
    end
    lfs.isfile = isfile
end

-- handy

function dir.current()
    return (gsub(currentdir(),"\\","/"))
end

-- optimizing for no find (*) does not save time

--~ local function globpattern(path,patt,recurse,action) -- fails in recent luatex due to some change in lfs
--~     local ok, scanner
--~     if path == "/" then
--~         ok, scanner = xpcall(function() return walkdir(path..".") end, function() end) -- kepler safe
--~     else
--~         ok, scanner = xpcall(function() return walkdir(path)      end, function() end) -- kepler safe
--~     end
--~     if ok and type(scanner) == "function" then
--~         if not find(path,"/$") then path = path .. '/' end
--~         for name in scanner do
--~             local full = path .. name
--~             local mode = attributes(full,'mode')
--~             if mode == 'file' then
--~                 if find(full,patt) then
--~                     action(full)
--~                 end
--~             elseif recurse and (mode == "directory") and (name ~= '.') and (name ~= "..") then
--~                 globpattern(full,patt,recurse,action)
--~             end
--~         end
--~     end
--~ end

local lfsisdir = isdir

local function isdir(path)
    path = gsub(path,"[/\\]+$","")
    return lfsisdir(path)
end

lfs.isdir = isdir

local function globpattern(path,patt,recurse,action)
    if path == "/" then
        path = path .. "."
    elseif not find(path,"/$") then
        path = path .. '/'
    end
    if isdir(path) then -- lfs.isdir does not like trailing /
        for name in walkdir(path) do -- lfs.dir accepts trailing /
            local full = path .. name
            local mode = attributes(full,'mode')
            if mode == 'file' then
                if find(full,patt) then
                    action(full)
                end
            elseif recurse and (mode == "directory") and (name ~= '.') and (name ~= "..") then
                globpattern(full,patt,recurse,action)
            end
        end
    end
end

dir.globpattern = globpattern

local function collectpattern(path,patt,recurse,result)
    local ok, scanner
    result = result or { }
    if path == "/" then
        ok, scanner, first = xpcall(function() return walkdir(path..".") end, function() end) -- kepler safe
    else
        ok, scanner, first = xpcall(function() return walkdir(path)      end, function() end) -- kepler safe
    end
    if ok and type(scanner) == "function" then
        if not find(path,"/$") then path = path .. '/' end
        for name in scanner, first do
            local full = path .. name
            local attr = attributes(full)
            local mode = attr.mode
            if mode == 'file' then
                if find(full,patt) then
                    result[name] = attr
                end
            elseif recurse and (mode == "directory") and (name ~= '.') and (name ~= "..") then
                attr.list = collectpattern(full,patt,recurse)
                result[name] = attr
            end
        end
    end
    return result
end

dir.collectpattern = collectpattern

local pattern = Ct {
    [1] = (C(P(".") + P("/")^1) + C(R("az","AZ") * P(":") * P("/")^0) + Cc("./")) * V(2) * V(3),
    [2] = C(((1-S("*?/"))^0 * P("/"))^0),
    [3] = C(P(1)^0)
}

local filter = Cs ( (
    P("**") / ".*" +
    P("*")  / "[^/]*" +
    P("?")  / "[^/]" +
    P(".")  / "%%." +
    P("+")  / "%%+" +
    P("-")  / "%%-" +
    P(1)
)^0 )

local function glob(str,t)
    if type(t) == "function" then
        if type(str) == "table" then
            for s=1,#str do
                glob(str[s],t)
            end
        elseif isfile(str) then
            t(str)
        else
            local split = lpegmatch(pattern,str) -- we could use the file splitter
            if split then
                local root, path, base = split[1], split[2], split[3]
                local recurse = find(base,"%*%*")
                local start = root .. path
                local result = lpegmatch(filter,start .. base)
                globpattern(start,result,recurse,t)
            end
        end
    else
        if type(str) == "table" then
            local t = t or { }
            for s=1,#str do
                glob(str[s],t)
            end
            return t
        elseif isfile(str) then
            if t then
                t[#t+1] = str
                return t
            else
                return { str }
            end
        else
            local split = lpegmatch(pattern,str) -- we could use the file splitter
            if split then
                local t = t or { }
                local action = action or function(name) t[#t+1] = name end
                local root, path, base = split[1], split[2], split[3]
                local recurse = find(base,"%*%*")
                local start = root .. path
                local result = lpegmatch(filter,start .. base)
                globpattern(start,result,recurse,action)
                return t
            else
                return { }
            end
        end
    end
end

dir.glob = glob

--~ list = dir.glob("**/*.tif")
--~ list = dir.glob("/**/*.tif")
--~ list = dir.glob("./**/*.tif")
--~ list = dir.glob("oeps/**/*.tif")
--~ list = dir.glob("/oeps/**/*.tif")

local function globfiles(path,recurse,func,files) -- func == pattern or function
    if type(func) == "string" then
        local s = func
        func = function(name) return find(name,s) end
    end
    files = files or { }
    local noffiles = #files
    for name in walkdir(path) do
        if find(name,"^%.") then
            --- skip
        else
            local mode = attributes(name,'mode')
            if mode == "directory" then
                if recurse then
                    globfiles(path .. "/" .. name,recurse,func,files)
                end
            elseif mode == "file" then
                if not func or func(name) then
                    noffiles = noffiles + 1
                    files[noffiles] = path .. "/" .. name
                end
            end
        end
    end
    return files
end

dir.globfiles = globfiles

-- t = dir.glob("c:/data/develop/context/sources/**/????-*.tex")
-- t = dir.glob("c:/data/develop/tex/texmf/**/*.tex")
-- t = dir.glob("c:/data/develop/context/texmf/**/*.tex")
-- t = dir.glob("f:/minimal/tex/**/*")
-- print(dir.ls("f:/minimal/tex/**/*"))
-- print(dir.ls("*.tex"))

function dir.ls(pattern)
    return concat(glob(pattern),"\n")
end

--~ mkdirs("temp")
--~ mkdirs("a/b/c")
--~ mkdirs(".","/a/b/c")
--~ mkdirs("a","b","c")

local make_indeed = true -- false

local onwindows = os.type == "windows" or find(os.getenv("PATH"),";")

if onwindows then

    function dir.mkdirs(...)
        local str, pth = "", ""
        for i=1,select("#",...) do
            local s = select(i,...)
            if s == "" then
                -- skip
            elseif str == "" then
                str = s
            else
                str = str .. "/" .. s
            end
        end
        local first, middle, last
        local drive = false
        first, middle, last = match(str,"^(//)(//*)(.*)$")
        if first then
            -- empty network path == local path
        else
            first, last = match(str,"^(//)/*(.-)$")
            if first then
                middle, last = match(str,"([^/]+)/+(.-)$")
                if middle then
                    pth = "//" .. middle
                else
                    pth = "//" .. last
                    last = ""
                end
            else
                first, middle, last = match(str,"^([a-zA-Z]:)(/*)(.-)$")
                if first then
                    pth, drive = first .. middle, true
                else
                    middle, last = match(str,"^(/*)(.-)$")
                    if not middle then
                        last = str
                    end
                end
            end
        end
        for s in gmatch(last,"[^/]+") do
            if pth == "" then
                pth = s
            elseif drive then
                pth, drive = pth .. s, false
            else
                pth = pth .. "/" .. s
            end
            if make_indeed and not isdir(pth) then
                lfs.mkdir(pth)
            end
        end
        return pth, (isdir(pth) == true)
    end

    --~ print(dir.mkdirs("","","a","c"))
    --~ print(dir.mkdirs("a"))
    --~ print(dir.mkdirs("a:"))
    --~ print(dir.mkdirs("a:/b/c"))
    --~ print(dir.mkdirs("a:b/c"))
    --~ print(dir.mkdirs("a:/bbb/c"))
    --~ print(dir.mkdirs("/a/b/c"))
    --~ print(dir.mkdirs("/aaa/b/c"))
    --~ print(dir.mkdirs("//a/b/c"))
    --~ print(dir.mkdirs("///a/b/c"))
    --~ print(dir.mkdirs("a/bbb//ccc/"))

else

    function dir.mkdirs(...)
        local str, pth = "", ""
        for i=1,select("#",...) do
            local s = select(i,...)
            if s and s ~= "" then -- we catch nil and false
                if str ~= "" then
                    str = str .. "/" .. s
                else
                    str = s
                end
            end
        end
        str = gsub(str,"/+","/")
        if find(str,"^/") then
            pth = "/"
            for s in gmatch(str,"[^/]+") do
                local first = (pth == "/")
                if first then
                    pth = pth .. s
                else
                    pth = pth .. "/" .. s
                end
                if make_indeed and not first and not isdir(pth) then
                    lfs.mkdir(pth)
                end
            end
        else
            pth = "."
            for s in gmatch(str,"[^/]+") do
                pth = pth .. "/" .. s
                if make_indeed and not isdir(pth) then
                    lfs.mkdir(pth)
                end
            end
        end
        return pth, (isdir(pth) == true)
    end

    --~ print(dir.mkdirs("","","a","c"))
    --~ print(dir.mkdirs("a"))
    --~ print(dir.mkdirs("/a/b/c"))
    --~ print(dir.mkdirs("/aaa/b/c"))
    --~ print(dir.mkdirs("//a/b/c"))
    --~ print(dir.mkdirs("///a/b/c"))
    --~ print(dir.mkdirs("a/bbb//ccc/"))

end

dir.makedirs = dir.mkdirs

-- we can only define it here as it uses dir.current

if onwindows then

    function dir.expandname(str) -- will be merged with cleanpath and collapsepath
        local first, nothing, last = match(str,"^(//)(//*)(.*)$")
        if first then
            first = dir.current() .. "/" -- dir.current sanitizes
        end
        if not first then
            first, last = match(str,"^(//)/*(.*)$")
        end
        if not first then
            first, last = match(str,"^([a-zA-Z]:)(.*)$")
            if first and not find(last,"^/") then
                local d = currentdir()
                if chdir(first) then
                    first = dir.current()
                end
                chdir(d)
            end
        end
        if not first then
            first, last = dir.current(), str
        end
        last = gsub(last,"//","/")
        last = gsub(last,"/%./","/")
        last = gsub(last,"^/*","")
        first = gsub(first,"/*$","")
        if last == "" or last == "." then
            return first
        else
            return first .. "/" .. last
        end
    end

else

    function dir.expandname(str) -- will be merged with cleanpath and collapsepath
        if not find(str,"^/") then
            str = currentdir() .. "/" .. str
        end
        str = gsub(str,"//","/")
        str = gsub(str,"/%./","/")
        str = gsub(str,"(.)/%.$","%1")
        return str
    end

end

file.expandname = dir.expandname -- for convenience

local stack = { }

function dir.push(newdir)
    insert(stack,currentdir())
    if newdir and newdir ~= "" then
        chdir(newdir)
    end
end

function dir.pop()
    local d = remove(stack)
    if d then
        chdir(d)
    end
    return d
end

local function found(...) -- can have nil entries
    for i=1,select("#",...) do
        local path = select(i,...)
        local kind = type(path)
        if kind == "string" then
            if isdir(path) then
                return path
            end
        elseif kind == "table" then
            -- here we asume no holes, i.e. an indexed table
            local path = found(unpack(path))
            if path then
                return path
            end
        end
    end
 -- return nil -- if we want print("crappath") to show something
end

dir.found = found
