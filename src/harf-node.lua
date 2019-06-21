local hb = require("harf-base")

local direct       = node.direct
local tonode       = direct.tonode
local todirect     = direct.todirect
local traverse     = direct.traverse
local traverseid   = direct.traverse_id
local insertbefore = direct.insert_before
local insertafter  = direct.insert_after
local protectglyph = direct.protect_glyph
local newnode      = direct.new
local copynode     = direct.copy
local removenode   = direct.remove
local copynodelist = direct.copy_list
local isglyph      = direct.is_glyph

local getattrs     = direct.getattributelist
local setattrs     = direct.setattributelist
local getchar      = direct.getchar
local setchar      = direct.setchar
local getdir       = direct.getdir
local setdir       = direct.setdir
local getdata      = direct.getdata
local setdata      = direct.setdata
local getfont      = direct.getfont
local setfont      = direct.setfont
local getfield     = direct.getfield
local setfield     = direct.setfield
local getid        = direct.getid
local getkern      = direct.getkern
local setkern      = direct.setkern
local getnext      = direct.getnext
local setnext      = direct.setnext
local getoffsets   = direct.getoffsets
local setoffsets   = direct.setoffsets
local getproperty  = direct.getproperty
local setproperty  = direct.setproperty
local getprev      = direct.getprev
local setprev      = direct.setprev
local getsubtype   = direct.getsubtype
local setsubtype   = direct.setsubtype
local getwidth     = direct.getwidth
local setwidth     = direct.setwidth

local getpre       = function (n) return getfield(n, "pre")        end
local setpre       = function (n, v)     setfield(n, "pre", v)     end
local getpost      = function (n) return getfield(n, "post")       end
local setpost      = function (n, v)     setfield(n, "post", v)    end
local getrep       = function (n) return getfield(n, "replace")    end
local setrep       = function (n, v)     setfield(n, "replace", v) end

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
local p_color       = "color"
local p_string      = "string"

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
  local props = getproperty(n)
  if not props then
    props = {}
    setproperty(n, props)
  end
  props.harf = props.harf or {}
  props.harf[prop] = value
end

-- Copy node properties and attributes.
local function copyprops(src, dst)
  local props = getproperty(src)
  local attrs = getattrs(src)
  if props then
    setproperty(dst, copytable(props))
  end
  if attrs then
    setattrs(dst, copynodelist(attrs))
  end
end

-- Convert list of integers to UTF-16 hex string used in PDF.
local function to_utf16_hex(uni)
  if uni < 0x10000 then
    return format("%04X", uni)
  else
    uni = uni - 0x10000
    local hi = 0xD800 + (uni // 0x400)
    local lo = 0xDC00 + (uni % 0x400)
    return format("%04X%04X", hi, lo)
  end
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

local process

local function itemize(head, direction)
  -- Collect character properties (font, direction, script) and resolve common
  -- and inherited scripts. Pre-requisite for itemization into smaller runs.
  local props, nodes, codes = {}, {}, {}
  local dirstack, pairstack = {}, {}
  local currdir = direction or "TLT"
  local currfontid = nil

  for n in direct.traverse(head) do
    local id = getid(n)
    local code = 0xFFFC -- OBJECT REPLACEMENT CHARACTER
    local script = sc_common
    local skip = false

    if id == glyphid then
      currfontid = getfont(n)
      if getsubtype(n) > 255 then
        skip = true
      else
        code = getchar(n)
        script = getscript(code)
      end
    elseif id == glueid and getsubtype(n) == spaceskip then
      code = 0x0020 -- SPACE
    elseif id == discid then
      code = 0x00AD -- SOFT HYPHEN
    elseif id == dirid then
      local dir = getdir(n)
      if dir:sub(1, 1) == "+" then
        -- Push the current direction to the stack.
        table.insert(dirstack, currdir)
        currdir = dir:sub(2)
      else
        assert(currdir == dir:sub(2))
        -- Pop the last direction from the stack.
        currdir = table.remove(dirstack)
      end
    elseif id == localparid then
      currdir = getdir(n)
    end

    local fontdata = currfontid and font.getfont(currfontid)
    local hbdata = fontdata and fontdata.hb
    if not hbdata then skip = true end

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

    -- If script is not resolved yet, and the font has a "script" option, use
    -- it.
    if (script == sc_common or script == sc_inherited) and hbdata then
      local spec = hbdata.spec
      local features = spec.features
      local options = spec.options
      script = options.script and hb.Script.new(options.script) or script
    end

    codes[#codes + 1] = code
    nodes[#nodes + 1] = n
    props[#props + 1] = {
      font = currfontid,
      -- XXX handle RTT and LTL.
      dir = currdir == "TRT" and dir_rtl or dir_ltr,
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

  -- Split into a list of runs, each has the same font, direction and script.
  -- TODO: itemize by language as well.
  local runs = {}
  local currfontid, currdir, currscript, currskip = nil, nil, nil, nil
  for i, prop in next, props do
    local fontid = prop.font
    local dir = prop.dir
    local script = prop.script
    local skip = prop.skip

    -- Start a new run if there is a change in properties.
    if fontid ~= currfontid or
       dir ~= currdir or
       script ~= currscript or
       skip ~= currskip then
      runs[#runs + 1] = {
        start = i,
        len = 0,
        font = fontid,
        dir = dir,
        script = script,
        skip = skip,
        nodes = nodes,
        codes = codes,
      }
    end

    runs[#runs].len = runs[#runs].len + 1

    currfontid = fontid
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
     and getid(nodes[glyph.cluster + 1]) ~= glueid
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
    if getid(nodes[i]) ~= discid then
      subnodes[#subnodes + 1] = copynode(nodes[i])
      subcodes[#subcodes + 1] = codes[i]
    end
  end
  -- Prepend any existing nodes to the list.
  for n in traverse(nodelist) do
    subnodes[#subnodes + 1] = n
    subcodes[#subcodes + 1] = getchar(n)
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

  local fontdata = font.getfont(fontid)
  local hbdata = fontdata.hb
  local palette = hbdata.palette
  local spec = hbdata.spec
  local features = spec.features
  local options = spec.options
  local hbshared = hbdata.shared
  local hbfont = hbshared.font
  local hbface = hbshared.face

  local lang = lang or options.language or lang_invalid
  local shapers = options.shaper and { options.shaper } or {}

  local buf = hb.Buffer.new()
  buf:set_direction(dir)
  buf:set_script(script)
  buf:set_language(lang)
  buf:set_cluster_level(buf.CLUSTER_LEVEL_MONOTONE_CHARACTERS)
  buf:add_codepoints(codes, offset - 1, len)

  local hscale = hbdata.hscale
  local vscale = hbdata.vscale
  hbfont:set_scale(hscale, vscale)

  if hb.shape_full(hbfont, buf, features, shapers) then
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
        local hex = ""
        local str = ""
        for j = 0, nchars - 1 do
          local id = getid(nodes[nodeindex + j])
          if id == glyphid or id == glueid then
            local code = codes[nodeindex + j]
            hex = hex..to_utf16_hex(code)
            str = str..utf8.char(code)
          end
        end
        glyph.tounicode = hex
        glyph.string = str
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

          local pre, post, rep = getpre(disc), getpost(disc), getrep(disc)
          glyph.disc = disc
          glyph.replace = makesub(run, startindex, stopindex, rep)
          glyph.pre = makesub(run, startindex, discindex - 1, pre)
          glyph.post = makesub(run, discindex + 1, stopindex, post)
        end
      end
    end
    return glyphs
  end

  return {}
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
  local fontdata = font.getfont(fontid)
  local characters = fontdata.characters
  local hbdata = fontdata.hb
  local hbshared = hbdata.shared
  local hbfont = hbshared.font
  local fontglyphs = hbshared.glyphs
  local rtl = dir:is_backward()

  local tracinglostchars = tex.tracinglostchars
  local tracingonline = tex.tracingonline

  local scale = hbdata.scale
  local letterspace = hbdata.letterspace

  local haspng = hbshared.haspng
  local fonttype = hbshared.fonttype

  for i, glyph in next, glyphs do
    local index = glyph.cluster + 1
    local gid = glyph.codepoint
    local char = hb.CH_GID_PREFIX + gid
    local n = nodes[index]
    local id = getid(n)
    local nchars, nglyphs = glyph.nchars, glyph.nglyphs

    -- If this glyph is part of a complex cluster, then copy the node as
    -- more than one glyph will use it.
    if nglyphs < 1 or nglyphs > 1 then
      n = copynode(nodes[index])
    end

    if color then
      setprop(n, p_color, color)
    end

    if glyph.disc then
      -- For discretionary the glyph itself is skipped and a discretionary node
      -- is output in place of it.
      local disc = glyph.disc
      local rep, pre, post = glyph.replace, glyph.pre, glyph.post

      setrep(disc, tonodes(nil, nil, rep.run, rep.glyphs, color))
      setpre(disc, tonodes(nil, nil, pre.run, pre.glyphs, color))
      setpost(disc, tonodes(nil, nil, post.run, post.glyphs, color))

      head, current = insertafter(head, current, disc)
    elseif not glyph.skip then
      if glyph.color then
        setprop(n, p_color, color_to_rgba(glyph.color))
      end

      if id == glyphid then
        local fontglyph = fontglyphs[gid]

        local pngblob = fontglyph.png
        if haspng and not pngblob then
          pngblob = hbfont:ot_color_glyph_get_png(gid)
          fontglyph.png = pngblob
        end
        local character = characters[char]
        if pngblob then
          -- Color bitmap font, extract the PNG data and insert it in the node
          -- list.
          local data = pngblob:get_data()
          local path = cachedpng(data)

          local image = img.node {
            filename  = path,
            width     = character.width,
            height    = character.height,
            depth     = character.depth,
          }
          head, current = insertafter(head, current, todirect(image))
        else
          if haspng and not fonttype then
            -- If this is a color bitmap font with no glyph outlines (like Noto
            -- Color Emoji) and we end up here then the glyph is not supported
            -- by the font.  LuaTeX does not now how to embed such fonts, so we
            -- don’t want them to reach the backend as it will cause a fatal
            -- error. We use `nullfont` instead.
            -- That is a hack, but I think it is good enough for now.
            setfont(n, 0)
          else
            local oldcharacter = characters[getchar(n)]
            -- If the glyph index of current font chars is the same as shaped
            -- glyph, keep the node char unchanged. Helps with primitives that
            -- take characters as input but actually work on glyphs, like
            -- `\rpcode`.
            if not oldcharacter or character.index ~= oldcharacter.index then
              setchar(n, char)
            end
          end
          local xoffset = (rtl and -glyph.x_offset or glyph.x_offset) * scale
          local yoffset = glyph.y_offset * scale
          setoffsets(n, xoffset, yoffset)
          protectglyph(n)
          head, current = insertafter(head, current, n)

          local x_advance = glyph.x_advance + letterspace
          local width = fontglyph.width
          if width ~= x_advance then
            -- LuaTeX always uses the glyph width from the font, so we need to
            -- insert a kern node if the x advance is different.
            local kern = newnode(kernid)
            setkern(kern, (x_advance - width) * scale)
            copyprops(n, kern)
            if rtl then
              head = insertbefore(head, current, kern)
            else
              head, current = insertafter(head, current, kern)
            end
          end

          -- HarfTeX will use this string when printing a glyph node e.g. in
          -- overfull messages, otherwise it will be trying to print our
          -- invalid pseudo Unicode code points.
          -- If the string is empty it means this glyph is part of a larger
          -- cluster and we don’t to print anything for it as the first glyph
          -- in the cluster will have the string of the whole cluster.
          setprop(n, p_string, glyph.string or "")

          -- Handle PDF text extraction:
          -- * Find how many characters in this cluster and how many glyphs,
          -- * If there is more than 0 characters
          --   * One glyph: one to one or one to many mapping, can be
          --     represented by font’s /ToUnicode
          --   * More than one: many to one or many to many mapping, can be
          --     represented by /ActualText spans.
          -- * If there are zero characters, then this glyph is part of complex
          --   cluster that will be covered by an /ActualText span.
          local tounicode = glyph.tounicode
          if tounicode then
            if nglyphs == 1 and not fontglyph.tounicode then
              fontglyph.tounicode = tounicode
            elseif tounicode ~= fontglyph.tounicode then
              setprop(n, p_startactual, tounicode)
              glyphs[i + nglyphs - 1].endactual = true
            end
          end
          if glyph.endactual then
            setprop(n, p_endactual, true)
          end
        end
      elseif id == glueid and getsubtype(n) == spaceskip then
        -- If the glyph advance is different from the font space, then a
        -- substitution or positioning was applied to the space glyph changing
        -- it from the default, so reset the glue using the new advance.
        -- We are intentionally not comparing with the existing glue width as
        -- spacing after the period is larger by default in TeX.
        local width = (glyph.x_advance + letterspace) * scale
        if fontdata.parameters.space ~= width then
          setwidth(n, width)
          setfield(n, "stretch", width / 2)
          setfield(n, "shrink", width / 3)
        end
        head, current = insertafter(head, current, n)
      elseif id == kernid and getsubtype(n) == italiccorrection then
        -- If this is an italic correction node and the previous node is a
        -- glyph, update its kern value with the glyph’s italic correction.
        -- I’d have expected the engine to do this, but apparently it doesn’t.
        -- May be it is checking for the italic correction before we have had
        -- loaded the glyph?
        local prevchar, prevfontid = isglyph(current)
        if prevchar > 0 then
          local prevfontdata = font.getfont(prevfontid)
          local prevcharacters = prevfontdata and prevfontdata.characters
          local italic = prevcharacters and prevcharacters[prevchar].italic
          if italic then
            setkern(n, italic)
          end
        end
        head, current = insertafter(head, current, n)
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
        if current and getid(current) == kernid and getsubtype(current) == fontkern then
          setprev(current, nil)
          setnext(current, nil)
          setfield(n, "replace", current)
          head, current = removenode(head, current)
        end
        local pre, post, rep = getpre(n), getpost(n), getrep(n)
        setfield(n, "pre", process(pre, direction))
        setfield(n, "post", process(post, direction))
        setfield(n, "replace", process(rep, direction))

        head, current = insertafter(head, current, n)
      else
        head, current = insertafter(head, current, n)
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

local function shape_run(head, current, run)
  if not run.skip then
    -- Font loaded with our loader and an HarfBuzz face is present, do our
    -- shaping.
    local fontid = run.font
    local fontdata = font.getfont(fontid)
    local options = fontdata.hb.spec.options
    local color = options and options.color and hex_to_rgba(options.color)

    local glyphs = shape(run)
    head, current = tonodes(head, current, run, glyphs, color)
  else
    -- Not shaping, insert the original node list of of this run.
    local nodes = run.nodes
    local offset = run.start
    local len = run.len
    for i = offset, offset + len - 1 do
      head, current = insertafter(head, current, nodes[i])
    end
  end

  return head, current
end

process = function(head, direction)
  local newhead, current = nil, nil
  local runs = itemize(head, direction)

  for _, run in next, runs do
    newhead, current = shape_run(newhead, current, run)
  end

  return newhead or head
end

local function process_nodes(head, groupcode, size, packtype, direction)
  local head = todirect(head)

  -- Check if any fonts are loaded by us and then process the whole node list,
  -- we will take care of skipping fonts we did not load later, otherwise
  -- return unmodified head.
  for n in traverseid(glyphid, head) do
    local fontid = getfont(n)
    local fontdata = font.getfont(fontid)
    local hbdata = fontdata and fontdata.hb
    if hbdata then
      head = process(head, direction)
      break
    end
  end

  -- Nothing to do; no glyphs or no HarfBuzz fonts.
  return tonode(head)
end

local function pdfdirect(data)
  local n = newnode("whatsit", "pdf_literal")
  setfield(n, "mode", directmode)
  setdata(n, data)
  return n
end

local function post_process(head, currentcolor)
  for n in traverse(head) do
    local props = getproperty(n)
    local harfprops = props and props.harf

    local startactual, endactual, color
    if harfprops then
      startactual = harfprops[p_startactual]
      endactual = harfprops[p_endactual]
      color = harfprops[p_color]
    end

    if currentcolor and currentcolor ~= color then
      -- Pop current color.
      head = insertbefore(head, n, pdfdirect("0 g"))
    end

    if currentcolor ~= color then
      -- Push new color.
      head = insertbefore(head, n, pdfdirect(color))
      currentcolor = color
    end

    if startactual then
      local actualtext = "/Span<</ActualText<FEFF"..startactual..">>>BDC"
      head = insertbefore(head, n, pdfdirect(actualtext))
    end

    if endactual then
      head = insertafter(head, n, pdfdirect("EMC"))
    end

    local replace = getfield(n, "replace")
    if replace then
      setfield(n, "replace", post_process(replace, currentcolor))
    end

    local subhead = getfield(n, "head")
    if subhead then
      setfield(n, "head", post_process(subhead, currentcolor))
    end
  end
  return head
end

local function post_process_nodes(head, groupcode)
  return tonode(post_process(todirect(head)))
end

local function run_cleanup()
  -- Remove temporary PNG files that we created, if any.
  for _, path in next, pngcache do
    os.remove(path)
  end
end

local function get_tounicode(fontid, c)
  local fontdata = font.getfont(fontid)
  local hbdata = fontdata.hb
  if hbdata then
    local hbshared = hbdata.shared
    local fontglyphs = hbshared.glyphs
    local hbfont = hbshared.font

    local gid = c - hb.CH_GID_PREFIX
    if c < hb.CH_GID_PREFIX then
      gid = hbfont:get_nominal_glyph(c)
    end

    return fontglyphs[gid].tounicode
  end
end

local function get_glyph_string(n)
  local n = todirect(n)
  local props = getproperty(n)
  props = props and props.harf
  return props and props[p_string] or nil
end

return {
  process = process_nodes,
  post_process = post_process_nodes,
  cleanup = run_cleanup,
  get_tounicode = get_tounicode,
  get_glyph_string = get_glyph_string,
}
