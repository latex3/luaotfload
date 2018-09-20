if not modules then modules = { } end modules ['util-env'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local allocate, mark = utilities.storage.allocate, utilities.storage.mark

local format, sub, match, gsub, find = string.format, string.sub, string.match, string.gsub, string.find
local unquoted, quoted, optionalquoted = string.unquoted, string.quoted, string.optionalquoted
local concat, insert, remove = table.concat, table.insert, table.remove

environment         = environment or { }
local environment   = environment

-- locales are a useless feature in and even dangerous for luatex

local setlocale = os.setlocale

setlocale(nil,nil) -- setlocale("all","C")

-- function os.resetlocale()
--     setlocale(nil,nil)
-- end
--
-- function os.pushlocale(l,...)
--     insert(stack, {
--         collate  = setlocale(nil,"collate"),
--         ctype    = setlocale(nil,"ctype"),
--         monetary = setlocale(nil,"monetary"),
--         numeric  = setlocale(nil,"numeric"),
--         time     = setlocale(nil,"time"),
--     })
--     if l then
--         setlocale(l,...)
--     else
--         setlocale(status.lc_collate ,"collate"),
--         setlocale(status.lc_ctype   ,"ctype"),
--         setlocale(status.lc_monetary,"monetary"),
--         setlocale(status.lc_numeric ,"numeric"),
--         setlocale(status.lc_time    ,"time"),
--     end
-- end
--
-- function os.poplocale()
--     local l = remove(stack)
--     if l then
--         setlocale(unpack(l))
--     else
--         resetlocale()
--     end
-- end

local report = logs.reporter("system")

function os.setlocale(a,b)
    if a or b then
        if report then
            report()
            report("You're messing with os.locale in a supposedly locale neutral enviroment. From")
            report("now on are on your own and without support. Crashes or unexpected side effects")
            report("can happen but don't bother the luatex and context developer team with it.")
            report()
            report = nil
        end
        setlocale(a,b)
    end
end

-- dirty tricks (we will replace the texlua call by luatex --luaonly)

local validengines = allocate {
    ["luatex"]        = true,
    ["luajittex"]     = true,
 -- ["luatex.exe"]    = true,
 -- ["luajittex.exe"] = true,
}

local basicengines = allocate {
    ["luatex"]        = "luatex",
    ["texlua"]        = "luatex",
    ["texluac"]       = "luatex",
    ["luajittex"]     = "luajittex",
    ["texluajit"]     = "luajittex",
 -- ["texlua.exe"]    = "luatex",
 -- ["texluajit.exe"] = "luajittex",
}

local luaengines = allocate {
    ["lua"]    = true,
    ["luajit"] = true,
}

environment.validengines = validengines
environment.basicengines = basicengines

-- [-1] = binary
-- [ 0] = self
-- [ 1] = argument 1 ...

-- instead we could set ranges

if not arg then
    environment.used_as_library = true
    -- used as library
elseif luaengines[file.removesuffix(arg[-1])] then
--     arg[-1] = arg[0]
--     arg[ 0] = arg[1]
--     for k=2,#arg do
--         arg[k-1] = arg[k]
--     end
--     remove(arg) -- last
--
--    environment.used_as_library = true
elseif validengines[file.removesuffix(arg[0])] then
    if arg[1] == "--luaonly" then
        arg[-1] = arg[0]
        arg[ 0] = arg[2]
        for k=3,#arg do
            arg[k-2] = arg[k]
        end
        remove(arg) -- last
        remove(arg) -- pre-last
    else
        -- tex run
    end

    -- This is an ugly hack but it permits symlinking a script (say 'context') to 'mtxrun' as in:
    --
    --   ln -s /opt/minimals/tex/texmf-linux-64/bin/mtxrun context
    --
    -- The special mapping hack is needed because 'luatools' boils down to 'mtxrun --script base'
    -- but it's unlikely that there will be more of this

    local originalzero   = file.basename(arg[0])
    local specialmapping = { luatools == "base" }

    if originalzero ~= "mtxrun" and originalzero ~= "mtxrun.lua" then
       arg[0] = specialmapping[originalzero] or originalzero
       insert(arg,0,"--script")
       insert(arg,0,"mtxrun")
    end

end

-- environment

environment.arguments   = allocate()
environment.files       = allocate()
environment.sortedflags = nil

-- context specific arguments (in order not to confuse the engine)

function environment.initializearguments(arg)
    local arguments, files = { }, { }
    environment.arguments, environment.files, environment.sortedflags = arguments, files, nil
    for index=1,#arg do
        local argument = arg[index]
        if index > 0 then
            local flag, value = match(argument,"^%-+(.-)=(.-)$")
            if flag then
                flag = gsub(flag,"^c:","")
                arguments[flag] = unquoted(value or "")
            else
                flag = match(argument,"^%-+(.+)")
                if flag then
                    flag = gsub(flag,"^c:","")
                    arguments[flag] = true
                else
                    files[#files+1] = argument
                end
            end
        end
    end
    environment.ownname = file.reslash(environment.ownname or arg[0] or 'unknown.lua')
end

function environment.setargument(name,value)
    environment.arguments[name] = value
end

-- todo: defaults, better checks e.g on type (boolean versus string)
--
-- tricky: too many hits when we support partials unless we add
-- a registration of arguments so from now on we have 'partial'

function environment.getargument(name,partial)
    local arguments, sortedflags = environment.arguments, environment.sortedflags
    if arguments[name] then
        return arguments[name]
    elseif partial then
        if not sortedflags then
            sortedflags = allocate(table.sortedkeys(arguments))
            for k=1,#sortedflags do
                sortedflags[k] = "^" .. sortedflags[k]
            end
            environment.sortedflags = sortedflags
        end
        -- example of potential clash: ^mode ^modefile
        for k=1,#sortedflags do
            local v = sortedflags[k]
            if find(name,v) then
                return arguments[sub(v,2,#v)]
            end
        end
    end
    return nil
end

environment.argument = environment.getargument

function environment.splitarguments(separator) -- rather special, cut-off before separator
    local done, before, after = false, { }, { }
    local originalarguments = environment.originalarguments
    for k=1,#originalarguments do
        local v = originalarguments[k]
        if not done and v == separator then
            done = true
        elseif done then
            after[#after+1] = v
        else
            before[#before+1] = v
        end
    end
    return before, after
end

function environment.reconstructcommandline(arg,noquote)
    local resolveprefix = resolvers.resolve -- something rather special
    arg = arg or environment.originalarguments
    if noquote and #arg == 1 then
        return unquoted(resolveprefix and resolveprefix(arg[1]) or arg[1])
    elseif #arg > 0 then
        local result = { }
        for i=1,#arg do
            result[i] = optionalquoted(resolveprefix and resolveprefix(arg[i]) or resolveprefix)
        end
        return concat(result," ")
    else
        return ""
    end
end

-- handy in e.g. package.addluapath(environment.relativepath("scripts"))

function environment.relativepath(path,root)
    if not path then
        path = ""
    end
    if not file.is_rootbased_path(path) then
        if not root then
            root = file.pathpart(environment.ownscript or environment.ownname or ".")
        end
        if root == "" then
            root = "."
        end
        path = root .. "/" .. path
    end
    return file.collapsepath(path,true)
end

-- -- when script lives on e:/tmp we get this:
--
-- print(environment.relativepath("x/y/z","c:/w")) -- c:/w/x/y/z
-- print(environment.relativepath("x"))            -- e:/tmp/x
-- print(environment.relativepath("../x"))         -- e:/x
-- print(environment.relativepath("./x"))          -- e:/tmp/x
-- print(environment.relativepath("/x"))           -- /x
-- print(environment.relativepath("c:/x"))         -- c:/x
-- print(environment.relativepath("//x"))          -- //x
-- print(environment.relativepath())               -- e:/tmp

if arg then

    -- new, reconstruct quoted snippets (maybe better just remove the " then and add them later)

    local newarg, instring = { }, false

    for index=1,#arg do
        local argument = arg[index]
        if find(argument,"^\"") then
            if find(argument,"\"$") then
                newarg[#newarg+1] = gsub(argument,"^\"(.-)\"$","%1")
                instring = false
            else
                newarg[#newarg+1] = gsub(argument,"^\"","")
                instring = true
            end
        elseif find(argument,"\"$") then
            if instring then
                newarg[#newarg] = newarg[#newarg] .. " " .. gsub(argument,"\"$","")
                instring = false
            else
                newarg[#newarg+1] = argument
            end
        elseif instring then
            newarg[#newarg] = newarg[#newarg] .. " " .. argument
        else
            newarg[#newarg+1] = argument
        end
    end
    for i=1,-5,-1 do
        newarg[i] = arg[i]
    end

    environment.initializearguments(newarg)

    environment.originalarguments = mark(newarg)
    environment.rawarguments      = mark(arg)

    arg = { } -- prevent duplicate handling

end
