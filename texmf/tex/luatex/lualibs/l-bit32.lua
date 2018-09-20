if not modules then modules = { } end modules ['l-bit32'] = {
    version = 1.001,
    license = "the same as regular Lua",
    source  = "bitwise.lua, v 1.24 2014/12/26 17:20:53 roberto",
    comment = "drop-in for bit32, adapted a bit by Hans Hagen",

}

-- Lua 5.3 has bitwise operators built in but code meant for 5.2 can expect the
-- bit32 library to be present. For the moment (and maybe forever) we will ship
-- the bit32 library as part of LuaTeX bit just in case it is missing, here is a
-- drop-in. The code is an adapted version of code by Roberto. The Luajit variant
-- is a mixture of mapping and magic.

if bit32 then

    -- lua 5.2: we're okay

elseif utf8 then

    -- lua 5.3:  bitwise.lua, v 1.24 2014/12/26 17:20:53 roberto

    bit32 = load ( [[
local select = select -- instead of: arg = { ... }

bit32 = {
  bnot = function (a)
    return ~a & 0xFFFFFFFF
  end,
  band = function (x, y, z, ...)
    if not z then
      return ((x or -1) & (y or -1)) & 0xFFFFFFFF
    else
      local res = x & y & z
      for i=1,select("#",...) do
        res = res & select(i,...)
      end
      return res & 0xFFFFFFFF
    end
  end,
  bor = function (x, y, z, ...)
    if not z then
      return ((x or 0) | (y or 0)) & 0xFFFFFFFF
    else
      local res = x | y | z
      for i=1,select("#",...) do
        res = res | select(i,...)
      end
      return res & 0xFFFFFFFF
    end
  end,
  bxor = function (x, y, z, ...)
    if not z then
      return ((x or 0) ~ (y or 0)) & 0xFFFFFFFF
    else
      local res = x ~ y ~ z
      for i=1,select("#",...) do
        res = res ~ select(i,...)
      end
      return res & 0xFFFFFFFF
    end
  end,
  btest = function (x, y, z, ...)
    if not z then
      return (((x or -1) & (y or -1)) & 0xFFFFFFFF) ~= 0
    else
      local res = x & y & z
      for i=1,select("#",...) do
          res = res & select(i,...)
      end
      return (res & 0xFFFFFFFF) ~= 0
    end
  end,
  lshift = function (a, b)
    return ((a & 0xFFFFFFFF) << b) & 0xFFFFFFFF
  end,
  rshift = function (a, b)
    return ((a & 0xFFFFFFFF) >> b) & 0xFFFFFFFF
  end,
  arshift = function (a, b)
    a = a & 0xFFFFFFFF
    if b <= 0 or (a & 0x80000000) == 0 then
      return (a >> b) & 0xFFFFFFFF
    else
      return ((a >> b) | ~(0xFFFFFFFF >> b)) & 0xFFFFFFFF
    end
  end,
  lrotate = function (a ,b)
    b = b & 31
    a = a & 0xFFFFFFFF
    a = (a << b) | (a >> (32 - b))
    return a & 0xFFFFFFFF
  end,
  rrotate = function (a, b)
    b = -b & 31
    a = a & 0xFFFFFFFF
    a = (a << b) | (a >> (32 - b))
    return a & 0xFFFFFFFF
  end,
  extract = function (a, f, w)
    return (a >> f) & ~(-1 << (w or 1))
  end,
  replace = function (a, v, f, w)
    local mask = ~(-1 << (w or 1))
    return ((a & ~(mask << f)) | ((v & mask) << f)) & 0xFFFFFFFF
  end,
}
        ]] )

elseif bit then

    -- luajit (for now)

    bit32 = load ( [[
local band, bnot, rshift, lshift = bit.band, bit.bnot, bit.rshift, bit.lshift

bit32 = {
  arshift = bit.arshift,
  band    = band,
  bnot    = bnot,
  bor     = bit.bor,
  bxor    = bit.bxor,
  btest   = function(...)
    return band(...) ~= 0
  end,
  extract = function(a,f,w)
    return band(rshift(a,f),2^(w or 1)-1)
  end,
  lrotate = bit.rol,
  lshift  = lshift,
  replace = function(a,v,f,w)
    local mask = 2^(w or 1)-1
    return band(a,bnot(lshift(mask,f)))+lshift(band(v,mask),f)
  end,
  rrotate = bit.ror,
  rshift  = rshift,
}
        ]] )

else

    -- hope for the best or fail

 -- bit32 = require("bit32")

    xpcall(function() local _, t = require("bit32") if t then bit32 = t end return end,function() end)

end

return bit32 or false
