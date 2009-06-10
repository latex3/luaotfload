if not modules then modules = { } end modules ['data-con'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local format, lower, gsub = string.format, string.lower, string.gsub

local trace_cache      = false  trackers.register("resolvers.cache",      function(v) trace_cache      = v end)
local trace_containers = false  trackers.register("resolvers.containers", function(v) trace_containers = v end)
local trace_storage    = false  trackers.register("resolvers.storage",    function(v) trace_storage    = v end)
local trace_verbose    = false  trackers.register("resolvers.verbose",    function(v) trace_verbose    = v end)
local trace_locating   = false  trackers.register("resolvers.locating",   function(v) trace_locating   = v trackers.enable("resolvers.verbose") end)

--[[ldx--
<p>Once we found ourselves defining similar cache constructs
several times, containers were introduced. Containers are used
to collect tables in memory and reuse them when possible based
on (unique) hashes (to be provided by the calling function).</p>

<p>Caching to disk is disabled by default. Version numbers are
stored in the saved table which makes it possible to change the
table structures without bothering about the disk cache.</p>

<p>Examples of usage can be found in the font related code.</p>
--ldx]]--

containers = containers or { }

containers.usecache = true

local function report(container,tag,name)
    if trace_cache or trace_containers then
        logs.report(format("%s cache",container.subcategory),"%s: %s",tag,name or 'invalid')
    end
end

local allocated = { }

-- tracing

function containers.define(category, subcategory, version, enabled)
    return function()
        if category and subcategory then
            local c = allocated[category]
            if not c then
                c  = { }
                allocated[category] = c
            end
            local s = c[subcategory]
            if not s then
                s = {
                    category = category,
                    subcategory = subcategory,
                    storage = { },
                    enabled = enabled,
                    version = version or 1.000,
                    trace = false,
                    path = caches and caches.setpath and caches.setpath(category,subcategory),
                }
                c[subcategory] = s
            end
            return s
        else
            return nil
        end
    end
end

function containers.is_usable(container, name)
    return container.enabled and caches and caches.iswritable(container.path, name)
end

function containers.is_valid(container, name)
    if name and name ~= "" then
        local storage = container.storage[name]
        return storage and not table.is_empty(storage) and storage.cache_version == container.version
    else
        return false
    end
end

function containers.read(container,name)
    if container.enabled and caches and not container.storage[name] and containers.usecache then
        container.storage[name] = caches.loaddata(container.path,name)
        if containers.is_valid(container,name) then
            report(container,"loaded",name)
        else
            container.storage[name] = nil
        end
    end
    if container.storage[name] then
        report(container,"reusing",name)
    end
    return container.storage[name]
end

function containers.write(container, name, data)
    if data then
        data.cache_version = container.version
        if container.enabled and caches then
            local unique, shared = data.unique, data.shared
            data.unique, data.shared = nil, nil
            caches.savedata(container.path, name, data)
            report(container,"saved",name)
            data.unique, data.shared = unique, shared
        end
        report(container,"stored",name)
        container.storage[name] = data
    end
    return data
end

function containers.content(container,name)
    return container.storage[name]
end

function containers.cleanname(name)
    return (gsub(lower(name),"[^%w%d]+","-"))
end
