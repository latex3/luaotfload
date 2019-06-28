-----------------------------------------------------------------------
--         FILE:  luaotfload-notdef.lua
--  DESCRIPTION:  part of luaotfload / notdef
-----------------------------------------------------------------------

local ProvidesLuaModule = { 
    name          = "luaotfload-notdef",
    version       = "2.9806",       --TAGVERSION
    date          = "2019-06-20", --TAGDATE
    description   = "luaotfload submodule / color",
    license       = "GPL v2.0",
    author        = "Marcel Krüger"
}

if luatexbase and luatexbase.provides_module then
  luatexbase.provides_module (ProvidesLuaModule)
end  

local nodenew            = node.direct.new
local getfont            = font.getfont
local setfont            = node.direct.setfont
local getwhd             = node.direct.getwhd
local insert_after       = node.direct.insert_after
local traverse_char      = node.direct.traverse_char
local protect_glyph      = node.direct.protect_glyph
local otffeatures        = fonts.constructors.newfeatures "otf"

local function setnotdef(tfmdata, factor)
  tfmdata.notdefcode = tfmdata.resources.unicodes[".notdef"]
  if tfmdata.notdefcode then return end
  for code, char in pairs(tfmdata.shared.rawdata.descriptions) do
    if char.index == 0 then
      tfmdata.notdefcode = code
      return
    end
  end
end

local glyph_id = node.id'glyph'
local function donotdef(head, font, attr, dir, n)
  local tfmdata = getfont(font)
  local notdef, chars = tfmdata.unscaled.notdefcode, tfmdata.characters
  if not notdef then return end
  for cur, cid, fid in traverse_char(head) do if fid == font then
    local w, h, d = getwhd(cur)
    if w == 0 and h == 0 and d == 0 and not chars[cid] then
      local notdefnode = nodenew(glyph_id, 256)
      setfont(notdefnode, font, notdef)
      insert_after(cur, cur, notdefnode)
      protect_glyph(cur)
    end
  end end
end

otffeatures.register {
  name        = "notdef",
  description = "Add notdef glyphs",
  default     = 1,
  initializers = {
    node = setnotdef,
  },
  processors = {
    node = donotdef,
  }
}

--- vim:sw=2:ts=2:expandtab:tw=71
