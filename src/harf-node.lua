local hb = require("harf-base")

local discid     = node.id("disc")
local glueid     = node.id("glue")
local glyphid    = node.id("glyph")
local dirid      = node.id("dir")
local kernid     = node.id("kern")
local localparid = node.id("local_par")

local spaceskip        = 13
local directmode       = 2
local fontkern         = 0
local italiccorrection = 3

local getscript    = hb.unicode.script
local sc_common    = hb.Script.new("Zyyy")
local sc_inherited = hb.Script.new("Zinh")
local sc_unknown   = hb.Script.new("Zzzz")
local sc_latn      = hb.Script.new("Latn")
local dir_ltr      = hb.Direction.new("ltr")
local dir_rtl      = hb.Direction.new("rtl")
local lang_invalid = hb.Language.new()
local fl_unsafe    = hb.Buffer.GLYPH_FLAG_UNSAFE_TO_BREAK

local p_startactual = "startactualtext"
local p_endactual   = "endactualtext"

local format = string.format

-- Simple table copying function.
local function copytable(old)
  local new = {}
  for k, v in next, old do
    if type(v) == "table" then v = copytable(v) end
    new[k] = v
  end
  return new
end

-- Set and get properties from our private `harf` subtable.
local function setprop(n, prop, value)
  local props = node.getproperty(n)
  if not props then
    props = {}
    node.setproperty(n, props)
  end
  props.harf = props.harf or {}
  props.harf[prop] = value
end

local function getprop(n, prop, value)
  local p = node.getproperty(n)
  local h = p and p.harf
  return h and h[prop]
end

-- Copy node properties and attributes.
local function copyprops(src, dst)
  local props = node.getproperty(src)
  local attrs = src.attr
  if props then
    node.setproperty(dst, copytable(props))
  end
  if attrs then
    dst.attr = node.copy_list(attrs)
  end
end

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
  local props = {}
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
    local skip = false

    if id == glyphid then
      if n.subtype > 255 then skip = true end
      code = n.char
      currfont = n.font
      script = getscript(code)
    elseif id == glueid and n.subtype == spaceskip then
      code = 0x0020 -- SPACE
    elseif id == discid then
      code = 0x00AD -- SOFT HYPHEN
    elseif id == dirid then
      if n.dir:sub(1, 1) == "+" then
        -- Push the current direction to the stack.
        table.insert(dirstack, currdir)
        currdir = n.dir:sub(2)
      else
        assert(currdir == n.dir:sub(2))
        -- Pop the last direction from the stack.
        currdir = table.remove(dirstack)
      end
    elseif id == localparid then
      currdir = n.dir
    end

    local fontdata = currfont and font.fonts[currfont]
    if not (fontdata and fontdata.hb) then skip = true end

    -- Resolve common and inherited scripts. Inherited takes the script of the
    -- previous character. Common almost the same, but we tray to make paired
    -- characters (e.g. parentheses) to take the same script.
    if #props > 0 and (script == sc_common or script == sc_inherited) then
      script = props[#props].script
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
    nodes[#nodes + 1] = n
    props[#props + 1] = {
      font = currfont,
      dir = to_hb_dir[currdir],
      script = script,
      skip = skip,
    }
  end

  for i = #props - 1, 1, -1 do
    -- If script is not resolved yet, use that of the next character.
    if props[i].script == sc_common or props[i].script == sc_inherited then
      props[i].script = props[i + 1].script
    end
  end

  return props, nodes, codes
end

-- Split into a list of runs, each has the same font, direction and script.
-- TODO: itemize by language as well.
local function itemize(props, nodes, codes)
  local runs = {}
  local currfont, currdir, currscript, currskip = nil, nil, nil, nil
  for i, prop in next, props do
    local font = prop.font
    local dir = prop.dir
    local script = prop.script
    local skip = prop.skip

    -- Start a new run if there is a change in properties.
    if font ~= currfont or
       dir ~= currdir or
       script ~= currscript or
       skip ~= currskip then
      runs[#runs + 1] = {
        start = i,
        len = 0,
        font = font,
        dir = dir,
        script = script,
        skip = skip,
        nodes = nodes,
        codes = codes,
      }
    end

    runs[#runs].len = runs[#runs].len + 1

    currfont = font
    currdir = dir
    currscript = script
    currskip = skip
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
     and nodes[glyph.cluster + 1].id ~= glueid
end

local shape

-- Make s a sub run, used by discretionary nodes.
local function makesub(run, start, stop, nodelist)
  local nodes = run.nodes
  local codes = run.codes
  local start = start
  local stop = stop
  local subnodes, subcodes = {}, {}
  for i = start, stop do
    if nodes[i].id ~= discid then
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
    nodes = subnodes,
    codes = subcodes,
  }
  return { glyphs = shape(subrun), run = subrun }
end

-- Main shaping function that calls HarfBuzz, and does some post-processing of
-- the output.
shape = function(run)
  local nodes = run.nodes
  local codes = run.codes
  local offset = run.start
  local len = run.len
  local fontid = run.font
  local dir = run.dir
  local script = run.script
  local lang = run.lang
  local fordisc = run.fordisc

  local fontdata = font.fonts[fontid]
  local hbdata = fontdata.hb
  local hbshared = hbdata.shared
  local hbfont = hbshared.font
  local hbface = hbshared.face
  local features = hbdata.spec.features
  local palette = hbdata.palette

  local lang = lang or hbdata.spec.options.language or lang_invalid

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

    -- If the font has COLR/CPAL tables, decompose each glyph to its color
    -- layers and set the color from the palette.
    if palette then
      for i, glyph in next, glyphs do
        local gid = glyph.codepoint
        local layers = hbface:ot_color_glyph_get_layers(gid)
        if layers then
          -- Remove this glyph, we will use its layers.
          table.remove(glyphs, i)
          for j, layer in next, layers do
            -- All glyphs but the last use 0 advance so that the layers
            -- overlap.
            local xadavance, yadvance = nil, nil
            if dir:is_backward() then
              x_advance = j == 1 and glyph.x_advance or 0
              y_advance = j == 1 and glyph.y_advance or 0
            else
              x_advance = j == #layers and glyph.x_advance or 0
              y_advance = j == #layers and glyph.y_advance or 0
            end
            table.insert(glyphs, i + j - 1, {
              codepoint = layer.glyph,
              cluster = glyph.cluster,
              x_advance = x_advance,
              y_advance = y_advance,
              x_offset = glyph.x_offset,
              y_offset = glyph.y_offset,
              flags = glyph.flags,
              -- color_index has a special value, 0x10000, that mean use text
              -- color, we don’t check for it here explicitly since we will
              -- get nil anyway.
              color = palette[layer.color_index],
            })
          end
        end
      end
    end

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
          if id == glyphid or id == glueid then
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
          glyph.replace = makesub(run, startindex, stopindex, disc.replace)
          glyph.pre = makesub(run, startindex, discindex - 1, disc.pre)
          glyph.post = makesub(run, discindex + 1, stopindex, disc.post)
        end
      end
    end
    return glyphs
  end

  return {}
end

local function pdfdirect(data)
  local n = node.new("whatsit", "pdf_literal")
  n.mode = directmode
  n.data = data
  return n
end

local function color_to_rgba(color)
  local r = color.red   / 255
  local g = color.green / 255
  local b = color.blue  / 255
  local a = color.alpha / 255
  if a ~= 1 then
    -- XXX: alpha
    return format('%s %s %s rg', r, g, b)
  else
    return format('%s %s %s rg', r, g, b)
  end
end

-- Cache of color glyph PNG data for bookkeeping, only because I couldn’t
-- figure how to make LuaTeX load the image from the binary data directly.
local pngcache = {}
local function cachedpng(data)
  local hash = md5.sumhexa(data)
  local path = pngcache[hash]
  if not path then
    path = os.tmpname()
    local file = io.open(path, "wb")
    file:write(data)
    file:close()
    pngcache[hash] = path
  end
  return path
end

-- Convert glyphs to nodes and collect font characters.
local function tonodes(head, current, run, glyphs, color)
  local nodes = run.nodes
  local dir = run.dir
  local fontid = run.font
  local fontdata = font.fonts[fontid]
  local characters = fontdata.characters
  local hbdata = fontdata.hb
  local hbshared = hbdata.shared
  local hbfont = hbshared.font
  local hbglyphs = hbshared.glyphs
  local rtl = dir:is_backward()

  local tracinglostchars = tex.tracinglostchars
  local tracingonline = tex.tracingonline

  local scale = hbdata.scale
  local ascender = hbshared.ascender
  local descender = hbshared.descender

  local haspng = hbshared.haspng
  local fonttype = hbshared.fonttype

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

    if color then
      setprop(n, "color", color)
    end

    if glyph.disc then
      -- For discretionary the glyph itself is skipped and a discretionary node
      -- is output in place of it.
      local disc = glyph.disc
      local replace = glyph.replace
      local pre = glyph.pre
      local post = glyph.post

      disc.replace = tonodes(nil, nil, replace.run, replace.glyphs, color)
      disc.pre = tonodes(nil, nil, pre.run, pre.glyphs, color)
      disc.post = tonodes(nil, nil, post.run, post.glyphs, color)

      head, current = node.insert_after(head, current, disc)
    elseif not glyph.skip then
      if glyph.color then
        setprop(n, "color", color_to_rgba(glyph.color))
      end

      if id == glyphid then
        local hbglyph = hbglyphs[gid]

        -- Report missing characters, trying to emulate the engine behaviour as
        -- much as possible.
        if gid == 0 and tracinglostchars > 0 then
          local code = n.char
          local target = "log"
          local msg = format("Missing character: There is no %s (U+%04X) in "..
                             "font %s!", utf8.char(code), code, fontdata.name)
          if tracinglostchars > 1 or tracingonline > 0 then
            target = "term and log"
          end
          texio.write_nl(target, msg)
          texio.write_nl(target, "")
        end

        local pngblob = hbglyph.png
        if haspng and not pngblob then
          pngblob = hbfont:ot_color_glyph_get_png(gid)
          hbglyph.png = pngblob
        end
        if pngblob then
          -- Color bitmap font, extract the PNG data and insert it in the node
          -- list.
          local data = pngblob:get_data()
          local path = cachedpng(data)
          local character = characters[char]

          local image = img.node {
            filename  = path,
            width     = character.width,
            height    = character.height,
            depth     = character.depth,
          }
          head, current = node.insert_after(head, current, image)
        else
          if haspng and not fonttype then
            -- If this is a color bitmap font with no glyph outlines (like Noto
            -- Color Emoji) and we end up here then the glyph is not supported
            -- by the font.  LuaTeX does not now how to embed such fonts, so we
            -- don’t want them to reach the backend as it will cause a fatal
            -- error. We use `nullfont` instead.
            -- That is a hack, but I think it is good enough for now.
            n.font = 0
          else
            n.char = char
          end
          n.xoffset = (rtl and -glyph.x_offset or glyph.x_offset) * scale
          n.yoffset = glyph.y_offset * scale
          node.protect_glyph(n)
          head, current = node.insert_after(head, current, n)

          local width = hbglyph.width
          if width ~= glyph.x_advance then
            -- LuaTeX always uses the glyph width from the font, so we need to
            -- insert a kern node if the x advance is different.
            local kern = node.new(kernid)
            kern.kern = (glyph.x_advance - width) * scale
            copyprops(n, kern)
            if rtl then
              head = node.insert_before(head, current, kern)
            else
              head, current = node.insert_after(head, current, kern)
            end
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
            if nglyphs == 1 and not hbglyph.tounicode then
              hbglyph.tounicode = tounicode
            elseif tounicode ~= hbglyph.tounicode then
              setprop(current, p_startactual, tounicode)
              glyphs[i + nglyphs - 1].endactual = true
            end
          end
          if glyph.endactual then
            setprop(current, p_endactual, true)
          end
        end
      elseif id == glueid and n.subtype == spaceskip then
        if n.width ~= (glyph.x_advance * scale) then
          n.width = glyph.x_advance * scale
        end
        head, current = node.insert_after(head, current, n)
      elseif id == kernid and n.subtype == italiccorrection then
        -- If this is an italic correction node and the previous node is a
        -- glyph, update its kern value with the glyph’s italic correction.
        -- I’d have expected the engine to do this, but apparently it doesn’t.
        -- May be it is checking for the italic correction before we have had
        -- loaded the glyph?
        local prevchar, prevfontid = node.is_glyph(current)
        if prevchar > 0 then
          local italic = font.fonts[prevfontid].characters[prevchar].italic
          if italic then
            n.kern = italic
          end
        end
        head, current = node.insert_after(head, current, n)
      elseif id == discid then
        assert(nglyphs == 1)
        -- The simple case of a discretionary that is not part of a complex
        -- cluster. We only need to make sure kerning before the hyphenation
        -- point is dropped when a line break is inserted here.
        --
        -- TODO: nothing as simple as it sounds, we need to handle this like
        -- the other discretionary handling, otherwise the discretionary
        -- contents do not interact with the surrounding (e.g. no ligatures or
        -- kerning) as it should.
        if current and current.id == kernid and current.subtype == fontkern then
          current.prev, current.next = nil, nil
          n.replace = current
          head, current = node.remove(head, current)
        end
        n.pre = process(n.pre, direction)
        n.post = process(n.post, direction)
        n.replace = process(n.replace, direction)

        head, current = node.insert_after(head, current, n)
      else
        head, current = node.insert_after(head, current, n)
      end
    end
  end

  return head, current
end

local function validate_color(s)
  local r = tonumber(s:sub(1, 2), 16)
  local g = tonumber(s:sub(3, 4), 16)
  local b = tonumber(s:sub(5, 6), 16)
  if not (r and g and b) then return end
  if #s == 8 then
    local a = tonumber(s:sub(7, 8), 16)
    if not a then return end
  end
  return s
end

local function hex_to_rgba(s)
  if not validate_color(s) then return end
  local r = tonumber(s:sub(1, 2), 16) / 255
  local g = tonumber(s:sub(3, 4), 16) / 255
  local b = tonumber(s:sub(5, 6), 16) / 255
  if #s == 8 then
    local a = tonumber(s:sub(7, 8), 16) / 255
    -- XXX: alpha
    return format('%s %s %s rg', r, g, b)
  else
    return format('%s %s %s rg', r, g, b)
  end
end

local function update_font_tounicode(fontid)
  local fontdata = font.fonts[fontid]
  local characters = fontdata.characters
  local glyphs = fontdata.hb.shared.glyphs

  local new = {}
  local needsupdate = false
  for gid, glyph in next, glyphs do
    local char = gid + hb.CH_GID_PREFIX
    local character = characters[char]
    if not character.tounicode and glyph.tounicode then
      character.tounicode = glyph.tounicode
      new[char] = character
      needsupdate = true
    end
  end
  if needsupdate then
    font.addcharacters(fontid, { nomath = true, characters = new })
  end
end

local function shape_run(head, current, run)
  if not run.skip then
    -- Font loaded with our loader and an HarfBuzz face is present, do our
    -- shaping.
    local fontid = run.font
    local options = font.fonts[fontid].hb.spec.options
    local color = options and options.color and hex_to_rgba(options.color)

    local glyphs = shape(run)
    head, current = tonodes(head, current, run, glyphs, color)

    update_font_tounicode(fontid)
  else
    -- Not shaping, insert the original node list of of this run.
    local nodes = run.nodes
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
  local props, nodes, codes = collect(head, direction)
  local runs = itemize(props, nodes, codes)

  for _, run in next, runs do
    newhead, current = shape_run(newhead, current, run)
  end

  return newhead or head
end

local function process_nodes(head, groupcode, size, packtype, direction)
  local fonts = font and font.fonts or {}

  -- Check if any fonts are loaded by us and then process the whole node list,
  -- we will take care of skipping fonts we did not load later, otherwise
  -- return unmodified head.
  for n in node.traverse_id(glyphid, head) do
    if fonts[n.font] and fonts[n.font].hb ~= nil then
      return process(head, direction)
    end
  end

  -- Nothing to do; no glyphs or no HarfBuzz fonts.
  return head
end

local function post_process_nodes(head, groupcode, size, packtype, maxdepth, direction, currentcolor)
  for n in node.traverse(head) do
    local startactual = getprop(n, p_startactual)
    local endactual = getprop(n, p_endactual)
    local color = getprop(n, "color")

    if currentcolor and currentcolor ~= color then
      -- Pop current color.
      head = node.insert_before(head, n, pdfdirect("0 g"))
    end

    if startactual then
      local actualtext = "/Span<</ActualText<FEFF"..startactual..">>>BDC"
      head = node.insert_before(head, n, pdfdirect(actualtext))
    end

    if endactual then
      head = node.insert_after(head, n, pdfdirect("EMC"))
    end

    if currentcolor ~= color then
      -- Push new color.
      head = node.insert_before(head, n, pdfdirect(color))
      currentcolor = color
    end

    if n.head then
      post_process_nodes(n.head, currentcolor)
    end
  end
  return head
end

local function run_cleanup()
  -- Remove temporary PNG files that we created, if any.
  for _, path in next, pngcache do
    os.remove(path)
  end
end

return {
  process = process_nodes,
  post_process = post_process_nodes,
  cleanup = run_cleanup,
}
