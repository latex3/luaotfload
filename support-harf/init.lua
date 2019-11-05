local tmpname = os.tmpname
local prefix = os.tmpname()
do
  os.remove(prefix)
  local pathsep = lpeg.S'\\/'
  prefix = lpeg.C(((1-pathsep)^0 * pathsep)^0):match(prefix)
end
local i = 0
function os.tmpname()
  i = i + 1
  return prefix .. 'luatmp_' .. i
end
