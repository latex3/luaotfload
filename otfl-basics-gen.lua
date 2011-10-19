if not modules then modules = { } end modules ['luat-basics-gen'] = {
    version   = 1.100,
    comment   = "companion to luatex-*.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

if context then
    texio.write_nl("fatal error: this module is not for context")
    os.exit()
end

local dummyfunction = function() end
local dummyreporter = function(c) return function(...) texio.write(c .. " : " .. string.format(...)) end end

statistics = {
    register      = dummyfunction,
    starttiming   = dummyfunction,
    stoptiming    = dummyfunction,
    elapsedtime   = nil,
}

directives = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}

trackers = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}

experiments = {
    register      = dummyfunction,
    enable        = dummyfunction,
    disable       = dummyfunction,
}

storage = { -- probably no longer needed
    register      = dummyfunction,
    shared        = { },
}

logs = {
    new           = dummyreporter,
    reporter      = dummyreporter,
    messenger     = dummyreporter,
    report        = dummyfunction,
}

callbacks = {
    register = function(n,f) return callback.register(n,f) end,

}

utilities = {
    storage = {
        allocate = function(t) return t or { } end,
        mark     = function(t) return t or { } end,
    },
}

characters = characters or {
    data = { }
}

-- we need to cheat a bit here

texconfig.kpse_init = true

resolvers = resolvers or { } -- no fancy file helpers used

local remapper = {
    otf   = "opentype fonts",
    ttf   = "truetype fonts",
    ttc   = "truetype fonts",
    dfont = "truetype fonts", -- "truetype dictionary",
    cid   = "cid maps",
    fea   = "font feature files",
    pfa   = "type1 fonts", -- this is for Khaled, in ConTeXt we don't use this!
    pfb   = "type1 fonts", -- this is for Khaled, in ConTeXt we don't use this!
}

function resolvers.findfile(name,fileformat)
    name = string.gsub(name,"\\","\/")
    fileformat = fileformat and string.lower(fileformat)
    local found = kpse.find_file(name,(fileformat and fileformat ~= "" and (remapper[fileformat] or fileformat)) or file.extname(name,"tex"))
    if not found or found == "" then
        found = kpse.find_file(name,"other text files")
    end
    return found
end

function resolvers.findbinfile(name,fileformat)
    if not fileformat or fileformat == "" then
        fileformat = file.extname(name) -- string.match(name,"%.([^%.]-)$")
    end
    return resolvers.findfile(name,(fileformat and remapper[fileformat]) or fileformat)
end

function resolvers.resolve(s)
    return s
end

function resolvers.unresolve(s)
    return s
end

-- Caches ... I will make a real stupid version some day when I'm in the
-- mood. After all, the generic code does not need the more advanced
-- ConTeXt features. Cached data is not shared between ConTeXt and other
-- usage as I don't want any dependency at all. Also, ConTeXt might have
-- different needs and tricks added.

--~ containers.usecache = true

caches = { }

local writable, readables = nil, { }

if not caches.namespace or caches.namespace == "" or caches.namespace == "context" then
    caches.namespace = 'generic'
end

do

    local cachepaths = kpse.expand_path('$TEXMFCACHE') or ""

    if cachepaths == "" then
        cachepaths = kpse.expand_path('$TEXMFVAR')
    end

    if cachepaths == "" then
        cachepaths = kpse.expand_path('$VARTEXMF')
    end

    if cachepaths == "" then
        cachepaths = "."
    end

    cachepaths = string.split(cachepaths,os.type == "windows" and ";" or ":")

    for i=1,#cachepaths do
        if file.is_writable(cachepaths[i]) then
            writable = file.join(cachepaths[i],"luatex-cache")
            lfs.mkdir(writable)
            writable = file.join(writable,caches.namespace)
            lfs.mkdir(writable)
            break
        end
    end

    for i=1,#cachepaths do
        if file.is_readable(cachepaths[i]) then
            readables[#readables+1] = file.join(cachepaths[i],"luatex-cache",caches.namespace)
        end
    end

    if not writable then
        texio.write_nl("quiting: fix your writable cache path")
        os.exit()
    elseif #readables == 0 then
        texio.write_nl("quiting: fix your readable cache path")
        os.exit()
    elseif #readables == 1 and readables[1] == writable then
        texio.write(string.format("(using cache: %s)",writable))
    else
        texio.write(string.format("(using write cache: %s)",writable))
        texio.write(string.format("(using read cache: %s)",table.concat(readables, " ")))
    end

end

function caches.getwritablepath(category,subcategory)
    local path = file.join(writable,category)
    lfs.mkdir(path)
    path = file.join(path,subcategory)
    lfs.mkdir(path)
    return path
end

function caches.getreadablepaths(category,subcategory)
    local t = { }
    for i=1,#readables do
        t[i] = file.join(readables[i],category,subcategory)
    end
    return t
end

local function makefullname(path,name)
    if path and path ~= "" then
        name = "temp-" .. name -- clash prevention
        return file.addsuffix(file.join(path,name),"lua"), file.addsuffix(file.join(path,name),"luc")
    end
end

function caches.is_writable(path,name)
    local fullname = makefullname(path,name)
    return fullname and file.is_writable(fullname)
end

function caches.loaddata(paths,name)
    for i=1,#paths do
        local data = false
        local luaname, lucname = makefullname(paths[i],name)
        if lucname and lfs.isfile(lucname) then
            texio.write(string.format("(load: %s)",lucname))
            data = loadfile(lucname)
        end
        if not data and luaname and lfs.isfile(luaname) then
            texio.write(string.format("(load: %s)",luaname))
            data = loadfile(luaname)
        end
        return data and data()
    end
end

function caches.savedata(path,name,data)
    local luaname, lucname = makefullname(path,name)
    if luaname then
        texio.write(string.format("(save: %s)",luaname))
        table.tofile(luaname,data,true,{ reduce = true })
        if lucname and type(caches.compile) == "function" then
            os.remove(lucname) -- better be safe
            texio.write(string.format("(save: %s)",lucname))
            caches.compile(data,luaname,lucname)
        end
    end
end

-- According to KH os.execute is not permitted in plain/latex so there is
-- no reason to use the normal context way. So the method here is slightly
-- different from the one we have in context. We also use different suffixes
-- as we don't want any clashes (sharing cache files is not that handy as
-- context moves on faster.)
--
-- Beware: serialization might fail on large files (so maybe we should pcall
-- this) in which case one should limit the method to luac and enable support
-- for execution.

caches.compilemethod = "luac" -- luac dump both

function caches.compile(data,luaname,lucname)
    local done = false
    if caches.compilemethod == "luac" or caches.compilemethod == "both" then
        local command = "-o " .. string.quoted(lucname) .. " -s " .. string.quoted(luaname)
        done = os.spawn("texluac " .. command) == 0
    end
    if not done and (caches.compilemethod == "dump" or caches.compilemethod == "both") then
        local d = table.serialize(data,true)
        if d and d ~= "" then
            local f = io.open(lucname,'w')
            if f then
                local s = loadstring(d)
                f:write(string.dump(s))
                f:close()
            end
        end
    end
end

--

function table.setmetatableindex(t,f)
    setmetatable(t,{ __index = f })
end
