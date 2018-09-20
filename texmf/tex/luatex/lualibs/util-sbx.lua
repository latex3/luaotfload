if not modules then modules = { } end modules ['util-sbx'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- Note: we use expandname and collapsepath and these use chdir
-- which is overloaded so we need to use originals there. Just
-- something to keep in mind.

if not sandbox then require("l-sandbox") end -- for testing

local next, type = next, type

local replace        = utilities.templates.replace
local collapsepath   = file.collapsepath
local expandname     = dir.expandname
local sortedhash     = table.sortedhash
local lpegmatch      = lpeg.match
local platform       = os.type
local P, S, C        = lpeg.P, lpeg.S, lpeg.C
local gsub           = string.gsub
local lower          = string.lower
local find           = string.find
local concat         = string.concat
local unquoted       = string.unquoted
local optionalquoted = string.optionalquoted
local basename       = file.basename
local nameonly       = file.nameonly

local sandbox        = sandbox
local validroots     = { }
local validrunners   = { }
local validbinaries  = true -- all permitted
local validlibraries = true -- all permitted
local validators     = { }
local finalized      = nil
local trace          = false

local p_validroot    = nil
local p_split        = lpeg.firstofsplit(" ")

local report         = logs.reporter("sandbox")

trackers.register("sandbox",function(v) trace = v end) -- often too late anyway

sandbox.setreporter(report)

sandbox.finalizer {
    category = "files",
    action   = function()
        finalized = true
    end
}

local function registerroot(root,what) -- what == read|write
    if finalized then
        report("roots are already finalized")
    else
        if type(root) == "table" then
            root, what = root[1], root[2]
        end
        if type(root) == "string" and root ~= "" then
            root = collapsepath(expandname(root))
         -- if platform == "windows" then
         --     root = lower(root) -- we assume ascii names
         -- end
            if what == "r" or what == "ro" or what == "readable" then
                what = "read"
            elseif what == "w" or what == "wo" or what == "writable" then
                what = "write"
            end
            -- true: read & write | false: read
            validroots[root] = what == "write" or false
        end
    end
end

sandbox.finalizer {
    category = "files",
    action   = function() -- initializers can set the path
        if p_validroot then
            report("roots are already initialized")
        else
            sandbox.registerroot(".","write") -- always ok
            -- also register texmf as read
            for name in sortedhash(validroots) do
                if p_validroot then
                    p_validroot = P(name) + p_validroot
                else
                    p_validroot = P(name)
                end
            end
            p_validroot = p_validroot / validroots
        end
    end
}

local function registerbinary(name)
    if finalized then
        report("binaries are already finalized")
    elseif type(name) == "string" and name ~= "" then
        if not validbinaries then
            return
        end
        if validbinaries == true then
            validbinaries = { [name] = true }
        else
            validbinaries[name] = true
        end
    elseif name == true then
        validbinaries = { }
    end
end

local function registerlibrary(name)
    if finalized then
        report("libraries are already finalized")
    elseif type(name) == "string" and name ~= "" then
        if not validlibraries then
            return
        end
        if validlibraries == true then
            validlibraries = { [nameonly(name)] = true }
        else
            validlibraries[nameonly(name)] = true
        end
    elseif name == true then
        validlibraries = { }
    end
end

-- begin of validators

local p_write = S("wa")       p_write = (1 - p_write)^0 * p_write
local p_path  = S("\\/~$%:")  p_path  = (1 - p_path )^0 * p_path  -- be easy on other arguments

local function normalized(name) -- only used in executers
    if platform == "windows" then
        name = gsub(name,"/","\\")
    end
    return name
end

function sandbox.possiblepath(name)
    return lpegmatch(p_path,name) and true or false
end

local filenamelogger = false

function sandbox.setfilenamelogger(l)
    filenamelogger = type(l) == "function" and l or false
end

local function validfilename(name,what)
    if p_validroot and type(name) == "string" and lpegmatch(p_path,name) then
        local asked = collapsepath(expandname(name))
     -- if platform == "windows" then
     --     asked = lower(asked) -- we assume ascii names
     -- end
        local okay = lpegmatch(p_validroot,asked)
        if okay == true then
            -- read and write access
            if filenamelogger then
                filenamelogger(name,"w",asked,true)
            end
            return name
        elseif okay == false then
            -- read only access
            if not what then
                -- no further argument to io.open so a readonly case
                if filenamelogger then
                    filenamelogger(name,"r",asked,true)
                end
                return name
            elseif lpegmatch(p_write,what) then
                if filenamelogger then
                    filenamelogger(name,"w",asked,false)
                end
                return -- we want write access
            else
                if filenamelogger then
                    filenamelogger(name,"r",asked,true)
                end
                return name
            end
        elseif filenamelogger then
            filenamelogger(name,"*",name,false)
        end
    else
        return name
    end
end

local function readable(name,finalized)
--     if platform == "windows" then -- yes or no
--         name = lower(name) -- we assume ascii names
--     end
    return validfilename(name,"r")
end

local function normalizedreadable(name,finalized)
--     if platform == "windows" then -- yes or no
--         name = lower(name) -- we assume ascii names
--     end
    local valid = validfilename(name,"r")
    if valid then
        return normalized(valid)
    end
end

local function writeable(name,finalized)
--     if platform == "windows" then
--         name = lower(name) -- we assume ascii names
--     end
    return validfilename(name,"w")
end

local function normalizedwriteable(name,finalized)
--     if platform == "windows" then
--         name = lower(name) -- we assume ascii names
--     end
    local valid = validfilename(name,"w")
    if valid then
        return normalized(valid)
    end
end

validators.readable            = readable
validators.writeable           = normalizedwriteable
validators.normalizedreadable  = normalizedreadable
validators.normalizedwriteable = writeable
validators.filename            = readable

table.setmetatableindex(validators,function(t,k)
    if k then
        t[k] = readable
    end
    return readable
end)

function validators.string(s,finalized)
    -- can be used to prevent filename checking (todo: only when registered)
    if finalized and suspicious(s) then
        return ""
    else
        return s
    end
end

function validators.cache(s)
    if finalized then
        return basename(s)
    else
        return s
    end
end

function validators.url(s)
    if finalized and find("^file:") then
        return ""
    else
        return s
    end
end

-- end of validators

local function filehandlerone(action,one,...)
    local checkedone = validfilename(one)
    if checkedone then
        return action(one,...)
    else
     -- report("file %a is unreachable",one)
    end
end

local function filehandlertwo(action,one,two,...)
    local checkedone = validfilename(one)
    if checkedone then
        local checkedtwo = validfilename(two)
        if checkedtwo then
            return action(one,two,...)
        else
         -- report("file %a is unreachable",two)
        end
    else
     -- report("file %a is unreachable",one)
    end
end

local function iohandler(action,one,...)
    if type(one) == "string" then
        local checkedone = validfilename(one)
        if checkedone then
            return action(one,...)
        end
    elseif one then
        return action(one,...)
    else
        return action()
    end
end

-- runners can be strings or tables
--
-- os.execute : string
-- os.exec    : string or table with program in [0|1]
-- os.spawn   : string or table with program in [0|1]
--
-- our execute: registered program with specification

local osexecute = sandbox.original(os.execute)
local iopopen   = sandbox.original(io.popen)
local reported  = { }

local function validcommand(name,program,template,checkers,defaults,variables,reporter,strict)
    if validbinaries ~= false and (validbinaries == true or validbinaries[program]) then
        if variables then
            for variable, value in next, variables do
                local checker = validators[checkers[variable]]
                if checker then
                    value = checker(unquoted(value),strict)
                    if value then
                        variables[variable] = optionalquoted(value)
                    else
                        report("variable %a with value %a fails the check",variable,value)
                        return
                    end
                else
                    report("variable %a has no checker",variable)
                    return
                end
            end
            for variable, default in next, defaults do
                local value = variables[variable]
                if not value or value == "" then
                    local checker = validators[checkers[variable]]
                    if checker then
                        default = checker(unquoted(default),strict)
                        if default then
                            variables[variable] = optionalquoted(default)
                        else
                            report("variable %a with default %a fails the check",variable,default)
                            return
                        end
                    end
                end
            end
        end
        local command  = program .. " " .. replace(template,variables)
        if reporter then
            reporter("executing runner %a: %s",name,command)
        elseif trace then
            report("executing runner %a: %s",name,command)
        end
        return command
    elseif not reported[name] then
        report("executing program %a of runner %a is not permitted",program,name)
        reported[name] = true
    end
end

local runners = {
    --
    -- name,program,template,checkers,variables,reporter
    --
    resultof = function(...)
        local command = validcommand(...)
        if command then
            if trace then
                report("resultof: %s",command)
            end
            local handle = iopopen(command,"r") -- already has flush
            if handle then
                local result = handle:read("*all") or ""
                handle:close()
                return result
            end
        end
    end,
    execute = function(...)
        local command = validcommand(...)
        if command then
            if trace then
                report("execute: %s",command)
            end
            return osexecute(command)
        end
    end,
    pipeto = function(...)
        local command = validcommand(...)
        if command then
            if trace then
                report("pipeto: %s",command)
            end
            return iopopen(command,"w") -- already has flush
        end
    end,
}

function sandbox.registerrunner(specification)
    if type(specification) == "string" then
        local wrapped = validrunners[specification]
        inspect(table.sortedkeys(validrunners))
        if wrapped then
            return wrapped
        else
            report("unknown predefined runner %a",specification)
            return
        end
    end
    if type(specification) ~= "table" then
        report("specification should be a table (or string)")
        return
    end
    local name = specification.name
    if type(name) ~= "string" then
        report("invalid name, string expected",name)
        return
    end
    if validrunners[name] then
        report("invalid name, runner %a already defined")
        return
    end
    local program = specification.program
    if type(program) == "string" then
        -- common for all platforms
    elseif type(program) == "table" then
        program = program[platform] or program.default or program.unix
    end
    if type(program) ~= "string" or program == "" then
        report("invalid runner %a specified for platform %a",name,platform)
        return
    end
    local template = specification.template
    if not template then
        report("missing template for runner %a",name)
        return
    end
    local method   = specification.method   or "execute"
    local checkers = specification.checkers or { }
    local defaults = specification.defaults or { }
    local runner   = runners[method]
    if runner then
        local finalized = finalized -- so, the current situation is frozen
        local wrapped = function(variables)
            return runner(name,program,template,checkers,defaults,variables,specification.reporter,finalized)
        end
        validrunners[name] = wrapped
        return wrapped
    else
        validrunners[name] = nil
        report("invalid method for runner %a",name)
    end
end

function sandbox.getrunner(name)
    return name and validrunners[name]
end

local function suspicious(str)
    return (find(str,"[/\\]") or find(command,"..",1,true)) and true or false
end

local function binaryrunner(action,command,...)
    if validbinaries == false then
        -- nothing permitted
        report("no binaries permitted, ignoring command: %s",command)
        return
    end
    if type(command) ~= "string" then
        -- we only handle strings, maybe some day tables
        report("command should be a string")
        return
    end
    local program = lpegmatch(p_split,command)
    if not program or program == "" then
        report("unable to filter binary from command: %s",command)
        return
    end
    if validbinaries == true then
        -- everything permitted
    elseif not validbinaries[program] then
        report("binary not permitted, ignoring command: %s",command)
        return
    elseif suspicious(command) then
        report("/ \\ or .. found, ignoring command (use sandbox.registerrunner): %s",command)
        return
    end
    return action(command,...)
end

-- local function binaryrunner(action,command,...)
--     local original = command
--     if validbinaries == false then
--         -- nothing permitted
--         report("no binaries permitted, ignoring command: %s",command)
--         return
--     end
--     local program
--     if type(command) == "table" then
--         program = command[0]
--         if program then
--             command = concat(command," ",0)
--         else
--             program = command[1]
--             if program then
--                 command = concat(command," ")
--             end
--         end
--     elseif type(command) = "string" then
--         program = lpegmatch(p_split,command)
--     else
--         report("command should be a string or table")
--         return
--     end
--     if not program or program == "" then
--         report("unable to filter binary from command: %s",command)
--         return
--     end
--     if validbinaries == true then
--         -- everything permitted
--     elseif not validbinaries[program] then
--         report("binary not permitted, ignoring command: %s",command)
--         return
--     elseif find(command,"[/\\]") or find(command,"%.%.") then
--         report("/ \\ or .. found, ignoring command (use sandbox.registerrunner): %s",command)
--         return
--     end
--     return action(original,...)
-- end

local function dummyrunner(action,command,...)
    if type(command) == "table" then
        command = concat(command," ",command[0] and 0 or 1)
    end
    report("ignoring command: %s",command)
end

sandbox.filehandlerone = filehandlerone
sandbox.filehandlertwo = filehandlertwo
sandbox.iohandler      = iohandler

function sandbox.disablerunners()
    validbinaries = false
end

function sandbox.disablelibraries()
    validlibraries = false
end

if FFISUPPORTED and ffi then

    function sandbox.disablelibraries()
        validlibraries = false
        for k, v in next, ffi do
            if k ~= "gc" then
                ffi[k] = nil
            end
        end
    end

    local fiiload = ffi.load

    if fiiload then

        local reported = { }

        function ffi.load(name,...)
            if validlibraries == false then
                -- all blocked
            elseif validlibraries == true then
                -- all permitted
                return fiiload(name,...)
            elseif validlibraries[nameonly(name)] then
                -- 'name' permitted
                return fiiload(name,...)
            else
                -- 'name' not permitted
            end
            if not reported[name] then
                report("using library %a is not permitted",name)
                reported[name] = true
            end
            return nil
        end

    end

end

-------------------

local overload = sandbox.overload
local register = sandbox.register

    overload(loadfile,             filehandlerone,"loadfile") -- todo

if io then
    overload(io.open,              filehandlerone,"io.open")
    overload(io.popen,             binaryrunner,  "io.popen")
    overload(io.input,             iohandler,     "io.input")
    overload(io.output,            iohandler,     "io.output")
    overload(io.lines,             filehandlerone,"io.lines")
end

if os then
    overload(os.execute,           binaryrunner,  "os.execute")
    overload(os.spawn,             dummyrunner,   "os.spawn")
    overload(os.exec,              dummyrunner,   "os.exec")
    overload(os.resultof,          binaryrunner,  "os.resultof")
    overload(os.pipeto,            binaryrunner,  "os.pipeto")
    overload(os.rename,            filehandlertwo,"os.rename")
    overload(os.remove,            filehandlerone,"os.remove")
end

if lfs then
    overload(lfs.chdir,            filehandlerone,"lfs.chdir")
    overload(lfs.mkdir,            filehandlerone,"lfs.mkdir")
    overload(lfs.rmdir,            filehandlerone,"lfs.rmdir")
    overload(lfs.isfile,           filehandlerone,"lfs.isfile")
    overload(lfs.isdir,            filehandlerone,"lfs.isdir")
    overload(lfs.attributes,       filehandlerone,"lfs.attributes")
    overload(lfs.dir,              filehandlerone,"lfs.dir")
    overload(lfs.lock_dir,         filehandlerone,"lfs.lock_dir")
    overload(lfs.touch,            filehandlerone,"lfs.touch")
    overload(lfs.link,             filehandlertwo,"lfs.link")
    overload(lfs.setmode,          filehandlerone,"lfs.setmode")
    overload(lfs.readlink,         filehandlerone,"lfs.readlink")
    overload(lfs.shortname,        filehandlerone,"lfs.shortname")
    overload(lfs.symlinkattributes,filehandlerone,"lfs.symlinkattributes")
end

-- these are used later on

if zip then
    zip.open        = register(zip.open,       filehandlerone,"zip.open")
end

if fontloader then
    fontloader.open = register(fontloader.open,filehandlerone,"fontloader.open")
    fontloader.info = register(fontloader.info,filehandlerone,"fontloader.info")
end

if epdf then
    epdf.open       = register(epdf.open,      filehandlerone,"epdf.open")
end

sandbox.registerroot    = registerroot
sandbox.registerbinary  = registerbinary
sandbox.registerlibrary = registerlibrary
sandbox.validfilename   = validfilename

-- not used in a normal mkiv run : os.spawn = os.execute
-- not used in a normal mkiv run : os.exec  = os.exec

-- print(io.open("test.log"))
-- sandbox.enable()
-- print(io.open("test.log"))
-- print(io.open("t:/test.log"))
