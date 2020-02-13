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

local insert             = table.insert
local otfregister        = fonts.constructors.features.otf.register

local sequence = {
  features = {szss = {["*"] = {["*"] = true}}},
  flags = {false, false, false, false},
  name = "szss",
  order = {"szss"},
  nofsteps = 1,
  steps = {{
    coverage = {
      [0x1E9E] = {0x53, 0x53},
    },
    index = 1,
  }},
  type = "gsub_multiple",
}
local function szssinitializer(tfmdata, value, features)
  if value == 'auto' then
    value = not tfmdata.characters[0x1E9E]
    features.szss = value
    if not value then return end -- Not strictly necessary
  end
  local resources = tfmdata.resources
  local sequences = resources and resources.sequences
  if sequences then
    -- Add the substitution at the very beginning to properly
    -- integrate the 'SS' in shaping decisions
    insert(sequences, 1, sequence)
  end
end
otfregister {
  name = 'szss',
  description = 'Replace capital ß with SS',
  default = 'auto',
  initializers = {
    node = szssinitializer,
  },
}

--- vim:sw=2:ts=2:expandtab:tw=71
