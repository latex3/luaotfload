if not luaotfload.set_colorsplitter then return end
local l = lpeg
local spaces = l.P' '^0
local digit16 = l.R('09', 'af', 'AF')
local function rep(patt, count)
  local result = patt
  for i=2, count do
    result = result * patt
  end
  return result
end
local traditional = spaces * l.C(rep(digit16, 6)) * (rep(l.S'fF', 2) + l.C(rep(digit16, 2)))^-1 * spaces * -1
local field = l.C((1 - l.S' ,')^1)
local new_syntax = spaces * field * (spaces * ',' * spaces * field)^-1 * spaces * -1
local split_patt = traditional + new_syntax

luaotfload.set_colorsplitter(function (value)
  local rgb, a = split_patt:match(value)
  return split_patt:match(value)
end)

local octet = rep(digit16, 2) / function(s) return string.format('%.3g ', tonumber(s, 16) / 255) end
local htmlcolor = l.Cs(rep(octet, 3) * -1 * l.Cc'rg')
local color_export = {
  token.create'endlocalcontrol',
  token.create'tex_hpack:D',
  token.new(0, 1),
  token.create'color_export:nnN',
  token.new(0, 1),
  '',
  token.new(0, 2),
  token.new(0, 1),
  'backend',
  token.new(0, 2),
  token.create'l_tmpa_tl',
  token.create'exp_after:wN',
  token.create'__color_select:nn',
  token.create'l_tmpa_tl',
  token.new(0, 2),
}
local group_end = token.create'group_end:'
local value = (1 - l.P'}')^0
luaotfload.set_colorparser(function (value)
  local html = htmlcolor:match(value)
  if html then return html end

  tex.runtoks(function()
    token.get_next()
    color_export[6] = value
    tex.sprint(-2, color_export)
  end)
  local list = token.scan_list()
  if not list.head or list.head.next or list.head.subtype ~= node.subtype'pdf_colorstack' then
    error'Unexpected backend behavior'
  end
  local cmd = list.head.data
  node.free(list)
  return cmd
end)
