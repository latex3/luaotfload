local hb = require("harf-base")

local disccode  = node.id("disc")
local gluecode  = node.id("glue")
local glyphcode = node.id("glyph")
local dircode   = node.id("dir")
local kerncode  = node.id("kern")
local localparcode = node.id("local_par")
local spaceskip = 13
local directmode = 2
local fontkern = 0

local getscript    = hb.unicode.script
local sc_common    = hb.Script.new("Zyyy")
local sc_inherited = hb.Script.new("Zinh")
local sc_unknown   = hb.Script.new("Zzzz")
local sc_latn      = hb.Script.new("Latn")
local dir_ltr      = hb.Direction.new("ltr")
local dir_rtl      = hb.Direction.new("rtl")
local lang_invalid = hb.Language.new()
local fl_unsafe    = hb.Buffer.GLYPH_FLAG_UNSAFE_TO_BREAK

local format = string.format

-- Convert list of integers to UTF-16 hex string used in PDF.
local function to_utf16_hex(unicodes)
  local hex = ""
  for _, uni in next, unicodes do
    if uni < 0x10000 then
      hex = hex..format("%04X", uni)
    else
      uni = uni - 0x10000
      local hi = 0xD800 + (uni // 0x400)
      local lo = 0xDC00 + (uni % 0x400)
      hex = hex..format("%04X%04X", hi, lo)
    end
  end
  return hex
end

local paired_open = {
  [0x0028] = 0x0029, [0x003c] = 0x003e, [0x005b] = 0x005d, [0x007b] = 0x007d,
  [0x00ab] = 0x00bb, [0x2018] = 0x2019, [0x201c] = 0x201d, [0x2039] = 0x203a,
  [0x3008] = 0x3009, [0x300a] = 0x300b, [0x300c] = 0x300d, [0x300e] = 0x300f,
  [0x3010] = 0x3011, [0x3014] = 0x3015, [0x3016] = 0x3017, [0x3018] = 0x3019,
  [0x301a] = 0x301b,
}

local paired_close = {
  [0x0029] = 0x0028, [0x003e] = 0x003c, [0x005d] = 0x005b, [0x007d] = 0x007b,
  [0x00bb] = 0x00ab, [0x2019] = 0x2018, [0x201d] = 0x201c, [0x203a] = 0x2039,
  [0x3009] = 0x3008, [0x300b] = 0x300a, [0x300d] = 0x300c, [0x300f] = 0x300e,
  [0x3011] = 0x3010, [0x3015] = 0x3014, [0x3017] = 0x3016, [0x3019] = 0x3018,
  [0x301b] = 0x301a,
}

local to_hb_dir = {
  TLT = dir_ltr,
  TRT = dir_rtl,
  RTT = dir_ltr, -- XXX What to do with this?
  LTL = dir_ltr, -- XXX Ditto
}

local process

-- Collect character properties (font, direction, script) and resolve common
-- and inherited scripts. Pre-requisite for itemization into smaller runs.
local function collect(head, direction)
  local nodes = {}
  local codes = {}
  local dirstack = {}
  local pairstack = {}
  local currdir = direction or "TLT"
  local currfont = nil

  for n in node.traverse(head) do
    local id = n.id
    local code = 0xFFFC -- OBJECT REPLACEMENT CHARACTER
    local script = sc_common

    if id == glyphcode then
      code = n.char
      currfont = n.font
      script = getscript(code)
    elseif id == gluecode and n.subtype == spaceskip then
      code = 0x0020 -- SPACE
    elseif id == disccode then
      code = 0x00AD -- SOFT HYPHEN
    elseif id == dircode then
      if n.dir:sub(1, 1) == "+" then
        -- Push the current direction to the stack.
        table.insert(dirstack, currdir)
        currdir = n.dir:sub(2)
      else
        assert(currdir == n.dir:sub(2))
        -- Pop the last direction from the stack.
        currdir = table.remove(dirstack)
      end
    elseif id == localparcode then
      currdir = n.dir
    end

    -- Resolve common and inherited scripts. Inherited takes the script of the
    -- previous character. Common almost the same, but we tray to make paired
    -- characters (e.g. parentheses) to take the same script.
    if #nodes > 0 and (script == sc_common or script == sc_inherited) then
      script = nodes[#nodes].script
      -- Paired punctuation characters
      if paired_open[code] then
        table.insert(pairstack, { code, script })
      elseif paired_close[code] then
        while #pairstack > 0 do
          local c = table.remove(pairstack)
          if c[1] == paired_close[code] then
            script = c[2]
            break
          end
        end
      end
    end

    codes[#codes + 1] = code
    nodes[#nodes + 1] = {
      node = n,
      font = currfont,
      dir = to_hb_dir[currdir],
      script = script,
    }

    dir = currdir
  end

  for i = #nodes - 1, 1, -1 do
    -- If script is not resolved yet, use that of the next character.
    if nodes[i].script == sc_common or nodes[i].script == sc_inherited then
      nodes[i].script = nodes[i + 1].script
    end
  end

  return nodes, codes
end

-- Split into a list of runs, each has the same font, direction and script.
-- TODO: itemize by language as well.
local function itemize(nodes)
  local runs = {}
  local currfont, currdir, currscript = nil, nil, nil
  for i, n in next, nodes do
    local font = n.font
    local dir = n.dir
    local script = n.script

    -- Start a new run if there is a change in properties.
    if font ~= currfont or dir ~= currdir or script ~= currscript then
      runs[#runs + 1] = {
        start = i,
        len = 0,
        font = font,
        dir = dir,
        script = script,
      }
    end

    runs[#runs].len = runs[#runs].len + 1

    currfont = font
    currdir = dir
    currscript = script
  end

  return runs
end

-- Find how many characters are part of this glyph.
--
-- The first return value is the number of characters, with 0 meaning it is
-- inside a multi-glyph cluster
--
-- The second return value is the number of glyph in this cluster.
--
local function chars_in_glyph(i, glyphs, stop)
  local nchars, nglyphs = 0, 0
  local cluster = glyphs[i].cluster

  -- Glyph is not the first in cluster
  if glyphs[i - 1] and glyphs[i - 1].cluster == cluster then
    return 0, 0
  end

  -- Find the last glyph in this cluster.
  while glyphs[i + nglyphs] and glyphs[i + nglyphs].cluster == cluster do
    nglyphs = nglyphs + 1
  end

  -- The number of characters is the diff between the next cluster in this one.
  if glyphs[i + nglyphs] then
    nchars = glyphs[i + nglyphs].cluster - cluster
  else
    -- This glyph cluster in the last in the run.
    nchars = stop - cluster - 1
  end

  return nchars, nglyphs
end

-- Check if it is safe to break before this glyph.
local function unsafetobreak(glyph, nodes)
  return glyph
     and glyph.flags
     and glyph.flags & fl_unsafe
     -- LuaTeX’s discretionary nodes can’t contain glue, so stop at first glue
     -- as well. This is incorrect, but I don’t have a better idea.
     and nodes[glyph.cluster + 1].id ~= gluecode
end

local shape

-- Make s a sub run, used by discretionary nodes.
local function makesub(run, nodes, codes, start, stop, nodelist)
  local start = start
  local stop = stop
  local subnodes, subcodes = {}, {}
  for i = start, stop do
    if nodes[i].id ~= disccode then
      subnodes[#subnodes + 1] = node.copy(nodes[i])
      subcodes[#subcodes + 1] = codes[i]
    end
  end
  -- Prepend any existing nodes to the list.
  for n in node.traverse(nodelist) do
    subnodes[#subnodes + 1] = n
    subcodes[#subcodes + 1] = n.char
  end
  local subrun = {
    start = 1,
    len = #subnodes,
    font = run.font,
    script = run.script,
    dir = run.dir,
    fordisc = true,
  }
  return {
    glyphs = shape(subrun, subnodes, subcodes),
    run = subrun,
    nodes = subnodes,
    codes = subcodes,
  }
end

-- Simple table copying function. DOES NOT copy sub tables.
local function copytable(old)
  local new = {}
  for k, v in next, old do
    new[k] = v
  end
  return new
end

-- Main shaping function that calls HarfBuzz, and does some post-processing of
-- the output.
shape = function(run, nodes, codes)
  local offset = run.start
  local len = run.len
  local fontid = run.font
  local dir = run.dir
  local script = run.script
  local lang = run.lang or lang_invalid
  local fordisc = run.fordisc

  local fontdata = font.fonts[fontid]
  local hbdata = fontdata.hb
  local hbfont = hbdata.font
  local features = hbdata.spec.features
  local loaded = hbdata.loaded

  local buf = hb.Buffer.new()
  buf:set_direction(dir)
  buf:set_script(script)
  buf:set_language(lang)
  buf:set_cluster_level(buf.CLUSTER_LEVEL_MONOTONE_CHARACTERS)
  buf:add_codepoints(codes, offset - 1, len)

  if hb.shape_full(hbfont, buf, features) then
    -- LuaTeX wants the glyphs in logical order, so reverse RTL buffers.
    if dir:is_backward() then buf:reverse() end

    local glyphs = buf:get_glyphs()
    for i, glyph in next, glyphs do
      local nodeindex = glyph.cluster + 1
      local nchars, nglyphs = chars_in_glyph(i, glyphs, offset + len)
      glyph.nchars, glyph.nglyphs = nchars, nglyphs

      -- Calculate the Unicode code points of this glyph. If nchars is zero
      -- then this is a glyph inside a complex cluster and will be handled with
      -- the start of its cluster.
      if nchars > 0 then
        local unicodes = {}
        for j = 0, nchars - 1 do
          local id = nodes[nodeindex + j].id
          if id == glyphcode or id == gluecode then
            unicodes[#unicodes + 1] = codes[nodeindex + j]
          end
        end
        glyph.unicodes = unicodes
      end

      -- Find if we have a discretionary inside a ligature, if nchars less than
      -- two then either this is not a ligature or there is no discretionary
      -- involved.
      if nchars > 2 and not fordisc then
        local discindex = nil
        for j = nodeindex, nodeindex + nchars - 1 do
          if codes[j] == 0x00AD then
            discindex = j
            break
          end
        end
        if discindex then
          -- Discretionary found.
          local disc = nodes[discindex]
          local startindex, stopindex = nil, nil
          local startglyph, stopglyph = nil, nil

          -- Find the previous glyph that is safe to break at.
          startglyph = i
          while unsafetobreak(glyphs[startglyph], nodes) do
            startglyph = startglyph - 1
          end
          -- Get the corresponding character index.
          startindex = glyphs[startglyph].cluster + 1

          -- Find the next glyph that is safe to break at.
          stopglyph = i + nglyphs
          while unsafetobreak(glyphs[stopglyph], nodes) do
            stopglyph = stopglyph + 1
          end
          -- We also want the last char in the previous glyph, so no +1 below.
          stopindex = glyphs[stopglyph].cluster
          -- We break up to stop glyph but not including it, so the -1 below.
          stopglyph = stopglyph - 1

          -- Mark these glyph for skipping since they will be replaced by the
          -- discretionary fields.
          for j = startglyph, stopglyph do
            glyphs[j].skip = true
          end

          glyph.disc = disc
          glyph.replace = makesub(run, nodes, codes, startindex, stopindex, disc.replace)
          glyph.pre = makesub(run, nodes, codes, startindex, discindex - 1, disc.pre)
          glyph.post = makesub(run, nodes, codes, discindex + 1, stopindex, disc.post)
        end
      end
    end
    return glyphs
  end

  return {}
end

local function pdfdirect(data)
  local actual = node.new("whatsit", "pdf_literal")
  actual.mode = directmode
  actual.data = data
  return actual
end

-- Convert glyphs to nodes and collect font characters.
local function tonodes(head, current, run, nodes, codes, glyphs, characters)
  local fordisc = run.fordisc
  local dir = run.dir
  local fontid = run.font
  local fontdata = fontid and font.fonts[fontid]
  local hbdata = fontdata and fontdata.hb
  local hbfont = hbdata.font
  local loaded = hbdata.loaded
  local rtl = dir:is_backward()

  local tracinglostchars = tex.tracinglostchars

  local fontextents = hbfont:get_h_extents()
  local ascender = fontextents and fontextents.ascender
  local descender = fontextents and fontextents.descender

  for i, glyph in next, glyphs do
    local index = glyph.cluster + 1
    local gid = glyph.codepoint
    local char = hb.CH_GID_PREFIX + gid
    local n = nodes[index]
    local id = n.id
    local nchars, nglyphs = glyph.nchars, glyph.nglyphs

    -- If this glyph is part of a complex cluster, then copy the node as
    -- more than one glyph will use it.
    if nglyphs < 1 or nglyphs > 1 then
      n = node.copy(nodes[index])
    end

    if glyph.disc then
      -- For discretionary the glyph itself is skipped and a discretionary node
      -- is output in place of it.
      local disc = glyph.disc
      local replace = glyph.replace
      local pre = glyph.pre
      local post = glyph.post

      disc.replace = tonodes(nil, nil, replace.run, replace.nodes, replace.codes, replace.glyphs, characters)
      disc.pre = tonodes(nil, nil, pre.run, pre.nodes, pre.codes, pre.glyphs, characters)
      disc.post = tonodes(nil, nil, post.run, post.nodes, post.codes, post.glyphs, characters)

      head, current = node.insert_after(head, current, disc)
    elseif not glyph.skip then
      head, current = node.insert_after(head, current, n)

      if id == glyphcode then
        local width = hbfont:get_glyph_h_advance(gid)

        -- Report missing characters, trying to emulate the engine behaviour as
        -- much as possible.
        if gid == 0 and tracinglostchars > 0 then
          local code = n.char
          local target = tracinglostchars > 1 and "term and log" or "log"
          local msg = format("Missing character: There is no %s (U+%04X) in "..
                             "font %s!", utf8.char(code), code, fontdata.name)
          texio.write_nl(target, msg)
          texio.write_nl(target, "")
        end

        n.char = char
        n.xoffset = rtl and -glyph.x_offset or glyph.x_offset
        n.yoffset = glyph.y_offset

        if width ~= glyph.x_advance then
          -- LuaTeX always uses the glyph width from the font, so we need to
          -- insert a kern node if the x advance is different.
          local kern = node.new("kern")
          kern.kern = glyph.x_advance - width
          if rtl then
            head = node.insert_before(head, current, kern)
          else
            head, current = node.insert_after(head, current, kern)
          end
        end

        node.protect_glyph(n)

        -- Load the glyph metrics of not already loaded.
        if not loaded[gid] then
          local extents = hbfont:get_glyph_extents(gid)
          local character = {
            index = gid,
            width = width,
            height = extents and extents.y_bearing or ascender,
            depth = -(extents and extents.y_bearing + extents.height or descender),
          }
          loaded[gid] = character
          characters[char] = character
        end

        -- Handle PDF text extraction:
        -- * Find how many characters in this cluster and how many glyphs,
        -- * If there is more than 0 characters
        --   * One glyph: one to one or one to many mapping, can be
        --     represented by font’s /ToUnicode
        --   * More than one: many to one or many to many mapping, can be
        --     represented by /ActualText spans.
        -- * If there are zero characters, then this glyph is part of complex
        --   cluster that will be covered by an /ActualText span.
        local unicodes = glyph.unicodes or {}
        if #unicodes > 0 then
          local tounicode = to_utf16_hex(unicodes)
          if nglyphs == 1 and not loaded[gid].tounicode then
            loaded[gid].tounicode = tounicode
            characters[char] = loaded[gid]
          elseif tounicode ~= loaded[gid].tounicode and not fordisc then
            local actual = "/Span<</ActualText<FEFF"..tounicode..">>>BDC"
            head = node.insert_before(head, current, pdfdirect(actual))
            glyphs[i + nglyphs - 1].endactual = true
          end
        end
        if glyph.endactual then
          head, current = node.insert_after(head, current, pdfdirect("EMC"))
        end
      elseif id == gluecode and n.subtype == spaceskip then
        if n.width ~= glyph.x_advance then
          n.width = glyph.x_advance
        end
      elseif id == disccode then
        assert(nglyphs == 1)
        -- The simple case of a discretionary that is not part of a complex
        -- cluster. We only need to make sure kerning before the hyphenation
        -- point is dropped when a line break is inserted here.
        local prev = current.prev
        if prev and prev.id == kerncode and prev.subtype == fontkern then
          head = node.remove(head, prev)
          prev.prev, prev.next = nil, nil
          n.replace = prev
        end
        n.pre = process(n.pre, direction)
      end
    end
  end

  return head, current, characters
end

local function shape_run(head, current, run, nodes, codes)
  local fontid = run.font
  local fontdata = fontid and font.fonts[fontid]

  if fontdata and fontdata.hb then
    -- Font loaded with our loader and an HarfBuzz face is present, do our
    -- shaping.
    local characters = {} -- LuaTeX font characters table

    local glyphs = shape(run, nodes, codes)
    head, current = tonodes(head, current, run, nodes, codes, glyphs, characters)

    if next(characters) ~= nil then
      font.addcharacters(run.font, { characters = characters })
    end
  else
    -- Not shaping, insert the original node list of of this run.
    local offset = run.start
    local len = run.len
    for i = offset, offset + len - 1 do
      head, current = node.insert_after(head, current, nodes[i])
    end
  end

  return head, current
end

process = function(head, direction)
  local newhead, current = nil, nil
  local nodes, codes = collect(head, direction)
  local runs = itemize(nodes)

  for i, n in next, nodes do
    nodes[i] = n.node
  end

  for _, run in next, runs do
    newhead, current = shape_run(newhead, current, run, nodes, codes)
  end

  return newhead or head
end

local function process_nodes(head, groupcode, size, packtype, direction)
  local fonts = font.fonts

  -- Check if any fonts are loaded by us and then process the whole node list,
  -- we will take care of skipping fonts we did not load later, otherwise
  -- return unmodified head.
  for n in node.traverse_id(glyphcode, head) do
    if fonts[n.font].hb ~= nil then
      return process(head, direction)
    end
  end

  -- Nothing to do; no glyphs or no HarfBuzz fonts.
  return head
end

return process_nodes
