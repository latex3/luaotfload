local hb = require("harf-base")

local disccode  = node.id("disc")
local gluecode  = node.id("glue")
local glyphcode = node.id("glyph")
local dircode   = node.id("dir")
local localparcode = node.id("local_par")
local spaceskip = 13
local directmode = 2

local getscript    = hb.unicode.script
local sc_common    = hb.Script.new("Zyyy")
local sc_inherited = hb.Script.new("Zinh")
local sc_unknown   = hb.Script.new("Zzzz")
local sc_latn      = hb.Script.new("Latn")
local dir_ltr      = hb.Direction.new("ltr")
local dir_rtl      = hb.Direction.new("rtl")
local lang_invalid = hb.Language.new()

-- Convert integer to UTF-16 hex string used in PDF.
local function to_utf16_hex(uni)
  if uni < 0x10000 then
    return string.format("%04X", uni)
  else
    uni = uni - 0x10000
    local hi = 0xD800 + (uni // 0x400)
    local lo = 0xDC00 + (uni % 0x400)
    return string.format("%04X%04X", hi, lo)
  end
end

-- Find how many characters are part of this glyph.
--
-- The first return value is the number of characters, with the these special
-- values:
--   0 means it is inside a multi-glyph cluster
--  -1 means as many characters tell the end of the run
--
-- The second return value is the number of glyph in this cluster.
--
local function chars_in_glyph(i, glyphs)
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
    nchars = -1
  end

  return nchars, nglyphs
end

local function shape(head, current, run, nodes, codes)
  local offset = run.start
  local len = run.len
  local fontid = run.font
  local fontdata = fontid and font.fonts[fontid]

  if fontdata and fontdata.hb then
    local dir = run.dir
    local script = run.script
    local lang = run.lang or lang_invalid
    local hbfont = fontdata.hb.font
    local loaded = fontdata.hb.loaded
    local buf = hb.Buffer.new()
    local rtl = dir:is_backward()

    buf:set_direction(dir)
    buf:set_script(script)
    buf:set_language(lang)
    buf:set_cluster_level(buf.CLUSTER_LEVEL_MONOTONE_CHARACTERS)
    buf:add_codepoints(codes, offset - 1, len)
    if hb.shape_full(hbfont, buf, {}) then
      if rtl then
        buf:reverse()
      end

      local fontextents = hbfont:get_h_extents()
      local ascender = fontextents and fontextents.ascender
      local descender = fontextents and fontextents.descender

      local characters = {} -- LuaTeX font characters table
      local glyphs = buf:get_glyphs()
      for i, g in next, glyphs do
        -- Copy the node for the first character in the cluster, so that we
        -- inherit any of its properties.
        local gid = g.codepoint
        local char = hb.CH_GID_PREFIX + gid
        local index = g.cluster + 1
        local n = node.copy(nodes[index].node)
        local id = n.id

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
          local nchars, nglyphs = chars_in_glyph(i, glyphs)
          nchars = nchars >= 0 and nchars or offset + len - index
          if nchars > 0 then
            local tounicode = ""
            for j = 0, nchars - 1 do
              local id = nodes[index + j].node.id
              if id == glyphcode or id == gluecode then
                tounicode = tounicode..to_utf16_hex(codes[index + j])
              end
            end
            if tounicode ~= "" then
              if nglyphs == 1 and not loaded[gid].tounicode then
                loaded[gid].tounicode = tounicode
                characters[char] = loaded[gid]
              elseif tounicode ~= loaded[gid].tounicode then
                local actual = node.new("whatsit", "pdf_literal")
                actual.mode = directmode
                actual.data = "/Span<</ActualText<FEFF"..tounicode..">>>BDC"
                head = node.insert_before(head, current, actual)
                glyphs[i + nglyphs - 1].endactual = true
              end
            end
          end
          if g.endactual then
            local actual = node.new("whatsit", "pdf_literal")
            actual.mode = directmode
            actual.data = "EMC"
            head, current = node.insert_after(head, current, actual)
          end
        elseif id == gluecode and n.subtype == spaceskip then
          if n.width ~= g.x_advance then
            n.width = g.x_advance
          end
        end
      end

      if next(characters) ~= nil then
        font.addcharacters(run.font, { characters = characters })
      end
    end
  else
    -- Not shaping, insert the original node list of of this run.
    for i = offset, offset + len - 1 do
      head, current = node.insert_after(head, current, nodes[i].node)
    end
  end

  return head, current
end

local paired_open = {
  [0x0028] = 0x0029,
  [0x003c] = 0x003e,
  [0x005b] = 0x005d,
  [0x007b] = 0x007d,
  [0x00ab] = 0x00bb,
  [0x2018] = 0x2019,
  [0x201c] = 0x201d,
  [0x2039] = 0x203a,
  [0x3008] = 0x3009,
  [0x300a] = 0x300b,
  [0x300c] = 0x300d,
  [0x300e] = 0x300f,
  [0x3010] = 0x3011,
  [0x3014] = 0x3015,
  [0x3016] = 0x3017,
  [0x3018] = 0x3019,
  [0x301a] = 0x301b,
}

local paired_close = {
  [0x0029] = 0x0028,
  [0x003e] = 0x003c,
  [0x005d] = 0x005b,
  [0x007d] = 0x007b,
  [0x00bb] = 0x00ab,
  [0x2019] = 0x2018,
  [0x201d] = 0x201c,
  [0x203a] = 0x2039,
  [0x3009] = 0x3008,
  [0x300b] = 0x300a,
  [0x300d] = 0x300c,
  [0x300f] = 0x300e,
  [0x3011] = 0x3010,
  [0x3015] = 0x3014,
  [0x3017] = 0x3016,
  [0x3019] = 0x3018,
  [0x301b] = 0x301a,
}

local to_hb_dir = {
  TLT = dir_ltr,
  TRT = dir_rtl,
  RTT = dir_ltr, -- XXX What to do with this?
  LTL = dir_ltr, -- XXX Ditto
}

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
      -- XXX actually handle this
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

    fontid = currfont
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

local function process(head, groupcode, size, packtype, direction)
  local fontid
  local has_hb
  for n in node.traverse_id(glyphcode, head) do
    local fontdata = font.fonts[n.font]
    has_hb = has_hb or fontdata.hb ~= nil
    fontid = fontid or n.font
  end

  -- Nothing to do; no glyphs or no HarfBuzz fonts.
  if not has_hb then
    return head
  end

  local currfont, currdir, currscript = nil, nil, nil
  local nodes, codes = collect(head, direction)
  local runs = {}
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

  local newhead, current
  for _, run in next, runs do
    newhead, current = shape(newhead, current, run, nodes, codes)
  end

  return newhead or head
end

callback.register('pre_linebreak_filter', process)
callback.register('hpack_filter',         process)
