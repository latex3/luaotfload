local hb = require("harf-base")

local disccode  = node.id("disc")
local gluecode  = node.id("glue")
local glyphcode = node.id("glyph")
local dircode   = node.id("dir")
local parcode   = node.id("local_par")
local spaceskip = 13
local directmode = 2

-- Convert integer to UTF-16 hex string used in PDF.
local function to_utf16_hex(uni)
  if uni < 0x10000 then
    return string.format("%04X", uni)
  else
    uni = uni - 0x10000
    local hi = 0xD800 + bit32.rshift(uni, 10) -- 0xD800 + (uni // 0x400)
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
  local dir = run.dir
  local fontid = run.font
  local fontdata = fontid and font.fonts[fontid]

  if fontdata and fontdata.hb then
    local hbfont = fontdata.hb.font
    local loaded = fontdata.hb.loaded
    local options = {}
    local buf = hb.Buffer.new()
    local rtl = dir == "TRT"

    if rtl then
      options.direction = hb.Direction.HB_DIRECTION_RTL
    else
      options.direction = hb.Direction.HB_DIRECTION_LTR
    end

    buf:add_codepoints(codes, offset - 1, len)
    if hb.shape(hbfont, buf, options) then
      if rtl then
        buf:reverse()
      end

      local fontextents = hbfont:get_h_extents()
      local ascender = fontextents and fontextents.ascender
      local descender = fontextents and fontextents.descender

      local characters = {} -- LuaTeX font characters table
      local glyphs = buf:get_glyph_infos_and_positions()
      for i, g in next, glyphs do
        -- Copy the node for the first character in the cluster, so that we
        -- inherit any of its properties.
        local gid = g.codepoint
        local char = hb.CH_GID_PREFIX + gid
        local index = g.cluster + 1
        local n = node.copy(nodes[index])
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
              local id = nodes[index + j].id
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
    for i = offset, offset + len do
      head, current = node.insert_after(head, current, nodes[i])
    end
  end

  return head, current
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

  local dirstack = {}
  local dir = direction or "TLT"
  local nodes, codes = {}, {}
  local runs = { { font = fontid, dir = dir, start = 1, len = 0 } }
  local i = 1
  for n in node.traverse(head) do
    local id = n.id
    local char = 0xFFFC -- OBJECT REPLACEMENT CHARACTER
    local currdir = dir
    local currfont = fontid

    if id == glyphcode then
      currfont = n.font
      char = n.char
    elseif id == gluecode and n.subtype == spaceskip then
      char = 0x0020 -- SPACE
    elseif id == disccode then
      -- XXX actually handle this
      char = 0x00AD -- SOFT HYPHEN
    elseif id == dircode then
      if n.dir:sub(1, 1) == "+" then
        table.insert(dirstack, currdir)  -- push
        currdir = n.dir:sub(2)
      else
        currdir = table.remove(dirstack) -- pop
      end
    elseif id == parcode then
      currdir = n.dir
    end

    if currfont ~= fontid or currdir ~= dir then
      runs[#runs + 1] = { font = currfont, dir = currdir, start = i, len = 0 }
    end

    fontid = currfont
    dir = currdir
    runs[#runs].len = runs[#runs].len + 1

    nodes[#nodes + 1] = n
    codes[#codes + 1] = char
    i = i + 1
  end

  local newhead, current
  for _, run in next, runs do
    newhead, current = shape(newhead, current, run, nodes, codes)
  end

  return newhead or head
end

callback.register('pre_linebreak_filter', process)
callback.register('hpack_filter',         process)
