-----------------------------------------------------------------------
--         FILE:  luaotfload-harf-var-t2-writer.lua
--  DESCRIPTION:  part of luaotfload / HarfBuzz / Serialize Type 2 charstrings
-----------------------------------------------------------------------
do
 assert(luaotfload_module, "This is a part of luaotfload and should not be loaded independently") { 
     name          = "luaotfload-harf-var-t2-writer",
     version       = "3.19-dev",       --TAGVERSION
     date          = "2021-05-21", --TAGDATE
     description   = "luaotfload submodule / Type 2 charstring writer",
     license       = "GPL v2.0",
     author        = "Marcel Krüger",
     copyright     = "Luaotfload Development Team",     
 }
end

local pack = string.pack
local function numbertot2(n)
  if math.abs(n) > 2^15 then
    error[[Number too big]]
  end
  local num = math.floor(n + .5)
  if n ~= 0 and math.abs((num-n)/n) > 0.001  then
    num = math.floor(n * 2^16 + 0.5)
    return pack(">Bi4", 255, math.floor(n * 2^16 + 0.5))
  elseif num >= -107 and num <= 107 then
    return string.char(num + 139)
  elseif num >= 108 and num <= 1131 then
    return pack(">I2", num+0xF694) -- -108+(247*0x100)
  elseif num >= -1131 and num <= -108 then
    return pack(">I2", -num+0xFA94) -- -108+(251*0x100)
  else
    return pack(">Bi2", 28, num)
  end
end
local function convert_cs(cs, upem)
  local cs_parts = {}
  local function add(cmd, first, ...)
    if cmd == 19 or cmd == 20 then
      cs_parts[#cs_parts+1] = string.char(cmd)
      cs_parts[#cs_parts+1] = first
      return
    end
    if first then
      cs_parts[#cs_parts+1] = numbertot2(first*upem/1000)
      return add(cmd, ...)
    end
    if cmd then
      if cmd < 0 then
        cs_parts[#cs_parts+1] = string.char(12, -cmd-1)
      else
        cs_parts[#cs_parts+1] = string.char(cmd)
      end
    end
  end
  for _, args in ipairs(cs) do if args then add(table.unpack(args)) end end
  return table.concat(cs_parts)
end

return function(cs, upem)
  return convert_cs(cs, upem or 1000)
end
