if not modules then modules = { } end modules ['node-pro'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local utf = unicode.utf8
local format, concat = string.format, table.concat

local trace_callbacks = false  trackers.register("nodes.callbacks", function(v) trace_callbacks = v end)

local glyph = node.id('glyph')

local free_node       = node.free
local first_character = node.first_character

nodes.processors = nodes.processors or { }

-- vbox: grouptype: vbox vtop output split_off split_keep  | box_type: exactly|aditional
-- hbox: grouptype: hbox adjusted_hbox(=hbox_in_vmode)     | box_type: exactly|aditional

lists = lists or { }
chars = chars or { }
words = words or { } -- not used yet

local actions = tasks.actions("processors",4)

local n = 0

local function reconstruct(head)
    local t = { }
    local h = head
    while h do
        local id = h.id
        if id == glyph then
            t[#t+1] = utf.char(h.char)
        else
            t[#t+1] = "[]"
        end
        h = h.next
    end
    return concat(t)
end

local function tracer(what,state,head,groupcode,before,after,show)
    if not groupcode then
        groupcode = "unknown"
    elseif groupcode == "" then
        groupcode = "mvl"
    end
    n = n + 1
    if show then
        logs.report("nodes","%s %s: %s, group: %s, nodes: %s -> %s, string: %s",what,n,state,groupcode,before,after,reconstruct(head))
    else
        logs.report("nodes","%s %s: %s, group: %s, nodes: %s -> %s",what,n,state,groupcode,before,after)
    end
end

nodes.processors.enabled = true -- thsi will become a proper state (like trackers)

function nodes.processors.pre_linebreak_filter(head,groupcode,size,packtype,direction)
    local first, found = first_character(head)
    if found then
        if trace_callbacks then
            local before = nodes.count(head,true)
            local head, done = actions(head,groupcode,size,packtype,direction)
            local after = nodes.count(head,true)
            if done then
                tracer("pre_linebreak","changed",head,groupcode,before,after,true)
            else
                tracer("pre_linebreak","unchanged",head,groupcode,before,after,true)
            end
            return (done and head) or true
        else
            local head, done = actions(head,groupcode,size,packtype,direction)
            return (done and head) or true
        end
    elseif trace_callbacks then
        local n = nodes.count(head,false)
        tracer("pre_linebreak","no chars",head,groupcode,n,n)
    end
    return true
end

function nodes.processors.hpack_filter(head,groupcode,size,packtype,direction)
    local first, found = first_character(head)
    if found then
        if trace_callbacks then
            local before = nodes.count(head,true)
            local head, done = actions(head,groupcode,size,packtype,direction)
            local after = nodes.count(head,true)
            if done then
                tracer("hpack","changed",head,groupcode,before,after,true)
            else
                tracer("hpack","unchanged",head,groupcode,before,after,true)
            end
            return (done and head) or true
        else
            local head, done = actions(head,groupcode,size,packtype,direction)
            return (done and head) or true
        end
    elseif trace_callbacks then
        local n = nodes.count(head,false)
        tracer("hpack","no chars",head,groupcode,n,n)
    end
    return true
end

callbacks.register('pre_linebreak_filter', nodes.processors.pre_linebreak_filter,"all kind of horizontal manipulations (before par break)")
callbacks.register('hpack_filter'        , nodes.processors.hpack_filter,"all kind of horizontal manipulations")

local actions = tasks.actions("finalizers",1) -- head, where

-- beware, these are packaged boxes so no first_character test
-- maybe some day a hash with valid groupcodes
--
-- beware, much can pass twice, for instance vadjust passes two times

function nodes.processors.post_linebreak_filter(head,groupcode)
--~     local first, found = first_character(head)
--~     if found then
        if trace_callbacks then
            local before = nodes.count(head,true)
            local head, done = actions(head,groupcode)
            local after = nodes.count(head,true)
            if done then
                tracer("finalizer","changed",head,groupcode,before,after,true)
            else
                tracer("finalizer","unchanged",head,groupcode,before,after,true)
            end
            return (done and head) or true
        else
            local head, done = actions(head,groupcode)
            return (done and head) or true
        end
--~     elseif trace_callbacks then
--~         local n = nodes.count(head,false)
--~         tracer("finalizer","no chars",head,groupcode,n,n)
--~     end
--~     return true
end

callbacks.register('post_linebreak_filter', nodes.processors.post_linebreak_filter,"all kind of horizontal manipulations (after par break)")

statistics.register("h-node processing time", function()
    return statistics.elapsedseconds(nodes,"including kernel") -- hm, ok here?
end)
