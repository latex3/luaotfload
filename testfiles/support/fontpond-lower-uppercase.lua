local unicode_data = kpse.find_file("UnicodeData.txt")

local characters = {}

for line in io.lines(unicode_data) do
  local fields = line:explode ";"
  -- we want to process only uppercase letters
  if fields[3] == "Ll" then
    local lowercase = tonumber(fields[1],16)
    -- uppercase codepoint is in field 15
    -- some uppercase letters doesn't have lowercase versions
    local uppercase = tonumber(fields[15],16)
    characters[lowercase] = uppercase
  end
end

return characters
