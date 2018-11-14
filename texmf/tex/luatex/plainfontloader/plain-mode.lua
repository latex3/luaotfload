-- plain font reader to test plain mode
-- see https://github.com/u-fischer/luaotfload/pull/26
-- width/bold need luatex 1.09

fonts.readers.plain = function(spec)
  local f = font.read_tfm(spec.forcedname or spec.name, spec.size)
  local s = spec.features.raw.slant
  if s then
    f.slant = tonumber(s)
  end
  local b = spec.features.raw.bold
  if b then
    f.mode = 2
    f.width = f.width*tonumber(b)
  end
  local o = spec.features.raw.outline
  if o then
    f.mode = 1
    f.width = tonumber(o)*1000
  end 
  return f
end
