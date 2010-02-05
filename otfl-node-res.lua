if not modules then modules = { } end modules ['node-res'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gmatch, format = string.gmatch, string.format
local copy_node, free_node, free_list, new_node = node.copy, node.free, node.flush_list, node.new

--[[ldx--
<p>The next function is not that much needed but in <l n='context'/> we use
for debugging <l n='luatex'/> node management.</p>
--ldx]]--

nodes = nodes or { }

nodes.whatsits = { } -- table.swapped(node.whatsits())

local reserved = { }
local whatsits = nodes.whatsits

for k, v in pairs(node.whatsits()) do
    whatsits[k], whatsits[v] = v, k -- two way
end

function nodes.register(n)
    reserved[#reserved+1] = n
    return n
end

function nodes.cleanup_reserved(nofboxes) -- todo
    nodes.tracers.steppers.reset() -- todo: make a registration subsystem
    local nr, nl = #reserved, 0
    for i=1,nr do
        free_node(reserved[i])
    end
    if nofboxes then
        local tb = tex.box
        for i=0,nofboxes do
            local l = tb[i]
            if l then
                free_node(tb[i])
                nl = nl + 1
            end
        end
    end
    reserved = { }
    return nr, nl, nofboxes -- can be nil
end

function nodes.usage()
    local t = { }
    for n, tag in gmatch(status.node_mem_usage,"(%d+) ([a-z_]+)") do
        t[tag] = n
    end
    return t
end

local disc       = nodes.register(new_node("disc"))
local kern       = nodes.register(new_node("kern",1))
local penalty    = nodes.register(new_node("penalty"))
local glue       = nodes.register(new_node("glue"))
local glue_spec  = nodes.register(new_node("glue_spec"))
local glyph      = nodes.register(new_node("glyph",0))
local textdir    = nodes.register(new_node("whatsit",whatsits.dir)) -- 7
local rule       = nodes.register(new_node("rule"))
local latelua    = nodes.register(new_node("whatsit",whatsits.late_lua)) -- 35
local user_n     = nodes.register(new_node("whatsit",whatsits.user_defined)) user_n.type = 100 -- 44
local user_l     = nodes.register(new_node("whatsit",whatsits.user_defined)) user_l.type = 110 -- 44
local user_s     = nodes.register(new_node("whatsit",whatsits.user_defined)) user_s.type = 115 -- 44
local user_t     = nodes.register(new_node("whatsit",whatsits.user_defined)) user_t.type = 116 -- 44

function nodes.glyph(fnt,chr)
    local n = copy_node(glyph)
    if fnt then n.font = fnt end
    if chr then n.char = chr end
    return n
end
function nodes.penalty(p)
    local n = copy_node(penalty)
    n.penalty = p
    return n
end
function nodes.kern(k)
    local n = copy_node(kern)
    n.kern = k
    return n
end
function nodes.glue(width,stretch,shrink)
    local n, s = copy_node(glue), copy_node(glue_spec)
    s.width, s.stretch, s.shrink = width, stretch, shrink
    n.spec = s
    return n
end
function nodes.glue_spec(width,stretch,shrink)
    local s = copy_node(glue_spec)
    s.width, s.stretch, s.shrink = width, stretch, shrink
    return s
end
function nodes.disc()
    return copy_node(disc)
end
function nodes.textdir(dir)
    local t = copy_node(textdir)
    t.dir = dir
    return t
end
function nodes.rule(w,h,d)
    local n = copy_node(rule)
    if w then n.width  = w end
    if h then n.height = h end
    if d then n.depth  = d end
    return n
end
function nodes.latelua(code)
    local n = copy_node(latelua)
    n.data = code
    return n
end

local cache = { }

function nodes.usernumber(num)
    local n = cache[num]
    if n then
        return copy_node(n)
    else
        local n = copy_node(user_n)
        if num then n.value = num end
        return n
    end
end

function nodes.userlist(list)
    local n = copy_node(user_l)
    if list then n.value = list end
    return n
end

local cache = { } -- we could use the same cache

function nodes.userstring(str)
    local n = cache[str]
    if n then
        return copy_node(n)
    else
        local n = copy_node(user_s)
        n.type = 115
        if str then n.value = str end
        return n
    end
end

function nodes.usertokens(tokens)
    local n = copy_node(user_t)
    if tokens then n.value = tokens end
    return n
end

statistics.register("cleaned up reserved nodes", function()
    return format("%s nodes, %s lists of %s", nodes.cleanup_reserved(tex.count["lastallocatedbox"]))
end) -- \topofboxstack

statistics.register("node memory usage", function() -- comes after cleanup !
    return status.node_mem_usage
end)
