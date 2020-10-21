local mapping_tables = require'luaotfload-unicode'.casemapping

local uppercase = mapping_tables.uppercase
local lowercase = mapping_tables.lowercase

local otfregister  = fonts.constructors.features.otf.register

local direct = node.direct
local is_char = direct.is_char
local has_glyph = direct.has_glyph
local uses_font = direct.uses_font
local getnext = direct.getnext
local setchar = direct.setchar
local setdisc = direct.setdisc
local getdisc = direct.getdisc

local disc = node.id'disc'
local glyph = node.id'disc'
local function process(table)
  local function processor(head, font)
    local n = head
    while n do
      n = has_glyph(n)
      if not n then break end
      local char, id = is_char(n, font)
      if char then
        local mapping = table[char]
        if mapping then
          setchar(n, mapping)
        end
      elseif id == disc and uses_font(n, font) then
        local pre, post, rep = getdisc(n)
        setdisc(n, processor(pre, font), processor(post, font), processor(rep, font))
      end
      n = getnext(n)
    end
    return head
  end
  return processor
end

local upper_process = process(uppercase)
otfregister {
  name = 'upper',
  description = 'Map to uppercase',
  default = false,
  processors = {
    position = 1,
    plug = upper_process,
    node = upper_process,
    base = upper_process,
  },
}

local lower_process = process(lowercase)
otfregister {
  name = 'lower',
  description = 'Map to lowercase',
  default = false,
  processors = {
    position = 1,
    plug = lower_process,
    node = lower_process,
    base = lower_process,
  },
}
