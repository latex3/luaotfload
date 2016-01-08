if not modules then modules = { } end modules ['letterspace'] = {
    version   = "2.5",
    comment   = "companion to luaotfload-main.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL; adapted by Philipp Gesang",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--- This code diverged quite a bit from its origin in Context. Please
--- do *not* report bugs on the Context list.

local log                = luaotfload.log
local logreport          = log.report

local getmetatable       = getmetatable
local require            = require
local setmetatable       = setmetatable
local tonumber           = tonumber

local next               = next
local nodes, node, fonts = nodes, node, fonts

local nodedirect         = nodes.nuts

local getfield           = nodedirect.getfield
local setfield           = nodedirect.setfield

local field_setter = function (name) return function (n, ...) setfield (n, name, ...) end end
local field_getter = function (name) return function (n, ...) getfield (n, name, ...) end end

--- As of December 2014 the faster ``node.direct.*`` interface is
--- preferred.

local getfont            = nodedirect.getfont
local getid              = nodedirect.getid

local getnext            = nodedirect.getnext or field_getter "next"
local setnext            = nodedirect.setnext or field_setter "next"

local getprev            = nodedirect.getprev or field_getter "prev"
local setprev            = nodedirect.setprev or field_setter "prev"

--- since r5336
local getboth            = nodedirect.getboth or function (n)
  return getprev (n), getnext (n)
end

local setlink            = nodedirect.setlink or function (a, b)
  setnext (a, b)
  setprev (b, a)
end

local getdisc            = nodedirect.getdisc or field_getter "disc"
local setdisc            = nodedirect.setdisc or field_setter "disc"

local getsubtype         = nodedirect.getsubtype or field_getter "subtype"
local setsubtype         = nodedirect.setsubtype or field_setter "subtype"

local getchar            = nodedirect.getchar or field_getter "subtype"
local setchar            = nodedirect.setchar or field_setter "subtype"

local find_node_tail     = nodedirect.tail
local todirect           = nodedirect.tonut
local tonode             = nodedirect.tonode

local insert_node_before = nodedirect.insert_before
local free_node          = nodedirect.free
local copy_node          = nodedirect.copy
local new_node           = nodedirect.new

local nodepool           = nodedirect.pool
local new_kern           = nodepool.kern

local nodecodes          = nodes.nodecodes

local glyph_code         = nodecodes.glyph
local kern_code          = nodecodes.kern
local disc_code          = nodecodes.disc
local math_code          = nodecodes.math
local glue_code          = nodecodes.glue

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
local skipcodes = bothways {  [0] = "userskip"
                           , [13] = "spaceskip"
                           , [14] = "xspaceskip"
                           }

kerncodes.kerning       = kerncodes.fontkern --- idiosyncrasy
local kerning_code      = kerncodes.kerning
local userkern_code     = kerncodes.userkern
local userskip_code     = skipcodes.userskip
local spaceskip_code    = skipcodes.spaceskip
local xspaceskip_code   = skipcodes.xspaceskip

-----------------------------------------------------------------------
--- node-res
-----------------------------------------------------------------------

local glue_spec   = new_node "glue_spec"

local new_gluespec = function (width,
                               stretch,       shrink,
                               stretch_order, shrink_order)
  local spec = copy_node(glue_spec)
  if width         then setfield(spec, "width"        , width        )  end
  if stretch       then setfield(spec, "stretch"      , stretch      )  end
  if shrink        then setfield(spec, "shrink"       , shrink       )  end
  if stretch_order then setfield(spec, "stretch_order", stretch_order)  end
  if shrink_order  then setfield(spec, "shrink_order" , shrink_order )  end
  return spec
end

local new_glue = function (width, stretch, shrink,
                           stretch_order, shrink_order)
  local n = new_node "glue"
  if not width then return n end
    -- no spec
  if width == false then
    local width = tonumber(width)
    if width then
      setfield(n, "spec",
               new_gluespec(width, stretch, shrink,
                            stretch_order, shrink_order))
    end
  else
    -- shared
    setfield(n, "spec", copy_node(width))
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
    local s = getfield(g, "spec")
    setfield(s, "stretch", kern)
    setfield(s, "stretch_order", 1)
    return g
  end
  return new_kern(kern)
end

local kernable_skip = function (n)
  local st = getsubtype (n)
  return st == userskip_code
      or st == spaceskip_code
      or st == xspaceskip_code
end

local function spec_injector (fillup, width, stretch, shrink)
  if fillup then
    local spec = new_gluespec(width, 2 * stretch, 2 * shrink)
    setfield(spec, "stretch_order", 1)
    return spec
  end
  return new_gluespec(width,stretch,shrink)
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
    local id = getid(start)
    if id == glyph_code then
      --- 1) look up kern factor (slow, but cached rudimentarily)
      local krn
      local fontid = getfont(start)
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
          if (id ~= disc_code) and (not getfield(start, "components")) then
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
      local c = getfield(start, "components")

      if c then
        if keepligature and keepligature(start) then
          -- keep 'm
          c = nil
        else
          while c do
            local s = start
            local p, n = getboth (s)
            if p then
              setlink (p, c)
            else
              head = c
            end
            if n then
              local tail = find_node_tail(c)
              setlink (tail, n)
            end
            start = c
            setfield(s, "components", nil)
            free_node(s)
            done = true
            c = getfield (start, "components")
          end
        end
      end -- kern ligature

      --- 3) apply the extra kerning
      local prev = getprev(start)
      if prev then
        local pid = getid(prev)

        if not pid then
          -- nothing

        elseif pid == glue_code and kernable_skip(prev) then
          local spec = getfield(prev, "spec")
          local wd   = getfield(spec, "width")
          if wd > 0 then
            --- formula taken from Context
            ---      existing_width extended by four times the
            ---      width times the font’s kernfactor
            local newwd     = wd + --[[two en to a quad]] 4 * wd * krn
            local stretched = (getfield(spec,"stretch") * newwd) / wd
            local shrunk    = (getfield(spec,"shrink")  * newwd) / wd
            setfield(prev, "spec",
                     spec_injector(fillup, newwd, stretched, shrunk))
            done = true
          end

        elseif pid == kern_code then
          local prev_subtype = getsubtype(prev)
          if prev_subtype == kerning_code   --- context does this by means of an
          or prev_subtype == userkern_code  --- attribute; we may need a test
          then

            local pprev    = getprev(prev)
            local pprev_id = getid(pprev)

            if    keeptogether
              and pprev_id == glyph_code
              and keeptogether(pprev, start)
            then
              -- keep
            else
              setsubtype (prev, userkern_code)
              local prev_kern = getfield(prev, "kern")
              prev_kern = prev_kern + quaddata[lastfont] * krn
              setfield (prev, "kern", prev_kern)
              done = true
            end
          end

        elseif pid == glyph_code then
          if getfont(prev) == lastfont then
            local prevchar = getchar(prev)
            local lastchar = getchar(start)
            if keeptogether and keeptogether(prev, start) then
              -- keep 'm
            elseif identifiers[lastfont] then
              local kerns = chardata[lastfont] and chardata[lastfont][prevchar].kerns
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
          local disc = prev -- disc
          local pre, post, replace = getdisc (disc)
          local prv = getprev(disc)
          local nxt = getnext(disc)

          if pre and prv then -- must pair with start.prev
            -- this one happens in most cases
            local before = copy_node(prv)
            setprev(pre,    before)
            setnext(before, pre)
            setprev(before, nil)
            pre = kerncharacters (before)
            pre = getnext(pre)
            setprev(pre, nil)
            setfield(disc, "pre", pre)
            free_node(before)
          end

          if post and nxt then  -- must pair with start
            local after = copy_node(nxt)
            local tail = find_node_tail(post)
            setnext(tail,  after)
            setprev(after, tail)
            setnext(after, nil)
            post = kerncharacters (post)
            setnext(tail, nil)
            setfield(disc, "post", post)
            free_node(after)
          end

          if replace and prv and nxt then -- must pair with start and start.prev
            local before = copy_node(prv)
            local after = copy_node(nxt)
            local tail = find_node_tail(replace)
            setprev(replace, before)
            setnext(before,  replace)
            setprev(before,  nil)
            setnext(tail,    after)
            setprev(after,   tail)
            setnext(after,   nil)
            replace = kerncharacters (before)
            replace = getnext(replace)
            setprev(replace, nil)
            setnext(getprev(after), nil)
            setfield(disc, "replace",   replace)
            free_node(after)
            free_node(before)

          elseif identifiers[lastfont] then
            if    prv
              and getid(prv)   == glyph_code
              and getfont(prv) == lastfont
            then
              local prevchar = getchar(prv)
              local lastchar = getchar(start)
              local kerns = chardata[lastfont] and chardata[lastfont][prevchar].kerns
              local kern = kerns and kerns[lastchar] or 0
              krn = kern + quaddata[lastfont]*krn -- here
            else
              krn = quaddata[lastfont]*krn -- here
            end
            setfield(disc, "replace", kern_injector(false, krn))
          end --[[if replace and prv and nxt]]
        end --[[if not pid]]
      end --[[if prev]]
    end --[[if id == glyph_code]]

    ::nextnode::
    if start then
      start = getnext(start)
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

--- When font kerning is requested, usually by defining a font with the
--- ``letterspace`` parameter, we inject a wrapper for the
--- ``kerncharacters()`` node processor in the relevant callbacks. This
--- wrapper initially converts the received head node into its “direct”
--- counterpart. Likewise, the callback result is converted back to an
--- ordinary node prior to returning. Internally, ``kerncharacters()``
--- performs all node operations on direct nodes.

--- unit -> bool
local enablefontkerning = function ( )

  local handler = function (hd)
    local direct_hd = todirect (hd)
    logreport ("term", 5, "letterspace",
               "kerncharacters() invoked with node.direct interface \z
               (``%s`` -> ``%s``)", tostring (hd), tostring (direct_hd))
    local direct_hd, _done = kerncharacters (direct_hd)
    if not direct_hd then --- bad
      logreport ("both", 0, "letterspace",
                 "kerncharacters() failed to return a valid new head")
    end
    return tonode (direct_hd)
  end

  return add_processor( handler
                      , "luaotfload.letterspace"
                      , "pre_linebreak_filter"
                      , "hpack_filter")
end

--- unit -> bool
---al disablefontkerning = function ( )
---eturn remove_processor "luaotfload.letterspace"
---

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
    logreport ("both", 0, "letterspace",
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

