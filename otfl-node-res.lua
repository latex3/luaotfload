if not modules then modules = { } end modules ['node-res'] = {
    version   = 1.001,
    comment   = "companion to node-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local gmatch, format = string.gmatch, string.format
local copy_node, free_node, free_list, new_node, node_type, node_id = node.copy, node.free, node.flush_list, node.new, node.type, node.id
local tonumber, round = tonumber, math.round

local glyph_node = node_id("glyph")

--[[ldx--
<p>The next function is not that much needed but in <l n='context'/> we use
for debugging <l n='luatex'/> node management.</p>
--ldx]]--

nodes = nodes or { }

nodes.whatsits = { } -- table.swapped(node.whatsits())

local reserved = { }
local whatsits = nodes.whatsits

for k, v in next, node.whatsits() do
    whatsits[k], whatsits[v] = v, k -- two way
end

local function register_node(n)
    reserved[#reserved+1] = n
    return n
end

nodes.register = register_node

function nodes.cleanup_reserved(nofboxes) -- todo
    nodes.tracers.steppers.reset() -- todo: make a registration subsystem
    local nr, nl = #reserved, 0
    for i=1,nr do
        local ri = reserved[i]
    --  if not (ri.id == glue_spec and not ri.is_writable) then
            free_node(reserved[i])
    --  end
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

local disc              = register_node(new_node("disc"))
local kern              = register_node(new_node("kern",1))
local penalty           = register_node(new_node("penalty"))
local glue              = register_node(new_node("glue")) -- glue.spec = nil
local glue_spec         = register_node(new_node("glue_spec"))
local glyph             = register_node(new_node("glyph",0))
local textdir           = register_node(new_node("whatsit",whatsits.dir)) -- 7 (6 is local par node)
local rule              = register_node(new_node("rule"))
local latelua           = register_node(new_node("whatsit",whatsits.late_lua)) -- 35
local user_n            = register_node(new_node("whatsit",whatsits.user_defined)) user_n.type = 100 -- 44
local user_l            = register_node(new_node("whatsit",whatsits.user_defined)) user_l.type = 110 -- 44
local user_s            = register_node(new_node("whatsit",whatsits.user_defined)) user_s.type = 115 -- 44
local user_t            = register_node(new_node("whatsit",whatsits.user_defined)) user_t.type = 116 -- 44
local left_margin_kern  = register_node(new_node("margin_kern",0))
local right_margin_kern = register_node(new_node("margin_kern",1))
local lineskip          = register_node(new_node("glue",1))
local baselineskip      = register_node(new_node("glue",2))
local leftskip          = register_node(new_node("glue",8))
local rightskip         = register_node(new_node("glue",9))
local temp              = register_node(new_node("temp",0))

function nodes.zeroglue(n)
    local s = n.spec
    return not writable or (
                     s.width == 0
         and       s.stretch == 0
         and        s.shrink == 0
         and s.stretch_order == 0
         and  s.shrink_order == 0
        )
end

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

function nodes.glue_spec(width,stretch,shrink)
    local s = copy_node(glue_spec)
    s.width, s.stretch, s.shrink = width, stretch, shrink
    return s
end

local function someskip(skip,width,stretch,shrink)
    local n = copy_node(skip)
    if not width then
        -- no spec
    elseif tonumber(width) then
        local s = copy_node(glue_spec)
        s.width, s.stretch, s.shrink = width, stretch, shrink
        n.spec = s
    else
        -- shared
        n.spec = copy_node(width)
    end
    return n
end

function nodes.glue(width,stretch,shrink)
    return someskip(glue,width,stretch,shrink)
end
function nodes.leftskip(width,stretch,shrink)
    return someskip(leftskip,width,stretch,shrink)
end
function nodes.rightskip(width,stretch,shrink)
    return someskip(rightskip,width,stretch,shrink)
end
function nodes.lineskip(width,stretch,shrink)
    return someskip(lineskip,width,stretch,shrink)
end
function nodes.baselineskip(width,stretch,shrink)
    return someskip(baselineskip,width,stretch,shrink)
end

function nodes.disc()
    return copy_node(disc)
end

function nodes.textdir(dir)
    local t = copy_node(textdir)
    t.dir = dir
    return t
end

function nodes.rule(width,height,depth,dir)
    local n = copy_node(rule)
    if width  then n.width  = width  end
    if height then n.height = height end
    if depth  then n.depth  = depth  end
    if dir    then n.dir    = dir    end
    return n
end

function nodes.latelua(code)
    local n = copy_node(latelua)
    n.data = code
    return n
end

function nodes.leftmarginkern(glyph,width)
    local n = copy_node(left_margin_kern)
    if not glyph then
        logs.fatal("nodes","invalid pointer to left margin glyph node")
    elseif glyph.id ~= glyph_node then
        logs.fatal("nodes","invalid node type %s for left margin glyph node",node_type(glyph))
    else
        n.glyph = glyph
    end
    if width then
        n.width = width
    end
    return n
end

function nodes.rightmarginkern(glyph,width)
    local n = copy_node(right_margin_kern)
    if not glyph then
        logs.fatal("nodes","invalid pointer to right margin glyph node")
    elseif glyph.id ~= glyph_node then
        logs.fatal("nodes","invalid node type %s for right margin glyph node",node_type(p))
    else
        n.glyph = glyph
    end
    if width then
        n.width = width
    end
    return n
end

function nodes.temp()
    return copy_node(temp)
end
--[[
<p>At some point we ran into a problem that the glue specification
of the zeropoint dimension was overwritten when adapting a glue spec
node. This is a side effect of glue specs being shared. After a
couple of hours tracing and debugging Taco and I came to the
conclusion that it made no sense to complicate the spec allocator
and settled on a writable flag. This all is a side effect of the
fact that some glues use reserved memory slots (with the zeropoint
glue being a noticeable one). So, next we wrap this into a function
and hide it for the user. And yes, LuaTeX now gives a warning as
well.</p>
]]--

if tex.luatexversion > 51 then

    function nodes.writable_spec(n)
        local spec = n.spec
        if not spec then
            spec = copy_node(glue_spec)
            n.spec = spec
        elseif not spec.writable then
            spec = copy_node(spec)
            n.spec = spec
        end
        return spec
    end

else

    function nodes.writable_spec(n)
        local spec = n.spec
        if not spec then
            spec = copy_node(glue_spec)
        else
            spec = copy_node(spec)
        end
        n.spec = spec
        return spec
    end

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
