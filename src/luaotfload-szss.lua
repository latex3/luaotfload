-----------------------------------------------------------------------
--         FILE:  luaotfload-szss.lua
--  DESCRIPTION:  part of luaotfload / szss
-----------------------------------------------------------------------

local ProvidesLuaModule = { 
    name          = "luaotfload-szss",
    version       = "3.1301-dev",       --TAGVERSION
    date          = "2020-02-02", --TAGDATE
    description   = "luaotfload submodule / color",
    license       = "GPL v2.0",
    author        = "Marcel Krüger"
}

if luatexbase and luatexbase.provides_module then
  luatexbase.provides_module (ProvidesLuaModule)
end  

local direct       = node.direct
local otfregister  = fonts.constructors.features.otf.register

local copy         = direct.copy
local getdisc      = direct.getdisc
local getnext      = direct.getnext
local insert_after = direct.insert_after
local is_char      = direct.is_char
local setchar      = direct.setchar
local setdisc      = direct.setdisc

local disc_t       = node.id'disc'

local szsstable = setmetatable({}, { __index = function(t, i)
  local v = font.getfont(i)
  v = v and v.properties
  v = v and v.transform_sz or false
  t[i] = v
  return v
end})

local function szssinitializer(tfmdata, value, features)
  if value == 'auto' then
    value = not tfmdata.characters[0x1E9E]
  end
  local properties = tfmdata.properties
  properties.transform_sz = value
end

local function szssprocessor(head,font) -- ,attr,direction)
  if not szsstable[font] then return end
  local n = head
  while n do
    local c, id = is_char(n, font)
    if c == 0x1E9E then
      setchar(n, 0x53)
      head, n = insert_after(head, n, copy(n))
    elseif id == disc_t then
      local pre, post, replace = getdisc(n)
      pre = szssprocessor(pre, font)
      post = szssprocessor(post, font)
      replace = szssprocessor(replace, font)
      setdisc(n, pre, post, replace)
    end
    n = getnext(n)
  end
  return head
end

otfregister {
  name = 'szss',
  description = 'Replace capital ß with SS',
  default = 'auto',
  initializers = {
    node = szssinitializer,
    plug = szssinitializer,
  },
  processors = {
    position = 1,
    node = szssprocessor,
    plug = szssprocessor,
  },
}

-- harf-only features (for node they are implemented in the fontloader

otfregister {
  name = 'extend',
  description = 'Fake extend',
  default = false,
  manipulators = {
    plug = function(tfmdata, _, value)
      value = tonumber(value)
      if not value then
        error[[Invalid extend value]]
      end
      tfmdata.extend = value * 1000
      tfmdata.hb.hscale = tfmdata.units_per_em * value
      local parameters = tfmdata.parameters
      parameters.slant = parameters.slant * value
      parameters.space = parameters.space * value
      parameters.space_stretch = parameters.space_stretch * value
      parameters.space_shrink = parameters.space_shrink * value
      parameters.quad = parameters.quad * value
      parameters.extra_space = parameters.extra_space * value
      local done = {}
      for _, char in next, tfmdata.characters do
        if char.width and not done[char] then
          char.width = char.width * value
          done[char] = true
        end
      end
    end,
  },
}

otfregister {
  name = 'slant',
  description = 'Fake slant',
  default = false,
  manipulators = {
    plug = function(tfmdata, _, value)
      value = tonumber(value)
      if not value then
        error[[Invalid slant value]]
      end
      tfmdata.slant = value * 1000
      local parameters = tfmdata.parameters
      parameters.slant = parameters.slant + value * 65536
    end,
  },
}

otfregister {
  name = 'squeeze',
  description = 'Fake squeeze',
  default = false,
  manipulators = {
    plug = function(tfmdata, _, value)
      value = tonumber(value)
      if not value then
        error[[Invalid squeeze value]]
      end
      tfmdata.squeeze = value * 1000
      tfmdata.hb.vscale = tfmdata.units_per_em * value
      local parameters = tfmdata.parameters
      parameters.slant = parameters.slant / value
      parameters.x_height = parameters.x_height * value
      parameters[8] = parameters[8] * value
      local done = {}
      for _, char in next, tfmdata.characters do
        if not done[char] then
          if char.height then
            char.height = char.height * value
          end
          if char.depth then
            char.depth = char.depth * value
          end
          done[char] = true
        end
      end
    end,
  },
}
  -- if features.tlig then
  --   for char in next, characters do
  --     local ligatures = tlig[char]
  --     if ligatures then
  --       characters[char].ligatures = ligatures
  --     end
  --   end
  -- end

--- vim:sw=2:ts=2:expandtab:tw=71
