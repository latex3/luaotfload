-----------------------------------------------------------------------
--         FILE:  luaotfload-mirror.lua
--  DESCRIPTION:  part of luaotfload / mirror
-----------------------------------------------------------------------

local ProvidesLuaModule = {
    name          = "luaotfload-mirror",
    version       = "3.0004",       --TAGVERSION
    date          = "2019-08-11", --TAGDATE
    description   = "luaotfload submodule / mirror",
    license       = "GPL v2.0",
    author        = "Marcel Krüger"
}

if luatexbase and luatexbase.provides_module then
  luatexbase.provides_module (ProvidesLuaModule)
end

local flush_node         = node.direct.flush_node
local getfont            = font.getfont
local getnext            = node.direct.getnext
local getwhd             = node.direct.getwhd
local insert             = table.insert
local insert_after       = node.direct.insert_after
local kern_id            = node.id'kern'
local nodenew            = node.direct.new
local otfregister        = fonts.constructors.features.otf.register
local protect_glyph      = node.direct.protect_glyph
local remove             = node.direct.remove
local setfont            = node.direct.setfont
local traverse_char      = node.direct.traverse_char

local handlers = fonts.handlers.otf.handlers

local opentype_mirroring do
  local codepoint = lpeg.S'0123456789ABCDEF'^4/function(c)return tonumber(c, 16)end
  local entry = lpeg.Cg(codepoint * '; ' * codepoint * ' ')^-1 * (1-lpeg.P'\n')^0 * '\n'
  local file = lpeg.Cf(
      lpeg.Ct''
    * entry^0
  , rawset)

  local f = io.open(kpse.find_file"BidiMirroring-510.txt")
  opentype_mirroring = file:match(f:read'*a')
  f:close()
end

local function dirchecking_handler(basehandler)
  local basehandler = handlers[basehandler]
  if not basehandler then return false end
  return function(head, start, dataset, sequence, param, rlmode, skiphash, step)
    local value = dataset[1]
    if value ~= true and rlmode ~= value then
      return head, start, false, false
    end
    return basehandler(head, start, dataset, sequence, param, rlmode, skiphash, step)
  end
end

local sequence = {
  features = {base_rtlm = {["*"] = {["*"] = true}}},
  flags = {false, false, false, false},
  name = "based mirroring",
  order = {"base_rtlm"},
  nofsteps = 1,
  steps = {{
    coverage = opentype_mirroring,
  }},
  type = "dir_gsub_single",
}
handlers.dir_gsub_single = dirchecking_handler'gsub_single'
local function mirroringinitialiser(tfmdata, value)
  local resources = tfmdata.resources
  local sequences = resources and resources.sequences
  if sequences then
    local features = tfmdata.shared.features
    features.ltrm, features.ltra = 1, 1
    features.rtlm, features.rtla, features.base_rtlm = -1, -1, -1
    for i = 1,#sequences do
      local cur_sequence = sequences[i]
      -- In some cases, sequences are shared. Then we find `sequence`
      -- already in the list.
      -- In this case we are already done.
      if sequence == cur_sequence then return end
      local features = cur_sequence.features
      if features and (features.ltrm or features.ltra
                    or features.rtlm or features.rtla) then
        local newtype = 'dir_' .. cur_sequence.type
        if handlers[newtype] == nil then
          handlers[newtype] = dirchecking_handler(cur_sequence.type)
        end
        cur_sequence.type = newtype
      end
    end
    insert(sequences, 1, sequence)
  end
end
otfregister {
  name = 'dir_mirroring',
  description = 'Apply directional mirroring and alternates',
  default = true,
  initializers = {
    node = mirroringinitialiser,
  },
}

--- vim:sw=2:ts=2:expandtab:tw=71
