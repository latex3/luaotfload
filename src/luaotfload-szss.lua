-----------------------------------------------------------------------
--         FILE:  luaotfload-szss.lua
--  DESCRIPTION:  part of luaotfload / szss
-----------------------------------------------------------------------

local ProvidesLuaModule = { 
    name          = "luaotfload-szss",
    version       = "3.1302-dev",       --TAGVERSION
    date          = "2020-02-23", --TAGDATE
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

--- vim:sw=2:ts=2:expandtab:tw=71
