if not modules then modules = { } end modules ['letterspace'] = {
    version   = "2.3a",
    comment   = "companion to luaotfload.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL; adapted by Philipp Gesang",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local next               = next
local nodes, node, fonts = nodes, node, fonts

local find_node_tail     = node.tail or node.slide
local free_node          = node.free
local free_nodelist      = node.flush_list
local copy_node          = node.copy
local copy_nodelist      = node.copy_list
local insert_node_before = node.insert_before
local insert_node_after  = node.insert_after

local nodepool           = nodes.pool
local tasks              = nodes.tasks

local new_kern           = nodepool.kern
local new_glue           = nodepool.glue

local nodecodes          = nodes.nodecodes
local kerncodes          = nodes.kerncodes
local skipcodes          = nodes.skipcodes

local glyph_code         = nodecodes.glyph
local kern_code          = nodecodes.kern
local disc_code          = nodecodes.disc
local glue_code          = nodecodes.glue
local hlist_code         = nodecodes.hlist
local vlist_code         = nodecodes.vlist
local math_code          = nodecodes.math

local kerning_code       = kerncodes.kerning
local userkern_code      = kerncodes.userkern

local fonthashes         = fonts.hashes
local chardata           = fonthashes.characters
local quaddata           = fonthashes.quads

typesetters              = typesetters or { }
local typesetters        = typesetters

typesetters.kernfont     = typesetters.kernfont or { }
local kernfont           = typesetters.kernfont

kernfont.keepligature    = false
kernfont.keeptogether    = false

local kern_injector = function (fillup,kern)
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
    This is a preliminary, makeshift adaptation of the Context
    character kerning mechanism that emulates XeTeX-style fontwise
    letterspacing. Note that in its present state it is far inferior to
    the original, which is attribute-based and ignores font-boundaries.
    Nevertheless, due to popular demand the following callback has been
    added. It should not be relied upon to be present in future
    versions.

--doc]]--

local kernfactors = { } --- fontid -> factor

local kerncharacters
kerncharacters = function (head)
  local start, done   = head, false
  local lastfont      = nil
  local keepligature  = kernfont.keepligature --- function
  local keeptogether  = kernfont.keeptogether --- function
  local fillup        = false

  local identifiers   = fonthashes.identifiers
  local kernfactors   = kernfactors

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
          goto nextnode
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
          c = kerncharacters (c)
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

kernfont.handler = kerncharacters

--- vim:sw=2:ts=2:expandtab:tw=71

