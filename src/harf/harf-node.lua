local hb = require("harf-base")

local assert            = assert
local next              = next
local tonumber          = tonumber
local type              = type
local format            = string.format
local open              = io.open
local tableinsert       = table.insert
local tableremove       = table.remove
local ostmpname         = os.tmpname
local osremove          = os.remove

local direct            = node.direct
local tonode            = direct.tonode
local todirect          = direct.todirect
local traverse          = direct.traverse
local insertbefore      = direct.insert_before
local insertafter       = direct.insert_after
local protectglyph      = direct.protect_glyph
local newnode           = direct.new
local copynode          = direct.copy
local removenode        = direct.remove
local copynodelist      = direct.copy_list
local isglyph           = direct.is_glyph

local getattrs          = direct.getattributelist
local setattrs          = direct.setattributelist
local getchar           = direct.getchar
local setchar           = direct.setchar
local getdir            = direct.getdir
local setdir            = direct.setdir
local getdisc           = direct.getdisc
local setdisc           = direct.setdisc
local getfont           = direct.getfont
local getdata           = direct.getdata
local setdata           = direct.setdata
local getfont           = direct.getfont
local setfont           = direct.setfont
local getfield          = direct.getfield
local setfield          = direct.setfield
local getid             = direct.getid
local getkern           = direct.getkern
local setkern           = direct.setkern
local getnext           = direct.getnext
local setnext           = direct.setnext
local getoffsets        = direct.getoffsets
local setoffsets        = direct.setoffsets
local getproperty       = direct.getproperty
local setproperty       = direct.setproperty
local getprev           = direct.getprev
local setprev           = direct.setprev
local getsubtype        = direct.getsubtype
local setsubtype        = direct.setsubtype
local getwidth          = direct.getwidth
local setwidth          = direct.setwidth
local is_char           = direct.is_char
local tail              = direct.tail

local imgnode           = img.node

local disc_t            = node.id("disc")
local glue_t            = node.id("glue")
local glyph_t           = node.id("glyph")
local dir_t             = node.id("dir")
local kern_t            = node.id("kern")
local localpar_t        = node.id("local_par")
local whatsit_t         = node.id("whatsit")
local pdfliteral_t      = node.subtype("pdf_literal")
local pdfcolorstack_t   = node.subtype("pdf_colorstack")

local explicitdisc_t    = 1
local fontkern_t        = 0
local italiccorr_t      = 3
local regulardisc_t     = 3
local spaceskip_t       = 13

local invalid_l         = hb.Language.new()
local invalid_s         = hb.Script.new()

local dir_ltr           = hb.Direction.new("ltr")
local dir_rtl           = hb.Direction.new("rtl")
local fl_unsafe         = hb.Buffer.GLYPH_FLAG_UNSAFE_TO_BREAK

local startactual_p     = "startactualtext"
local endactual_p       = "endactualtext"
local color_p           = "color"
local string_p          = "string"

-- Simple table copying function.
local function copytable(old)
  local new = {}
  for k, v in next, old do
    if type(v) == "table" then v = copytable(v) end
    new[k] = v
  end
  setmetatable(new, getmetatable(old))
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

local function inherit(t, base, properties)
  local n = newnode(t)
  setattrs(n, getattrs(base))
  setproperty(n, properties and copytable(properties))
  return n
end
-- New kern node of amount `v`, inheriting the properties/attributes of `n`.
local function newkern(v, n)
  local kern = inherit(kern_t, n, getproperty(n))
  setkern(kern, v)
  return kern
end

local function insertkern(head, current, kern, rtl)
  if rtl then
    head = insertbefore(head, current, kern)
  else
    head, current = insertafter(head, current, kern)
  end
  return head, current
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

local process

local trep = hb.texrep

local function itemize(head, fontid, direction)
  local fontdata = font.getfont(fontid)
  local hbdata   = fontdata and fontdata.hb
  local spec     = fontdata and fontdata.specification
  local options  = spec and spec.features.raw
  local texlig   = options and options.tlig

  local runs, codes = {}, {}
  local dirstack = {}
  local currdir = direction or "TLT"
  local lastdir, lastskip, lastrun

  for n, id, subtype in direct.traverse(head) do
    local code = 0xFFFC -- OBJECT REPLACEMENT CHARACTER
    local skip = false

    if id == glyph_t then
      if is_char(n) and getfont(n) == fontid then
        code = getchar(n)
      else
        skip = true
      end
    elseif id == glue_t and subtype == spaceskip_t then
      code = 0x0020 -- SPACE
    elseif id == disc_t -- FIXME
      and (subtype == explicitdisc_t  -- \-
        or subtype == regulardisc_t)  -- \discretionary
    then
      code = 0x00AD -- SOFT HYPHEN
    elseif id == dir_t then
      local dir = getdir(n)
      if dir:sub(1, 1) == "+" then
        -- Push the current direction to the stack.
        tableinsert(dirstack, currdir)
        currdir = dir:sub(2)
      else
        assert(currdir == dir:sub(2))
        -- Pop the last direction from the stack.
        currdir = tableremove(dirstack)
      end
    elseif id == localpar_t then
      currdir = getdir(n)
    end

    if not skip and texlig then
      local replacement = trep[code]
      if replacement then
        code = replacement
      end
    end

    codes[#codes + 1] = code

    if lastdir ~= currdir or lastskip ~= skip then
      lastrun = {
        start = #codes,
        len = 1,
        font = fontid,
        dir = currdir == "TRT" and dir_rtl or dir_ltr,
        skip = skip,
        codes = codes,
      }
      runs[#runs + 1] = lastrun
      lastdir, lastskip = currdir, skip
    else
      lastrun.len = lastrun.len + 1
    end
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

-- Check if it is not safe to break before this glyph.
local function unsafetobreak(glyph)
  return glyph
     and glyph.flags
     and glyph.flags & fl_unsafe
end

local shape

-- Make s a sub run, used by discretionary nodes.
local function makesub(run, codes, nodelist)
  local codes = run.codes
  local subrun = {
    start = 1,
    len = #codes,
    font = run.font,
    dir = run.dir,
    fordisc = true,
    node = nodelist,
    codes = codes,
  }
  table.print(subrun)
  for n in traverse(nodelist) do
    print(tonode(n))
  end
  local glyphs
  nodelist, glyphs = shape(nodelist, nodelist, subrun)
  return { glyphs = glyphs, run = subrun, head = nodelist }
end

local function printnodes(label, head)
  for n in node.traverse(tonode(head)) do
    print(label, n, n.char)
  end
end
-- Main shaping function that calls HarfBuzz, and does some post-processing of
-- the output.
shape = function(head, node, run)
  local codes = run.codes
  local offset = run.start
  local len = run.len
  local fontid = run.font
  local dir = run.dir
  local fordisc = run.fordisc
  local cluster = offset - 2

  local fontdata = font.getfont(fontid)
  local hbdata = fontdata.hb
  local palette = hbdata.palette
  local spec = hbdata.spec
  local features = spec.hb_features
  local options = spec.features.raw
  local hbshared = hbdata.shared
  local hbfont = hbshared.font
  local hbface = hbshared.face

  local lang = options.language or invalid_l
  local script = options.script or invalid_s
  local shapers = options.shaper and { options.shaper } or {}

  local buf = hb.Buffer.new()
  buf:set_direction(dir)
  buf:set_script(script)
  buf:set_language(lang)
  buf:set_cluster_level(buf.CLUSTER_LEVEL_MONOTONE_CHARACTERS)
  for n in traverse(node) do
    print(tonode(n))
  end
  -- table.print{codes, offset-1, len}
  buf:add_codepoints(codes, offset - 1, len)

  local hscale = hbdata.hscale
  local vscale = hbdata.vscale
  hbfont:set_scale(hscale, vscale)

  if hb.shape_full(hbfont, buf, features, shapers) then
    -- The engine wants the glyphs in logical order, but HarfBuzz outputs them
    -- in visual order, so we reverse RTL buffers.
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
          tableremove(glyphs, i)
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
            tableinsert(glyphs, i + j - 1, {
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

    table.print(codes)
    -- table.print(glyphs)
    for i, glyph in next, glyphs do
      local nodeindex = glyph.cluster + 1
      local nchars, nglyphs = chars_in_glyph(i, glyphs, offset + len)
      glyph.nchars, glyph.nglyphs = nchars, nglyphs

      -- Calculate the Unicode code points of this glyph. If cluster did not
      -- change then this is a glyph inside a complex cluster and will be
      -- handled with the start of its cluster.
      if cluster ~= glyph.cluster then
        cluster = glyph.cluster
        local hex = ""
        local str = ""
        local nextcluster
        for j = i+1, #glyphs do
          nextcluster = glyphs[j].cluster
          if cluster ~= nextcluster then
            goto NEXTCLUSTERFOUND -- break
          end
        end -- else -- only executed if the loop reached the end without
                    -- finding another cluster
          nextcluster = offset + len - 1
        ::NEXTCLUSTERFOUND:: -- end
        do
          local node = node
          for j = cluster,nextcluster-1 do
            local id = getid(node)
            if id == glyph_t or id == glue_t then
              local code = codes[j + 1]
              hex = hex..to_utf16_hex(code)
              str = str..utf8.char(code)
            end
          end
          glyph.tounicode = hex
          glyph.string = str
        end
        -- Find if we have a discretionary inside a ligature, if the cluster
        -- only spans one char than two then either this is not a ligature or
        -- there is no discretionary involved.
        if nextcluster > cluster + 1 and not fordisc then
          local discindex = nil
          local disc = node
          for j = cluster + 1, nextcluster do
            if codes[j] == 0x00AD then
              discindex = j
              break
            end
            disc = getnext(disc)
          end
          if discindex then
            -- Discretionary found.
            local startindex, stopindex = nil, nil
            local startglyph, stopglyph = nil, nil

            -- Find the previous glyph that is safe to break at.
            local startglyph = i
            while unsafetobreak(glyphs[startglyph])
                  and getid(startnode) ~= glue_t do
              startglyph = startglyph - 1
            end
            -- Get the corresponding character index.
            startindex = glyphs[startglyph].cluster + 1

            -- Find the next glyph that is safe to break at.
            stopglyph = i + 1
            local lastcluster = glyphs[i].cluster
            while unsafetobreak(glyphs[stopglyph])
                  or lastcluster == glyphs[stopglyph].cluster
                  and getid(stopnode) ~= glue_t do
              lastcluster = glyphs[stopglyph].cluster
              stopglyph = stopglyph + 1
            end
            -- We also want the last char in the previous glyph, so no +1 below.
            stopindex = glyphs[stopglyph].cluster

            local startnode, stopnode = node, node
            for j=cluster, startindex, -1 do
              startnode = getprev(startnode)
            end
            for j=cluster + 1, stopindex do
              stopnode = getnext(stopnode)
            end

            -- Mark these glyph for skipping since they will be replaced by the
            -- discretionary fields.
            -- We break up to stop glyph but not including it, so the -1 below.
            for j = startglyph, stopglyph - 1 do
              glyphs[j].skip = true
            end

            local subcodes, subindex = {}
            do
              local node = startnode
              while node ~= stopnode do
                print(node, stopnode, tonode(node))
                if getid(node) == disc_t and node ~= disc then
                  print'.1'
                  local oldnode = node
                  startnode, node = remove(startnode, node)
                  free(oldnode)
                  tableremove(codes, startindex)
                elseif node == disc then
                  print'.2'
                  subindex = #subcodes
                  tableremove(codes, startindex)
                  node = getnext(node)
                else
                  print'.3'
                  subcodes[#subcodes + 1] = tableremove(codes, startindex)
                  node = getnext(node)
                end
              end
              table.print{subcodes = subcodes, subindex}
            end
            
            local pre, post, rep, lastpre, lastpost, lastrep = getdisc(disc, true)
            local precodes, postcodes, repcodes = {}, {}, {}
            table.move(subcodes, 1, subindex, 1, repcodes)
            for n, id, subtype in traverse(rep) do
              repcodes[#repcodes + 1] = id == glyph_t and getchar(n) or 0xFFFC
            end
            table.move(subcodes, subindex + 1, #subcodes, #repcodes + 1, repcodes)
            table.move(subcodes, 1, subindex, 1, precodes)
            for n, id, subtype in traverse(pre) do
              precodes[#precodes + 1] = id == glyph_t and getchar(n) or 0xFFFC
            end
            for n, id, subtype in traverse(post) do
              postcodes[#postcodes + 1] = id == glyph_t and getchar(n) or 0xFFFC
            end
            table.move(subcodes, subindex + 1, #subcodes, #postcodes + 1, postcodes)
            table.print{repcodes, precodes, postcodes}
            do local newpre = copynodelist(startnode, disc)
               setnext(tail(newpre), pre)
               pre = newpre end
            printnodes('PRE', pre)
            if post then
              setnext(lastpost, copynodelist(getnext(disc), stopnode))
            else
              post = copynodelist(getnext(disc), stopnode)
            end
            printnodes('POST', post)
            printnodes('HEAD', head)
            printnodes('REP', rep)
            if startnode ~= disc then
              local predisc = getprev(disc)
              setnext(predisc, rep)
              setprev(rep, predisc)
              if startnode == head then
                head = disc
              else
                local before = getprev(startnode)
                setnext(before, disc)
                setprev(disc, before)
              end
              setprev(startnode, nil)
              rep = startnode
              lastrep = lastrep or predisc
            end
            printnodes('HEAD', head)
            printnodes('REP', rep)
            if getnext(disc) ~= stopnode then
              setnext(getprev(stopnode), nil)
              setprev(stopnode, disc)
              setprev(getnext(disc), lastrep)
              setnext(lastrep, getnext(disc))
              rep = rep or getnext(disc)
              setnext(disc, stopnode)
              print(disc, stopnode)
            end
            printnodes('HEAD', head)
            printnodes('REP', rep)
            glyph.replace = makesub(run, repcodes, rep)
            glyph.pre = makesub(run, precodes, pre)
            glyph.post = makesub(run, postcodes, post)
          end
        end
      end
      node = getnext(node)
    end
    return head, glyphs
  end

  return head, {}
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
-- figure how to make the engine load the image from the binary data directly.
local pngcache = {}
local function cachedpng(data)
  local hash = md5.sumhexa(data)
  local path = pngcache[hash]
  if not path then
    path = ostmpname()
    local file = open(path, "wb")
    file:write(data)
    file:close()
    pngcache[hash] = path
  end
  return path
end

-- Convert glyphs to nodes and collect font characters.
local function tonodes(head, node, run, glyphs, color)
  local nodeindex = run.start - 1
  local dir = run.dir
  local fontid = run.font
  local fontdata = font.getfont(fontid)
  local characters = fontdata.characters
  local hbdata = fontdata.hb
  local hbshared = hbdata.shared
  local nominals = hbshared.nominals
  local hbfont = hbshared.font
  local fontglyphs = hbshared.glyphs
  local rtl = dir:is_backward()
  local lastprops

  local scale = hbdata.scale
  local letterspace = hbdata.letterspace

  local haspng = hbshared.haspng
  local fonttype = hbshared.fonttype

  for i, glyph in ipairs(glyphs) do
    if glyph.cluster < nodeindex then -- Ups, we went too far
      nodeindex = nodeindex - 1
      local new = inherit(glyph_t, getprev(node), lastprops)
      setfont(new, fontid)
      head, node = insertbefore(head, node, new)
    else
      for j = nodeindex, glyph.cluster - 1 do
        head, node = removenode(head, node)
      end
      lastprops = getproperty(node)
      nodeindex = glyph.cluster
    end
    local gid = glyph.codepoint
    local char = nominals[gid] or hb.CH_GID_PREFIX + gid
    local id = getid(node)
    local nchars, nglyphs = glyph.nchars, glyph.nglyphs

    if color then
      setprop(node, color_p, color)
    end

    if glyph.replace then
      -- For discretionary the glyph itself is skipped and a discretionary node
      -- is output in place of it.
      local rep, pre, post = glyph.replace, glyph.pre, glyph.post

      setdisc(node, tonodes(pre.head, pre.head, pre.run, pre.glyphs, color),
                    tonodes(post.head, post.head, post.run, post.glyphs, color),
                    tonodes(rep.head, rep.head, rep.run, rep.glyphs, color))
    elseif not glyph.skip then
      if glyph.color then
        setprop(node, color_p, color_to_rgba(glyph.color))
      end

      if id == glyph_t then
        local fontglyph = fontglyphs[gid]

        local pngblob = fontglyph.png -- FIXME: Rewrite
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

          local image = imgnode {
            filename  = path,
            width     = character.width,
            height    = character.height,
            depth     = character.depth,
          }
          if fonttype then
            -- Color bitmap font with glyph outlines. Insert negative kerning
            -- as we will insert the glyph node below (to help with text
            -- copying) and want the bitmap and the glyph to take the same
            -- advance width.
            local kern = newkern(-character.width, node)
            head, node = insertkern(head, node, kern, rtl)
          end
        end
        if pngblob and not fonttype then
          -- Color bitmap font with no glyph outlines, and has a bitmap for
          -- this glyph. No further work is needed.
        elseif haspng and not fonttype then
          -- Color bitmap font with no glyph outlines (like Noto
          -- Color Emoji) but has no bitmap for current glyph (most likely
          -- `.notdef` glyph). The engine does not know how to embed such
          -- fonts, so we don’t want them to reach the backend as it will cause
          -- a fatal error. We use `nullfont` instead.  That is a hack, but I
          -- think it is good enough for now.
          -- We insert the glyph node and move on, no further work is needed.
          setfont(node, 0)
          head, current = insertafter(head, current, node)
        else
          local oldcharacter = characters[getchar(node)]
          -- If the glyph index of current font character is the same as shaped
          -- glyph, keep the node char unchanged. Helps with primitives that
          -- take characters as input but actually work on glyphs, like
          -- `\rpcode`.
          if not oldcharacter or character.index ~= oldcharacter.index then
            setchar(node, char)
          end
          local xoffset = (rtl and -glyph.x_offset or glyph.x_offset) * scale
          local yoffset = glyph.y_offset * scale
          setoffsets(node, xoffset, yoffset)

          fontglyph.used = true

          -- The engine will use this string when printing a glyph node e.g. in
          -- overfull messages, otherwise it will be trying to print our
          -- invalid pseudo Unicode code points.
          -- If the string is empty it means this glyph is part of a larger
          -- cluster and we don’t to print anything for it as the first glyph
          -- in the cluster will have the string of the whole cluster.
          setprop(node, string_p, glyph.string or "")

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
              setprop(node, startactual_p, tounicode)
              glyphs[i + nglyphs - 1].endactual = true
            end
          end
          if glyph.endactual then
            setprop(node, endactual_p, true)
          end
          local x_advance = glyph.x_advance + letterspace
          local width = fontglyph.width
          if width ~= x_advance then
            -- The engine always uses the glyph width from the font, so we need
            -- to insert a kern node if the x advance is different.
            local kern = newkern((x_advance - width) * scale, node)
            head, node = insertkern(head, node, kern, rtl)
          end
        end
      elseif id == glue_t and getsubtype(node) == spaceskip_t then
        -- If the glyph advance is different from the font space, then a
        -- substitution or positioning was applied to the space glyph changing
        -- it from the default, so reset the glue using the new advance.
        -- We are intentionally not comparing with the existing glue width as
        -- spacing after the period is larger by default in TeX.
        local width = (glyph.x_advance + letterspace) * scale
        if fontdata.parameters.space ~= width then
          setwidth(node, width)
          setfield(node, "stretch", width / 2)
          setfield(node, "shrink", width / 3)
        end
      elseif id == kern_t and getsubtype(node) == italiccorr_t then
        -- If this is an italic correction node and the previous node is a
        -- glyph, update its kern value with the glyph’s italic correction.
        -- FIXME: This fails if the previous glyph was e.g. a png glyph
        local prevchar, prevfontid = ischar(getprev(node))
        if prevfontid == fontid and prevchar and prevchar > 0 then
          local italic = characters[prevchar].italic
          if italic then
            setkern(node, italic)
          end
        end
      elseif id == disc_t then
        assert(false, "Should be unreachable") -- This feels like it should be unreachable
        assert(nglyphs == 1)
        -- The simple case of a discretionary that is not part of a complex
        -- cluster. We only need to make sure kerning before the hyphenation
        -- point is dropped when a line break is inserted here.
        --
        -- TODO: nothing as simple as it sounds, we need to handle this like
        -- the other discretionary handling, otherwise the discretionary
        -- contents do not interact with the surrounding (e.g. no ligatures or
        -- kerning) as it should.
        if current and getid(current) == kern_t and getsubtype(current) == fontkern_t then
          setprev(current, nil)
          setnext(current, nil)
          setfield(node, "replace", current)
          head, current = removenode(head, current)
        end
        local pre, post, rep = getdisc(node)
        setdisc(node, process(pre, fontid, direction),
                      process(post, fontid, direction),
                      process(rep, fontid, direction))

        head, current = insertafter(head, current, node)
      end
    end
    node = getnext(node)
    nodeindex = nodeindex + 1
  end

  return head, node
end

local hex_to_rgba do
  local hex = lpeg.R'09' + lpeg.R'AF' + lpeg.R'af'
  local twohex = hex * hex / function(s) return tonumber(s, 16) / 255 end
  local color_expr = twohex * twohex * twohex * twohex^-1 * -1
  function hex_to_rgba(s)
    local r, g, b, a = color_expr:match(s)
    if r then
      return format('%s %s %s rg', r, g, b)
    end
  end
end

local function shape_run(head, current, run)
  if not run.skip then
    -- Font loaded with our loader and an HarfBuzz face is present, do our
    -- shaping.
    local fontid = run.font
    local fontdata = font.getfont(fontid)
    local options = fontdata.specification.features.raw
    local color = options and options.color and hex_to_rgba(options.color)

    local glyphs
    head, glyphs = shape(head, current, run)
    print'X0'
    for n in node.traverse(tonode(head)) do
      print('C0', n)
    end
    return tonodes(head, current, run, glyphs, color)
  else
    for i = 1, len do
      current = getnext(current)
    end
    return head, current
  end
end

function process(head, font, direction)
  local newhead, current = head, head
  local runs = itemize(head, font, direction)

  for _, run in next, runs do
    newhead, current = shape_run(newhead, current, run)
  end
  print'X'
  for n in node.traverse(tonode(newhead)) do
    print('C', n)
  end

  return newhead or head
end

local function pdfdirect(data)
  local n = newnode(whatsit_t, pdfliteral_t)
  setfield(n, "mode", 2) -- direct
  setdata(n, data)
  return n
end

local function pdfcolor(color)
  local c = newnode(whatsit_t, pdfcolorstack_t)
  setfield(c, "stack", 0)
  setfield(c, "command", color and 1 or 2) -- 1: push, 2: pop
  setfield(c, "data", color)
  return c
end

local function post_process(head, currentcolor)
  for n in traverse(head) do
    local props = getproperty(n)
    local harfprops = props and props.harf

    local startactual, endactual, color
    if harfprops then
      startactual = harfprops[startactual_p]
      endactual = harfprops[endactual_p]
      color = harfprops[color_p]
    end

    if currentcolor and currentcolor ~= color then
      -- Pop current color.
      currentcolor = nil
      head = insertbefore(head, n, pdfcolor(currentcolor))
    end

    if currentcolor ~= color then
      -- Push new color.
      currentcolor = color
      head = insertbefore(head, n, pdfcolor(currentcolor))
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
    osremove(path)
  end
end

local function set_tounicode()
  for fontid, fontdata in font.each() do
    local hbdata = fontdata.hb
    if hbdata and fontid == pdf.getfontname(fontid) then
      local characters = fontdata.characters
      local newcharacters = {}
      local hbshared = hbdata.shared
      local glyphs = hbshared.glyphs
      local nominals = hbshared.nominals
      for gid = 0, #glyphs do
        local glyph = glyphs[gid]
        if glyph.used then
          local tounicode = glyph.tounicode or "FFFD"
          local character = characters[gid + hb.CH_GID_PREFIX]
          newcharacters[gid + hb.CH_GID_PREFIX] = character
          local unicode = nominals[gid]
          if unicode then
            newcharacters[unicode] = character
          end
          character.tounicode = tounicode
          character.used = true
        end
      end
      font.addcharacters(fontid, { characters = newcharacters })
    end
  end
end

local function get_glyph_string(n)
  local n = todirect(n)
  local props = getproperty(n)
  props = props and props.harf
  return props and props[string_p] or nil
end

fonts.handlers.otf.registerplugin('harf', process)

return {
  -- process = process_nodes,
  post_process = post_process_nodes,
  cleanup = run_cleanup,
  set_tounicode = set_tounicode,
  get_glyph_string = get_glyph_string,
}
