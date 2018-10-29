local hb = require("harf-base")

local disccode  = node.id("disc")
local gluecode  = node.id("glue")
local glyphcode = node.id("glyph")
local dircode   = node.id("dir")
local parcode   = node.id("local_par")
local spaceskip = 13

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
      for _, g in next, glyphs do
        -- Copy the node for the first character in the cluster, so that we
        -- inherit any of its properties.
        local n = node.copy(nodes[g.cluster + 1])
        local id = n.id
        local gid = g.codepoint

        head, current = node.insert_after(head, current, n)

        if id == glyphcode then
          local width = hbfont:get_glyph_h_advance(gid)

          n.char = hb.CH_GID_PREFIX + gid
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
            characters[hb.CH_GID_PREFIX + gid] = {
              index = gid,
              width = width,
              height = extents and extents.y_bearing or ascender,
              depth = -(extents and extents.y_bearing + extents.height or descender),
            }
            loaded[gid] = true
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
