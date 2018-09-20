if not modules then modules = { } end modules ['util-seq'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>Here we implement a mechanism for chaining the special functions
that we use in <l n="context"> to deal with mode list processing. We
assume that namespaces for the functions are used, but for speed we
use locals to refer to them when compiling the chain.</p>
--ldx]]--

-- todo: delayed: i.e. we register them in the right order already but delay usage

-- todo: protect groups (as in tasks)

local gsub, gmatch = string.gsub, string.gmatch
local concat, sortedkeys = table.concat, table.sortedkeys
local type, load, next, tostring = type, load, next, tostring

utilities               = utilities or { }
local tables            = utilities.tables
local allocate          = utilities.storage.allocate

local formatters        = string.formatters
local replacer          = utilities.templates.replacer

local trace_used        = false
local trace_detail      = false
local report            = logs.reporter("sequencer")
local usedcount         = 0
local usednames         = { }

trackers.register("sequencers.used",  function(v) trace_used   = true end)
trackers.register("sequencers.detail",function(v) trace_detail = true end)

local sequencers        = { }
utilities.sequencers    = sequencers

local functions         = allocate()
sequencers.functions    = functions

local removevalue       = tables.removevalue
local replacevalue      = tables.replacevalue
local insertaftervalue  = tables.insertaftervalue
local insertbeforevalue = tables.insertbeforevalue

local usedsequences     = { }

local function validaction(action)
    if type(action) == "string" then
        local g = _G
        for str in gmatch(action,"[^%.]+") do
            g = g[str]
            if not g then
                return false
            end
        end
    end
    return true
end

local compile

local known = { } -- just a convenience, in case we want public access (only to a few methods)

function sequencers.new(t) -- was reset
    local s = {
        list   = { },
        order  = { },
        kind   = { },
        askip  = { },
        gskip  = { },
        dirty  = true,
        runner = nil,
        steps  = 0,
    }
    if t then
        s.arguments    = t.arguments
        s.templates    = t.templates
        s.returnvalues = t.returnvalues
        s.results      = t.results
        local name     = t.name
        if name and name ~= "" then
            s.name      = name
            known[name] = s
        end
    end
    table.setmetatableindex(s,function(t,k)
        -- this will automake a dirty runner
        if k == "runner" then
            local v = compile(t,t.compiler)
            return v
        end
    end)
    known[s] = s -- saves test for string later on
    return s
end

function sequencers.prependgroup(t,group,where)
    if t and group then
        t = known[t]
        if t then
            local order = t.order
            removevalue(order,group)
            insertbeforevalue(order,where,group)
            t.list[group] = { }
            t.dirty       = true
            t.runner      = nil
        end
    end
end

function sequencers.appendgroup(t,group,where)
    if t and group then
        t = known[t]
        if t then
            local order = t.order
            removevalue(order,group)
            insertaftervalue(order,where,group)
            t.list[group] = { }
            t.dirty       = true
            t.runner      = nil
        end
    end
end

function sequencers.prependaction(t,group,action,where,kind,force)
    if t and group and action then
        t = known[t]
        if t then
            local g = t.list[group]
            if g and (force or validaction(action)) then
                removevalue(g,action)
                insertbeforevalue(g,where,action)
                t.kind[action] = kind
                t.dirty        = true
                t.runner       = nil
            end
        end
    end
end

function sequencers.appendaction(t,group,action,where,kind,force)
    if t and group and action then
        t = known[t]
        if t then
            local g = t.list[group]
            if g and (force or validaction(action)) then
                removevalue(g,action)
                insertaftervalue(g,where,action)
                t.kind[action] = kind
                t.dirty        = true
                t.runner       = nil
            end
        end
    end
end

function sequencers.enableaction(t,action)
    if t and action then
        t = known[t]
        if t then
            t.askip[action] = false
            t.dirty         = true
            t.runner        = nil
        end
    end
end

function sequencers.disableaction(t,action)
    if t and action then
        t = known[t]
        if t then
            t.askip[action] = true
            t.dirty         = true
            t.runner        = nil
        end
    end
end

function sequencers.enablegroup(t,group)
    if t and group then
        t = known[t]
        if t then
            t.gskip[group] = false
            t.dirty        = true
            t.runner       = nil
        end
    end
end

function sequencers.disablegroup(t,group)
    if t and group then
        t = known[t]
        if t then
            t.gskip[group] = true
            t.dirty        = true
            t.runner       = nil
        end
    end
end

function sequencers.setkind(t,action,kind)
    if t and action then
        t = known[t]
        if t then
            t.kind[action] = kind
            t.dirty        = true
            t.runner       = nil
        end
    end
end

function sequencers.removeaction(t,group,action,force)
    if t and group and action then
        t = known[t]
        local g = t and t.list[group]
        if g and (force or validaction(action)) then
            removevalue(g,action)
            t.dirty  = true
            t.runner = nil
        end
    end
end

function sequencers.replaceaction(t,group,oldaction,newaction,force)
    if t and group and oldaction and newaction then
        t = known[t]
        if t then
            local g = t.list[group]
            if g and (force or validaction(oldaction)) then
                replacevalue(g,oldaction,newaction)
                t.dirty  = true
                t.runner = nil
            end
        end
    end
end

local function localize(str)
    return (gsub(str,"[%.: ]+","_"))
end

local function construct(t)
    local list         = t.list
    local order        = t.order
    local kind         = t.kind
    local gskip        = t.gskip
    local askip        = t.askip
    local name         = t.name or "?"
    local arguments    = t.arguments or "..."
    local returnvalues = t.returnvalues
    local results      = t.results
    local variables    = { }
    local calls        = { }
    local n            = 0
    usedcount          = usedcount + 1
    for i=1,#order do
        local group = order[i]
        if not gskip[group] then
            local actions = list[group]
            for i=1,#actions do
                local action = actions[i]
                if not askip[action] then
                    if trace_used then
                        local action = tostring(action)
                        report("%02i: category %a, group %a, action %a",usedcount,name,group,action)
                        usednames[action] = true
                    end
                    local localized
                    if type(action) == "function" then
                        local name = localize(tostring(action))
                        functions[name] = action
                        action = formatters["utilities.sequencers.functions.%s"](name)
                        localized = localize(name) -- shorter than action
                    else
                        localized = localize(action)
                    end
                    n = n + 1
                    variables[n] = formatters["local %s = %s"](localized,action)
                    if not returnvalues then
                        calls[n] = formatters["%s(%s)"](localized,arguments)
                    elseif n == 1 then
                        calls[n] = formatters["local %s = %s(%s)"](returnvalues,localized,arguments)
                    else
                        calls[n] = formatters["%s = %s(%s)"](returnvalues,localized,arguments)
                    end
                end
            end
        end
    end
    t.dirty = false
    t.steps = n
    if n == 0 then
        t.compiled = ""
    else
        variables = concat(variables,"\n")
        calls = concat(calls,"\n")
        if results then
            t.compiled = formatters["%s\nreturn function(%s)\n%s\nreturn %s\nend"](variables,arguments,calls,results)
        else
            t.compiled = formatters["%s\nreturn function(%s)\n%s\nend"](variables,arguments,calls)
        end
    end
    return t.compiled -- also stored so that we can trace
end

sequencers.tostring = construct
sequencers.localize = localize

compile = function(t,compiler,...) -- already referred to in sequencers.new
    local compiled
    if not t or type(t) == "string" then
        return false
    end
    if compiler then
        compiled = compiler(t,...)
        t.compiled = compiled
    else
        compiled = construct(t,...)
    end
    local runner
    if compiled == "" then
        runner = false
    else
        runner = compiled and load(compiled)() -- we can use loadstripped here
    end
    t.runner = runner
    return runner
end

sequencers.compile = compile

function sequencers.nodeprocessor(t,nofarguments)
    --
    local templates = nofarguments
    --
    if type(templates) ~= "table" then
        return ""
    end
    --
    local replacers = { }
    for k, v in next, templates do
        replacers[k] = replacer(v)
    end
    --
    local construct = replacers.process
    local step      = replacers.step
    if not construct or not step then
        return ""
    end
    --
    local calls     = { }
    local aliases   = { }
    local ncalls    = 0
    local naliases  = 0
    local f_alias   = formatters["local %s = %s"]
    --
    local list  = t.list
    local order = t.order
    local kind  = t.kind
    local gskip = t.gskip
    local askip = t.askip
    local name  = t.name or "?"
    local steps = 0
    usedcount   = usedcount + 1
    --
    if trace_detail then
        naliases = naliases + 1
        aliases[naliases] = formatters["local report = logs.reporter('sequencer',%q)"](name)
        ncalls = ncalls + 1
        calls[ncalls] = [[report("start")]]
    end
    for i=1,#order do
        local group = order[i]
        if not gskip[group] then
            local actions = list[group]
            for i=1,#actions do
                local action = actions[i]
                if not askip[action] then
                    steps = steps + 1
                    if trace_used or trace_detail then
                        local action = tostring(action)
                        report("%02i: category %a, group %a, action %a",usedcount,name,group,action)
                        usednames[action] = true
                    end
                    if trace_detail then
                        ncalls = ncalls + 1
                        calls[ncalls] = formatters[ [[report("  step %a, action %a")]] ](steps,tostring(action))
                    end
                    local localized = localize(action)
                    local onestep   = replacers[kind[action]] or step
                    naliases = naliases + 1
                    ncalls   = ncalls + 1
                    aliases[naliases] = f_alias(localized,action)
                    calls  [ncalls]   = onestep { action = localized }
                end
            end
        end
    end
    t.steps = steps
    local processor
    if steps == 0 then
        processor = templates.default or construct { }
    else
        if trace_detail then
            ncalls = ncalls + 1
            calls[ncalls] = [[report("stop")]]
        end
        processor = construct {
            localize = concat(aliases,"\n"),
            actions  = concat(calls,"\n"),
        }
    end
 -- processor = "print('running : " .. (t.name or "?") .. "')\n" .. processor
 -- print(processor)
    return processor
end

statistics.register("used sequences",function()
    if next(usednames) then
        return concat(sortedkeys(usednames)," ")
    end
end)
