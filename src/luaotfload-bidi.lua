-----------------------------------------------------------------------
--         FILE:  luaotfload-bidi.lua
--  DESCRIPTION:  part of luaotfload / fallback
-----------------------------------------------------------------------

local ProvidesLuaModule = { 
    name          = "luaotfload-bidi",
    version       = "3.0004",       --TAGVERSION
    date          = "2019-08-11", --TAGDATE
    description   = "luaotfload submodule / bidi",
    license       = "GPL v2.0",
    author        = "Marcel Krüger"
}

if luatexbase and luatexbase.provides_module then
  luatexbase.provides_module (ProvidesLuaModule)
end  

local nodenew            = node.direct.new
local nodecopy           = node.direct.copy
local nodeflush          = node.direct.flush_node
local free               = node.direct.free
local setsubtype         = node.direct.setsubtype
local setchar            = node.direct.setchar
local getchar            = node.direct.getchar
local getfont            = node.direct.getfont
local getid              = node.direct.getid
local setnext            = node.direct.setnext
local getnext            = node.direct.getnext
local setprev            = node.direct.setprev
local getprev            = node.direct.getprev
local traverse           = node.direct.traverse
local getwhd             = node.direct.getwhd
local tail               = node.direct.tail
local remove             = node.direct.remove
local insert_after       = node.direct.insert_after
local insert_before      = node.direct.insert_before
local traverse_char      = node.direct.traverse_char
local protect_glyph      = node.direct.protect_glyph
local getdirection       = node.direct.getdirection
local setdirection       = node.direct.setdirection
local otffeatures        = fonts.constructors.newfeatures "otf"

local codepoint = lpeg.S'0123456789ABCDEF'^4/function(c)return tonumber(c, 16)end
local bidi_classes do
  local entry = lpeg.Cg(codepoint * ';' * (1-lpeg.P';')^0 * ';' * (1-lpeg.P';')^0 * ';' * (1-lpeg.P';')^0 * ';' * lpeg.C((1-lpeg.P';')^0) * ';')^-1 * (1-lpeg.P'\n')^0 * '\n'
  local file = lpeg.Cf(
      lpeg.Ct''
    * entry^0
  , rawset)

  local f = io.open(kpse.find_file"UnicodeData.txt")
  bidi_classes = setmetatable(file:match(f:read'*a'), {
      __index = function(t, cp)
        if     (cp >= 0xAC00 and cp <= 0xDCA3)
            or (cp >= 0xD800 and cp <= 0xF8FF)
            or (cp >= 0x17000 and cp <= 0x187F7)
            or (cp >= 0x20000 and cp <= 0x2EBE0) -- Technically there are some
                                                 -- small gaps in there, but
                                                 -- why would anyone store
                                                 -- other kinds of characters
                                                 -- there? Also it would add
                                                 -- three additional ranges...
            or (cp >= 0xF0000 and cp <= 0x10FFFD) then
          t[cp] = "L"
          return "L"
        else
          t[cp] = "ON"
          return "ON"
        end
      end
    })
  f:close()
end

local bidi_brackets do
  local entry = lpeg.Cg(codepoint * '; ' * lpeg.Ct(lpeg.Cg(codepoint, 'other') * '; ' * lpeg.Cg(lpeg.S'oc', 'type')) * ' ')^-1 * (1-lpeg.P'\n')^0 * '\n'
  local file = lpeg.Cf(
      lpeg.Ct''
    * entry^0
  , rawset)

  local f = io.open(kpse.find_file"BidiBrackets.txt")
  bidi_brackets = file:match(f:read'*a')
  f:close()
end

-- At the time of writing (Unicode 12.1.0), this is a complete list of
-- characters whose canonical decomposition contains a bidi_brackets
-- entry. Given that this isn't stored directly AFAICT, it is easier to
-- list them here than parse some file.
local bidi_brackets_canonical = {
  [0x2329] = 0x3008,
  [0x232A] = 0x3009,
}
for k, v in pairs(bidi_brackets) do
  bidi_brackets_canonical[k] = bidi_brackets_canonical[k] or k
end

local opentype_mirroring do
  local entry = lpeg.Cg(codepoint * '; ' * codepoint * ' ')^-1 * (1-lpeg.P'\n')^0 * '\n'
  local file = lpeg.Cf(
      lpeg.Ct''
    * entry^0
  , rawset)

  local f = io.open(kpse.find_file"BidiMirroring-510.txt")
  opentype_mirroring = file:match(f:read'*a')
  f:close()
end

local bidi_fonts = setmetatable({}, {
  __index = function(t, fid)
    local f = font.getfont(fid)
    -- table.tofile('myfont2', f)
    local res = f and f.bidi or false
    t[fid] = res
    return res
  end,
})

local function makebidifont(tfmdata)
  tfmdata.bidi = true
end

local glyph_id = node.id'glyph'
local dir_id = node.id'dir'
local glue_id = node.id'glue'
local kern_id = node.id'kern'

local Strong = {
  L = 'L',
  R = 'R',
  AN = 'R',
  EN = 'R',
}

local NI = {
  B = true,
  S = true,
  WS = true,
  ON = true,
  FSI = true,
  LRI = true,
  PDI = true,
}

local function adjust_nsm(pre, stop, dir, node_class, node_origclass)
  local follow = getnext(pre)
  local follow_origclass = node_origclass[follow]
  while follow ~= stop and (not follow_origclass or follow_origclass == "NSM") do
    if follow_origclass then
      node_class[follow] = dir
    end
    follow = getnext(follow)
    follow_origclass = node_origclass[follow]
  end
end
local gettime = socket.gettime
local fulltime1, fulltime2, fulltime3 = 0, 0, 0
function do_wni(head, level, stop, sos, eos, node_class, node_level, node_origclass)
  local starttime = gettime()
  local opposite, direction
  if level % 2 == 0 then
    direction, opposite = 'L', 'R'
  else
    direction, opposite = 'R', 'L'
  end
  local stop = getnext(stop)
  local prevclass, prevstrong = sos, sos
  -- We combine W1--W7, that shouldn't make a difference and is
  -- faster.
  local cur = head
  while cur ~= stop do
    local curclass = node_class[cur]
    if curclass == "NSM" then
      curclass = prevclass == "PDI" and "ON" or prevclass
      node_class[cur] = curclass
    elseif curclass == "EN" then
      if prevstrong == "AL" then
        curclass = "AN"
        node_class[cur] = curclass
      elseif prevstrong == "L" then
        node_class[cur] = "L"
        -- HACK: No curclass change. Therefore prevclass is still EN,
        -- such that this W7 change does not affect the ES/ET changes
        -- in W4-W5
      end
    elseif curclass == "ES" then
      if prevclass == "EN" then
        local follow = getnext(cur)
        local followclass = node_class[follow]
        while follow ~= stop and not followclass do
          follow = getnext(follow)
          followclass = node_class[follow]
        end
        if follow ~= stop and followclass == "EN" then
          curclass = "EN"
          node_class[cur] = prevstrong == "L" and "L" or curclass
        end
      end
    elseif curclass == "CS" then
      if prevclass == "EN" or prevclass == "AN" then
        local follow = getnext(cur)
        local followclass = node_class[follow]
        while follow ~= stop and not followclass do
          follow = getnext(follow)
          followclass = node_class[follow]
        end
        if follow ~= stop then
          if followclass == "EN" then
            if prevstrong == "AL" then
              curclass = "AN"
              node_class[cur] = curclass
            elseif prevclass == "EN" then
              curclass = "EN"
              node_class[cur] = prevstrong == "L" and "L" or curclass
            else
              curclass = "ON"
              node_class[cur] = curclass
            end
          elseif followclass == "AN" and prevclass == "AN" then
            curclass = "AN"
            node_class[cur] = curclass
          else
            curclass = "ON"
            node_class[cur] = curclass
          end
        else
          curclass = "ON"
          node_class[cur] = curclass
        end
      else
        curclass = "ON"
        node_class[cur] = curclass
      end
    elseif curclass == "ET" then
      if prevclass == "EN" then
        local follow = cur
        local followclass = curclass
        while follow ~= stop and (followclass == "ET" or not followclass) do
          if followclass then
            node_class[follow] = "EN"
          end
          follow = getnext(follow)
          followclass = node_class[follow]
        end
      else
        local follow = getnext(cur)
        local followclass = node_class[follow]
        while follow ~= stop and (followclass == "ET" or not followclass) do
          follow = getnext(follow)
          followclass = node_class[follow]
        end
        if followclass == "EN" and prevstrong ~= "AL" then
          follow = cur
          followclass = curclass
          while follow ~= stop and (followclass == "ET" or not followclass) do
            if followclass then
              node_class[follow] = "EN"
            end
            follow = getnext(follow)
            followclass = node_class[follow]
          end
        else
          curclass = "ON"
          node_class[cur] = curclass
        end
      end
    elseif curclass == "AL" then
      prevstrong = "AL"
      curclass = "R"
      node_class[cur] = curclass
    elseif curclass == "L" or curclass == "R" then
      prevstrong = curclass
    elseif not curclass then
      curclass = prevclass -- Do not change prevclass for the next run
    end
    prevclass = curclass
    cur = getnext(cur)
  end
  cur = head
  local last_e, last_s = 0, 0
  local stack = {}
  local need_context = {}
  while cur ~= stop do
    local curclass = node_class[cur]
    if curclass == "ON" and getid(cur) == glyph_id and bidi_fonts[getfont(cur)] then
      local cp = bidi_brackets_canonical[getchar(cur)]
      local bracket = bidi_brackets[cp]
      if bracket then
        if bracket.type == 'o' then
          local info = {cur, bracket.other}
          stack[#stack + 1] = info
        else -- if cp.type == 'c'
          for i = #stack,1,-1 do
            local entry = stack[i]
            if entry[2] == cp then
              for j = i,#stack do
                stack[j] = nil
              end
              if last_e >= i then
                local beg = entry[1]
                node_class[beg], node_class[cur] = direction, direction
                adjust_nsm(beg, stop, direction, node_class, node_origclass)
                adjust_nsm(cur, stop, direction, node_class, node_origclass)
                last_s, last_e = i-1, i-1
              elseif last_s >= i then
                need_context[entry[1]] = cur
                if entry[3] then
                  local beg = entry[1]
                  node_class[beg], node_class[cur] = opposite, opposite
                  adjust_nsm(beg, stop, opposite, node_class, node_origclass)
                  adjust_nsm(cur, stop, opposite, node_class, node_origclass)
                end
                last_s = i-1
              end
              break
            end
          end
        end
      end
    else
      local strong = Strong[curclass]
      if strong == direction then
        last_e, last_s = #stack, #stack
      elseif strong == opposite then
        last_s = #stack
      end
    end
    cur = getnext(cur)
  end
  cur = head
  prevstrong = sos
  local newlevels = direction == 'L' and {
    L = level,
    R = level+1,
    AN = level+2,
    EN = level+2,
  } or {
    L = level+1,
    R = level,
    AN = level+1,
    EN = level+1,
  }
  while cur ~= stop do
    local curclass = node_class[cur]
    local strong = Strong[curclass]
    if strong then
      prevstrong = strong
      node_level[cur] = newlevels[curclass]
      cur = getnext(cur)
    elseif need_context[cur] then
      local final = need_context[cur]
      node_class[cur], node_class[final] = prevstrong, prevstrong
      adjust_nsm(final, stop, prevstrong, node_class, node_origclass)
      adjust_nsm(cur, stop, prevstrong, node_class, node_origclass)
      node_level[cur] = newlevels[prevstrong]
      cur = getnext(cur)
    else
      local follow = getnext(cur)
      local followclass = need_context[follow] and prevstrong or Strong[node_class[follow]]
      while follow ~= stop and not followclass do
        follow = getnext(follow)
        followclass = need_context[follow] and prevstrong or Strong[node_class[follow]]
      end
      if follow == stop then
        followclass = eos
      end
      local outerdir = followclass == prevstrong and followclass or direction
      follow = cur
      followclass = curclass
      while follow ~= stop and not Strong[followclass] do
        node_class[follow], node_level[follow] = followclass and outerdir, followclass and newlevels[outerdir]
        follow = getnext(follow)
        followclass = need_context[follow] and prevstrong or node_class[follow]
      end
      cur = follow
    end
  end
  fulltime1 = fulltime1 + gettime() - starttime
end
node_class, node_origclass, node_level = {}, {}, {} -- Making these local was significantly
-- slower necause they are sparse arrays with medium sized integer
-- keys, requiring relativly big allocations
function dobidi(head, a, b, c, par_direction)
  head = node.direct.todirect(head)
  local node_class, node_origclass, node_level = node_class, node_origclass, node_level
  local dir_matches = {}
  par_direction = par_direction == "TRT" and "R" or "L" -- We hope to only encounter TRT/TLT
  local parlevel, level, oldlevel, overwrite, isolate = par_direction == "R" and 1 or 0
  level, oldlevel = parlevel, -1
  local stack = {}
  local function push(dir, new_overwrite)
    stack[#stack+1] = {level, overwrite, isolate}
    level, overwrite, isolate = level + (level + dir + 1)%2 + 1, new_overwrite, nil
  end
  local function pop()
    local last = stack[#stack]
    stack[#stack] = nil
    level, overwrite, isolate = last[1], last[2], last[3]
  end
  local isolating_level_runs = {}
  local current_run
  local old_dir
  for cur, tcur, scur in traverse(head) do
    local class, curlevel, isolate_flag
    if tcur == glyph_id and bidi_fonts[getfont(cur)] then
      class = bidi_classes[getchar(cur)]
      if class == "RLE" then
        class, curlevel = nil, level
        push(1)
      elseif class == "LRE" then
        class, curlevel = nil, level
        push(0)
      elseif class == "RLO" then
        class, curlevel = nil, level
        push(1, "R")
      elseif class == "LRO" then
        class, curlevel = nil, level
        push(0, "L")
      elseif class == "PDF" then
        class = nil
        if not isolate and #stack >= 1 then
          pop()
        end
      -- elseif class == "RLI" then -- Not supported yet, use textdir
      --   -- TODO
      -- elseif class == "LRI" then -- Not supported yet, use textdir
      --   -- TODO
      -- elseif class == "FSI" then -- Not supported yet, use textdir
      --   -- TODO
      -- elseif class == "PDI" then -- Not supported yet, use textdir
      --   -- TODO
      elseif class == "BN" then
        class = overwrite or nil
      elseif class == "B" then
        assert(false) -- FIXME: Can this happen in TeX?
      else
        class = overwrite or class
      end
    elseif tcur == dir_id then
      local dir, reset = getdirection(cur)
      if reset then
        while not isolate and #stack >= 1 do
          pop()
        end
        if isolate then
          isolate_flag = isolate
          pop()
        else
          -- Unmatched reset. LuaTeX inserts them sometimes, just
          -- dropping them normally works fine. But deleting is
          -- difficult here because the loop needs the next pointer.
          -- Technically they should stay
          if old_dir then nodeflush(old_dir) end
          head = remove(head, cur)
          old_dir = cur
          goto SKIP
        end
        class = overwrite or "PDI"
      else
        curlevel = level
        dir = dir == 1 and 1 or 0
        class = overwrite or (dir == 1 and "LRI" or "RLI")
        push(dir, nil)
        isolate_flag = false
      end
    elseif tcur == glue_id or tcur == kern_id then -- Not sure about kerns
      class = "WS"
    else
      class = "ON"
    end
    curlevel = curlevel or level
    node_class[cur], node_origclass[cur] = class, class
    --
    if curlevel ~= oldlevel and class then
      local os = (oldlevel > curlevel and oldlevel or curlevel) % 2 == 1 and 'R' or 'L'
      oldlevel = curlevel
      if current_run then
        current_run[3] = getprev(cur)
        current_run[5] = os
        current_run = nil
      end
      if isolate_flag then
        current_run = isolate_flag
        local beg = current_run.remember
        if getnext(beg) ~= cur then -- Handle stupid input
          dir_matches[beg] = {getnext(beg), getprev(cur)}
          setprev(getnext(beg), nil)
          setnext(getprev(cur), nil)
          setnext(beg, cur)
          setprev(cur, beg)
        end
      else
        current_run = {cur, curlevel, nil, os}
        isolating_level_runs[#isolating_level_runs+1] = current_run
      end
    end
    if isolate_flag == false then
      current_run.remember = cur
      isolate = current_run
      current_run = nil
    end
    ::SKIP::
  end
  local t = tail(head)
  do
    local tid = getid(t)
    while t and tid > dir_id and tid ~= glyph_id do t = getprev(t) tid = getid(t) end
    if not t then return head end -- Everything is discardable, so ignore it
  end
  if current_run then
    current_run[3] = t
    current_run[5] = (oldlevel > parlevel and oldlevel or parlevel) % 2 == 1 and 'R' or 'L'
    -- Should always be level IINM, but let's us the offical check
    current_run = nil
  end
  for i = 1,#stack do
    if isolate then
      local beg = isolate.remember
      local n
      if beg == t then
        n = getprev(t)
        if not n then return head end
        setnext(n, free(t))
      else
        dir_matches[beg] = {getnext(beg), t}
        if old_dir then
          n = old_dir
          setdirection(n, getdirection(beg), 1)
          old_dir = nil
        else
          n = nodecopy(beg)
          setsubtype(n, 1)
        end
        node_class[n], node_origclass[n] = "PDI", "PDI"
        setnext(n, getnext(t))
        setprev(getnext(beg), nil)
        setnext(t, nil)
        setnext(beg, n)
        setprev(n, beg)
      end
      t = n
      isolate[3], isolate[5] = n, isolate[2] % 2 == 1 and 'R' or 'L'
    end
    pop()
  end
  for i = 1, #isolating_level_runs do
    local run = isolating_level_runs[i]
    do_wni(run[1], run[2], run[3], run[4], run[5], node_class, node_level, node_origclass)
  end
  level = parlevel
  local curdir = level
  function push(n, newlevel)
    local dirnode = nodenew(dir_id)
    setdirection(dirnode, newlevel % 2, 0)
    stack[#stack + 1] = {level, dirnode}
    -- tableinsert(stack, 
    level = newlevel
    return insert_before(head, n, dirnode)
  end
  function pop(head, n)
    local entry = stack[#stack]
    stack[#stack] = nil
    level = entry[1]
    local dirnode = nodecopy(entry[2])
    setsubtype(dirnode, 1)
    return insert_before(head, n, dirnode), entry[2]
  end
  for cur, tcur, scur in traverse(head) do
    local curlevel = node_level[cur]
    if tcur == dir_id and scur == 1 then
      local newlevel = curlevel + (curlevel + getdirection(cur) + 1)%2 + 1
      while level > newlevel do
        head = pop(head, cur)
      end
      stack[#stack] = nil
      level = curlevel
    end
    if curlevel and level ~= curlevel then
      local push_pos = cur
      while level > curlevel do
        head, push_pos = pop(head, cur)
      end
      if level < curlevel then
        push(push_pos, curlevel)
      end
    end
    if tcur == dir_id and scur == 0 then
      local newlevel = curlevel + (curlevel + getdirection(cur) + 1)%2 + 1
      stack[#stack + 1] = {level, cur}
      level = newlevel
      local remembered = dir_matches[cur]
      if remembered then
        local newnext, newprev = remembered[1], remembered[2]
        setnext(newprev, getnext(cur))
        setprev(getnext(cur), newprev)
        setprev(newnext, cur)
        setnext(cur, newnext)
      end
    elseif level % 2 == 1 and tcur == glyph_id and scur == 0 and bidi_fonts[getfont(cur)] then
      local char = opentype_mirroring[getchar(cur)]
      if char then
        setchar(cur, char)
      end
    end
  end
  return node.direct.tonode(head)
end

otffeatures.register {
  name        = "bidi",
  description = "Apply Unicode bidi algorithm",
  default = 1,
  manipulators = {
    node = makebidifont,
  },
  --                -- We have to see how processors interact with
  --                -- multiscript fonts
  -- processors = {
  --   node = donotdef,
  -- }
}

--- vim:sw=2:ts=2:expandtab:tw=71
