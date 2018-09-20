if not modules then modules = { } end modules ['l-sandbox'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- We use string instead of function variables, so 'io.open' instead of io.open. That
-- way we can still intercept repetetive overloads. One complication is that when we use
-- sandboxed functions in helpers in the sanbox checkers, we can get a recursion loop
-- so for that reason we need to keep originals around till we enable the sandbox.

-- if sandbox then return end

local global   = _G
local next     = next
local unpack   = unpack or table.unpack
local type     = type
local tprint   = texio and texio.write_nl or print
local tostring = tostring
local format   = string.format -- no formatters yet
local concat   = table.concat
local sort     = table.sort
local gmatch   = string.gmatch
local gsub     = string.gsub
local requiem  = require

sandbox            = { }
local sandboxed    = false
local overloads    = { }
local skiploads    = { }
local initializers = { }
local finalizers   = { }
local originals    = { }
local comments     = { }
local trace        = false
local logger       = false
local blocked      = { }

-- this comes real early, so that we can still alias

local function report(...)
    tprint("sandbox         ! " .. format(...)) -- poor mans tracer
end

sandbox.report = report

function sandbox.setreporter(r)
    report         = r
    sandbox.report = r
end

function sandbox.settrace(v)
    trace = v
end

function sandbox.setlogger(l)
    logger = type(l) == "function" and l or false
end

local function register(func,overload,comment)
    if type(func) == "function" then
        if type(overload) == "string" then
            comment  = overload
            overload = nil
        end
        local function f(...)
            if sandboxed then
                local overload = overloads[f]
                if overload then
                    if logger then
                        local result = { overload(func,...) }
                        logger {
                            comment   = comments[f] or tostring(f),
                            arguments = { ... },
                            result    = result[1] and true or false,
                        }
                        return unpack(result)
                    else
                        return overload(func,...)
                    end
                else
                    -- ignored, maybe message
                end
            else
                return func(...)
            end
        end
        if comment then
            comments[f] = comment
            if trace then
                report("registering function: %s",comment)
            end
        end
        overloads[f] = overload or false
        originals[f] = func
        return f
    end
end

local function redefine(func,comment)
    if type(func) == "function" then
        skiploads[func] = comment or comments[func] or "unknown"
        if overloads[func] == false then
            overloads[func] = nil -- not initialized anyway
        end
    end
end

sandbox.register = register
sandbox.redefine = redefine

function sandbox.original(func)
    return originals and originals[func] or func
end

function sandbox.overload(func,overload,comment)
    comment = comment or comments[func] or "?"
    if type(func) ~= "function" then
        if trace then
            report("overloading unknown function: %s",comment)
        end
    elseif type(overload) ~= "function" then
        if trace then
            report("overloading function with bad overload: %s",comment)
        end
    elseif overloads[func] == nil then
        if trace then
            report("function is not registered: %s",comment)
        end
    elseif skiploads[func] then
        if trace then
            report("function is not skipped: %s",comment)
        end
    else
        if trace then
            report("overloading function: %s",comment)
        end
        overloads[func] = overload
    end
    return func
end

local function whatever(specification,what,target)
    if type(specification) ~= "table" then
        report("%s needs a specification",what)
    elseif type(specification.category) ~= "string" or type(specification.action) ~= "function" then
        report("%s needs a category and action",what)
    elseif not sandboxed then
        target[#target+1] = specification
    elseif trace then
        report("already enabled, discarding %s",what)
    end
end

function sandbox.initializer(specification)
    whatever(specification,"initializer",initializers)
end

function sandbox.finalizer(specification)
    whatever(specification,"finalizer",finalizers)
end

function require(name)
    local n = gsub(name,"^.*[\\/]","")
    local n = gsub(n,"[%.].*$","")
    local b = blocked[n]
    if b == false then
        return nil -- e.g. ffi
    elseif b then
        if trace then
            report("using blocked: %s",n)
        end
        return b
    else
        if trace then
            report("requiring: %s",name)
        end
        return requiem(name)
    end
end

function blockrequire(name,lib)
    if trace then
        report("preventing reload of: %s",name)
    end
    blocked[name] = lib or _G[name] or false
end

function sandbox.enable()
    if not sandboxed then
        for i=1,#initializers do
            initializers[i].action()
        end
        for i=1,#finalizers do
            finalizers[i].action()
        end
        local nnot = 0
        local nyes = 0
        local cnot = { }
        local cyes = { }
        local skip = { }
        for k, v in next, overloads do
            local c = comments[k]
            if v then
                if c then
                    cyes[#cyes+1] = c
                else -- if not skiploads[k] then
                    nyes = nyes + 1
                end
            else
                if c then
                    cnot[#cnot+1] = c
                else -- if not skiploads[k] then
                    nnot = nnot + 1
                end
            end
        end
        for k, v in next, skiploads do
            skip[#skip+1] = v
        end
        if #cyes > 0 then
            sort(cyes)
            report("overloaded known: %s",concat(cyes," | "))
        end
        if nyes > 0 then
            report("overloaded unknown: %s",nyes)
        end
        if #cnot > 0 then
            sort(cnot)
            report("not overloaded known: %s",concat(cnot," | "))
        end
        if nnot > 0 then
            report("not overloaded unknown: %s",nnot)
        end
        if #skip > 0 then
            sort(skip)
            report("not overloaded redefined: %s",concat(skip," | "))
        end
        --
        initializers = nil
        finalizers   = nil
        originals    = nil
        sandboxed    = true
    end
end

blockrequire("lfs",lfs)
blockrequire("io",io)
blockrequire("os",os)
blockrequire("ffi",ffi)

-- require = register(require,"require")

-- we sandbox some of the built-in functions now:

-- todo: require
-- todo: load

local function supported(library)
    local l = _G[library]
 -- if l then
 --     for k, v in next, l do
 --         report("%s.%s",library,k)
 --     end
 -- end
    return l
end

-- io.tmpfile : we don't know where that one ends up but probably is user temp space
-- os.tmpname : no need to deal with this: outputs rubish anyway (\s9v0. \s9v0.1 \s9v0.2 etc)
-- os.tmpdir  : not needed either (luatex.vob000 luatex.vob000 etc)

-- os.setenv  : maybe
-- require    : maybe (normally taken from tree)
-- http etc   : maybe (all schemes that go outside)

loadfile = register(loadfile,"loadfile")

if supported("io") then
    io.open               = register(io.open,              "io.open")
    io.popen              = register(io.popen,             "io.popen") -- needs checking
    io.lines              = register(io.lines,             "io.lines")
    io.output             = register(io.output,            "io.output")
    io.input              = register(io.input,             "io.input")
end

if supported("os") then
    os.execute            = register(os.execute,           "os.execute")
    os.spawn              = register(os.spawn,             "os.spawn")
    os.exec               = register(os.exec,              "os.exec")
    os.rename             = register(os.rename,            "os.rename")
    os.remove             = register(os.remove,            "os.remove")
end

if supported("lfs") then
    lfs.chdir             = register(lfs.chdir,            "lfs.chdir")
    lfs.mkdir             = register(lfs.mkdir,            "lfs.mkdir")
    lfs.rmdir             = register(lfs.rmdir,            "lfs.rmdir")
    lfs.isfile            = register(lfs.isfile,           "lfs.isfile")
    lfs.isdir             = register(lfs.isdir,            "lfs.isdir")
    lfs.attributes        = register(lfs.attributes,       "lfs.attributes")
    lfs.dir               = register(lfs.dir,              "lfs.dir")
    lfs.lock_dir          = register(lfs.lock_dir,         "lfs.lock_dir")
    lfs.touch             = register(lfs.touch,            "lfs.touch")
    lfs.link              = register(lfs.link,             "lfs.link")
    lfs.setmode           = register(lfs.setmode,          "lfs.setmode")
    lfs.readlink          = register(lfs.readlink,         "lfs.readlink")
    lfs.shortname         = register(lfs.shortname,        "lfs.shortname")
    lfs.symlinkattributes = register(lfs.symlinkattributes,"lfs.symlinkattributes")
end

