if not modules then modules = { } end modules ["extralibs"] = {
    version   = "2.4",
    comment   = "companion to luaotfload.lua",
    author    = "Philipp Gesang, based on code by Hans Hagen",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "GPL v.2.0",
}

--===================================================================--
---                             PREPARE
--===================================================================--

local getmetatable    = getmetatable
local require         = require
local setmetatable    = setmetatable
local tonumber        = tonumber

local new_node        = node.new
local copy_node       = node.copy
local otffeatures     = fonts.constructors.newfeatures "otf"

-----------------------------------------------------------------------
--- namespace
-----------------------------------------------------------------------

--[[doc--

  Since the letterspacing method was derived initially from Context’s
  typo-krn.lua we keep the sub-namespace “typesetters” inside the
  “luaotfload” table.

--doc]]--

luaotfload.typesetters   = luaotfload.typesetters or { }
local typesetters        = luaotfload.typesetters
typesetters.kernfont     = typesetters.kernfont or { }
local kernfont           = typesetters.kernfont

-----------------------------------------------------------------------
--- node-ini
-----------------------------------------------------------------------

nodes              = nodes or { } --- should be present with luaotfload
local bothways     = function (t) return table.swapped (t, t) end

local kerncodes = bothways({
  [0] = "fontkern",
  [1] = "userkern",
  [2] = "accentkern",
})

kerncodes.kerning   = kerncodes.fontkern --- idiosyncrasy
nodes.kerncodes     = kerncodes

-----------------------------------------------------------------------
--- node-res
-----------------------------------------------------------------------

nodes.pool        = nodes.pool or { }
local pool        = nodes.pool

local kern        = new_node ("kern", nodes.kerncodes.userkern)
local glue_spec   = new_node "glue_spec"

pool.kern = function (k)
  local n = copy_node (kern)
  n.kern = k
  return n
end

pool.glue = function (width, stretch, shrink,
                      stretch_order, shrink_order)
  local n = new_node"glue"
  if not width then
    -- no spec
  elseif width == false or tonumber(width) then
    local s = copy_node(glue_spec)
    if width         then s.width         = width         end
    if stretch       then s.stretch       = stretch       end
    if shrink        then s.shrink        = shrink        end
    if stretch_order then s.stretch_order = stretch_order end
    if shrink_order  then s.shrink_order  = shrink_order  end
    n.spec = s
  else
    -- shared
    n.spec = copy_node(width)
  end
  return n
end

-----------------------------------------------------------------------
--- font-hsh
-----------------------------------------------------------------------
--- some initialization resembling font-hsh
local fonthashes         = fonts.hashes
local identifiers        = fonthashes.identifiers --- was: fontdata
local chardata           = fonthashes.characters
local quaddata           = fonthashes.quads
local parameters         = fonthashes.parameters

--- ('a, 'a) hash -> (('a, 'a) hash -> 'a -> 'a) -> ('a, 'a) hash
local setmetatableindex = function (t, f)
  local mt = getmetatable(t)
  if mt then
    mt.__index = f
  else
    setmetatable(t, { __index = f })
  end
  return t
end

if not parameters then
  parameters = { }
  setmetatableindex(parameters, function(t, k)
    if k == true then
      return parameters[currentfont()]
    else
      local parameters = identifiers[k].parameters
      t[k] = parameters
      return parameters
    end
  end)
  fonthashes.parameters = parameters
end

if not chardata then
  chardata = { }
  setmetatableindex(chardata, function(t, k)
    if k == true then
      return chardata[currentfont()]
    else
      local tfmdata = identifiers[k]
      if not tfmdata then --- unsafe
        tfmdata = font.fonts[k]
      end
      if tfmdata then
        local characters = tfmdata.characters
        t[k] = characters
        return characters
      end
    end
  end)
  fonthashes.characters = chardata
end

if not quaddata then
  quaddata = { }
  setmetatableindex(quaddata, function(t, k)
    if k == true then
      return quads[currentfont()]
    else
      local parameters = parameters[k]
      local quad = parameters and parameters.quad or 0
      t[k] = quad
      return quad
    end
  end)
  fonthashes.quads = quaddata
end

--===================================================================--
---                              LOAD
--===================================================================--

--- we should be ready at this moment to insert the libraries
require "luaotfload-letterspace" --- typesetters.kernfont

--===================================================================--
---                              CLEAN
--===================================================================--

--- kernfont_callback : fontwise
--- · callback:     kernfont.handler
--- · enabler:      enablefontkerning
--- · disabler:     disablefontkerning

--- callback wrappers

--- (node_t -> node_t) -> string -> string list -> bool
local registered_as = { } --- procname -> callbacks
local add_processor = function (processor, name, ...)
  local callbacks = { ... }
  for i=1, #callbacks do
    luatexbase.add_to_callback(callbacks[i], processor, name)
  end
  registered_as[name] = callbacks --- for removal
  return true
end

--- string -> bool
local remove_processor = function (name)
  local callbacks = registered_as[name]
  if callbacks then
    for i=1, #callbacks do
      luatexbase.remove_from_callback(callbacks[i], name)
    end
    return true
  end
  return false --> unregistered
end

--- now for the simplistic variant
--- unit -> bool
local enablefontkerning = function ( )
  return add_processor( kernfont.handler
                      , "typesetters.kernfont"
                      , "pre_linebreak_filter"
                      , "hpack_filter")
end

--- unit -> bool
local disablefontkerning = function ( )
  return remove_processor "typesetters.kernfont"
end

--- fontwise kerning uses a font property for passing along the
--- letterspacing factor

local fontkerning_enabled = false --- callback state

--- fontobj -> float -> unit
local initializefontkerning = function (tfmdata, factor)
  if factor ~= "max" then
    factor = tonumber(factor) or 0
  end
  if factor == "max" or factor ~= 0 then
    local fontproperties = tfmdata.properties
    if fontproperties then
      --- hopefully this field stays unused otherwise
      fontproperties.kerncharacters = factor
    end
    if not fontkerning_enabled then
      fontkerning_enabled = enablefontkerning()
    end
  end
end

--- like the font colorization, fontwise kerning is hooked into the
--- feature mechanism

otffeatures.register {
  name        = "kernfactor",
  description = "kernfactor",
  initializers = {
    base = initializefontkerning,
    node = initializefontkerning,
  }
}

--[[doc--

  The “letterspace” feature is essentially identical with the above
  “kernfactor” method, but scales the factor to percentages to match
  Xetex’s behavior. (See the Xetex reference, page 5, section 1.2.2.)

  Since Xetex doesn’t appear to have a (documented) “max” keyword, we
  assume all input values are numeric.

--doc]]--

local initializecompatfontkerning = function (tfmdata, percentage)
  local factor = tonumber (percentage)
  if not factor then
    logs.names_report ("both", 0, "letterspace",
                       "Invalid argument to letterspace: %s (type %q), " ..
                       "was expecting percentage as Lua number instead.",
                       percentage, type (percentage))
    return
  end
  return initializefontkerning (tfmdata, factor * 0.01)
end

otffeatures.register {
  name        = "letterspace",
  description = "letterspace",
  initializers = {
    base = initializecompatfontkerning,
    node = initializecompatfontkerning,
  }
}

-----------------------------------------------------------------------
--- erase fake Context layer
-----------------------------------------------------------------------

attributes     = nil
--commands       = nil  --- used in lualibs
storage        = nil    --- not to confuse with utilities.storage
nodes.tasks    = nil

collectgarbage"collect"

--[[example--

See https://bitbucket.org/phg/lua-la-tex-tests/src/tip/pln-letterspace-8-compare.tex
for an example.

--example]]--

-- vim:ts=2:sw=2:expandtab
