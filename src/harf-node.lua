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

-- Convert list of integers to UTF-16 hex string used in PDF.
local function to_utf16_hex(unicodes)
  local hex = ""
  for _, uni in next, unicodes do
    if uni < 0x10000 then
      hex = hex..string.format("%04X", uni)
    else
      uni = uni - 0x10000
      local hi = 0xD800 + (uni // 0x400)
      local lo = 0xDC00 + (uni % 0x400)
      hex = hex..string.format("%04X%04X", hi, lo)
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

local to_luatex_dir = {
  dir_ltr = "TLT",
  dir_rtl = "TRT",
}

local collect
local itemize
local process

collect = function(head, direction)
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
        table.insert(dirstack, currdir)
        currdir = n.dir:sub(2)
      else
        assert(currdir == n.dir:sub(2))
        currdir = table.remove(dirstack)
      end
    elseif id == localparcode then
      currdir = n.dir
    end

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
    -- If script is not resolved yet, use that of the next glyph.
    if nodes[i].script == sc_common or nodes[i].script == sc_inherited then
      nodes[i].script = nodes[i + 1].script
    end
  end

  return nodes, codes
end

itemize = function(nodes)
  local runs = {}
  local currfont, currdir, currscript = nil, nil, nil
  for i, n in next, nodes do
    local font = n.font
    local dir = n.dir
    local script = n.script

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

  while glyphs[i + nglyphs] and glyphs[i + nglyphs].cluster == cluster do
    nglyphs = nglyphs + 1
  end

  if glyphs[i + nglyphs] then
    nchars = glyphs[i + nglyphs].cluster - cluster
  else
    nchars = stop - cluster - 1
  end

  return nchars, nglyphs
end

local function shape(run, nodes, codes)
  local offset = run.start
  local len = run.len
  local fontid = run.font
  local dir = run.dir
  local script = run.script
  local lang = run.lang or lang_invalid

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

      if nchars > 0 then
        local unicodes = {}
        for j = 0, nchars - 1 do
          local id = nodes[nodeindex + j].node.id
          if id == glyphcode or id == gluecode then
            unicodes[#unicodes + 1] = codes[nodeindex + j]
          end
        end
        glyph.unicodes = unicodes
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

local function layout(head, current, run, nodes, codes)
  local offset = run.start
  local len = run.len
  local fontid = run.font
  local fontdata = fontid and font.fonts[fontid]
  local hbdata = fontdata and fontdata.hb

  if hbdata then
    local dir = run.dir
    local rtl = dir:is_backward()
    local hbfont = hbdata.font
    local loaded = hbdata.loaded

    local fontextents = hbfont:get_h_extents()
    local ascender = fontextents and fontextents.ascender
    local descender = fontextents and fontextents.descender

    local characters = {} -- LuaTeX font characters table
    local glyphs = shape(run, nodes, codes)
    for i, g in next, glyphs do
      local index = g.cluster + 1

      if not nodes[index].skip then
        local gid = g.codepoint
        local char = hb.CH_GID_PREFIX + gid
        local n = nodes[index].node
        local id = n.id
        local nchars, nglyphs = g.nchars, g.nglyphs
        -- If this glyph is part of a complex cluster, then copy the node as
        -- more than one glyph will use it.
        if nglyphs < 1 or nglyphs > 1 then
          n = node.copy(nodes[index].node)
        end

        head, current = node.insert_after(head, current, n)

        if id == glyphcode then
          local width = hbfont:get_glyph_h_advance(gid)

          n.char = char
          n.xoffset = rtl and -g.x_offset or g.x_offset
          n.yoffset = g.y_offset

          if width ~= g.x_advance then
            -- LuaTeX always uses the glyph width from the font, so we need to
            -- insert a kern node if the x advance is different.
            local kern = node.new("kern")
            kern.kern = g.x_advance - width
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
              tounicode = tounicode
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
          local unicodes = g.unicodes or {}
          if #unicodes > 0 then
            local tounicode = to_utf16_hex(unicodes)
            if nglyphs == 1 and not loaded[gid].tounicode then
              loaded[gid].tounicode = tounicode
              characters[char] = loaded[gid]
            elseif tounicode ~= loaded[gid].tounicode then
              local actual = "/Span<</ActualText<FEFF"..tounicode..">>>BDC"
              --head = node.insert_before(head, current, pdfdirect(actual))
              glyphs[i + nglyphs - 1].endactual = true
            end
          end
          if g.endactual then
            head, current = node.insert_after(head, current, pdfdirect("EMC"))
          end

          if nchars > 2 then
            -- XXX: ugly and complex code, refactor!
            -- See if we have a discretionary inside a complex glyph cluster.
            local discindex
            for j = index, index + nchars - 1 do
              if codes[j] == 0x00AD then
                discindex = j
                break
              end
            end
            if discindex then
              local direction = to_luatex_dir[dir]
              local disc = nodes[discindex].node
              local start, stop
              local j

              -- Find the previous safe to break at glyph.
              j = i
              while glyphs[j] do
                j = j - 1
                if not (glyphs[j].flags and glyphs[j].flags & fl_unsafe) then
                  break
                end
              end
              start = glyphs[j + 1].cluster

              -- Remove the current node from the list, it will be part of the
              -- discretionary’s replace list.
              local k = i
              while k > j - 1 do
                if not (current.id == kerncode and
                        current.subtype == fontkern)
                then
                  k = k - 1
                end
                head = node.remove(head, current)
                current = node.tail(head)
              end

              -- Find the next safe to break at glyph.
              j = i + nglyphs
              while glyphs[j] do
                j = j + 1
                if not (glyphs[j].flags and glyphs[j].flags & fl_unsafe) then
                  break
                end
              end
              stop = glyphs[j - 1].cluster

              -- Insert the discretionary.
              head, current = node.insert_after(head, current, disc)

              local replace, pre, post = nil, nil, nil
              -- Create the “replace” list, to be used if no line breaking
              -- happens here.
              -- XXX: We can re-use the already shaped glyphs here.
              for j = start, stop do
                local nn = nodes[j].node
                if nn.id == glyphcode then
                  nn = node.copy(nn)
                  if nn.char >= hb.CH_GID_PREFIX then
                    nn.char = codes[j]
                    node.unprotect_glyph(nn)
                  end
                  replace = node.insert_after(replace, nil, nn)
                end
                -- Mark these glyphs to be skipped to not insert them twice.
                nodes[j].skip = true
              end
              disc.replace = process(replace, direction)

              -- Create the “pre” list, to be inserted before the line break.
              for j = start, discindex - 1 do
                local nn = nodes[j].node
                if nn.id == glyphcode then
                  nn = node.copy(nn)
                  if nn.char >= hb.CH_GID_PREFIX then
                    nn.char = codes[j]
                    node.unprotect_glyph(nn)
                  end
                  pre = node.insert_after(pre, nil, nn)
                end
              end
              -- include the hyphen.
              pre = node.insert_after(pre, nil, disc.pre)
              disc.pre = process(pre, direction)

              -- Create the “post” list, to inserted after the line break.
              for j = discindex + 1, stop do
                local nn = nodes[j].node
                if nn.id == glyphcode then
                  nn = node.copy(nn)
                  if nn.char >= hb.CH_GID_PREFIX then
                    nn.char = codes[j]
                    node.unprotect_glyph(nn)
                  end
                  post = node.insert_after(post, nil, nn)
                end
              end
              disc.post = process(post, direction)
            end
          end
        elseif id == gluecode and n.subtype == spaceskip then
          if n.width ~= g.x_advance then
            n.width = g.x_advance
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

    if next(characters) ~= nil then
      font.addcharacters(run.font, { characters = characters })
    end
  else
    -- Not shaping, insert the original node list of of this run.
    for i = offset, offset + len - 1 do
      head, current = node.insert_after(head, current, nodes[i].node)
    end
  end

  return head, current
end

process = function(head, direction)
  local newhead, current = nil, nil
  local nodes, codes = collect(head, direction)
  local runs = itemize(nodes)

  for _, run in next, runs do
    newhead, current = layout(newhead, current, run, nodes, codes)
  end

  return newhead or head
end

local function process_nodes(head, groupcode, size, packtype, direction)
  local fonts = font.fonts
  for n in node.traverse_id(glyphcode, head) do
    if fonts[n.font].hb ~= nil then
      return process(head, direction)
    end
  end

  -- Nothing to do; no glyphs or no HarfBuzz fonts.
  return head
end

return process_nodes
