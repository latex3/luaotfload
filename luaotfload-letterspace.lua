if not modules then modules = { } end modules ['letterspace'] = {
    version   = "2.4",
    comment   = "companion to luaotfload.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL; adapted by Philipp Gesang",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local getmetatable       = getmetatable
local require            = require
local setmetatable       = setmetatable
local tonumber           = tonumber

local next               = next
local nodes, node, fonts = nodes, node, fonts

local find_node_tail     = node.tail or node.slide
local free_node          = node.free
local copy_node          = node.copy
local new_node           = node.new
local insert_node_before = node.insert_before

local nodepool           = nodes.pool

local new_kern           = nodepool.kern
local new_glue           = nodepool.glue

local nodecodes          = nodes.nodecodes

local glyph_code         = nodecodes.glyph
local kern_code          = nodecodes.kern
local disc_code          = nodecodes.disc
local math_code          = nodecodes.math

local fonthashes         = fonts.hashes
local chardata           = fonthashes.characters
local quaddata           = fonthashes.quads
local otffeatures        = fonts.constructors.newfeatures "otf"

--[[doc--

  Since the letterspacing method was derived initially from Context’s
  typo-krn.lua we keep the sub-namespace “letterspace” inside the
  “luaotfload” table.

--doc]]--

luaotfload.letterspace   = luaotfload.letterspace or { }
local letterspace        = luaotfload.letterspace

letterspace.keepligature = false
letterspace.keeptogether = false

---=================================================================---
---                     preliminary definitions
---=================================================================---
-- We set up a layer emulating some Context internals that are needed
-- for the letterspacing callback.
-----------------------------------------------------------------------
--- node-ini
-----------------------------------------------------------------------

local bothways  = function (t) return table.swapped (t, t) end
local kerncodes = bothways { [0] = "fontkern"
                           , [1] = "userkern"
                           , [2] = "accentkern"
                           }

kerncodes.kerning    = kerncodes.fontkern --- idiosyncrasy
local kerning_code   = kerncodes.kerning
local userkern_code  = kerncodes.userkern


-----------------------------------------------------------------------
--- node-res
-----------------------------------------------------------------------

nodes.pool        = nodes.pool or { }
local pool        = nodes.pool

local kern        = new_node ("kern", kerncodes.userkern)
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
  --fonthashes.parameters = parameters
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
  --fonthashes.quads = quaddata
end

---=================================================================---
---                 character kerning functionality
---=================================================================---

local kern_injector = function (fillup, kern)
  if fillup then
    local g = new_glue(kern)
    local s = g.spec
    s.stretch = kern
    s.stretch_order = 1
    return g
  else
    return new_kern(kern)
  end
end

--[[doc--

    Caveat lector.
    This is an adaptation of the Context character kerning mechanism
    that emulates XeTeX-style fontwise letterspacing. Note that in its
    present state it is far inferior to the original, which is
    attribute-based and ignores font-boundaries. Nevertheless, due to
    popular demand the following callback has been added.

--doc]]--

local kernfactors = { } --- fontid -> factor

local kerncharacters
kerncharacters = function (head)
  local start, done   = head, false
  local lastfont      = nil
  local keepligature  = letterspace.keepligature --- function
  local keeptogether  = letterspace.keeptogether --- function
  local fillup        = false

  local identifiers   = fonthashes.identifiers
  local kernfactors   = kernfactors

  local firstkern     = true

  while start do
    local id = start.id
    if id == glyph_code then

      --- 1) look up kern factor (slow, but cached rudimentarily)
      local krn
      local fontid = start.font
      do
        krn = kernfactors[fontid]
        if not krn then
          local tfmdata = identifiers[fontid]
          if not tfmdata then -- unsafe
            tfmdata = font.fonts[fontid]
          end
          if tfmdata then
            fontproperties = tfmdata.properties
            if fontproperties then
              krn = fontproperties.kerncharacters
            end
          end
          kernfactors[fontid] = krn
        end
        if not krn or krn == 0 then
          firstkern = true
          goto nextnode
        elseif firstkern then
          firstkern = false
          if (id ~= disc_code) and (not start.components) then
            --- not a ligature, skip node
            goto nextnode
          end
        end
      end

      if krn == "max" then
        krn = .25
        fillup = true
      else
        fillup = false
      end

      lastfont = fontid

      --- 2) resolve ligatures
      local c = start.components

      if c then
        if keepligature and keepligature(start) then
          -- keep 'm
        else
          --- c = kerncharacters (c) --> taken care of after replacing
          local s = start
          local p, n = s.prev, s.next
          local tail = find_node_tail(c)
          if p then
            p.next = c
            c.prev = p
          else
            head = c
          end
          if n then
            n.prev = tail
          end
          tail.next = n
          start = c
          s.components = nil
          -- we now leak nodes !
          --  free_node(s)
          done = true
        end
      end -- kern ligature

      --- 3) apply the extra kerning
      local prev = start.prev
      if prev then
        local pid = prev.id

        if not pid then
          -- nothing

        elseif pid == kern_code then
          if prev.subtype == kerning_code   --- context does this by means of an
          or prev.subtype == userkern_code  --- attribute; we may need a test
          then
            if keeptogether and prev.prev.id == glyph_code and keeptogether(prev.prev,start) then
              -- keep
            else
              prev.subtype = userkern_code
              prev.kern = prev.kern + quaddata[lastfont]*krn -- here
              done = true
            end
          end

        elseif pid == glyph_code then
          if prev.font == lastfont then
            local prevchar, lastchar = prev.char, start.char
            if keeptogether and keeptogether(prev,start) then
              -- keep 'm
            elseif identifiers[lastfont] then
              local kerns = chardata[lastfont][prevchar].kerns
              local kern = kerns and kerns[lastchar] or 0
              krn = kern + quaddata[lastfont]*krn -- here
              insert_node_before(head,start,kern_injector(fillup,krn))
              done = true
            end
          else
            krn = quaddata[lastfont]*krn -- here
            insert_node_before(head,start,kern_injector(fillup,krn))
            done = true
          end

        elseif pid == disc_code then
          -- a bit too complicated, we can best not copy and just calculate
          -- but we could have multiple glyphs involved so ...
          local disc = prev -- disc
          local pre, post, replace = disc.pre, disc.post, disc.replace
          local prv, nxt = disc.prev, disc.next

          if pre and prv then -- must pair with start.prev
            -- this one happens in most cases
            local before = copy_node(prv)
            pre.prev = before
            before.next = pre
            before.prev = nil
            pre = kerncharacters (before)
            pre = pre.next
            pre.prev = nil
            disc.pre = pre
            free_node(before)
          end

          if post and nxt then  -- must pair with start
            local after = copy_node(nxt)
            local tail = find_node_tail(post)
            tail.next = after
            after.prev = tail
            after.next = nil
            post = kerncharacters (post)
            tail.next = nil
            disc.post = post
            free_node(after)
          end

          if replace and prv and nxt then -- must pair with start and start.prev
            local before = copy_node(prv)
            local after = copy_node(nxt)
            local tail = find_node_tail(replace)
            replace.prev = before
            before.next = replace
            before.prev = nil
            tail.next = after
            after.prev = tail
            after.next = nil
            replace = kerncharacters (before)
            replace = replace.next
            replace.prev = nil
            after.prev.next = nil
            disc.replace = replace
            free_node(after)
            free_node(before)
          elseif identifiers[lastfont] then
            if prv and prv.id == glyph_code and prv.font == lastfont then
              local prevchar, lastchar = prv.char, start.char
              local kerns = chardata[lastfont][prevchar].kerns
              local kern = kerns and kerns[lastchar] or 0
              krn = kern + quaddata[lastfont]*krn -- here
            else
              krn = quaddata[lastfont]*krn -- here
            end
            disc.replace = kern_injector(false,krn) -- only kerns permitted, no glue
          end

        end
      end
    end

    ::nextnode::
    if start then
      start = start.next
    end
  end
  return head, done
end

---=================================================================---
---                         integration
---=================================================================---

--- · callback:     kerncharacters
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
  return add_processor( kerncharacters
                      , "luaotfload.letterspace"
                      , "pre_linebreak_filter"
                      , "hpack_filter")
end

--- unit -> bool
local disablefontkerning = function ( )
  return remove_processor "luaotfload.letterspace"
end

--[[doc--

  Fontwise kerning is enabled via the “kernfactor” option at font
  definition time. Unlike the Context implementation which relies on
  Luatex attributes, it uses a font property for passing along the
  letterspacing factor of a node.

  The callback is activated the first time a letterspaced font is
  requested and stays active until the end of the run. Since the font
  is a property of individual glyphs, every glyph in the entire
  document must be checked for the kern property. This is quite
  inefficient compared to Context’s attribute based approach, but Xetex
  compatibility reduces our options significantly.

--doc]]--


local fontkerning_enabled = false --- callback state

--- fontobj -> float -> unit
local initializefontkerning = function (tfmdata, factor)
  if factor ~= "max" then
    factor = tonumber (factor) or 0
  end
  if factor == "max" or factor ~= 0 then
    local fontproperties = tfmdata.properties
    if fontproperties then
      --- hopefully this field stays unused otherwise
      fontproperties.kerncharacters = factor
    end
    if not fontkerning_enabled then
      fontkerning_enabled = enablefontkerning ()
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

--[[example--

See https://bitbucket.org/phg/lua-la-tex-tests/src/tip/pln-letterspace-8-compare.tex
for an example.

--example]]--

--- vim:sw=2:ts=2:expandtab:tw=71

